import AppKit
import Testing
@testable import PanelessKit

struct AnnotationHitTestTests {
    func make(_ shape: Annotation.Shape, lineWidth: CGFloat = 3) -> Annotation {
        Annotation(shape: shape, color: .red, lineWidth: lineWidth)
    }

    @Test func lineIsGrabbedNearTheStrokeOnly() {
        let line = make(.line(CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)))
        #expect(line.hitTest(CGPoint(x: 50, y: 4)))
        #expect(line.hitTest(CGPoint(x: 100, y: 0)))
        #expect(!line.hitTest(CGPoint(x: 50, y: 20)))
        #expect(!line.hitTest(CGPoint(x: 120, y: 0)))
    }

    @Test func penIsGrabbedAlongAnySegment() {
        let pen = make(.pen([CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 0), CGPoint(x: 50, y: 50)]))
        #expect(pen.hitTest(CGPoint(x: 25, y: 2)))
        #expect(pen.hitTest(CGPoint(x: 52, y: 30)))
        #expect(!pen.hitTest(CGPoint(x: 20, y: 30)))
    }

    @Test func singleDotPenIsGrabbable() {
        let dot = make(.pen([CGPoint(x: 10, y: 10)]))
        #expect(dot.hitTest(CGPoint(x: 13, y: 10)))
        #expect(!dot.hitTest(CGPoint(x: 30, y: 10)))
    }

    @Test func thickMarkerHasAWiderGrabArea() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)]
        let point = CGPoint(x: 50, y: 9)
        #expect(make(.marker(points)).hitTest(point))
        #expect(!make(.pen(points)).hitTest(point))
    }

    @Test func rectangleIsGrabbedByItsBorderNotItsInterior() {
        let rect = make(.rectangle(CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 60)))
        #expect(rect.hitTest(CGPoint(x: 50, y: 1)))
        #expect(rect.hitTest(CGPoint(x: 99, y: 30)))
        #expect(rect.hitTest(CGPoint(x: 50, y: 62)))
        #expect(!rect.hitTest(CGPoint(x: 50, y: 30)))
    }

    @Test func arrowHeadIsGrabbable() {
        let arrow = make(.arrow(CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)))
        #expect(arrow.hitTest(CGPoint(x: 95, y: 8)))
        #expect(!arrow.hitTest(CGPoint(x: 40, y: 15)))
    }

    @Test func textAndEmojiAreGrabbedAnywhereInTheirBox() throws {
        var text = make(.text("", CGPoint(x: 10, y: 10)))
        text.setText("Hello world")
        let bounds = try #require(text.textBounds)
        #expect(text.hitTest(CGPoint(x: bounds.midX, y: bounds.midY)))
        #expect(!text.hitTest(CGPoint(x: bounds.maxX + 20, y: bounds.midY)))

        let emoji = make(.emoji("x", center: CGPoint(x: 50, y: 50), size: 40))
        #expect(emoji.hitTest(CGPoint(x: 65, y: 35)))
        #expect(!emoji.hitTest(CGPoint(x: 80, y: 50)))
    }

    @Test func boundingRectCoversTheStroke() {
        let line = make(.line(CGPoint(x: 10, y: 10), CGPoint(x: 50, y: 10)), lineWidth: 4)
        #expect(line.boundingRect == CGRect(x: 8, y: 8, width: 44, height: 4))
    }
}

struct AnnotationOffsetTests {
    let delta = CGPoint(x: 5, y: -3)

    @Test(arguments: [Tool.pen, .marker, .line, .arrow, .rectangle, .text, .emoji])
    func offsetMovesEveryShapeRigidly(tool: Tool) {
        var annotation = Annotation(tool: tool, at: CGPoint(x: 10, y: 10), color: .red, lineWidth: 3)
        annotation.extend(to: CGPoint(x: 40, y: 30))
        annotation.setText("hi")

        let moved = annotation.offset(by: delta)
        let before = annotation.boundingRect, after = moved.boundingRect
        #expect(abs(after.minX - before.minX - delta.x) < 0.001)
        #expect(abs(after.minY - before.minY - delta.y) < 0.001)
        #expect(abs(after.width - before.width) < 0.001)
        #expect(abs(after.height - before.height) < 0.001)
        #expect(moved.text == annotation.text)
    }
}

struct AnnotationHistoryTests {
    func line(_ y: CGFloat) -> Annotation {
        Annotation(shape: .line(CGPoint(x: 0, y: y), CGPoint(x: 100, y: y)), color: .red, lineWidth: 3)
    }

    @Test func undoRemovesAddedAnnotationsInOrder() {
        var history = AnnotationHistory()
        history.add(line(0))
        history.add(line(50))
        history.undo()
        #expect(history.annotations.count == 1)
        history.undo()
        #expect(history.annotations.isEmpty)
        #expect(!history.canUndo)
        history.undo()
        #expect(history.annotations.isEmpty)
    }

    @Test func undoRestoresPositionAfterMove() {
        var history = AnnotationHistory()
        history.add(line(0))
        let original = history.annotations[0]

        history.checkpoint()
        history.replace(at: 0, with: original.offset(by: CGPoint(x: 0, y: 40)))
        #expect(history.index(at: CGPoint(x: 50, y: 40)) == 0)

        history.undo()
        #expect(history.index(at: CGPoint(x: 50, y: 0)) == 0)
        #expect(history.index(at: CGPoint(x: 50, y: 40)) == nil)
    }

    @Test func discardedCheckpointLeavesNothingToUndo() {
        var history = AnnotationHistory()
        history.add(line(0))
        history.checkpoint()
        history.discardCheckpoint()
        history.undo()
        #expect(history.annotations.isEmpty)
        #expect(!history.canUndo)
    }

    @Test func reeditingTextIsOneUndoStep() {
        var history = AnnotationHistory()
        var text = Annotation(tool: .text, at: CGPoint(x: 10, y: 10), color: .red, lineWidth: 3)
        text.setText("before")
        history.add(text)

        history.checkpoint()
        var editing = history.remove(at: 0)
        editing.setText("after")
        history.append(editing)
        #expect(history.annotations.map(\.text) == ["after"])

        history.undo()
        #expect(history.annotations.map(\.text) == ["before"])
    }

    @Test func hitTestingPicksTheTopmostAnnotation() {
        var history = AnnotationHistory()
        history.add(line(0))
        history.add(line(2))
        #expect(history.index(at: CGPoint(x: 50, y: 1)) == 1)
        #expect(history.index(at: CGPoint(x: 50, y: 200)) == nil)
    }

    @Test func removeAllClearsUndoToo() {
        var history = AnnotationHistory()
        history.add(line(0))
        history.removeAll()
        #expect(history.annotations.isEmpty)
        #expect(!history.canUndo)
    }
}
