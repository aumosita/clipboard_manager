import AppKit
import SwiftData

@MainActor
final class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let modelContext: ModelContext
    private let maxItems = 100

    /// Content to ignore on next clipboard change (set when we paste via PasteService)
    var ignoreNextContent: String?

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

        guard let content = pasteboard.string(forType: .string),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // Skip if this was set by our own paste action
        if let ignoreContent = ignoreNextContent, ignoreContent == content {
            ignoreNextContent = nil
            return
        }

        // Avoid duplicating the most recent item
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        if let existing = try? modelContext.fetch(descriptor).first,
           existing.content == content {
            // Update timestamp so it moves to top
            existing.timestamp = Date()
            try? modelContext.save()
            return
        }

        // Insert new item
        let item = ClipboardItem(content: content)
        modelContext.insert(item)

        // Enforce max count (only for non-pinned items)
        pruneOldItems()

        try? modelContext.save()
    }

    private func pruneOldItems() {
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate<ClipboardItem> { !$0.isPinned },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        guard let unpinnedItems = try? modelContext.fetch(descriptor) else { return }

        if unpinnedItems.count > maxItems {
            let itemsToDelete = unpinnedItems.suffix(from: maxItems)
            for item in itemsToDelete {
                modelContext.delete(item)
            }
        }
    }
}
