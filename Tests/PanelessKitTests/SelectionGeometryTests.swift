import CoreGraphics
import Testing
@testable import PanelessKit

struct SelectionGeometryTests {
    let rect = CGRect(x: 100, y: 100, width: 200, height: 100)

    @Test func cornerInitializerNormalizesAnyDragDirection() {
        let expected = CGRect(x: 10, y: 20, width: 30, height: 40)
        #expect(CGRect(corner: CGPoint(x: 10, y: 20), corner: CGPoint(x: 40, y: 60)) == expected)
        #expect(CGRect(corner: CGPoint(x: 40, y: 60), corner: CGPoint(x: 10, y: 20)) == expected)
        #expect(CGRect(corner: CGPoint(x: 40, y: 20), corner: CGPoint(x: 10, y: 60)) == expected)
    }

    @Test(arguments: [
        (SelectionHandle.topLeft, CGPoint(x: 100, y: 100)),
        (.top, CGPoint(x: 200, y: 100)),
        (.topRight, CGPoint(x: 300, y: 100)),
        (.right, CGPoint(x: 300, y: 150)),
        (.bottomRight, CGPoint(x: 300, y: 200)),
        (.bottom, CGPoint(x: 200, y: 200)),
        (.bottomLeft, CGPoint(x: 100, y: 200)),
        (.left, CGPoint(x: 100, y: 150)),
    ])
    func handlePointsSitOnCornersAndEdgeMidpoints(handle: SelectionHandle, expected: CGPoint) {
        #expect(SelectionGeometry.point(for: handle, in: rect) == expected)
        #expect(SelectionGeometry.handle(at: expected, in: rect, size: 7) == handle)
    }

    @Test func handleHitTestingAllowsSlopButIgnoresInterior() {
        #expect(SelectionGeometry.handle(at: CGPoint(x: 106, y: 106), in: rect, size: 7) == .topLeft)
        #expect(SelectionGeometry.handle(at: CGPoint(x: 110, y: 110), in: rect, size: 7) == nil)
        #expect(SelectionGeometry.handle(at: CGPoint(x: 150, y: 130), in: rect, size: 7) == nil)
    }

    @Test(arguments: [
        (SelectionHandle.topLeft, CGRect(x: 50, y: 60, width: 250, height: 140)),
        (.top, CGRect(x: 100, y: 60, width: 200, height: 140)),
        (.topRight, CGRect(x: 100, y: 60, width: 150, height: 140)),
        (.right, CGRect(x: 100, y: 100, width: 150, height: 100)),
        (.bottomRight, CGRect(x: 100, y: 100, width: 150, height: 160)),
        (.bottom, CGRect(x: 100, y: 100, width: 200, height: 160)),
        (.bottomLeft, CGRect(x: 50, y: 100, width: 250, height: 160)),
        (.left, CGRect(x: 50, y: 100, width: 250, height: 100)),
    ])
    func resizeMovesOnlyTheDraggedEdges(handle: SelectionHandle, expected: CGRect) {
        let target: CGPoint = switch handle {
        case .topLeft, .top, .left: CGPoint(x: 50, y: 60)
        case .topRight: CGPoint(x: 250, y: 60)
        case .right, .bottomRight, .bottom: CGPoint(x: 250, y: 260)
        case .bottomLeft: CGPoint(x: 50, y: 260)
        }
        #expect(SelectionGeometry.resize(rect, handle: handle, to: target) == expected)
    }

    @Test func resizingPastTheOppositeEdgeFlipsInsteadOfGoingNegative() {
        let flipped = SelectionGeometry.resize(rect, handle: .topLeft, to: CGPoint(x: 350, y: 260))
        #expect(flipped == CGRect(x: 300, y: 200, width: 50, height: 60))
    }

    @Test func moveKeepsSelectionInsideBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        #expect(SelectionGeometry.move(rect, by: CGPoint(x: 10, y: -20), within: bounds)
            == CGRect(x: 110, y: 80, width: 200, height: 100))
        #expect(SelectionGeometry.move(rect, by: CGPoint(x: -500, y: -500), within: bounds)
            == CGRect(x: 0, y: 0, width: 200, height: 100))
        #expect(SelectionGeometry.move(rect, by: CGPoint(x: 5000, y: 5000), within: bounds)
            == CGRect(x: 800, y: 700, width: 200, height: 100))
    }

    @Test func clampPinsPointsToBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 50)
        #expect(SelectionGeometry.clamp(CGPoint(x: -5, y: 70), to: bounds) == CGPoint(x: 0, y: 50))
        #expect(SelectionGeometry.clamp(CGPoint(x: 40, y: 20), to: bounds) == CGPoint(x: 40, y: 20))
    }

    @Test func pixelRectScalesAndRoundsToWholePixels() {
        let selection = CGRect(x: 10.3, y: 20.6, width: 5.2, height: 5.2)
        #expect(SelectionGeometry.pixelRect(for: selection, scale: 2) == CGRect(x: 21, y: 41, width: 10, height: 10))
        #expect(SelectionGeometry.pixelRect(for: selection, scale: 1) == CGRect(x: 10, y: 21, width: 5, height: 5))
    }
}

struct ToolbarPlacementTests {
    let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let sideSize = CGSize(width: 40, height: 200)
    let bottomSize = CGSize(width: 120, height: 40)

    func frames(for selection: CGRect) -> (side: CGRect, bottom: CGRect) {
        SelectionGeometry.toolbarFrames(selection: selection, sideSize: sideSize, bottomSize: bottomSize, bounds: bounds, gap: 6)
    }

    @Test func toolsSitRightOfSelectionAndActionsBelowIt() {
        let (side, bottom) = frames(for: CGRect(x: 100, y: 100, width: 300, height: 300))
        #expect(side == CGRect(x: 406, y: 200, width: 40, height: 200))
        #expect(bottom == CGRect(x: 280, y: 406, width: 120, height: 40))
    }

    @Test func toolsFlipToTheLeftNearTheRightEdge() {
        let (side, bottom) = frames(for: CGRect(x: 700, y: 100, width: 295, height: 300))
        #expect(side.minX == 654)
        #expect(bottom.maxX == 995)
        #expect(!side.intersects(bottom))
    }

    @Test func actionsMoveAboveSelectionNearTheBottomEdge() {
        let (_, bottom) = frames(for: CGRect(x: 100, y: 500, width: 300, height: 280))
        #expect(bottom.maxY == 494)
    }

    @Test func fullScreenSelectionKeepsBothToolbarsOnScreenWithoutOverlap() {
        let (side, bottom) = frames(for: bounds)
        #expect(bounds.contains(side))
        #expect(bounds.contains(bottom))
        #expect(!side.intersects(bottom))
    }

    @Test func sideToolbarIsClampedToTopOfScreenForShortSelections() {
        let (side, _) = frames(for: CGRect(x: 100, y: 10, width: 100, height: 50))
        #expect(side.minY == 0)
    }
}
