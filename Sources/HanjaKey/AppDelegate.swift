import AppKit
import SwiftUI
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: PopupPanel?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Default the expanded (Tab) view to the Windows-style wide grid.
        UserDefaults.standard.register(defaults: [AppSettings.expandedWideKey: true])
        UserSymbols.ensureTemplate() // write a starter symbols.json on first run

        // Prompt once for Accessibility — needed for caret-grab + in-place insertion (#3).
        AXPermission.ensureTrusted(prompt: true)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "漢" // text glyph suits a Hanja tool better than any SF Symbol
        let menu = NSMenu()

        let settings = NSMenuItem(title: "설정…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

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

    /// Open (or focus) the preferences window hosting `SettingsView`.
    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 280),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "HanjaKey 설정"
            window.contentView = NSHostingView(rootView: SettingsView())
            window.isReleasedWhenClosed = false // reuse across opens
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
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
