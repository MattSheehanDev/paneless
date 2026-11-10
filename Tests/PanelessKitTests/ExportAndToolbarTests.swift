import AppKit
import Testing
@testable import PanelessKit

@MainActor
struct ImageExporterTests {
    let image = TestImage.make(width: 40, height: 20) { _, _ in RGBA(r: 10, g: 20, b: 30) }

    @Test func defaultFileNameMatchesMacOSScreenshotStyle() {
        let name = ImageExporter.defaultFileName(date: Date(timeIntervalSince1970: 0), timeZone: TimeZone(identifier: "UTC")!)
        #expect(name == "Screenshot 1970-01-01 at 00.00.00.png")
    }

    @Test(arguments: ["png", "PNG", "", "tiff"])
    func encodesPNGByDefault(pathExtension: String) throws {
        let data = try #require(ImageExporter.encodedData(image, pointSize: CGSize(width: 20, height: 10), pathExtension: pathExtension))
        #expect(Array(data.prefix(4)) == [0x89, 0x50, 0x4E, 0x47])
    }

    @Test(arguments: ["jpg", "JPEG"])
    func encodesJPEGForJPEGExtensions(pathExtension: String) throws {
        let data = try #require(ImageExporter.encodedData(image, pointSize: .zero, pathExtension: pathExtension))
        #expect(Array(data.prefix(2)) == [0xFF, 0xD8])
    }

    @Test func pngRoundTripsPixels() throws {
        let data = try #require(ImageExporter.encodedData(image, pointSize: .zero, pathExtension: "png"))
        let decoded = try #require(NSBitmapImageRep(data: data)?.cgImage)
        #expect(decoded.width == 40)
        #expect(TestImage.pixel(decoded, x: 5, y: 5) == RGBA(r: 10, g: 20, b: 30))
    }

    @Test func bitmapCarriesPointSizeForRetinaPaste() {
        let rep = ImageExporter.bitmap(image, pointSize: CGSize(width: 20, height: 10))
        #expect(rep.pixelsWide == 40)
        #expect(rep.size == CGSize(width: 20, height: 10))
    }
}

@MainActor
struct ToolbarViewTests {
    let items: [ToolbarView.Item] = [
        .init(id: "a", symbol: "pencil", tooltip: "A"),
        .init(id: "b", symbol: nil, tooltip: "B"),
        .init(id: "c", symbol: "xmark", tooltip: "C"),
    ]

    @Test func verticalToolbarStacksItems() {
        let bar = ToolbarView(items: items, axis: .vertical)
        let length = 3 * ToolbarView.itemSize + 2 * ToolbarView.inset
        #expect(bar.frame.size == CGSize(width: ToolbarView.itemSize + 2 * ToolbarView.inset, height: length))
        #expect(bar.rect(forItem: "c")?.minY == ToolbarView.inset + 2 * ToolbarView.itemSize)
    }

    @Test func horizontalToolbarLaysItemsInARow() {
        let bar = ToolbarView(items: items, axis: .horizontal)
        #expect(bar.frame.width > bar.frame.height)
        #expect(bar.rect(forItem: "b")?.minX == ToolbarView.inset + ToolbarView.itemSize)
        #expect(bar.rect(forItem: "missing") == nil)
    }

    @Test func clickingAnItemReportsItsID() throws {
        let bar = ToolbarView(items: items, axis: .horizontal)
        var clicked: [String] = []
        bar.onClick = { clicked.append($0) }

        let window = NSWindow(contentRect: bar.frame, styleMask: .borderless, backing: .buffered, defer: true)
        window.contentView = bar
        let center = try #require(bar.rect(forItem: "c"))
        let pointInWindow = bar.convert(CGPoint(x: center.midX, y: center.midY), to: nil)
        let event = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown, location: pointInWindow, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        ))
        bar.mouseDown(with: event)
        #expect(clicked == ["c"])
    }

    @Test func emojiItemsRenderInColorInsteadOfTheirSymbol() throws {
        let bar = ToolbarView(items: items, axis: .horizontal)
        let glyph = "\u{1F534}" // red circle
        bar.itemEmoji = ["a": glyph]

        let rep = try #require(bar.bitmapImageRepForCachingDisplay(in: bar.bounds))
        bar.cacheDisplay(in: bar.bounds, to: rep)
        let image = try #require(rep.cgImage)
        let item = try #require(bar.rect(forItem: "a"))
        let scale = CGFloat(image.width) / bar.bounds.width
        let center = TestImage.pixel(image, x: Int(item.midX * scale), y: Int(item.midY * scale))
        #expect(center.r > 150 && center.g < 100 && center.b < 100, "expected a red emoji, got \(center)")
    }

    @Test func paletteColorsAreDistinct() {
        let colors = ColorPaletteView.colors
        #expect(colors.count == 12)
        #expect(Set(colors.map { $0.description }).count == colors.count)
    }
}
