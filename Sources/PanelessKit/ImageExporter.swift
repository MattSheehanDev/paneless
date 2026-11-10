import AppKit
import UniformTypeIdentifiers

@MainActor
enum ImageExporter {
    static func copy(_ image: CGImage, pointSize: CGSize) {
        let rep = bitmap(image, pointSize: pointSize)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.png, .tiff], owner: nil)
        if let png = rep.representation(using: .png, properties: [:]) {
            pasteboard.setData(png, forType: .png)
        }
        if let tiff = rep.tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
        }
    }

    static func save(_ image: CGImage, pointSize: CGSize, completion: @escaping () -> Void) {
        let panel = NSSavePanel()
        panel.title = "Save Screenshot"
        panel.allowedContentTypes = [.png, .jpeg]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = defaultFileName()
        panel.directoryURL = Preferences.shared.saveDirectory

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            defer { completion() }
            guard response == .OK, let url = panel.url else { return }

            do {
                try encodedData(image, pointSize: pointSize, pathExtension: url.pathExtension)?.write(to: url, options: .atomic)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    /// JPEG for `.jpg`/`.jpeg`, PNG for anything else.
    static func encodedData(_ image: CGImage, pointSize: CGSize, pathExtension: String) -> Data? {
        let rep = bitmap(image, pointSize: pointSize)
        return ["jpg", "jpeg"].contains(pathExtension.lowercased())
            ? rep.representation(using: .jpeg, properties: [.compressionFactor: 0.92])
            : rep.representation(using: .png, properties: [:])
    }

    /// Bitmap tagged with its point size so Retina captures paste at the correct physical size.
    static func bitmap(_ image: CGImage, pointSize: CGSize) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(cgImage: image)
        if pointSize.width > 0, pointSize.height > 0 { rep.size = pointSize }
        return rep
    }

    static func defaultFileName(date: Date = Date(), timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "Screenshot \(formatter.string(from: date)).png"
    }
}
