import AppKit

final class PreferencesWindowController: NSWindowController {
    private let preferences: Preferences
    let folderIcon = NSImageView()
    let folderName = NSTextField(labelWithString: "")
    let folderPath = NSTextField(labelWithString: "")
    let resetButton = NSButton(title: "Use Desktop", target: nil, action: nil)

    init(preferences: Preferences = .shared) {
        self.preferences = preferences
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 120),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )
        window.title = "Paneless Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        if window?.isVisible == false { window?.center() }
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildContent() {
        let label = NSTextField(labelWithString: "Save screenshots to:")
        label.font = .boldSystemFont(ofSize: NSFont.systemFontSize)

        folderIcon.imageScaling = .scaleProportionallyUpOrDown
        folderIcon.widthAnchor.constraint(equalToConstant: 32).isActive = true
        folderIcon.heightAnchor.constraint(equalToConstant: 32).isActive = true

        folderPath.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        folderPath.textColor = .secondaryLabelColor
        folderPath.lineBreakMode = .byTruncatingMiddle
        folderPath.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        folderName.lineBreakMode = .byTruncatingTail
        folderName.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let names = NSStackView(views: [folderName, folderPath])
        names.orientation = .vertical
        names.alignment = .leading
        names.spacing = 2

        let showButton = NSButton(title: "Show in Finder", target: self, action: #selector(revealInFinder))
        let chooseButton = NSButton(title: "Choose…", target: self, action: #selector(chooseFolder))
        chooseButton.keyEquivalent = "\r"
        resetButton.target = self
        resetButton.action = #selector(resetToDefault)

        let folderRow = NSStackView(views: [folderIcon, names])
        folderRow.spacing = 10
        let buttons = NSStackView()
        buttons.setViews([showButton], in: .leading)
        buttons.setViews([resetButton, chooseButton], in: .trailing)
        buttons.spacing = 8
        for button in [showButton, resetButton, chooseButton] {
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        let hint = NSTextField(labelWithString: "The Save dialog (⌘S) opens in this folder.")
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [label, folderRow, hint, buttons])
        stack.setCustomSpacing(18, after: hint)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            folderRow.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor, constant: -40),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40),
            content.widthAnchor.constraint(equalToConstant: 520),
        ])
        window?.contentView = content
    }

    func refresh() {
        let url = preferences.saveDirectory
        folderIcon.image = NSWorkspace.shared.icon(forFile: url.path)
        folderName.stringValue = FileManager.default.displayName(atPath: url.path)
        folderPath.stringValue = (url.path as NSString).abbreviatingWithTildeInPath
        folderPath.toolTip = url.path
        resetButton.isEnabled = !preferences.isUsingDefaultSaveDirectory
    }

    func setSaveDirectory(_ url: URL) {
        preferences.saveDirectory = url
        refresh()
    }

    @objc private func chooseFolder() {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose where Paneless saves screenshots"
        panel.directoryURL = preferences.saveDirectory
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.setSaveDirectory(url)
        }
    }

    @objc func resetToDefault() {
        preferences.resetSaveDirectory()
        refresh()
    }

    @objc private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([preferences.saveDirectory])
    }
}
