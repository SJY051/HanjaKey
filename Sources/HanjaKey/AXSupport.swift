import AppKit
import ApplicationServices

enum AXPermission {
    /// Returns whether the process is trusted for Accessibility; pass `prompt: true` to show the
    /// system permission dialog (once) when it isn't.
    @discardableResult
    static func ensureTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }
}

private func isHangul(_ u: unichar) -> Bool {
    (u >= 0xAC00 && u <= 0xD7A3) || (u >= 0x3131 && u <= 0x3163) // syllables or compatibility jamo
}

private func containsHangul(_ s: String) -> Bool {
    s.unicodeScalars.contains { isHangul(unichar($0.value & 0xFFFF)) }
}

/// Best-effort read of a string AX attribute (used for diagnostic selected-text read-backs).
private func axString(_ el: AXUIElement, _ attr: String) -> String? {
    var obj: CFTypeRef?
    guard AXUIElementCopyAttributeValue(el, attr as CFString, &obj) == .success else { return nil }
    return obj as? String
}

/// A captured editing context: the Hangul to convert (read via AX), how many chars to re-select
/// before pasting, the target app, and the caret rect for popup positioning.
///
/// Reading uses Accessibility; *writing* uses synthesized key events (Shift+← then ⌘V), because
/// AX text-writes are unreliable in Electron (they report success but do nothing) and AX
/// selection is unreadable in some Electron apps.
struct AXContext {
    let app: NSRunningApplication
    let source: String
    let selectBack: Int     // captured-run length; the active-token length is passed to insert() per pick
    let screenRect: CGRect
    let canReplace: Bool    // false → no confirmed selection; insert() copies to the clipboard instead
    let autoCaptured: Bool  // true → we synthesized the grab (segment it); false → user's own selection

    static let maxCapture = 6 // grab up to a 6-syllable 어절 before the caret (matches the word dict)

    /// The trailing run of Hangul (syllables or jamo) at the end of `s` — the 어절 just before the caret.
    static func trailingHangulRun(_ s: String) -> String {
        var scalars: [Unicode.Scalar] = []
        for scalar in s.unicodeScalars.reversed() {
            if isHangul(unichar(scalar.value & 0xFFFF)) { scalars.append(scalar) } else { break }
        }
        return String(String.UnicodeScalarView(scalars.reversed()))
    }

    static func capture() -> AXContext? {
        CaptureLog.session()
        guard AXPermission.ensureTrusted(prompt: false) else {
            CaptureLog.log("guard: not AX-trusted → nil"); return nil
        }
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.processIdentifier != NSRunningApplication.current.processIdentifier else {
            CaptureLog.log("guard: no frontmost app (or self is front) → nil"); return nil
        }
        CaptureLog.log("app: \(frontApp.bundleIdentifier ?? "?") (\(frontApp.localizedName ?? "?")) pid=\(frontApp.processIdentifier)")

        let appEl = AXUIElementCreateApplication(frontApp.processIdentifier)
        // Force Chromium/Electron (and some browsers) to expose their AX tree.
        AXUIElementSetAttributeValue(appEl, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(appEl, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)

        var focusedObj: CFTypeRef?
        var err = AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &focusedObj)
        // Chromium/Electron build their AX tree lazily after AXManualAccessibility is set, so the first
        // read right after a keystroke often returns -25212 (cannotComplete). Retry a few times; if it
        // still fails we DON'T give up (spec 006 FR-006) — the ⌘C auto-capture path below needs no AX element.
        var tries = 1
        while err != .success && tries < 4 {
            usleep(25_000)
            err = AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &focusedObj)
            tries += 1
        }
        let el: AXUIElement? = (err == .success && focusedObj != nil
            && CFGetTypeID(focusedObj!) == AXUIElementGetTypeID()) ? (focusedObj as! AXUIElement) : nil
        if el == nil {
            CaptureLog.log("focused unavailable (err=\(err.rawValue)) after \(tries) tries → AX-less ⌘C capture")
        } else if tries > 1 {
            CaptureLog.log("focused: ok after \(tries) tries")
        }
        if let el, let role = axString(el, kAXRoleAttribute) { CaptureLog.log("focused role: \(role)") }

        var selected = ""
        if let el {
            var selObj: CFTypeRef?
            if AXUIElementCopyAttributeValue(el, kAXSelectedTextAttribute as CFString, &selObj) == .success {
                selected = selObj as? String ?? ""
            }
        }

