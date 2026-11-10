import AppKit
import Testing
@testable import PanelessKit

/// 200×100 px screenshot of a 100×50 pt "Retina" screen. Red channel marks the left half,
/// blue the right half, green the top half, so both crop position and orientation are checkable.
struct SelectionRendererTests {
    let screenSize = CGSize(width: 100, height: 50)
    let screenshot = TestImage.make(width: 200, height: 100) { x, y in
        RGBA(r: x < 100 ? 255 : 0, g: y < 50 ? 255 : 0, b: x >= 100 ? 255 : 0)
    }

    func render(_ selection: CGRect, _ annotations: [Annotation] = []) -> CGImage? {
        SelectionRenderer.render(screenshot: screenshot, screenSize: screenSize, selection: selection, annotations: annotations)
    }

    @Test func outputIsAtNativePixelResolution() throws {
        let image = try #require(render(CGRect(x: 10, y: 5, width: 30, height: 20)))
        #expect(image.width == 60)
        #expect(image.height == 40)
    }

    @Test func cropsTopRightQuadrant() throws {
        let image = try #require(render(CGRect(x: 50, y: 0, width: 50, height: 25)))
        let cyan = RGBA(r: 0, g: 255, b: 255)
        for (x, y) in [(0, 0), (99, 0), (0, 49), (99, 49)] {
            #expect(TestImage.pixel(image, x: x, y: y) == cyan)
        }
    }

    @Test func cropsBottomLeftQuadrantWithoutFlipping() throws {
        let image = try #require(render(CGRect(x: 0, y: 25, width: 50, height: 25)))
        let red = RGBA(r: 255, g: 0, b: 0)
        #expect(TestImage.pixel(image, x: 0, y: 0) == red)
        #expect(TestImage.pixel(image, x: 99, y: 49) == red)
    }

    @Test func annotationsAreDrawnInSelectionSpaceAndScaled() throws {
        let rectangle = Annotation(
            shape: .rectangle(CGPoint(x: 60, y: 5), CGPoint(x: 90, y: 20)),
            color: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1),
            lineWidth: 4
        )
        let image = try #require(render(CGRect(x: 50, y: 0, width: 50, height: 25), [rectangle]))

        // Top edge at y = 5pt → 10px; x = 75pt is 25pt into the selection → 50px.
        #expect(TestImage.pixel(image, x: 50, y: 10).isClose(to: RGBA(r: 0, g: 0, b: 0)))
        // Left edge at x = 60pt → 20px.
        #expect(TestImage.pixel(image, x: 20, y: 25).isClose(to: RGBA(r: 0, g: 0, b: 0)))
        // Interior is untouched screenshot.
        #expect(TestImage.pixel(image, x: 50, y: 25) == RGBA(r: 0, g: 255, b: 255))
    }

    @Test func annotationsOutsideSelectionAreNotVisible() throws {
        let dot = Annotation(shape: .pen([CGPoint(x: 10, y: 10)]), color: .black, lineWidth: 6)
        let image = try #require(render(CGRect(x: 50, y: 0, width: 50, height: 25), [dot]))
        for (x, y) in [(0, 0), (50, 25), (99, 49)] {
            #expect(TestImage.pixel(image, x: x, y: y) == RGBA(r: 0, g: 255, b: 255))
        }
    }

    @Test func markerIsTranslucent() throws {
        let marker = Annotation(shape: .marker([CGPoint(x: 70, y: 12), CGPoint(x: 80, y: 12)]), color: .black, lineWidth: 3)
        let image = try #require(render(CGRect(x: 50, y: 0, width: 50, height: 25), [marker]))
        let pixel = TestImage.pixel(image, x: 50, y: 24)
        #expect(pixel.g > 100 && pixel.g < 200, "expected a 40% black wash over cyan, got \(pixel)")
    }

    @Test func selectionOverhangingTheScreenIsClipped() throws {
        let image = try #require(render(CGRect(x: 90, y: 40, width: 20, height: 20)))
        #expect(image.width == 20)
        #expect(image.height == 20)
    }

    @Test func emptyOrOffscreenSelectionRendersNothing() {
        #expect(render(.zero) == nil)
        #expect(render(CGRect(x: 10, y: 10, width: 0.1, height: 20)) == nil)
        #expect(render(CGRect(x: 500, y: 500, width: 20, height: 20)) == nil)
    }
}

extension Annotation {
    init(shape: Shape, color: NSColor, lineWidth: CGFloat) {
        self.init(tool: .pen, at: .zero, color: color, lineWidth: lineWidth)
        self.shape = shape
    }
}
