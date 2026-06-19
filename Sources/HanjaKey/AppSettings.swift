import Foundation

/// Lightweight user preferences backed by `UserDefaults`. Shared between the AppKit menu and the
/// SwiftUI popup (which observes the same keys via `@AppStorage`).
///
/// Named `AppSettings` rather than `Settings` to avoid colliding with SwiftUI's `Settings` scene.
enum AppSettings {
    static let expandedWideKey = "expandedWide"

    /// Whether the Tab-expanded view uses the wide Windows-style grid (`true`) or the compact
    /// square grid (`false`).
    static var expandedWide: Bool {
        get { UserDefaults.standard.bool(forKey: expandedWideKey) }
        set { UserDefaults.standard.set(newValue, forKey: expandedWideKey) }
    }
}
