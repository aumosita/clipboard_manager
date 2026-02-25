import AppKit
import SwiftData

@MainActor
final class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let modelContext: ModelContext
    private let maxItems = 100

    /// When true, skip the next clipboard change (set when we paste via PasteService)
    var ignoreNextChange: Bool = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkClipboard()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount

        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        // Skip if this was set by our own paste action
        if ignoreNextChange {
            ignoreNextChange = false
            return
        }

        // Detect content type in priority order: file → image → text
        if let fileURLs = readFileURLs(from: pasteboard), !fileURLs.isEmpty {
            handleFileContent(fileURLs)
        } else if let image = readImage(from: pasteboard) {
            handleImageContent(image)
        } else if let text = pasteboard.string(forType: .string),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            handleTextContent(text)
        }
    }

    // MARK: - Content Type Detection

    private func readFileURLs(from pasteboard: NSPasteboard) -> [URL]? {
        // Check if pasteboard contains file URLs
        guard pasteboard.types?.contains(.fileURL) == true else { return nil }

        // Read file URLs — filter out non-file URLs
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL]

        return urls
    }

    private func readImage(from pasteboard: NSPasteboard) -> NSImage? {
        // Check for image types (TIFF is the native format for NSPasteboard images)
        let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]
        for type in imageTypes {
            if let data = pasteboard.data(forType: type),
               let image = NSImage(data: data) {
                return image
            }
        }
        return nil
    }

    // MARK: - Content Handling

    private func handleTextContent(_ text: String) {
        // Avoid duplicating the most recent text item
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        if let existing = try? modelContext.fetch(descriptor).first,
           existing.contentType == .text,
           existing.content == text {
            existing.timestamp = Date()
            try? modelContext.save()
            return
        }

        let item = ClipboardItem(content: text, contentType: .text)
        modelContext.insert(item)
        pruneOldItems()
        try? modelContext.save()
    }

    private func handleImageContent(_ image: NSImage) {
        // Save image to disk
        guard let filename = ImageStorageService.shared.save(image: image) else { return }

        // Create description with image dimensions
        let size = image.size
        let description = String(
            localized: "row.type.image",
            bundle: .main
        ) + " (\(Int(size.width))×\(Int(size.height)))"

        let item = ClipboardItem(content: description, contentType: .image)
        item.imagePath = filename
        modelContext.insert(item)
        pruneOldItems()
        try? modelContext.save()
    }

    private func handleFileContent(_ urls: [URL]) {
        let filenames = urls.map { $0.lastPathComponent }
        let displayText: String
        if filenames.count == 1 {
            displayText = filenames[0]
        } else {
            displayText = String(
                localized: "row.type.files",
                bundle: .main
            ) + " (\(filenames.count)): " + filenames.prefix(3).joined(separator: ", ")
            + (filenames.count > 3 ? "…" : "")
        }

        // Avoid duplicating the most recent file item with same URLs
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        if let existing = try? modelContext.fetch(descriptor).first,
           existing.contentType == .file,
           existing.fileURLList == urls {
            existing.timestamp = Date()
            try? modelContext.save()
            return
        }

        let item = ClipboardItem(content: displayText, contentType: .file)
        item.fileURLList = urls
        modelContext.insert(item)
        pruneOldItems()
        try? modelContext.save()
    }

    // MARK: - Pruning

    private func pruneOldItems() {
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate<ClipboardItem> { !$0.isPinned },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        guard let unpinnedItems = try? modelContext.fetch(descriptor) else { return }

        if unpinnedItems.count > maxItems {
            let itemsToDelete = unpinnedItems.suffix(from: maxItems)
            for item in itemsToDelete {
                // Clean up associated image files
                if let imagePath = item.imagePath {
                    ImageStorageService.shared.delete(path: imagePath)
                }
                modelContext.delete(item)
            }
        }
    }
}
