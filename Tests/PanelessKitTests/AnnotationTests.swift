import AppKit
import Testing
@testable import PanelessKit

struct AnnotationTests {
    let start = CGPoint(x: 10, y: 10)
    let end = CGPoint(x: 50, y: 40)

    func annotation(_ tool: Tool) -> Annotation {
        Annotation(tool: tool, at: start, color: .red, lineWidth: 3)
    }

    @Test func penAndMarkerAccumulatePoints() {
        for tool in [Tool.pen, .marker] {
            var a = annotation(tool)
            a.extend(to: CGPoint(x: 20, y: 20))
            a.extend(to: end)
            switch a.shape {
            case .pen(let points), .marker(let points):
                #expect(points == [start, CGPoint(x: 20, y: 20), end])
            default:
                Issue.record("unexpected shape \(a.shape) for \(tool)")
            }
        }
    }

    @Test func twoPointShapesKeepStartAndTrackEnd() {
        for tool in [Tool.line, .arrow, .rectangle] {
            var a = annotation(tool)
            a.extend(to: CGPoint(x: 99, y: 99))
            a.extend(to: end)
            switch a.shape {
            case .line(let s, let e), .arrow(let s, let e), .rectangle(let s, let e):
                #expect(s == start)
                #expect(e == end)
            default:
                Issue.record("unexpected shape \(a.shape) for \(tool)")
            }
        }
    }

    @Test func textIgnoresDragAndOnlyTextAcceptsText() {
        var text = annotation(.text)
        text.extend(to: end)
        text.setText("hello")
        #expect(text.text == "hello")
        if case .text(_, let origin) = text.shape { #expect(origin == start) }

        var line = annotation(.line)
        line.setText("nope")
        #expect(line.text == nil)
    }

    @Test func textBoundsGrowWithLinesAndCaretFollowsLastLine() throws {
        var a = annotation(.text)
        a.setText("one")
        let single = try #require(a.textBounds)
        #expect(single.origin == start)
        #expect(single.height == a.lineHeight)

        a.setText("one\ntwo\n")
        let multi = try #require(a.textBounds)
        #expect(multi.height == a.lineHeight * 3)

        let caret = try #require(a.caretRect)
        #expect(caret.minY == start.y + a.lineHeight * 2)
        #expect(caret.minX == start.x + 1)
    }

    @Test func fontSizeTracksLineWidth() {
        let thin = Annotation(tool: .text, at: .zero, color: .red, lineWidth: 2)
        let thick = Annotation(tool: .text, at: .zero, color: .red, lineWidth: 6)
        #expect(thick.font.pointSize > thin.font.pointSize)
    }

    @Test(arguments: Tool.allCases)
    func everyToolHasAValidSymbol(tool: Tool) {
        #expect(NSImage(systemSymbolName: tool.symbol, accessibilityDescription: nil) != nil)
        #expect(!tool.title.isEmpty)
    }
}

struct TextInputTests {
    @Test(arguments: [
        ("abc", "abc"),
        ("héllo 😀", "héllo 😀"),
        ("a\rb\tc", "abc"),
        ("\u{7F}", ""),
        ("\u{F700}\u{F703}x", "x"), // arrow-key function glyphs
    ])
    func keepsOnlyPrintableCharacters(input: String, expected: String) {
        #expect(TextInput.printable(input) == expected)
    }
}
