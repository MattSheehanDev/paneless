import AppKit

enum Tool: String, CaseIterable {
    case pen, line, arrow, rectangle, marker, text, emoji

    var symbol: String {
        switch self {
        case .pen: "pencil"
        case .line: "line.diagonal"
        case .arrow: "arrow.up.right"
        case .rectangle: "rectangle"
        case .marker: "highlighter"
        case .text: "textformat"
        case .emoji: "face.smiling"
        }
    }

    var title: String {
        switch self {
        case .pen: "Pen"
        case .line: "Line"
        case .arrow: "Arrow"
        case .rectangle: "Rectangle"
        case .marker: "Marker"
        case .text: "Text"
        case .emoji: "Emoji"
        }
    }
}

struct Annotation {
    enum Shape {
        case pen([CGPoint])
        case marker([CGPoint])
        case line(CGPoint, CGPoint)
        case arrow(CGPoint, CGPoint)
        case rectangle(CGPoint, CGPoint)
        case text(String, CGPoint)
        /// Emoji centered on a point, `size` points tall.
        case emoji(String, center: CGPoint, size: CGFloat)
    }

    static let minimumEmojiSize: CGFloat = 16

    var shape: Shape
    var color: NSColor
    var lineWidth: CGFloat

    init(tool: Tool, at point: CGPoint, color: NSColor, lineWidth: CGFloat, emoji: String = "😀") {
        self.color = color
        self.lineWidth = lineWidth
        switch tool {
        case .pen: shape = .pen([point])
        case .marker: shape = .marker([point])
        case .line: shape = .line(point, point)
        case .arrow: shape = .arrow(point, point)
        case .rectangle: shape = .rectangle(point, point)
        case .text: shape = .text("", point)
        case .emoji: shape = .emoji(emoji, center: point, size: Self.defaultEmojiSize(lineWidth: lineWidth))
        }
    }

    static func defaultEmojiSize(lineWidth: CGFloat) -> CGFloat {
        minimumEmojiSize + lineWidth * 6
    }

    mutating func extend(to point: CGPoint) {
        switch shape {
        case .pen(let points): shape = .pen(points + [point])
        case .marker(let points): shape = .marker(points + [point])
        case .line(let start, _): shape = .line(start, point)
        case .arrow(let start, _): shape = .arrow(start, point)
        case .rectangle(let start, _): shape = .rectangle(start, point)
        case .text: break
        case .emoji(let emoji, let center, let size):
            // Dragging away from the stamp point scales the emoji; a plain click keeps the default size.
            let dragged = hypot(point.x - center.x, point.y - center.y) * 2
            shape = .emoji(emoji, center: center, size: dragged >= Self.minimumEmojiSize ? dragged : size)
        }
    }

    // MARK: Text

    var font: NSFont { .systemFont(ofSize: 10 + lineWidth * 3, weight: .semibold) }

    var lineHeight: CGFloat { NSLayoutManager().defaultLineHeight(for: font) }

    var text: String? {
        if case .text(let string, _) = shape { return string }
        return nil
    }

    mutating func setText(_ string: String) {
        if case .text(_, let origin) = shape { shape = .text(string, origin) }
    }

    /// Bounding box of a text annotation, including empty trailing lines.
    var textBounds: CGRect? {
        guard case .text(let string, let origin) = shape else { return nil }
        let lines = string.components(separatedBy: "\n")
        let width = lines.map { NSAttributedString(string: $0, attributes: textAttributes).size().width }.max() ?? 0
        return CGRect(x: origin.x, y: origin.y, width: max(width, 2), height: CGFloat(lines.count) * lineHeight)
    }

    /// Insertion point at the end of the text, as a vertical line segment.
    var caretRect: CGRect? {
        guard case .text(let string, let origin) = shape else { return nil }
        let lines = string.components(separatedBy: "\n")
        let lastWidth = NSAttributedString(string: lines.last ?? "", attributes: textAttributes).size().width
        return CGRect(
            x: origin.x + lastWidth + 1,
            y: origin.y + CGFloat(lines.count - 1) * lineHeight,
            width: 1.5,
            height: lineHeight
        )
    }

