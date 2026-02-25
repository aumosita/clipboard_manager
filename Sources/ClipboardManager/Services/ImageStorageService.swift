import AppKit
import Foundation

final class ImageStorageService: @unchecked Sendable {
    static let shared = ImageStorageService()

    private let directoryName = "ClipboardImages"
    private let storageDirectoryURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "ClipboardManager"
        storageDirectoryURL = appSupport
            .appendingPathComponent(bundleID)
            .appendingPathComponent("ClipboardImages")

        // Ensure storage directory exists
        try? FileManager.default.createDirectory(at: storageDirectoryURL, withIntermediateDirectories: true)
    }

    /// Save an NSImage as PNG, returns the filename (not full path)
    func save(image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let filename = UUID().uuidString + ".png"
        let fileURL = storageDirectoryURL.appendingPathComponent(filename)

        do {
            try pngData.write(to: fileURL)
            return filename
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }

    /// Load an NSImage from a stored filename
    func load(path: String) -> NSImage? {
        let fileURL = storageDirectoryURL.appendingPathComponent(path)
        return NSImage(contentsOf: fileURL)
    }

    /// Delete a stored image file
    func delete(path: String) {
        let fileURL = storageDirectoryURL.appendingPathComponent(path)
        try? FileManager.default.removeItem(at: fileURL)
    }
}
