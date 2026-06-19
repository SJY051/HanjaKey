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

/// A captured editing context: the Hangul to convert (read via AX), how many chars to re-select
/// before pasting, the target app, and the caret rect for popup positioning.
///
/// Reading uses Accessibility; *writing* uses synthesized key events (Shift+← then ⌘V), because
/// AX text-writes are unreliable in Electron (they report success but do nothing) and AX
/// selection is unreadable in some Electron apps.
struct AXContext {
    let app: NSRunningApplication
    let source: String
    let selectBack: Int     // chars to select backward before pasting (0 if already selected)
    let screenRect: CGRect

    static func capture() -> AXContext? {
        guard AXPermission.ensureTrusted(prompt: false) else { return nil }
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.processIdentifier != NSRunningApplication.current.processIdentifier else { return nil }

        let appEl = AXUIElementCreateApplication(frontApp.processIdentifier)
        // Force Chromium/Electron (and some browsers) to expose their AX tree.
        AXUIElementSetAttributeValue(appEl, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(appEl, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)

        var focusedObj: CFTypeRef?
        var err = AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &focusedObj)
        if err != .success { // Electron may need a beat after enabling AX; retry once.
            err = AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &focusedObj)
        }
        guard err == .success, let focused = focusedObj, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let el = focused as! AXUIElement

        var selObj: CFTypeRef?
        let selected = (AXUIElementCopyAttributeValue(el, kAXSelectedTextAttribute as CFString, &selObj) == .success)
            ? (selObj as? String ?? "") : ""

        var caretRange = CFRange(location: 0, length: 0)
        var rangeObj: CFTypeRef?
        if AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &rangeObj) == .success,
           let ro = rangeObj, CFGetTypeID(ro) == AXValueGetTypeID() {
            AXValueGetValue((ro as! AXValue), .cfRange, &caretRange)
        }

        var source = ""
        var selectBack = 0
        var rectRange = caretRange
        let caret = Int(caretRange.location)

        if !selected.isEmpty, containsHangul(selected) {
            source = selected
            selectBack = 0                  // already selected → ⌘V replaces it
            rectRange = caretRange
        } else {
            // Read the char before the caret with REAL key events rather than AX: Electron/Chromium
            // serve a STALE AX value/caret right after typing (the AX tree updates asynchronously),
            // so select one char to the left and copy it — the editor's true state, never stale.
            let pasteboard = NSPasteboard.general
            let saved = pasteboard.string(forType: .string)
            let beforeCount = pasteboard.changeCount
            Output.synthesizeShiftLeft()
            Output.synthesizeCmdC()
            // Wait briefly for the target app (a separate process) to service ⌘C; stop once it does.
            var copied = ""
            for _ in 0..<24 { // up to ~120ms
                usleep(5_000)
                if pasteboard.changeCount != beforeCount {
                    copied = pasteboard.string(forType: .string) ?? ""
                    break
                }
            }
            // Restore the clipboard and collapse the probe selection (caret back where it started).
            pasteboard.clearContents()
            if let saved { pasteboard.setString(saved, forType: .string) }
            Output.synthesizeRightArrow()

            if containsHangul(copied) {
                source = copied
                selectBack = copied.utf16.count   // insert() re-selects this many chars before ⌘V
                if caret > 0 { rectRange = CFRange(location: caret - 1, length: 1) }
            }
        }

        guard !source.isEmpty else { return nil }

        // On-screen rect of the source, for positioning the popup near the caret (best-effort).
        var screenRect = CGRect.zero
        var tr = rectRange
        if let axRange = AXValueCreate(.cfRange, &tr) {
            var boundsObj: CFTypeRef?
            if AXUIElementCopyParameterizedAttributeValue(el, kAXBoundsForRangeParameterizedAttribute as CFString, axRange, &boundsObj) == .success,
               let bo = boundsObj, CFGetTypeID(bo) == AXValueGetTypeID() {
                AXValueGetValue((bo as! AXValue), .cgRect, &screenRect)
            }
        }
        return AXContext(app: frontApp, source: source, selectBack: selectBack, screenRect: screenRect)
    }

    /// Insert `replacement` over the source using synthesized keys: reactivate the target, select
    /// `selectBack` chars to the left (if not already selected), then ⌘V; restore the clipboard.
    func insert(_ replacement: String) {
        app.activate(options: [.activateAllWindows]) // bring the target fully forward (reliable focus return)

        let pasteboard = NSPasteboard.general
        let saved = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        pasteboard.setString(replacement, forType: .string)

        let back = selectBack
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { // let focus return to the target
            for _ in 0..<back { Output.synthesizeShiftLeft() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                Output.synthesizeCmdV()
                if let saved {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        pasteboard.clearContents()
                        pasteboard.setString(saved, forType: .string)
                    }
                }
            }
        }
    }
}
