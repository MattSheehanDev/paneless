import CoreGraphics

/// Resize handles around the selection. Coordinates are flipped (y grows downward), so "top" is `minY`.
enum SelectionHandle: CaseIterable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
}

enum SelectionGeometry {
    static func point(for handle: SelectionHandle, in r: CGRect) -> CGPoint {
        switch handle {
        case .topLeft: CGPoint(x: r.minX, y: r.minY)
        case .top: CGPoint(x: r.midX, y: r.minY)
        case .topRight: CGPoint(x: r.maxX, y: r.minY)
        case .right: CGPoint(x: r.maxX, y: r.midY)
        case .bottomRight: CGPoint(x: r.maxX, y: r.maxY)
        case .bottom: CGPoint(x: r.midX, y: r.maxY)
        case .bottomLeft: CGPoint(x: r.minX, y: r.maxY)
        case .left: CGPoint(x: r.minX, y: r.midY)
        }
    }

    static func handleRect(_ handle: SelectionHandle, in rect: CGRect, size: CGFloat) -> CGRect {
        let p = point(for: handle, in: rect)
        return CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size)
    }

    static func handle(at point: CGPoint, in rect: CGRect, size: CGFloat, slop: CGFloat = 4) -> SelectionHandle? {
        SelectionHandle.allCases.first { handleRect($0, in: rect, size: size).insetBy(dx: -slop, dy: -slop).contains(point) }
    }

    /// Drags `handle` to `p`; dragging past the opposite edge flips the rect rather than inverting it.
    static func resize(_ r: CGRect, handle: SelectionHandle, to p: CGPoint) -> CGRect {
        var minX = r.minX, maxX = r.maxX, minY = r.minY, maxY = r.maxY
        switch handle {
        case .topLeft: minX = p.x; minY = p.y
        case .top: minY = p.y
        case .topRight: maxX = p.x; minY = p.y
        case .right: maxX = p.x
        case .bottomRight: maxX = p.x; maxY = p.y
        case .bottom: maxY = p.y
        case .bottomLeft: minX = p.x; maxY = p.y
        case .left: minX = p.x
        }
        return CGRect(corner: CGPoint(x: minX, y: minY), corner: CGPoint(x: maxX, y: maxY))
    }

    static func move(_ rect: CGRect, by delta: CGPoint, within bounds: CGRect) -> CGRect {
        var moved = rect.offsetBy(dx: delta.x, dy: delta.y)
        moved.origin.x = min(max(moved.minX, bounds.minX), bounds.maxX - moved.width)
        moved.origin.y = min(max(moved.minY, bounds.minY), bounds.maxY - moved.height)
        return moved
    }

    static func clamp(_ p: CGPoint, to bounds: CGRect) -> CGPoint {
        CGPoint(x: min(max(p.x, bounds.minX), bounds.maxX), y: min(max(p.y, bounds.minY), bounds.maxY))
    }

    /// Lightshot placement: tools to the right of the selection (bottom-aligned), actions below it
    /// (right-aligned), falling back to the opposite side and then inside the selection near screen edges.
    static func toolbarFrames(
        selection: CGRect,
        sideSize: CGSize,
        bottomSize: CGSize,
        bounds: CGRect,
        gap: CGFloat
    ) -> (side: CGRect, bottom: CGRect) {
        var side = CGRect(origin: .zero, size: sideSize)
        side.origin.x = selection.maxX + gap
        if side.maxX > bounds.maxX {
            side.origin.x = selection.minX - gap - side.width
            if side.minX < bounds.minX { side.origin.x = selection.maxX - gap - side.width }
        }
        side.origin.y = min(max(selection.maxY - side.height, bounds.minY), bounds.maxY - side.height)

        var bottom = CGRect(origin: .zero, size: bottomSize)
        bottom.origin.y = selection.maxY + gap
        if bottom.maxY > bounds.maxY {
            bottom.origin.y = selection.minY - gap - bottom.height
            if bottom.minY < bounds.minY { bottom.origin.y = selection.maxY - gap - bottom.height }
        }
        bottom.origin.x = min(max(selection.maxX - bottom.width, bounds.minX), bounds.maxX - bottom.width)
        if bottom.intersects(side) {
            bottom.origin.x = max(side.minX - gap - bottom.width, bounds.minX)
        }
        return (side, bottom)
    }

    /// Selection in points converted to whole pixels of the backing screenshot.
    static func pixelRect(for selection: CGRect, scale: CGFloat) -> CGRect {
        CGRect(
            x: (selection.minX * scale).rounded(),
            y: (selection.minY * scale).rounded(),
            width: (selection.width * scale).rounded(),
            height: (selection.height * scale).rounded()
        )
    }
}

extension CGRect {
    init(corner a: CGPoint, corner b: CGPoint) {
        self.init(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }
}
