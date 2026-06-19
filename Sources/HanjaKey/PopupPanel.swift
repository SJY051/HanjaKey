import AppKit
import SwiftUI

/// A floating, borderless panel (Maccy-style) hosting the SwiftUI candidate list and committing
/// the pick back into the frontmost app (in place when possible).
final class PopupPanel: NSPanel {
    private var context: AXContext?
    private var lastScreenRect: CGRect?

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
        self.lastScreenRect = context?.screenRect
        let reading = context?.source ?? ""
        let view = CandidateView(
            reading: reading,
            onPick: { [weak self] in self?.commit($0) },
            onCancel: { [weak self] in self?.cancel() },
            onResize: { [weak self] size in self?.resize(to: size) }
        )
        let hosting = NSHostingView(rootView: view)
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 12
        hosting.layer?.cornerCurve = .continuous
        hosting.layer?.masksToBounds = true // clip the hosting layer's square corners to the glass shape
        contentView = hosting
        hosting.layoutSubtreeIfNeeded()      // ensure fittingSize reflects the laid-out SwiftUI content
        setContentSize(hosting.fittingSize)  // size the panel to the SwiftUI content
        positionNearCaret(lastScreenRect)
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

    /// Re-fit and re-place the panel when the SwiftUI content changes size (e.g. decomposition view).
    private func resize(to size: CGSize) {
        guard size.width > 1, size.height > 1, size != frame.size else { return }
        // Top-left stays put; grow down/right. Resize IMMEDIATELY (no NSAnimationContext): the SwiftUI
        // content already animates via withAnimation, and animating the frame on top of it raced — the
        // window jumped right then settled. Letting the frame follow the content reads smoother.
        let origin = NSPoint(x: frame.minX, y: frame.maxY - size.height)
        setFrame(NSRect(origin: origin, size: size), display: true)
    }

    /// Dismiss without inserting; return focus to the original app.
    private func cancel() {
        orderOut(nil)
        context?.app.activate(options: [.activateAllWindows])
    }

    private func positionNearCaret(_ rect: CGRect?) {
        // AX rects are global with a TOP-left origin relative to the PRIMARY screen; convert to
        // Cocoa's bottom-left global space using the primary (menu-bar) screen's height.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let caretBottom: NSPoint  // anchor at the caret bottom (or mouse) in Cocoa global coords
        let caretTop: CGFloat
        if let rect, rect != .zero {
            caretBottom = NSPoint(x: rect.minX, y: primaryHeight - rect.maxY)
            caretTop = primaryHeight - rect.minY
        } else {
            let mouse = NSEvent.mouseLocation // already Cocoa global — a sensible fallback
            caretBottom = mouse
            caretTop = mouse.y
        }
        let screen = NSScreen.screens.first(where: { $0.frame.contains(caretBottom) })
            ?? NSScreen.main ?? NSScreen.screens.first
        var origin = NSPoint(x: caretBottom.x, y: caretBottom.y - frame.height - 4) // just below caret
        if let visible = screen?.visibleFrame {
            if origin.y < visible.minY { origin.y = caretTop + 4 } // no room below → above the caret
            // Clamp fully inside the visible frame so the panel never clips off-screen.
            origin.x = min(max(origin.x, visible.minX), visible.maxX - frame.width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - frame.height)
        }
        setFrameOrigin(origin)
    }

    override var canBecomeKey: Bool { true }
}
