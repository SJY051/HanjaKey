import AppKit
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: PopupPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prompt once for Accessibility — needed for caret-grab + in-place insertion (#3).
        AXPermission.ensureTrusted(prompt: true)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "漢" // text glyph suits a Hanja tool better than any SF Symbol
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Quit HanjaKey",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        item.menu = menu
        statusItem = item

        KeyboardShortcuts.onKeyUp(for: .summon) { [weak self] in
            self?.togglePanel()
        }
    }

    /// Capture the editing context in the frontmost app, then show the candidate popup.
    private func togglePanel() {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            return
        }
        let context = AXContext.capture() // nil → popup falls back to type-in + clipboard
        let panel = self.panel ?? PopupPanel()
        self.panel = panel
        panel.present(context: context)
    }
}
