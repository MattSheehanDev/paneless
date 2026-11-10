import CoreGraphics

extension Annotation {
    /// Whether `point` grabs this annotation: near the stroke for lines and shapes (not their
    /// interior, so you can still draw inside a rectangle), anywhere in the box for text and emoji.
    func hitTest(_ point: CGPoint) -> Bool {
        let tolerance = max(strokeWidth / 2 + 4, 6)
        switch shape {
        case .pen(let points), .marker(let points):
            guard let first = points.first else { return false }
            if points.count == 1 { return Self.distance(point, first, first) <= tolerance }
            return zip(points, points.dropFirst()).contains { Self.distance(point, $0, $1) <= tolerance }
        case .line(let a, let b):
            return Self.distance(point, a, b) <= tolerance
        case .arrow(let a, let b):
            return Self.distance(point, a, b) <= tolerance || hypot(point.x - b.x, point.y - b.y) <= arrowHeadLength(a, b)
        case .rectangle(let a, let b):
            let r = CGRect(corner: a, corner: b)
            let corners = [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
                           CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY)]
            return zip(corners, corners.dropFirst() + [corners[0]]).contains { Self.distance(point, $0, $1) <= tolerance }
        case .text, .emoji:
            return boundingRect.contains(point)
        }
    }

    /// Area the annotation covers on screen, used for hit-testing text/emoji and hover outlines.
    var boundingRect: CGRect {
        switch shape {
        case .pen(let points), .marker(let points):
            guard let first = points.first else { return .null }
            let box = points.reduce(CGRect(origin: first, size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
            return box.insetBy(dx: -strokeWidth / 2, dy: -strokeWidth / 2)
        case .line(let a, let b):
            return CGRect(corner: a, corner: b).insetBy(dx: -strokeWidth / 2, dy: -strokeWidth / 2)
        case .arrow(let a, let b):
            let pad = max(strokeWidth / 2, arrowHeadLength(a, b) * 0.55)
            return CGRect(corner: a, corner: b).insetBy(dx: -pad, dy: -pad)
        case .rectangle(let a, let b):
            return CGRect(corner: a, corner: b).insetBy(dx: -strokeWidth / 2, dy: -strokeWidth / 2)
        case .text:
            return (textBounds ?? .null).insetBy(dx: -4, dy: -4)
        case .emoji(_, let center, let size):
            return CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
        }
    }

    func offset(by delta: CGPoint) -> Annotation {
        func move(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + delta.x, y: p.y + delta.y) }
        var copy = self
        switch shape {
        case .pen(let points): copy.shape = .pen(points.map(move))
        case .marker(let points): copy.shape = .marker(points.map(move))
        case .line(let a, let b): copy.shape = .line(move(a), move(b))
        case .arrow(let a, let b): copy.shape = .arrow(move(a), move(b))
        case .rectangle(let a, let b): copy.shape = .rectangle(move(a), move(b))
        case .text(let string, let origin): copy.shape = .text(string, move(origin))
        case .emoji(let emoji, let center, let size): copy.shape = .emoji(emoji, center: move(center), size: size)
        }
        return copy
    }

    var isText: Bool {
        if case .text = shape { return true }
        return false
    }

    private var strokeWidth: CGFloat {
        if case .marker = shape { return Self.markerWidth(lineWidth: lineWidth) }
        return lineWidth
    }

    static func distance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = min(max(((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared, 0), 1)
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }
}

/// Annotations plus snapshot-based undo, so adds, moves and text edits all undo the same way.
struct AnnotationHistory {
    private(set) var annotations: [Annotation] = []
    private var undoStack: [[Annotation]] = []

    var canUndo: Bool { !undoStack.isEmpty }

    /// Records the current state; call before a change that should be undoable.
    mutating func checkpoint() {
        undoStack.append(annotations)
    }

    /// Drops the most recent checkpoint, e.g. when a drag turned out to be a click.
    mutating func discardCheckpoint() {
        _ = undoStack.popLast()
    }

    mutating func add(_ annotation: Annotation) {
        checkpoint()
        annotations.append(annotation)
    }

    /// Appends without a checkpoint, for completing a change that already recorded one.
    mutating func append(_ annotation: Annotation) {
        annotations.append(annotation)
    }

    mutating func replace(at index: Int, with annotation: Annotation) {
        annotations[index] = annotation
    }

    mutating func remove(at index: Int) -> Annotation {
        annotations.remove(at: index)
    }

    mutating func undo() {
        if let previous = undoStack.popLast() { annotations = previous }
    }

    mutating func removeAll() {
        annotations.removeAll()
        undoStack.removeAll()
    }

    /// Topmost annotation under `point`.
    func index(at point: CGPoint) -> Int? {
        annotations.indices.reversed().first { annotations[$0].hitTest(point) }
    }
}
