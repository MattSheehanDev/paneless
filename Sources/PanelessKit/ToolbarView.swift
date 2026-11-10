import AppKit

/// Lightshot-style light gray strip of icon buttons.
final class ToolbarView: NSView, NSViewToolTipOwner {
    struct Item {
        let id: String
        /// SF Symbol name; `nil` renders a color swatch.
        let symbol: String?
        let tooltip: String
    }

    enum Axis { case vertical, horizontal }

    static let itemSize: CGFloat = 32
    static let inset: CGFloat = 3

    let items: [Item]
    let axis: Axis
    var onClick: ((String) -> Void)?

    var selectedID: String? { didSet { needsDisplay = true } }
    var swatchColor: NSColor = .red { didSet { needsDisplay = true } }
    /// Items drawn as a full-color emoji instead of their SF Symbol, keyed by item id.
    var itemEmoji: [String: String] = [:] { didSet { needsDisplay = true } }

    private var hoveredIndex: Int? { didSet { if oldValue != hoveredIndex { needsDisplay = true } } }
    private let icons: [NSImage?]

    init(items: [Item], axis: Axis) {
        self.items = items
        self.axis = axis
        self.icons = items.map { $0.symbol.flatMap { ToolbarView.icon($0, color: NSColor(white: 0.22, alpha: 1)) } }

        let length = CGFloat(items.count) * Self.itemSize + Self.inset * 2
        let thickness = Self.itemSize + Self.inset * 2
        let size = axis == .vertical
            ? NSSize(width: thickness, height: length)
            : NSSize(width: length, height: thickness)
        super.init(frame: NSRect(origin: .zero, size: size))

        for index in items.indices {
            addToolTip(itemRect(index), owner: self, userData: nil)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func itemRect(_ index: Int) -> NSRect {
        let offset = Self.inset + CGFloat(index) * Self.itemSize
        return axis == .vertical
            ? NSRect(x: Self.inset, y: offset, width: Self.itemSize, height: Self.itemSize)
            : NSRect(x: offset, y: Self.inset, width: Self.itemSize, height: Self.itemSize)
    }

    func rect(forItem id: String) -> NSRect? {
        items.firstIndex { $0.id == id }.map(itemRect)
    }

    private func index(at point: NSPoint) -> Int? {
        items.indices.first { itemRect($0).contains(point) }
    }

    override func draw(_ dirtyRect: NSRect) {
        let background = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 5, yRadius: 5)
        NSGradient(starting: NSColor(white: 0.98, alpha: 1), ending: NSColor(white: 0.9, alpha: 1))?
            .draw(in: background, angle: axis == .vertical ? 0 : 90)
        NSColor(white: 0, alpha: 0.3).setStroke()
        background.lineWidth = 1
        background.stroke()

        for (index, item) in items.enumerated() {
            let rect = itemRect(index)
            let highlight = NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), xRadius: 4, yRadius: 4)
            if item.id == selectedID {
                NSColor(srgbRed: 0.26, green: 0.52, blue: 0.96, alpha: 0.28).setFill()
                highlight.fill()
                NSColor(srgbRed: 0.26, green: 0.52, blue: 0.96, alpha: 0.6).setStroke()
                highlight.stroke()
            } else if index == hoveredIndex {
                NSColor(white: 0, alpha: 0.08).setFill()
                highlight.fill()
            }

            if let emoji = itemEmoji[item.id] {
                let glyph = NSAttributedString(string: emoji, attributes: [.font: NSFont.systemFont(ofSize: 18)])
                let size = glyph.size()
                glyph.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
            } else if let icon = icons[index] {
                let iconRect = NSRect(
                    x: rect.midX - icon.size.width / 2,
                    y: rect.midY - icon.size.height / 2,
                    width: icon.size.width,
                    height: icon.size.height
                )
                icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            } else {
                let swatch = NSBezierPath(roundedRect: rect.insetBy(dx: 8, dy: 8), xRadius: 2, yRadius: 2)
                swatchColor.setFill()
                swatch.fill()
                NSColor(white: 0, alpha: 0.5).setStroke()
                swatch.lineWidth = 1
                swatch.stroke()
            }
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseMoved(with event: NSEvent) {
        hoveredIndex = index(at: convert(event.locationInWindow, from: nil))
        NSCursor.arrow.set()
    }

    override func mouseExited(with event: NSEvent) {
        hoveredIndex = nil
    }

    override func mouseDown(with event: NSEvent) {
        if let index = index(at: convert(event.locationInWindow, from: nil)) {
            onClick?(items[index].id)
        }
    }

    func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String {
        index(at: point).map { items[$0].tooltip } ?? ""
    }

    static func icon(_ name: String, color: NSColor) -> NSImage? {
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 15, weight: .medium))
        else { return nil }
        return NSImage(size: base.size, flipped: false) { rect in
            base.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }
}

/// Grid of preset colors shown next to the color button.
final class ColorPaletteView: NSView {
    static let colors: [NSColor] = [
        (255, 0, 0), (255, 128, 0), (255, 221, 0), (0, 190, 0), (0, 200, 220), (0, 102, 255),
        (140, 40, 255), (255, 0, 200), (0, 0, 0), (128, 128, 128), (255, 255, 255), (140, 80, 20),
    ].map { NSColor(srgbRed: CGFloat($0.0) / 255, green: CGFloat($0.1) / 255, blue: CGFloat($0.2) / 255, alpha: 1) }

    private static let columns = 6
    private static let swatch: CGFloat = 20
    private static let spacing: CGFloat = 5
    private static let inset: CGFloat = 7

    var onPick: ((NSColor) -> Void)?
    var selectedColor: NSColor = colors[0] { didSet { needsDisplay = true } }

    init() {
        let rows = (Self.colors.count + Self.columns - 1) / Self.columns
        let width = Self.inset * 2 + CGFloat(Self.columns) * Self.swatch + CGFloat(Self.columns - 1) * Self.spacing
        let height = Self.inset * 2 + CGFloat(rows) * Self.swatch + CGFloat(rows - 1) * Self.spacing
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func swatchRect(_ index: Int) -> NSRect {
        let column = index % Self.columns, row = index / Self.columns
        return NSRect(
            x: Self.inset + CGFloat(column) * (Self.swatch + Self.spacing),
            y: Self.inset + CGFloat(row) * (Self.swatch + Self.spacing),
            width: Self.swatch,
            height: Self.swatch
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        let background = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 5, yRadius: 5)
        NSColor(white: 0.96, alpha: 1).setFill()
        background.fill()
        NSColor(white: 0, alpha: 0.3).setStroke()
        background.stroke()

        for (index, color) in Self.colors.enumerated() {
            let rect = swatchRect(index)
            color.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3).fill()
            let outline = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 3, yRadius: 3)
            NSColor(white: 0, alpha: 0.35).setStroke()
            outline.stroke()
            if color == selectedColor {
                let ring = NSBezierPath(roundedRect: rect.insetBy(dx: -2.5, dy: -2.5), xRadius: 4, yRadius: 4)
                ring.lineWidth = 2
                NSColor(srgbRed: 0.26, green: 0.52, blue: 0.96, alpha: 1).setStroke()
                ring.stroke()
            }
        }
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let index = Self.colors.indices.first(where: { swatchRect($0).insetBy(dx: -2, dy: -2).contains(point) }) {
            selectedColor = Self.colors[index]
            onPick?(Self.colors[index])
        }
    }
}
