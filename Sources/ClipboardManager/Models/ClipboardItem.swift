import Foundation
import SwiftData
import AppKit

enum ClipboardContentType: String, Codable {
    case text
    case image
    case file
}

@Model
final class ClipboardItem {
    var id: UUID
    var content: String
    var timestamp: Date
    var isPinned: Bool

    /// "text", "image", or "file" — stored as String for #Predicate compatibility
    var contentTypeRaw: String = ClipboardContentType.text.rawValue

    /// Path to saved image file (relative to app's image storage directory)
    var imagePath: String? = nil

    /// JSON array of file URL strings, e.g. ["file:///path/to/file1", "file:///path/to/file2"]
    var fileURLsJSON: String? = nil

    var contentType: ClipboardContentType {
        get { ClipboardContentType(rawValue: contentTypeRaw) ?? .text }
        set { contentTypeRaw = newValue.rawValue }
    }

    init(content: String, contentType: ClipboardContentType = .text, isPinned: Bool = false) {
        self.id = UUID()
        self.content = content
        self.contentTypeRaw = contentType.rawValue
        self.timestamp = Date()
        self.isPinned = isPinned
    }

    // MARK: - Computed Helpers

    var displayTitle: String {
        switch contentType {
        case .text:
            return content
        case .image:
            return content.isEmpty ? String(localized: "row.type.image", bundle: .main) : content
        case .file:
            return content
        }
    }

    var fileURLList: [URL] {
        get {
            guard let json = fileURLsJSON,
                  let data = json.data(using: .utf8),
                  let strings = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return strings.compactMap { URL(string: $0) }
        }
        set {
            let strings = newValue.map { $0.absoluteString }
            if let data = try? JSONEncoder().encode(strings) {
                fileURLsJSON = String(data: data, encoding: .utf8)
            }
        }
    }

    var thumbnailImage: NSImage? {
        guard contentType == .image, let imagePath = imagePath else { return nil }
        return ImageStorageService.shared.load(path: imagePath)
    }
}
