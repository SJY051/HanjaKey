import Foundation
import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp` (macOS 13+) for the "launch at login" preference.
///
/// The system is the source of truth — we never mirror this into `UserDefaults`, because the user can
/// also toggle it from System Settings ▸ General ▸ Login Items. Always read `isEnabled` (i.e. `status`)
/// rather than a cached flag.
enum LaunchAtLogin {
    /// The toggle's on/off state: registered, whether or not it still needs user approval.
    static var isEnabled: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval: return true
        default: return false
        }
    }

    /// `true` when registration succeeded but the user must still approve it in System Settings
    /// (e.g. they previously disabled the login item there). It won't actually launch until approved.
    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// Register or unregister the main app as a login item. Returns the resulting `isEnabled` so the
    /// caller can reflect the real state (registration can land in `.requiresApproval`).
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        let service = SMAppService.mainApp
        do {
            if enabled {
                switch service.status {
                case .enabled, .requiresApproval: break          // already registered
                default: try service.register()
                }
            } else {
                switch service.status {
                case .enabled, .requiresApproval: try service.unregister()
                default: break                                    // nothing to undo
                }
            }
        } catch {
            NSLog("[HanjaKey] LaunchAtLogin.setEnabled(\(enabled)) failed: \(error.localizedDescription)")
        }
        return isEnabled
    }

    /// Open System Settings ▸ General ▸ Login Items so the user can approve or manage the item.
    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
