import AppKit
import ScreenCaptureKit

struct ScreenCapture {
    let screen: NSScreen
    let image: CGImage
    /// App window frames on this screen, front to back, in the overlay's flipped coordinates.
    let windowFrames: [CGRect]
}

enum ScreenCapturer {
    @MainActor
    static func captureAllScreens() async throws -> [ScreenCapture] {
        let pid = ProcessInfo.processInfo.processIdentifier
        let windows = WindowList.onScreenWindowFrames(excludingPID: pid)
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let ownApp = content.applications.filter { $0.processID == pid }

        var captures: [ScreenCapture] = []
        for screen in NSScreen.screens {
            guard let displayID = screen.displayID,
                  let display = content.displays.first(where: { $0.displayID == displayID })
            else { continue }

            let filter = SCContentFilter(display: display, excludingApplications: ownApp, exceptingWindows: [])
            let config = SCStreamConfiguration()
            let scale = screen.backingScaleFactor
            config.width = Int(screen.frame.width * scale)
            config.height = Int(screen.frame.height * scale)
            config.showsCursor = false
            config.captureResolution = .best

            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            let windowFrames = WindowList.viewRects(windows, screenFrame: screen.frame, primaryScreenHeight: primaryHeight)
            captures.append(ScreenCapture(screen: screen, image: image, windowFrames: windowFrames))
        }
        return captures
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
