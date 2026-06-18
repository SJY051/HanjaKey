import AppKit

// Menu-bar agent entry point. `.accessory` makes the process a background app with no Dock
// icon or main menu — equivalent to LSUIElement=true, but set at runtime so no Info.plist is
// needed for the SwiftPM executable.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
