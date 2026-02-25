import AppKit
import CoreGraphics

@MainActor
final class PasteService {
    /// Pastes the given ClipboardItem by setting it on the system pasteboard
    /// and simulating ⌘V in the previously active application.
    /// Returns the change count after setting the pasteboard (for ignore logic).
    @discardableResult
    static func paste(_ item: ClipboardItem) -> Int {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.contentType {
        case .text:
            pasteboard.setString(item.content, forType: .string)

        case .image:
            if let image = item.thumbnailImage,
               let tiffData = image.tiffRepresentation {
                pasteboard.setData(tiffData, forType: .tiff)
            }

        case .file:
            let urls = item.fileURLList
            if !urls.isEmpty {
                pasteboard.writeObjects(urls as [NSURL])
            }
        }

        let changeCount = pasteboard.changeCount

        // Small delay to let the panel close and the previous app regain focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Self.simulateCmdV()
        }

        return changeCount
    }

    /// Legacy text-only paste for backward compatibility
    @discardableResult
    static func paste(_ text: String) -> Int {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let changeCount = pasteboard.changeCount

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Self.simulateCmdV()
        }

        return changeCount
    }

    private static func simulateCmdV() {
        // Create key-down event for ⌘V
        let source = CGEventSource(stateID: .hidSystemState)

        // 'v' keycode = 9
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
