import AppKit

/// Output sinks for a chosen candidate.
enum Output {
    /// M1: copy the chosen character to the system clipboard.
    static func copyToClipboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    /// M2: read the selected text in the frontmost app.
    /// Requires Accessibility permission. Strategy: AXUIElement `kAXSelectedTextAttribute`,
    /// with a clipboard-shuttle (synth ⌘C → read pasteboard → restore) fallback.
    static func selectedTextFromFrontmostApp() -> String? {
        // TODO (M2): implement via Accessibility. Returns nil if unavailable / not permitted.
        return nil
    }

    /// M2: paste the chosen result into the frontmost app (synthesized ⌘V via CGEvent).
    /// Requires Accessibility permission.
    static func pasteIntoFrontmostApp(_ string: String) {
        // TODO (M2): set pasteboard, then post a ⌘V key event with CGEvent.
    }
}