    private var textAttributes: [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: color]
    }

    // MARK: Drawing (expects a flipped graphics context)

    func draw() {
        switch shape {
        case .pen(let points):
            strokePolyline(points, color: color, width: lineWidth)
        case .marker(let points):
            strokePolyline(points, color: color.withAlphaComponent(0.4), width: Self.markerWidth(lineWidth: lineWidth))
        case .line(let start, let end):
            let path = NSBezierPath()
            path.move(to: start)
            path.line(to: end)
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            color.setStroke()
            path.stroke()
        case .arrow(let start, let end):
            drawArrow(from: start, to: end)
        case .rectangle(let start, let end):
            let path = NSBezierPath(rect: CGRect(corner: start, corner: end))
            path.lineWidth = lineWidth
            path.lineJoinStyle = .miter
            color.setStroke()
            path.stroke()
        case .text(let string, let origin):
            NSAttributedString(string: string, attributes: textAttributes).draw(at: origin)
        case .emoji(let emoji, let center, let size):
            let string = Self.emojiString(emoji, size: size)
            let bounds = string.size()
            string.draw(at: CGPoint(x: center.x - bounds.width / 2, y: center.y - bounds.height / 2))
        }
    }

    /// Emoji line height runs ~1.2× the font size, so this keeps the drawn glyph close to `size` tall.
    static func emojiString(_ emoji: String, size: CGFloat) -> NSAttributedString {
        NSAttributedString(string: emoji, attributes: [.font: NSFont.systemFont(ofSize: size / 1.2)])
    }

    private func strokePolyline(_ points: [CGPoint], color: NSColor, width: CGFloat) {
        guard let first = points.first else { return }
        color.set()
        if points.count == 1 {
            NSBezierPath(ovalIn: CGRect(x: first.x - width / 2, y: first.y - width / 2, width: width, height: width)).fill()
            return
        }
        let path = NSBezierPath()
        path.move(to: first)
        points.dropFirst().forEach { path.line(to: $0) }
        path.lineWidth = width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    private func drawArrow(from start: CGPoint, to end: CGPoint) {
        let dx = end.x - start.x, dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 0.5 else { return }

        let headLength = arrowHeadLength(start, end)
        let headHalfWidth = headLength * 0.55
        let ux = dx / length, uy = dy / length
        let base = CGPoint(x: end.x - ux * headLength, y: end.y - uy * headLength)

        color.set()
        let shaft = NSBezierPath()
        shaft.move(to: start)
        shaft.line(to: base)
        shaft.lineWidth = lineWidth
        shaft.lineCapStyle = .round
        shaft.stroke()

        let head = NSBezierPath()
        head.move(to: end)
        head.line(to: CGPoint(x: base.x - uy * headHalfWidth, y: base.y + ux * headHalfWidth))
        head.line(to: CGPoint(x: base.x + uy * headHalfWidth, y: base.y - ux * headHalfWidth))
        head.close()
        head.fill()
    }

    func arrowHeadLength(_ start: CGPoint, _ end: CGPoint) -> CGFloat {
        min(max(12, lineWidth * 4), hypot(end.x - start.x, end.y - start.y))
    }

    static func markerWidth(lineWidth: CGFloat) -> CGFloat {
        max(lineWidth * 4, 12)
    }
}

enum TextInput {
    /// Drops control characters and AppKit function-key glyphs (arrows, F-keys) from typed input.
    static func printable(_ characters: String) -> String {
        characters.filter { character in
            character.unicodeScalars.allSatisfy {
                $0.value >= 0x20 && $0.value != 0x7F && !(0xF700...0xF8FF).contains($0.value)
            }
        }
    }
}
