import AppKit

enum ExportAction { case copy, save }

@MainActor
protocol OverlayViewDelegate: AnyObject {
    func overlayViewDidBeginSelection(_ view: OverlayView)
    func overlayViewDidCancel(_ view: OverlayView)
    func overlayView(_ view: OverlayView, didRequest action: ExportAction)
}

/// Transparent layer above the frozen screenshot: dimming, selection, annotations and toolbars.
final class OverlayView: NSView {
    typealias Handle = SelectionHandle

    private enum Drag {
        case idle
        case creating(start: CGPoint)
        case moving(start: CGPoint, original: CGRect)
        case resizing(handle: Handle, original: CGRect)
        case drawing
        case movingAnnotation(index: Int, start: CGPoint, original: Annotation)
    }

    weak var delegate: OverlayViewDelegate?
    let screenshot: CGImage
    let windowFrames: [CGRect]
    /// Window (or whole screen) a click would select, highlighted while there's no selection.
    private var snapTarget: CGRect? { didSet { if oldValue != snapTarget { needsDisplay = true } } }

    private(set) var selection: CGRect?
    private var history = AnnotationHistory()
    private var annotations: [Annotation] { history.annotations }
    private var current: Annotation?
    private var editingText: Annotation?
    /// True when `editingText` was taken out of `history` by a double-click, so a checkpoint exists.
    private var isReeditingText = false
    private var hoveredAnnotation: Int? { didSet { if oldValue != hoveredAnnotation { needsDisplay = true } } }
    private var tool: Tool?
    private var color = ColorPaletteView.colors[0]
    private var lineWidth: CGFloat = 3
    private var drag = Drag.idle

    private let sideBar = ToolbarView(
        items: Tool.allCases.map { .init(id: $0.rawValue, symbol: $0.symbol, tooltip: $0.title) } + [
            .init(id: "color", symbol: nil, tooltip: "Color"),
            .init(id: "undo", symbol: "arrow.uturn.backward", tooltip: "Undo (⌘Z)"),
        ],
        axis: .vertical
    )
    private let bottomBar = ToolbarView(
        items: [
            .init(id: "copy", symbol: "doc.on.doc", tooltip: "Copy (⌘C)"),
            .init(id: "save", symbol: "square.and.arrow.down", tooltip: "Save (⌘S)"),
            .init(id: "close", symbol: "xmark", tooltip: "Close (Esc)"),
        ],
        axis: .horizontal
    )
    private let palette = ColorPaletteView()
    private let emojiPicker = EmojiPickerView()
    private var emoji = EmojiPickerView.categories[0].emojis[0]

    private static let dimColor = NSColor(white: 0, alpha: 0.45)
    private static let handleSize: CGFloat = 7
    private static let toolbarGap: CGFloat = 6

