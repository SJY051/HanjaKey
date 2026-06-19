import Foundation

/// Lightweight user preferences backed by `UserDefaults`. Shared between the AppKit menu and the
/// SwiftUI popup (which observes the same keys via `@AppStorage`).
///
/// Named `AppSettings` rather than `Settings` to avoid colliding with SwiftUI's `Settings` scene.
enum AppSettings {
    static let expandedWideKey = "expandedWide"
    static let halfwidthSymbolsKey = "halfwidthSymbols"
    static let showMenuBarIconKey = "showMenuBarIcon"

    /// Whether the Tab-expanded view uses the wide Windows-style grid (`true`) or the compact
    /// square grid (`false`).
    static var expandedWide: Bool {
        get { UserDefaults.standard.bool(forKey: expandedWideKey) }
        set { UserDefaults.standard.set(newValue, forKey: expandedWideKey) }
    }

    /// Whether jamo special symbols are inserted halfwidth (`!0A`) instead of fullwidth (`！０Ａ`).
    static var halfwidthSymbols: Bool {
        get { UserDefaults.standard.bool(forKey: halfwidthSymbolsKey) }
        set { UserDefaults.standard.set(newValue, forKey: halfwidthSymbolsKey) }
    }

    /// Whether the menu-bar 漢 icon is shown. When off, reach settings/quit from the popup's ⋯ menu.
    static var showMenuBarIcon: Bool {
        get { UserDefaults.standard.bool(forKey: showMenuBarIconKey) }
        set { UserDefaults.standard.set(newValue, forKey: showMenuBarIconKey) }
    }
}
