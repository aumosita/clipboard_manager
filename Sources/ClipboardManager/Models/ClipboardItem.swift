import Foundation
import SwiftData

@Model
final class ClipboardItem {
    var id: UUID
    var content: String
    var timestamp: Date
    var isPinned: Bool

    init(content: String, isPinned: Bool = false) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.isPinned = isPinned
    }
}
