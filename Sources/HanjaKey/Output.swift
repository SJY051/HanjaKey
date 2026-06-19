import AppKit

/// Output sinks for a chosen candidate.
enum Output {
    /// Copy the chosen character to the system clipboard (used when there's no in-place target).
    static func copyToClipboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
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

    /// Synthesize a → key event (collapse a selection to its right end). Requires Accessibility.
    static func synthesizeRightArrow() {
        guard let src = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: src, virtualKey: 0x7C /* right arrow */, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: 0x7C, keyDown: false) else { return }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
