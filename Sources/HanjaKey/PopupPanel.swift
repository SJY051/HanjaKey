import AppKit
import SwiftUI

/// A floating, borderless panel (Maccy-style) hosting the SwiftUI candidate list and committing
/// the pick back into the frontmost app (in place when possible).
final class PopupPanel: NSPanel {
    private var context: AXContext?
    private var target: NSRunningApplication?  // app to return focus to, even when capture (context) is nil
    private var lastScreenRect: CGRect?
    private var clickMonitor: Any?             // global click-away → dismiss (replaces hidesOnDeactivate)

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
        // spec 006 cold-start fix: macOS 14 can deny a not-user-clicked app's activate-steal (a global
        // hotkey doesn't count), so HanjaKey isn't truly frontmost on the first invocation. With
        // auto-hide ON, the floating panel is then hidden as "deactivated" and never renders (onScreen
        // stayed false for 18s in the log). Keep it visible regardless of active state; dismissal is
        // explicit (esc / pick / toggle, + an outside-click monitor to be added).
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
    }

    /// Show the popup for a captured context (nil → type-in + clipboard fallback).
    func present(context: AXContext?, target: NSRunningApplication?) {
        self.context = context
        self.target = target
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
        // spec 006 A1 (drop NSApp.activate) was tried and FAILED: a floating panel of an inactive agent
        // app does not render — present logged visible=true but nothing drew. The popup REQUIRES
        // activation to display, so focus theft is unavoidable with this panel; char-loss is addressed at
        // the selection layer instead (see spec 006, revised).
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        CaptureLog.log("present: key=\(isKeyWindow) appActive=\(NSApp.isActive) visible=\(isVisible) onScreen=\(occlusionState.contains(.visible))")
        // occlusionState settles async; re-check whether the panel actually rendered on screen (the
        // present-time visible=true can lie — see the A1 cold-start finding, spec 006).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else { return }
            CaptureLog.log("present+250ms: onScreen=\(self.occlusionState.contains(.visible)) key=\(self.isKeyWindow) appActive=\(NSApp.isActive) front=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?")")
        }
        installOutsideClickDismiss()
    }

    /// Dismiss when the user clicks another app/window — replaces `hidesOnDeactivate` (turned off for the
    /// cold-start fix). A GLOBAL monitor only sees clicks OUTSIDE our own app, so clicking the panel
    /// itself never triggers it; installed on present, torn down on any orderOut.
    private func installOutsideClickDismiss() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.dismiss()
        }
    }

    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
    }

    private func commit(_ chosen: String) {
        orderOut(nil)
        if let context {
            context.insert(chosen)          // in-place: re-select source, reactivate target, ⌘V
        } else {
            Output.copyToClipboard(chosen)  // no context → clipboard (M1 fallback)
            target?.activate(options: [.activateAllWindows]) // still return focus to the source app
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            CaptureLog.log("commit+200ms: front=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?")")
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
    private func cancel() { dismiss() }

    /// Hide the panel and return focus to the source app. Used by cancel/esc AND by the hotkey
    /// toggle-close — both must restore focus or HanjaKey stays frontmost and the next capture sees
    /// itself as front (the Chromium "list doesn't appear / focus doesn't return" cascade). Falls back
    /// to `target` (recorded before the panel stole focus) when there is no AX context.
    func dismiss() {
        orderOut(nil)
        let back = context?.app ?? target
        back?.activate(options: [.activateAllWindows])
        // No selection to restore: capture collapses its probe selection at capture time (spec 006), so
        // cancel is a true no-op for the source text — just hide and return focus.
        CaptureLog.log("dismiss: reactivate \(back?.bundleIdentifier ?? "?")")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            CaptureLog.log("dismiss+200ms: front=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?")")
        }
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
