import AppKit
import CoreGraphics

@MainActor
final class PasteService {
    /// Pastes the given text by setting it on the system pasteboard
    /// and simulating ⌘V in the previously active application.
    static func paste(_ text: String) {
        // Set the pasteboard content
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to let the panel close and the previous app regain focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Self.simulateCmdV()
        }
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
