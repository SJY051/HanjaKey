import AppKit
import SwiftUI

/// A floating, borderless panel (Maccy-style) hosting the SwiftUI candidate list and committing
/// the pick back into the frontmost app (in place when possible).
final class PopupPanel: NSPanel {
    private var context: AXContext?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 360),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear // let the SwiftUI material + rounded corners show through
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = true
        animationBehavior = .utilityWindow
    }

    /// Show the popup for a captured context (nil → type-in + clipboard fallback).
    func present(context: AXContext?) {
        self.context = context
        let reading = context?.source ?? ""
        let view = CandidateView(
            reading: reading,
            onPick: { [weak self] in self?.commit($0) },
            onCancel: { [weak self] in self?.cancel() }
        )
        let hosting = NSHostingView(rootView: view)
        contentView = hosting
        setContentSize(hosting.fittingSize) // size the panel to the SwiftUI content
        positionNearCaret(context?.screenRect)
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func commit(_ chosen: String) {
        orderOut(nil)
        if let context {
            context.insert(chosen)          // in-place: re-select source, reactivate target, ⌘V
        } else {
            Output.copyToClipboard(chosen)  // no context → clipboard (M1 fallback)
        }
    }

    /// Dismiss without inserting; return focus to the original app.
    private func cancel() {
        orderOut(nil)
        context?.app.activate(options: [.activateAllWindows])
    }

    private func positionNearCaret(_ rect: CGRect?) {
        guard let rect, rect != .zero, let screen = NSScreen.screens.first else { center(); return }
        // AX rect is screen coords with a TOP-left origin; AppKit window origin is BOTTOM-left.
        let caretBottomCocoaY = screen.frame.height - rect.maxY
        var origin = NSPoint(x: rect.minX, y: caretBottomCocoaY - frame.height - 4) // just below caret
        if origin.y < screen.visibleFrame.minY { // would clip off the bottom → flip above the caret
            origin.y = (screen.frame.height - rect.minY) + 4
        }
        setFrameOrigin(origin)
    }

    override var canBecomeKey: Bool { true }
}
