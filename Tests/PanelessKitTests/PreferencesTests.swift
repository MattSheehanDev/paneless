import AppKit
import Testing
@testable import PanelessKit

/// Each test gets its own defaults suite and temp folder so nothing touches the real settings.
final class PreferencesFixture {
    let suiteName = "PanelessTests.\(UUID().uuidString)"
    let defaults: UserDefaults
    let folder: URL
    let preferences: Preferences

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        preferences = Preferences(defaults: defaults)
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: folder)
    }
}

struct PreferencesTests {
    @Test func defaultsToTheDesktop() throws {
        let fixture = try PreferencesFixture()
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        #expect(fixture.preferences.saveDirectory == desktop)
        #expect(fixture.preferences.isUsingDefaultSaveDirectory)
    }

    @Test func remembersTheChosenFolder() throws {
        let fixture = try PreferencesFixture()
        fixture.preferences.saveDirectory = fixture.folder
        #expect(fixture.preferences.saveDirectory.standardizedFileURL == fixture.folder.standardizedFileURL)
        #expect(!fixture.preferences.isUsingDefaultSaveDirectory)

        let reloaded = Preferences(defaults: fixture.defaults)
        #expect(reloaded.saveDirectory.standardizedFileURL == fixture.folder.standardizedFileURL)
    }

    @Test func fallsBackToDesktopWhenFolderDisappears() throws {
        let fixture = try PreferencesFixture()
        fixture.preferences.saveDirectory = fixture.folder
        try FileManager.default.removeItem(at: fixture.folder)
        #expect(fixture.preferences.saveDirectory == fixture.preferences.defaultSaveDirectory)
    }

    @Test func ignoresAFileInPlaceOfAFolder() throws {
        let fixture = try PreferencesFixture()
        let file = fixture.folder.appendingPathComponent("not-a-folder.txt")
        try Data().write(to: file)
        fixture.preferences.saveDirectory = file
        #expect(fixture.preferences.saveDirectory == fixture.preferences.defaultSaveDirectory)
    }

    @Test func resetReturnsToDesktop() throws {
        let fixture = try PreferencesFixture()
        fixture.preferences.saveDirectory = fixture.folder
        fixture.preferences.resetSaveDirectory()
        #expect(fixture.preferences.isUsingDefaultSaveDirectory)
    }
}

@MainActor
struct PreferencesWindowControllerTests {
    @Test func showsCurrentFolderAndTogglesReset() throws {
        let fixture = try PreferencesFixture()
        let controller = PreferencesWindowController(preferences: fixture.preferences)
        let desktopPath = (fixture.preferences.defaultSaveDirectory.path as NSString).abbreviatingWithTildeInPath
        #expect(controller.folderPath.stringValue == desktopPath)
        #expect(!controller.resetButton.isEnabled)

        controller.setSaveDirectory(fixture.folder)
        #expect(controller.folderName.stringValue == fixture.folder.lastPathComponent)
        #expect(controller.folderPath.toolTip == fixture.folder.standardizedFileURL.path)
        #expect(controller.folderIcon.image != nil)
        #expect(controller.resetButton.isEnabled)

        controller.resetToDefault()
        #expect(controller.folderPath.stringValue == desktopPath)
        #expect(!controller.resetButton.isEnabled)
    }

    @Test func buttonsAreLaidOutInsideTheWindowWithoutOverlapping() throws {
        let fixture = try PreferencesFixture()
        let controller = PreferencesWindowController(preferences: fixture.preferences)
        controller.setSaveDirectory(fixture.folder)
        let window = try #require(controller.window)
        window.layoutIfNeeded()
        let content = try #require(window.contentView)

        func buttons(in view: NSView) -> [NSButton] {
            view.subviews.flatMap { ($0 as? NSButton).map { [$0] } ?? buttons(in: $0) }
        }
        let frames = buttons(in: content).map { $0.convert($0.bounds, to: content) }
        #expect(frames.count == 3)
        for (i, frame) in frames.enumerated() {
            #expect(content.bounds.contains(frame))
            #expect(frame.width > 60)
            for other in frames[(i + 1)...] { #expect(!frame.intersects(other)) }
        }
    }
}
