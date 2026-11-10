import AppKit

enum SelectionRenderer {
    /// Crops `screenshot` to `selection` (in points of a screen `screenSize` points wide) and draws
    /// `annotations` on top, at the screenshot's native pixel resolution.
    static func render(
        screenshot: CGImage,
        screenSize: CGSize,
        selection: CGRect,
        annotations: [Annotation]
    ) -> CGImage? {
        let scale = CGFloat(screenshot.width) / max(screenSize.width, 1)
        let imageBounds = CGRect(x: 0, y: 0, width: screenshot.width, height: screenshot.height)
        let pixelRect = SelectionGeometry.pixelRect(for: selection, scale: scale).intersection(imageBounds)
        guard !pixelRect.isNull, pixelRect.width >= 1, pixelRect.height >= 1,
              let cropped = screenshot.cropping(to: pixelRect),
              let colorSpace = screenshot.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: Int(pixelRect.width),
                  height: Int(pixelRect.height),
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }

        context.draw(cropped, in: CGRect(origin: .zero, size: pixelRect.size))

        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: 0, y: pixelRect.height / scale)
        context.scaleBy(x: 1, y: -1)
        context.translateBy(x: -pixelRect.minX / scale, y: -pixelRect.minY / scale)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        annotations.forEach { $0.draw() }
        NSGraphicsContext.restoreGraphicsState()

        return context.makeImage()
    }
}
