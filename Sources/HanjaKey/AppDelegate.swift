import AppKit
import SwiftUI
import KeyboardShortcuts

extension Notification.Name {
    /// Posted from the popup's ⋯ menu to open the preferences window.
    static let hkOpenSettings = Notification.Name("hk.openSettings")
    /// Posted when the "show menu-bar icon" setting changes, so the status item is added/removed live.
    static let hkMenuBarVisibilityChanged = Notification.Name("hk.menuBarVisibilityChanged")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: PopupPanel?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            AppSettings.expandedWideKey: true,    // wide expanded grid by default
            AppSettings.showMenuBarIconKey: true, // show the menu-bar icon by default
        ])
        UserSymbols.ensureTemplate() // write a starter symbols.json on first run

        // Prompt once for Accessibility — needed for caret-grab + in-place insertion.
        AXPermission.ensureTrusted(prompt: true)

        applyMenuBarVisibility()

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(openSettings), name: .hkOpenSettings, object: nil)
        center.addObserver(self, selector: #selector(applyMenuBarVisibility),
                           name: .hkMenuBarVisibilityChanged, object: nil)

        KeyboardShortcuts.onKeyUp(for: .summon) { [weak self] in
            self?.togglePanel()
        }
    }

    /// Add or remove the menu-bar status item to match the user's setting.
    @objc private func applyMenuBarVisibility() {
        if AppSettings.showMenuBarIcon {
            guard statusItem == nil else { return }
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.title = "漢" // text glyph suits a Hanja tool better than any SF Symbol
            item.menu = buildMenu()
            statusItem = item
        } else if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    private func buildMenu() -> NSMenu {
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
        return menu
    }

    /// Open (or focus) the preferences window hosting `SettingsView`.
    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 460),
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