    init(frame: NSRect, screenshot: CGImage, windowFrames: [CGRect] = []) {
        self.screenshot = screenshot
        self.windowFrames = windowFrames
        super.init(frame: frame)
        wantsLayer = true

        sideBar.swatchColor = color
        sideBar.itemEmoji = [Tool.emoji.rawValue: emoji]
        sideBar.onClick = { [weak self] id in self?.sideBarClicked(id) }
        bottomBar.onClick = { [weak self] id in self?.bottomBarClicked(id) }
        palette.onPick = { [weak self] color in self?.pickColor(color) }
        emojiPicker.onPick = { [weak self] emoji in self?.pickEmoji(emoji) }
        for view in [sideBar, bottomBar, palette, emojiPicker] as [NSView] {
            view.isHidden = true
            addSubview(view)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var pixelScale: CGFloat { CGFloat(screenshot.width) / max(bounds.width, 1) }

    func clearSelection() {
        selection = nil
        snapTarget = nil
        history.removeAll()
        current = nil
        editingText = nil
        isReeditingText = false
        hoveredAnnotation = nil
        drag = .idle
        updateToolbars()
        needsDisplay = true
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        let highlight = selection == nil ? visibleSnapTarget : nil
        let dim = NSBezierPath(rect: bounds)
        if let hole = selection ?? highlight {
            dim.appendRect(hole)
            dim.windingRule = .evenOdd
        }
        Self.dimColor.setFill()
        dim.fill()

        if let highlight {
            let border = NSBezierPath(rect: highlight.insetBy(dx: 1.5, dy: 1.5))
            border.lineWidth = 3
            NSColor(srgbRed: 0.26, green: 0.52, blue: 0.96, alpha: 0.9).setStroke()
            border.stroke()
            drawSizeLabel(highlight)
        }

        guard let selection else { return }

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: selection).addClip()
        annotations.forEach { $0.draw() }
        current?.draw()
        if let editingText { drawEditingText(editingText) }
        if let outlined = outlinedAnnotation { drawDashedBox(annotations[outlined].boundingRect.insetBy(dx: -3, dy: -3)) }
        NSGraphicsContext.restoreGraphicsState()

        drawSelectionBorder(selection)
        drawHandles(selection)
        drawSizeLabel(selection)
    }

    private func drawSelectionBorder(_ rect: CGRect) {
        let border = NSBezierPath(rect: rect.insetBy(dx: -0.5, dy: -0.5))
        border.lineWidth = 1
        NSColor.white.setStroke()
        border.stroke()
        border.setLineDash([4, 4], count: 2, phase: 0)
        NSColor.black.setStroke()
        border.stroke()
    }

    private func drawHandles(_ rect: CGRect) {
        for handle in Handle.allCases {
            let box = handleRect(handle, in: rect)
            NSColor.black.setFill()
            box.fill()
            NSColor.white.setStroke()
            NSBezierPath(rect: box.insetBy(dx: 0.5, dy: 0.5)).stroke()
        }
    }

    private func drawSizeLabel(_ rect: CGRect) {
        var text = "\(Int((rect.width * pixelScale).rounded())) × \(Int((rect.height * pixelScale).rounded()))"
        if tool != nil { text += "   \(Int(lineWidth.rounded()))px" }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let label = NSAttributedString(string: text, attributes: attributes)
        let size = label.size()
        var box = CGRect(x: rect.minX, y: rect.minY - size.height - 9, width: size.width + 10, height: size.height + 4)
        if box.minY < 2 { box.origin.y = rect.minY + 5; box.origin.x = rect.minX + 5 }
        box.origin.x = min(max(box.minX, 2), bounds.maxX - box.width - 2)

        NSColor(white: 0, alpha: 0.72).setFill()
        NSBezierPath(roundedRect: box, xRadius: 3, yRadius: 3).fill()
        label.draw(at: CGPoint(x: box.minX + 5, y: box.minY + 2))
    }

    private func drawEditingText(_ annotation: Annotation) {
        annotation.draw()
        guard let bounds = annotation.textBounds, let caret = annotation.caretRect else { return }
        drawDashedBox(bounds.union(caret).insetBy(dx: -4, dy: -3))
        annotation.color.setFill()
        caret.fill()
    }

    private func drawDashedBox(_ rect: CGRect) {
        let box = NSBezierPath(rect: rect)
        box.lineWidth = 1
        NSColor.white.setStroke()
        box.stroke()
        box.setLineDash([3, 3], count: 2, phase: 0)
        NSColor.black.setStroke()
        box.stroke()
    }

    private var visibleSnapTarget: CGRect? {
        guard case .idle = drag else { return nil }
        return snapTarget
    }

    /// Annotation being dragged, or else the one under the pointer.
    private var outlinedAnnotation: Int? {
        if case .movingAnnotation(let index, _, _) = drag { return index }
        guard case .idle = drag, let hoveredAnnotation, annotations.indices.contains(hoveredAnnotation) else { return nil }
        return hoveredAnnotation
    }

    // MARK: Geometry

    private func handleRect(_ handle: Handle, in rect: CGRect) -> CGRect {
        SelectionGeometry.handleRect(handle, in: rect, size: Self.handleSize)
    }

    private func handle(at point: CGPoint, in rect: CGRect) -> Handle? {
        SelectionGeometry.handle(at: point, in: rect, size: Self.handleSize)
    }

    private func location(of event: NSEvent) -> CGPoint {
        SelectionGeometry.clamp(convert(event.locationInWindow, from: nil), to: bounds)
    }

    // MARK: Mouse

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseExited(with event: NSEvent) {
        snapTarget = nil
    }

    /// Syncs hover state with a pointer that hasn't moved yet, e.g. when the overlay first appears.
    func pointerMoved(toWindowPoint point: CGPoint) {
        updateCursor(at: convert(point, from: nil))
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        let p = location(of: event)
        commitText()
        palette.isHidden = true
        emojiPicker.isHidden = true

        if let selection {
            if let handle = handle(at: p, in: selection) {
                drag = .resizing(handle: handle, original: selection)
                updateToolbars()
                return
            }
            if selection.contains(p), let index = history.index(at: p) {
                if event.clickCount == 2, annotations[index].isText {
                    beginReeditingText(at: index)
                } else {
                    history.checkpoint()
                    drag = .movingAnnotation(index: index, start: p, original: annotations[index])
                    NSCursor.closedHand.set()
                }
                needsDisplay = true
                return
            }
            if let tool, selection.contains(p) {
                if tool == .text {
                    let origin = CGPoint(x: p.x, y: p.y - Annotation(tool: .text, at: p, color: color, lineWidth: lineWidth).lineHeight / 2)
                    editingText = Annotation(tool: .text, at: origin, color: color, lineWidth: lineWidth)
                } else {
                    current = Annotation(tool: tool, at: p, color: color, lineWidth: lineWidth, emoji: emoji)
                    drag = .drawing
                }
                needsDisplay = true
                return
            }
            if selection.contains(p) {
                drag = .moving(start: p, original: selection)
                NSCursor.closedHand.set()
                updateToolbars()
                return
            }
            if !annotations.isEmpty { return }
        }

        selection = nil
        drag = .creating(start: p)
        delegate?.overlayViewDidBeginSelection(self)
        updateToolbars()
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let p = location(of: event)
        switch drag {
        case .idle:
            return
        case .creating(let start):
            selection = CGRect(corner: start, corner: p)
        case .moving(let start, let original):
            let delta = CGPoint(x: p.x - start.x, y: p.y - start.y)
            selection = SelectionGeometry.move(original, by: delta, within: bounds)
        case .resizing(let handle, let original):
            selection = SelectionGeometry.resize(original, handle: handle, to: p)
        case .drawing:
            current?.extend(to: p)
        case .movingAnnotation(let index, let start, let original):
            history.replace(at: index, with: original.offset(by: CGPoint(x: p.x - start.x, y: p.y - start.y)))
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        switch drag {
        case .creating(let start):
            if selection.map({ $0.width < 3 || $0.height < 3 }) ?? true {
                selection = WindowList.snapTarget(at: start, windowFrames: windowFrames, screenBounds: bounds)
                snapTarget = nil
            }
        case .resizing:
            if let selection, selection.width < 1 || selection.height < 1 { self.selection = nil }
        case .drawing:
            if let current { history.add(current) }
            current = nil
        case .movingAnnotation(_, let start, _):
            if location(of: event) == start { history.discardCheckpoint() }
        case .idle, .moving:
            break
        }
        drag = .idle
        updateToolbars()
        updateCursor(at: convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) {
        delegate?.overlayViewDidCancel(self)
    }

    override func scrollWheel(with event: NSEvent) {
        guard tool != nil || editingText != nil else { return }
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY / 8 : event.scrollingDeltaY
        lineWidth = min(max(lineWidth + delta, 1), 30)
        editingText?.lineWidth = lineWidth
        needsDisplay = true
    }

    private func updateCursor(at p: CGPoint) {
        if ([sideBar, bottomBar, palette, emojiPicker] as [NSView]).contains(where: { !$0.isHidden && $0.frame.contains(p) }) {
            NSCursor.arrow.set()
            return
        }
        hoveredAnnotation = nil
        snapTarget = selection == nil
            ? WindowList.snapTarget(at: p, windowFrames: windowFrames, screenBounds: bounds)
            : nil
        guard let selection else { return NSCursor.crosshair.set() }
        if let handle = handle(at: p, in: selection) { return Self.cursor(for: handle).set() }
        if selection.contains(p), let index = history.index(at: p) {
            hoveredAnnotation = index
            return NSCursor.openHand.set()
        }
        if selection.contains(p) {
            switch tool {
            case .text: NSCursor.iBeam.set()
            case .some: NSCursor.crosshair.set()
            case nil: NSCursor.openHand.set()
            }
            return
        }
        (annotations.isEmpty ? NSCursor.crosshair : NSCursor.arrow).set()
    }

    private static func cursor(for handle: Handle) -> NSCursor {
        if #available(macOS 15.0, *) {
            let position: NSCursor.FrameResizePosition = switch handle {
            case .topLeft: .topLeft
            case .top: .top
            case .topRight: .topRight
            case .right: .right
            case .bottomRight: .bottomRight
            case .bottom: .bottom
            case .bottomLeft: .bottomLeft
            case .left: .left
            }
            return NSCursor.frameResize(position: position, directions: .all)
        }
        switch handle {
        case .top, .bottom: return .resizeUpDown
        case .left, .right: return .resizeLeftRight
        default: return .crosshair
        }
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        if editingText != nil, handleTextKey(event) { return }

        let command = event.modifierFlags.contains(.command)
        switch (command, event.charactersIgnoringModifiers?.lowercased()) {
        case (true, "c"): export(.copy)
        case (true, "s"): export(.save)
        case (true, "z"): undo()
        default:
            switch event.keyCode {
            case 53: delegate?.overlayViewDidCancel(self) // Esc
            case 36, 76: export(.copy) // Return, keypad Enter
            default: super.keyDown(with: event)
            }
        }
    }

    /// Returns true if the key was consumed by the in-place text editor.
    private func handleTextKey(_ event: NSEvent) -> Bool {
        guard var annotation = editingText, let text = annotation.text else { return false }
        let flags = event.modifierFlags

        if flags.contains(.command) {
            if event.charactersIgnoringModifiers?.lowercased() == "v",
               let pasted = NSPasteboard.general.string(forType: .string) {
                annotation.setText(text + pasted)
                editingText = annotation
                needsDisplay = true
                return true
            }
            if event.charactersIgnoringModifiers?.lowercased() == "z" {
                undo()
                return true
            }
            commitText()
            return false
        }

        switch event.keyCode {
        case 53: // Esc
            commitText()
        case 36, 76: // Return
            if flags.contains(.shift) {
                annotation.setText(text + "\n")
                editingText = annotation
            } else {
                commitText()
            }
        case 51: // Delete
            annotation.setText(String(text.dropLast()))
            editingText = annotation
        default:
            let typed = TextInput.printable(event.characters ?? "")
            guard !typed.isEmpty else { return true }
            annotation.setText(text + typed)
            editingText = annotation
        }
        needsDisplay = true
        return true
    }

    private func commitText() {
        guard let annotation = editingText else { return }
        editingText = nil
        let hasText = !(annotation.text ?? "").isEmpty
        if isReeditingText {
            if hasText { history.append(annotation) }
        } else if hasText {
            history.add(annotation)
        }
        isReeditingText = false
        needsDisplay = true
    }

    private func beginReeditingText(at index: Int) {
        history.checkpoint()
        editingText = history.remove(at: index)
        isReeditingText = true
        hoveredAnnotation = nil
    }

    // MARK: Actions

    private func sideBarClicked(_ id: String) {
        commitText()
        switch id {
        case "undo":
            undo()
        case "color":
            palette.isHidden.toggle()
            emojiPicker.isHidden = true
            layoutPopovers()
        case Tool.emoji.rawValue:
            emojiPicker.isHidden.toggle()
            palette.isHidden = true
            if !emojiPicker.isHidden { selectTool(.emoji) }
            layoutPopovers()
        default:
            guard let selected = Tool(rawValue: id) else { return }
            selectTool(tool == selected ? nil : selected)
            palette.isHidden = true
            emojiPicker.isHidden = true
        }
        needsDisplay = true
    }

    private func selectTool(_ newTool: Tool?) {
        tool = newTool
        sideBar.selectedID = newTool?.rawValue
    }

    private func pickEmoji(_ newEmoji: String) {
        emoji = newEmoji
        sideBar.itemEmoji = [Tool.emoji.rawValue: newEmoji]
        emojiPicker.isHidden = true
        selectTool(.emoji)
        needsDisplay = true
    }

    private func bottomBarClicked(_ id: String) {
        switch id {
        case "copy": export(.copy)
        case "save": export(.save)
        default: delegate?.overlayViewDidCancel(self)
        }
    }

    private func pickColor(_ newColor: NSColor) {
        color = newColor
        sideBar.swatchColor = newColor
        editingText?.color = newColor
        palette.isHidden = true
        if tool == nil || tool == .emoji {
            selectTool(.pen)
        }
        needsDisplay = true
    }

    private func undo() {
        if editingText != nil {
            editingText = nil
            if isReeditingText { history.undo() }
            isReeditingText = false
        } else {
            history.undo()
        }
        hoveredAnnotation = nil
        needsDisplay = true
    }

    private func export(_ action: ExportAction) {
        guard selection != nil else { return }
        commitText()
        delegate?.overlayView(self, didRequest: action)
    }

    // MARK: Toolbars

    private func updateToolbars() {
        guard let selection, case .idle = drag else {
            sideBar.isHidden = true
            bottomBar.isHidden = true
            palette.isHidden = true
            emojiPicker.isHidden = true
            return
        }
        let frames = SelectionGeometry.toolbarFrames(
            selection: selection,
            sideSize: sideBar.frame.size,
            bottomSize: bottomBar.frame.size,
            bounds: bounds,
            gap: Self.toolbarGap
        )
        sideBar.frame = frames.side
        bottomBar.frame = frames.bottom
        sideBar.isHidden = false
        bottomBar.isHidden = false
        layoutPopovers()
    }

    private func layoutPopovers() {
        palette.selectedColor = color
        emojiPicker.selectedEmoji = emoji
        layoutPopover(palette, nextTo: "color")
        layoutPopover(emojiPicker, nextTo: Tool.emoji.rawValue)
    }

    /// Places a popover beside a side-toolbar item: to its left, or to its right if there's no room.
    private func layoutPopover(_ popover: NSView, nextTo itemID: String) {
        guard !popover.isHidden, let item = sideBar.rect(forItem: itemID) else { return }
        let anchor = sideBar.convert(item, to: self)
        var frame = popover.frame
        frame.origin.x = sideBar.frame.minX - Self.toolbarGap - frame.width
        if frame.minX < bounds.minX { frame.origin.x = sideBar.frame.maxX + Self.toolbarGap }
        frame.origin.y = min(max(anchor.midY - frame.height / 2, bounds.minY), bounds.maxY - frame.height)
        popover.frame = frame
    }

    // MARK: Export

    /// Renders the selected region plus annotations at the screenshot's native pixel resolution.
    func renderSelection() -> CGImage? {
        commitText()
        guard let selection else { return nil }
        return SelectionRenderer.render(
            screenshot: screenshot,
            screenSize: bounds.size,
            selection: selection,
            annotations: annotations
        )
    }
}
