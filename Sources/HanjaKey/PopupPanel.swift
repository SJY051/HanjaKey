import AppKit
import SwiftUI

/// A floating panel (Maccy-style) that hosts the SwiftUI candidate UI.
final class PopupPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 320),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .floating
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = true
        animationBehavior = .utilityWindow

        let root = CandidateView(onPick: { [weak self] value in
            Output.copyToClipboard(value)
            self?.orderOut(nil)
        })
        contentView = NSHostingView(rootView: root)
    }

    /// Center on screen, show, and take focus so the text field accepts typing (M1).
    func present() {
        center()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // A panel must opt in to becoming key for its text field to receive input.
    override var canBecomeKey: Bool { true }
}
