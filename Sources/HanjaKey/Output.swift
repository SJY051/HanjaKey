import AppKit

/// Output sinks for a chosen candidate.
enum Output {
    /// Copy the chosen character to the system clipboard (used when there's no in-place target — the
    /// user will paste it themselves, so this one is a normal, history-worthy copy).
    static func copyToClipboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    /// Pasteboard type that asks well-behaved clipboard managers (per nspasteboard.org) to ignore an
    /// entry. We tag every *internal* clipboard write with it — the ⌘C peeks, the clipboard restores,
    /// and the staged in-place ⌘V — so HanjaKey's plumbing never pollutes the user's clipboard history.
    static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    /// Write `string` to the general pasteboard marked transient (managers skip it), or clear it when
    /// `string` is nil. Used to stage the in-place paste and to restore the user's clipboard after peeks.
    static func writeTransient(_ string: String?, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        guard let string else { return }
        pasteboard.setString(string, forType: .string)
        pasteboard.setData(Data(), forType: transientType)
    }

    /// Synthesize a Shift+← key event (select one char to the left). Requires Accessibility.
    static func synthesizeShiftLeft() {
        guard let src = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: src, virtualKey: 0x7B /* left arrow */, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: 0x7B, keyDown: false) else { return }
        down.flags = .maskShift
        up.flags = .maskShift
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    /// Synthesize a ⌘V key event into the frontmost app. Requires Accessibility permission.
    static func synthesizeCmdV() {
        guard let src = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: src, virtualKey: 9 /* v */, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false) else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    /// Synthesize a ⌘C key event (copy the current selection). Requires Accessibility.
    static func synthesizeCmdC() {
        guard let src = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: src, virtualKey: 8 /* c */, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: 8, keyDown: false) else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    /// Synthesize a Shift+→ key event (shrink a leftward selection from its left edge, or extend
    /// right). Requires Accessibility.
    static func synthesizeShiftRight() {
        guard let src = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: src, virtualKey: 0x7C /* right arrow */, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: 0x7C, keyDown: false) else { return }
        down.flags = .maskShift
        up.flags = .maskShift
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    /// Synthesize a plain → key event (collapse a selection to its right end). Requires Accessibility.
    ///
    /// The flags are explicitly cleared. HanjaKey is triggered by ⌥⌘H, so the user is usually still
    /// physically holding ⌘/⌥ when capture() runs. With a `.combinedSessionState` source the event
    /// inherits those LIVE hardware modifiers unless we override them — turning this → into ⌘→ ("move
    /// to the end of the line"), which mid-sentence jumped the caret to the visual line end and made
    /// insert() overwrite (and lose) the trailing text. The other helpers are immune only because they
    /// set `.flags` explicitly; this one must do the same with an empty set.
    static func synthesizeRightArrow() {
        guard let src = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: src, virtualKey: 0x7C /* right arrow */, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: 0x7C, keyDown: false) else { return }
        down.flags = []
        up.flags = []
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
