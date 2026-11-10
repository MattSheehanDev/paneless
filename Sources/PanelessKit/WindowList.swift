import CoreGraphics
import Foundation

enum WindowList {
    /// Frames of normal app windows, front to back, in Quartz global coordinates
    /// (origin at the top-left of the primary display, y growing downward).
    static func onScreenWindowFrames(excludingPID pid: pid_t) -> [CGRect] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        return frames(from: info, excludingPID: pid)
    }

    /// Keeps regular (layer 0), visible, reasonably sized windows not owned by `pid`, preserving order.
    static func frames(from info: [[String: Any]], excludingPID pid: pid_t) -> [CGRect] {
        info.compactMap { window in
            guard (window[kCGWindowLayer as String] as? Int) == 0,
                  (window[kCGWindowOwnerPID as String] as? Int).map(pid_t.init) != pid,
                  (window[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let bounds = window[kCGWindowBounds as String],
                  let rect = CGRect(dictionaryRepresentation: bounds as! CFDictionary),
                  rect.width >= 40, rect.height >= 40
            else { return nil }
            return rect
        }
    }

    /// Converts a Quartz global rect into the flipped coordinates of an overlay covering `screenFrame`
    /// (a Cocoa screen frame, origin at the bottom-left of the primary display).
    static func viewRect(_ quartzRect: CGRect, screenFrame: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: quartzRect.minX - screenFrame.minX,
            y: quartzRect.minY - (primaryScreenHeight - screenFrame.maxY),
            width: quartzRect.width,
            height: quartzRect.height
        )
    }

    /// What a plain click selects: the frontmost window under `point`, or the whole screen over the desktop.
    static func snapTarget(at point: CGPoint, windowFrames: [CGRect], screenBounds: CGRect) -> CGRect {
        windowFrames.first { $0.contains(point) } ?? screenBounds
    }

    /// Window frames in overlay coordinates, clipped to the overlay and dropping windows on other screens.
    static func viewRects(_ quartzRects: [CGRect], screenFrame: CGRect, primaryScreenHeight: CGFloat) -> [CGRect] {
        let bounds = CGRect(origin: .zero, size: screenFrame.size)
        return quartzRects.compactMap { rect in
            let clipped = viewRect(rect, screenFrame: screenFrame, primaryScreenHeight: primaryScreenHeight).intersection(bounds)
            return clipped.isNull || clipped.width < 1 || clipped.height < 1 ? nil : clipped
        }
    }
}
