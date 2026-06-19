import AppKit
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: PopupPanel?
    private var wideMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Default the expanded (Tab) view to the Windows-style wide grid.
        UserDefaults.standard.register(defaults: [AppSettings.expandedWideKey: true])

        // Prompt once for Accessibility — needed for caret-grab + in-place insertion (#3).
        AXPermission.ensureTrusted(prompt: true)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "漢" // text glyph suits a Hanja tool better than any SF Symbol
        let menu = NSMenu()

        let wide = NSMenuItem(
            title: "와이드 확장 보기 (Tab)",
            action: #selector(toggleWide),
            keyEquivalent: ""
        )
        wide.target = self
        wide.state = AppSettings.expandedWide ? .on : .off
        menu.addItem(wide)
        wideMenuItem = wide

        menu.addItem(.separator())
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

    /// Toggle the expanded-view style between the wide (Windows) grid and the compact square grid.
    @objc private func toggleWide() {
        AppSettings.expandedWide.toggle()
        wideMenuItem?.state = AppSettings.expandedWide ? .on : .off
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
