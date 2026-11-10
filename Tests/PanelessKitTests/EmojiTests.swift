import AppKit
import Testing
@testable import PanelessKit

struct EmojiAnnotationTests {
    // Emoji literals inside #expect crash the TestingMacros plugin, so they stay outside macro arguments.
    let fire = "🔥"
    let center = CGPoint(x: 50, y: 50)

    func stamp(lineWidth: CGFloat = 3) -> Annotation {
        Annotation(tool: .emoji, at: center, color: .red, lineWidth: lineWidth, emoji: fire)
    }

    func emojiParts(_ annotation: Annotation) -> (String, CGPoint, CGFloat)? {
        if case .emoji(let emoji, let center, let size) = annotation.shape { return (emoji, center, size) }
        return nil
    }

    @Test func clickStampsChosenEmojiAtDefaultSize() throws {
        let (emoji, origin, size) = try #require(emojiParts(stamp()))
        #expect(emoji == fire)
        #expect(origin == center)
        #expect(size == Annotation.defaultEmojiSize(lineWidth: 3))
    }

    @Test func defaultSizeGrowsWithLineWidth() {
        #expect(Annotation.defaultEmojiSize(lineWidth: 10) > Annotation.defaultEmojiSize(lineWidth: 2))
    }

    @Test func draggingScalesAroundTheStampPoint() throws {
        var a = stamp()
        a.extend(to: CGPoint(x: 50, y: 90))
        let (_, origin, size) = try #require(emojiParts(a))
        #expect(origin == center)
        #expect(size == 80)
    }

    @Test func tinyDragKeepsDefaultSize() throws {
        var a = stamp()
        a.extend(to: CGPoint(x: 52, y: 51))
        let (_, _, size) = try #require(emojiParts(a))
        #expect(size == Annotation.defaultEmojiSize(lineWidth: 3))
    }

    @Test func emojiIsRenderedInColorAtItsCenter() throws {
        let white = RGBA(r: 255, g: 255, b: 255)
        let screenshot = TestImage.make(width: 200, height: 200) { _, _ in white }
        let annotation = Annotation(shape: .emoji("🔴", center: CGPoint(x: 50, y: 50), size: 60), color: .black, lineWidth: 3)
        let image = try #require(SelectionRenderer.render(
            screenshot: screenshot,
            screenSize: CGSize(width: 100, height: 100),
            selection: CGRect(x: 0, y: 0, width: 100, height: 100),
            annotations: [annotation]
        ))

        let middle = TestImage.pixel(image, x: 100, y: 100)
        #expect(middle.r > 150 && middle.g < 100 && middle.b < 100, "expected red emoji pixel, got \(middle)")
        #expect(TestImage.pixel(image, x: 5, y: 5) == white)
    }
}

@MainActor
struct EmojiPickerViewTests {
    @Test func categoriesHoldUniqueSingleGlyphEmoji() {
        for category in EmojiPickerView.categories {
            #expect(!category.emojis.isEmpty)
            #expect(Set(category.emojis).count == category.emojis.count, "duplicates in \(category.title)")
            for emoji in category.emojis + [category.icon] {
                #expect(emoji.count == 1, "\(emoji) in \(category.title) is not a single character")
                #expect(emoji.unicodeScalars.contains { $0.properties.isEmoji }, "\(emoji) is not an emoji")
            }
        }
    }

    @Test func gridFitsEveryEmojiInsideTheView() {
        let picker = EmojiPickerView()
        for category in EmojiPickerView.categories.indices {
            #expect(picker.bounds.contains(picker.tabRect(category)))
        }
        for index in picker.emojis.indices {
            #expect(picker.bounds.contains(picker.emojiRect(index)))
        }
    }

    @Test func hitTestingDistinguishesTabsAndEmoji() {
        let picker = EmojiPickerView()
        let tab = picker.tabRect(1)
        #expect(picker.hit(at: CGPoint(x: tab.midX, y: tab.midY)) == .category(1))

        let ninth = picker.emojiRect(8)
        #expect(picker.hit(at: CGPoint(x: ninth.midX, y: ninth.midY)) == .emoji(picker.emojis[8]))
        #expect(picker.hit(at: .zero) == nil)
    }

    @Test func clickingSwitchesCategoryThenPicksEmoji() throws {
        let picker = EmojiPickerView()
        var picked: [String] = []
        picker.onPick = { picked.append($0) }
        let window = NSWindow(contentRect: picker.frame, styleMask: .borderless, backing: .buffered, defer: true)
        window.contentView = picker

        func click(_ rect: NSRect) throws {
            let point = picker.convert(CGPoint(x: rect.midX, y: rect.midY), to: nil)
            let event = try #require(NSEvent.mouseEvent(
                with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            ))
            picker.mouseDown(with: event)
        }

        try click(picker.tabRect(2))
        #expect(picker.categoryIndex == 2)
        #expect(picked.isEmpty)

        try click(picker.emojiRect(0))
        #expect(picked == [EmojiPickerView.categories[2].emojis[0]])
        #expect(picker.selectedEmoji == picked.first)
    }
}