        var caretRange = CFRange(location: 0, length: 0)
        if let el {
            var rangeObj: CFTypeRef?
            if AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &rangeObj) == .success,
               let ro = rangeObj, CFGetTypeID(ro) == AXValueGetTypeID() {
                AXValueGetValue((ro as! AXValue), .cfRange, &caretRange)
            }
        }

        var source = ""
        var selectBack = 0
        var canReplace = true
        var autoCaptured = false
        var rectRange = caretRange
        let caret = Int(caretRange.location)
        CaptureLog.log("initial: selected=\(CaptureLog.vis(selected)) caretRange=(loc=\(caretRange.location), len=\(caretRange.length))")

        if !selected.isEmpty, containsHangul(selected) {
            source = selected
            selectBack = 0                  // already selected → ⌘V replaces it
            rectRange = caretRange
            CaptureLog.log("path: already-selected → source=\(CaptureLog.vis(source))")
        } else {
            // Read the Hangul 어절 before the caret with REAL key events rather than AX: Electron/
            // Chromium serve a STALE AX value/caret right after typing (the AX tree updates async).
            // Select up to maxCapture chars left, copy, then keep only the trailing Hangul run.
            CaptureLog.log("path: auto-capture (no usable selection)")
            let pasteboard = NSPasteboard.general
            let saved = pasteboard.string(forType: .string)
            let beforeCount = pasteboard.changeCount
            for _ in 0..<maxCapture { Output.synthesizeShiftLeft() }
            Output.synthesizeCmdC()
            // Wait briefly for the target app (a separate process) to service ⌘C; stop once it does.
            var copied = ""
            var polls = 0
            var pollOK = false
            for _ in 0..<24 { // up to ~120ms
                usleep(5_000)
                polls += 1
                if pasteboard.changeCount != beforeCount {
                    copied = pasteboard.string(forType: .string) ?? ""
                    pollOK = true
                    break
                }
            }
            // Restore the clipboard, marked transient so the probe copy is skipped by clipboard managers.
            Output.writeTransient(saved, to: pasteboard)
            CaptureLog.log("⌘C poll: \(pollOK ? "ok" : "TIMEOUT") after \(polls)×5ms, copied=\(CaptureLog.vis(copied))")

            let run = trailingHangulRun(copied)
            CaptureLog.log("trailingHangulRun=\(CaptureLog.vis(run))")
            if run.isEmpty {
                CaptureLog.log("run empty → right-arrow collapse, will fall through to nil")
                Output.synthesizeRightArrow()  // nothing to convert → collapse, restoring the caret
            } else {
                source = run
                autoCaptured = true
                let n = run.count
                rectRange = caret > 0 ? CFRange(location: max(0, caret - n), length: n) : caretRange

                // The probe left a selection that ENDS at the caret and runs up to maxCapture steps to
                // the left. Trim it down to exactly `run` by shrinking from the LEFT (Shift+→), checking
                // the clipboard after each step until the selection equals `run`. Only a clipboard-
                // confirmed selection is safe to paste over; otherwise insert() uses the clipboard.
                //
                // Why not AX range writes, or an arrow collapse + re-select? Electron mis-maps AX offsets
                // (read space ≠ write space — newlines counted differently), and an arrow COLLAPSE drifts
                // across empty paragraphs onto another line. Shrinking keeps the right edge anchored at
                // the caret, so the trailing run is preserved while the over-captured prefix is trimmed.
                // The clipboard is the only reliable witness of the live selection in Electron; native
                // fields shrink cleanly too, so one path covers both.
                canReplace = shrinkSelectionToRun(run: run)
                if canReplace {
                    // spec 006: collapse the probe selection NOW, while focus is still clean (the popup
                    // hasn't stolen it yet) — a right-arrow lands the caret at the run's right edge (the
                    // original caret). insert() re-selects via selectBack before ⌘V. Leaving NO live
                    // selection means cancelling can't clobber the user's text (the post-blur collapse on
                    // cancel was unreliable).
                    Output.synthesizeRightArrow()
                    selectBack = n
                } else {
                    selectBack = 0
                }
                CaptureLog.log("shrink result: canReplace=\(canReplace) selectBack=\(selectBack)")
            }
        }

        guard !source.isEmpty else {
            CaptureLog.log("guard: source empty → nil (nothing recognized)"); return nil
        }

        // On-screen rect of the source, for positioning the popup near the caret (best-effort).
        var screenRect = CGRect.zero
        if let el {
            var tr = rectRange
            if let axRange = AXValueCreate(.cfRange, &tr) {
                var boundsObj: CFTypeRef?
                if AXUIElementCopyParameterizedAttributeValue(el, kAXBoundsForRangeParameterizedAttribute as CFString, axRange, &boundsObj) == .success,
                   let bo = boundsObj, CFGetTypeID(bo) == AXValueGetTypeID() {
                    AXValueGetValue((bo as! AXValue), .cgRect, &screenRect)
                }
            }
        }
        CaptureLog.log("RESULT: source=\(CaptureLog.vis(source)) selectBack=\(selectBack) canReplace=\(canReplace) screenRect=\(screenRect)")
        return AXContext(app: frontApp, source: source, selectBack: selectBack, screenRect: screenRect, canReplace: canReplace, autoCaptured: autoCaptured)
    }

    /// Shrink the live selection from its LEFT edge down to exactly `run`, confirming via the clipboard
    /// after each step. The selection is expected to already END at the caret and be LEFT-active (the
    /// over-select probe makes exactly that), so Shift+→ moves the left edge rightward while the trailing
    /// run at the right edge — anchored at the caret — is preserved. Returns true only when the clipboard
    /// confirms the selection equals `run`: the only reliable witness in Electron, where AX selection
    /// reads/writes lie and an arrow collapse drifts across empty paragraphs.
    private static func shrinkSelectionToRun(run: String) -> Bool {
        let n = run.count
        let pb = NSPasteboard.general
        let saved = pb.string(forType: .string)

        // Generous cap: the over-selection is a few steps wide, but Shift+←/→ aren't perfectly symmetric
        // around empty paragraphs, so allow headroom. We stop the instant the clipboard reads `run`.
        // After every peek we put the user's clipboard straight back (transient), so the fragments we
        // copy never linger on the pasteboard or reach clipboard-manager history.
        for step in 0..<(maxCapture * 2) {
            let sel = copySelection(pb)
            Output.writeTransient(saved, to: pb)
            CaptureLog.log("shrink step \(step): sel=\(CaptureLog.vis(sel))")
            if sel == run { return true }
            guard sel.hasSuffix(run), sel.count > n else { break } // run no longer at the right edge → unsafe
            Output.synthesizeShiftRight()
        }

        // Couldn't confirm. Collapse back ONTO the caret without a drifting arrow collapse: the anchor
        // stayed at the caret, so pressing Shift+→ until the selection is empty lands the caret there.
        // Leaves no stray selection; report failure so insert() uses the clipboard.
        for _ in 0..<(maxCapture * 2) {
            let sel = copySelection(pb)
            Output.writeTransient(saved, to: pb)
            if sel.isEmpty { break }
            Output.synthesizeShiftRight()
        }
        CaptureLog.log("shrink: could not confirm selection == run → clipboard fallback")
        return false
    }

    /// ⌘C the current selection and return what landed on the pasteboard (best-effort, ~120ms).
    private static func copySelection(_ pb: NSPasteboard) -> String {
        let before = pb.changeCount
        Output.synthesizeCmdC()
        for _ in 0..<24 { // up to ~120ms
            usleep(5_000)
            if pb.changeCount != before { return pb.string(forType: .string) ?? "" }
        }
        return ""
    }

    /// Insert `replacement` over the source using synthesized keys: reactivate the target, select
    /// `selectBack` chars to the left (if not already selected), then ⌘V; restore the clipboard.
    func insert(_ replacement: String, selectBack overrideBack: Int? = nil) {
        let back = overrideBack ?? selectBack   // the active token's length (spec 007), else the whole run
        CaptureLog.log("insert: replacement=\(CaptureLog.vis(replacement)) selectBack=\(back) canReplace=\(canReplace) app=\(app.bundleIdentifier ?? "?")")
        guard canReplace else {
            // No selection we could confirm → don't paste over the wrong text. Hand the result to the
            // clipboard and return focus; the user pastes it where they want.
            Output.copyToClipboard(replacement)
            app.activate(options: [.activateAllWindows])
            return
        }
        app.activate(options: [.activateAllWindows]) // bring the target fully forward (reliable focus return)

        let pasteboard = NSPasteboard.general
        let saved = pasteboard.string(forType: .string)
        Output.writeTransient(replacement, to: pasteboard) // stage the paste, marked transient (managers skip)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { // let focus return to the target
            for _ in 0..<back { Output.synthesizeShiftLeft() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                Output.synthesizeCmdV()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { // ⌘V done → restore the user's clipboard
                    Output.writeTransient(saved, to: pasteboard)
                }
            }
        }
    }
}
