import Foundation

/// User-configurable settings, persisted in `UserDefaults`.
final class Preferences {
    static let shared = Preferences()

    private static let saveDirectoryKey = "SaveDirectory"

    private let defaults: UserDefaults
    private let fileManager: FileManager

    init(defaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        self.defaults = defaults
        self.fileManager = fileManager
    }

    var defaultSaveDirectory: URL {
        fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
    }

    /// Folder the Save dialog opens in. Falls back to the Desktop if the chosen folder was
    /// deleted, renamed or is on a disconnected drive.
    var saveDirectory: URL {
        get {
            guard let path = defaults.string(forKey: Self.saveDirectoryKey) else { return defaultSaveDirectory }
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
                return defaultSaveDirectory
            }
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        set {
            defaults.set(newValue.standardizedFileURL.path, forKey: Self.saveDirectoryKey)
        }
    }

    var isUsingDefaultSaveDirectory: Bool {
        saveDirectory.standardizedFileURL == defaultSaveDirectory.standardizedFileURL
    }

    func resetSaveDirectory() {
        defaults.removeObject(forKey: Self.saveDirectoryKey)
    }
}
