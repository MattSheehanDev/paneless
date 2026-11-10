import AppKit

final class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = true
        hasShadow = false
        backgroundColor = .black
        isReleasedWhenClosed = false
        animationBehavior = .none
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// One frozen-screen overlay per display, alive from hotkey press until copy/save/cancel.
@MainActor
final class CaptureSession: OverlayViewDelegate {
    var onFinish: (() -> Void)?

    private var windows: [OverlayWindow] = []
    private var overlays: [OverlayView] = []
    private let previousApp = NSWorkspace.shared.frontmostApplication

    init(captures: [ScreenCapture]) {
        for capture in captures {
            let window = OverlayWindow(screen: capture.screen)
            let size = capture.screen.frame.size

            let container = NSView(frame: NSRect(origin: .zero, size: size))
            container.wantsLayer = true

            let background = NSView(frame: container.bounds)
            background.wantsLayer = true
            background.layer?.contents = capture.image
            background.layer?.contentsGravity = .resize
            background.autoresizingMask = [.width, .height]
            container.addSubview(background)

            let overlay = OverlayView(frame: container.bounds, screenshot: capture.image, windowFrames: capture.windowFrames)
            overlay.autoresizingMask = [.width, .height]
            overlay.delegate = self
            container.addSubview(overlay)

            window.contentView = container
            windows.append(window)
            overlays.append(overlay)
        }
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        windows.forEach { $0.orderFrontRegardless() }

        let mouse = NSEvent.mouseLocation
        let index = windows.firstIndex { NSMouseInRect(mouse, $0.frame, false) } ?? 0
        if windows.indices.contains(index) {
            windows[index].makeKeyAndOrderFront(nil)
            windows[index].makeFirstResponder(overlays[index])
            overlays[index].pointerMoved(toWindowPoint: windows[index].convertPoint(fromScreen: mouse))
        }
    }

    private func close(restoreFocus: Bool = true) {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        overlays.removeAll()
        NSCursor.arrow.set()
        if restoreFocus { previousApp?.activate() }
        onFinish?()
    }

    // MARK: OverlayViewDelegate

    func overlayViewDidBeginSelection(_ view: OverlayView) {
        for overlay in overlays where overlay !== view {
            overlay.clearSelection()
        }
        view.window?.makeKey()
    }

    func overlayViewDidCancel(_ view: OverlayView) {
        close()
    }

    func overlayView(_ view: OverlayView, didRequest action: ExportAction) {
        guard let image = view.renderSelection() else { return }
        let pointSize = view.selection?.size ?? .zero
        switch action {
        case .copy:
            close()
            ImageExporter.copy(image, pointSize: pointSize)
        case .save:
            let previousApp = previousApp
            close(restoreFocus: false)
            ImageExporter.save(image, pointSize: pointSize) { previousApp?.activate() }
        }
    }
}
