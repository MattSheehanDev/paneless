import CoreGraphics
import Testing
@testable import PanelessKit

struct WindowListTests {
    func window(_ rect: CGRect, layer: Int = 0, pid: Int = 100, alpha: Double = 1) -> [String: Any] {
        [
            kCGWindowBounds as String: rect.dictionaryRepresentation,
            kCGWindowLayer as String: layer,
            kCGWindowOwnerPID as String: pid,
            kCGWindowAlpha as String: alpha,
        ]
    }

    @Test func keepsOnlyVisibleNormalWindowsOfOtherAppsInZOrder() {
        let front = CGRect(x: 10, y: 10, width: 300, height: 200)
        let back = CGRect(x: 50, y: 50, width: 800, height: 600)
        let info = [
            window(CGRect(x: 0, y: 0, width: 1440, height: 30), layer: 25), // menu bar
            window(front),
            window(CGRect(x: 0, y: 0, width: 500, height: 500), pid: 42), // Paneless itself
            window(CGRect(x: 0, y: 0, width: 500, height: 500), alpha: 0),
            window(CGRect(x: 0, y: 0, width: 20, height: 20)), // tiny helper window
            window(back),
        ]
        #expect(WindowList.frames(from: info, excludingPID: 42) == [front, back])
    }

    @Test func ignoresEntriesWithoutBounds() {
        let info: [[String: Any]] = [[kCGWindowLayer as String: 0, kCGWindowOwnerPID as String: 1]]
        #expect(WindowList.frames(from: info, excludingPID: 42).isEmpty)
    }

    @Test func convertsQuartzRectsOnThePrimaryScreen() {
        let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let rect = WindowList.viewRect(CGRect(x: 100, y: 50, width: 400, height: 300), screenFrame: primary, primaryScreenHeight: 900)
        #expect(rect == CGRect(x: 100, y: 50, width: 400, height: 300))
    }

    @Test func convertsQuartzRectsOnASecondaryScreen() {
        // External 1920×1080 display to the right of a 1440×900 primary, bottoms aligned:
        // its Cocoa frame is (1440, 0) and its top edge sits at Quartz y = 900 - 1080 = -180.
        let external = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let quartz = CGRect(x: 1540, y: -130, width: 400, height: 300)
        let rect = WindowList.viewRect(quartz, screenFrame: external, primaryScreenHeight: 900)
        #expect(rect == CGRect(x: 100, y: 50, width: 400, height: 300))
    }

    @Test func viewRectsClipToTheScreenAndDropOtherScreensWindows() {
        let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let rects = WindowList.viewRects(
            [
                CGRect(x: 1300, y: 800, width: 400, height: 300), // hangs off the bottom-right
                CGRect(x: 2000, y: 0, width: 400, height: 300), // on another display
            ],
            screenFrame: primary,
            primaryScreenHeight: 900
        )
        #expect(rects == [CGRect(x: 1300, y: 800, width: 140, height: 100)])
    }

    @Test func clickSnapsToFrontmostWindowOrWholeScreen() {
        let bounds = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let front = CGRect(x: 100, y: 100, width: 300, height: 300)
        let back = CGRect(x: 0, y: 0, width: 800, height: 600)
        let windows = [front, back]

        #expect(WindowList.snapTarget(at: CGPoint(x: 200, y: 200), windowFrames: windows, screenBounds: bounds) == front)
        #expect(WindowList.snapTarget(at: CGPoint(x: 600, y: 500), windowFrames: windows, screenBounds: bounds) == back)
        #expect(WindowList.snapTarget(at: CGPoint(x: 1000, y: 800), windowFrames: windows, screenBounds: bounds) == bounds)
    }
}
