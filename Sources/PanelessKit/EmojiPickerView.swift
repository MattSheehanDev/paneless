import AppKit

/// Tabbed grid of emoji shown next to the emoji tool button.
final class EmojiPickerView: NSView {
    struct Category {
        let icon: String
        let title: String
        let emojis: [String]
    }

    enum Hit: Equatable {
        case category(Int)
        case emoji(String)
    }

    static let categories: [Category] = [
        Category(icon: "😀", title: "Smileys", emojis: [
            "😀", "😂", "🤣", "😊", "😍", "🥰", "😎", "🤔",
            "😅", "😭", "😡", "🤯", "😱", "🥳", "😴", "🙄",
            "😬", "🤗", "😇", "🤡", "💀", "👻", "🤖", "💩",
        ]),
        Category(icon: "👍", title: "Gestures", emojis: [
            "👍", "👎", "👏", "🙌", "🙏", "👌", "✌️", "🤞",
            "👉", "👈", "👆", "👇", "☝️", "✋", "🤙", "💪",
            "👀", "🫡", "🤦", "🤷", "🙈", "🧠", "💯", "🔥",
        ]),
        Category(icon: "✅", title: "Symbols", emojis: [
            "✅", "❌", "⚠️", "❓", "❗", "⭐", "❤️", "💔",
            "💡", "🎉", "🚀", "🐛", "📌", "📎", "🔒", "🔑",
            "⏰", "📝", "💬", "🎯", "🏆", "⚡", "🛑", "🆗",
        ]),
    ]

    static let columns = 8
    static let cell: CGFloat = 30
    static let inset: CGFloat = 6
    static let tabGap: CGFloat = 5

    var onPick: ((String) -> Void)?
    private(set) var categoryIndex = 0 { didSet { needsDisplay = true } }
    var selectedEmoji: String? { didSet { needsDisplay = true } }
    private var hovered: Hit? { didSet { if oldValue != hovered { needsDisplay = true } } }

    private static var rows: Int {
        let longest = categories.map(\.emojis.count).max() ?? 0
        return (longest + columns - 1) / columns
    }

    init() {
        let width = Self.inset * 2 + CGFloat(Self.columns) * Self.cell
        let height = Self.inset * 2 + Self.cell + Self.tabGap + CGFloat(Self.rows) * Self.cell
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    var emojis: [String] { Self.categories[categoryIndex].emojis }

    func tabRect(_ index: Int) -> NSRect {
        NSRect(x: Self.inset + CGFloat(index) * Self.cell, y: Self.inset, width: Self.cell, height: Self.cell)
    }

    func emojiRect(_ index: Int) -> NSRect {
        let column = index % Self.columns, row = index / Self.columns
        return NSRect(
            x: Self.inset + CGFloat(column) * Self.cell,
            y: Self.inset + Self.cell + Self.tabGap + CGFloat(row) * Self.cell,
            width: Self.cell,
            height: Self.cell
        )
    }

    func hit(at point: NSPoint) -> Hit? {
        if let tab = Self.categories.indices.first(where: { tabRect($0).contains(point) }) {
            return .category(tab)
        }
        return emojis.indices.first { emojiRect($0).contains(point) }.map { .emoji(emojis[$0]) }
    }

    override func draw(_ dirtyRect: NSRect) {
        let background = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 5, yRadius: 5)
        NSColor(white: 0.96, alpha: 1).setFill()
        background.fill()
        NSColor(white: 0, alpha: 0.3).setStroke()
        background.stroke()

        for (index, category) in Self.categories.enumerated() {
            let rect = tabRect(index)
            if index == categoryIndex {
                fillHighlight(rect, NSColor(srgbRed: 0.26, green: 0.52, blue: 0.96, alpha: 0.28))
            } else if hovered == .category(index) {
                fillHighlight(rect, NSColor(white: 0, alpha: 0.08))
            }
            drawEmoji(category.icon, in: rect, size: 17)
        }

        let separatorY = Self.inset + Self.cell + Self.tabGap / 2
        NSColor(white: 0, alpha: 0.15).setFill()
        NSRect(x: Self.inset, y: separatorY, width: bounds.width - Self.inset * 2, height: 1).fill()

        for (index, emoji) in emojis.enumerated() {
            let rect = emojiRect(index)
            if emoji == selectedEmoji {
                fillHighlight(rect, NSColor(srgbRed: 0.26, green: 0.52, blue: 0.96, alpha: 0.28))
            } else if hovered == .emoji(emoji) {
                fillHighlight(rect, NSColor(white: 0, alpha: 0.08))
            }
            drawEmoji(emoji, in: rect, size: 20)
        }
    }

    private func fillHighlight(_ rect: NSRect, _ color: NSColor) {
        color.setFill()
        NSBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), xRadius: 4, yRadius: 4).fill()
    }

    private func drawEmoji(_ emoji: String, in rect: NSRect, size: CGFloat) {
        let string = NSAttributedString(string: emoji, attributes: [.font: NSFont.systemFont(ofSize: size)])
        let textSize = string.size()
        string.draw(at: CGPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2))
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
        hovered = hit(at: convert(event.locationInWindow, from: nil))
        NSCursor.arrow.set()
    }

    override func mouseExited(with event: NSEvent) {
        hovered = nil
    }

    override func mouseDown(with event: NSEvent) {
        switch hit(at: convert(event.locationInWindow, from: nil)) {
        case .category(let index):
            categoryIndex = index
        case .emoji(let emoji):
            selectedEmoji = emoji
            onPick?(emoji)
        case nil:
            break
        }
    }
}
