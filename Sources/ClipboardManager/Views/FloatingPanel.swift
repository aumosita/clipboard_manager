import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false
        self.animationBehavior = .utilityWindow
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.acceptsMouseMovedEvents = true
        self.becomesKeyOnlyIfNeeded = false

        self.contentView = contentView
    }

    /// Show the panel at current mouse cursor position
    func showAtCursor(size: NSSize = NSSize(width: 380, height: 460)) {
        let mouseLocation = NSEvent.mouseLocation

        // Find the screen containing the cursor
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.main ?? NSScreen.screens.first!

        let screenFrame = screen.visibleFrame

        // Position: panel appears below-right of cursor, adjusted to stay on screen
        var origin = NSPoint(
            x: mouseLocation.x - size.width / 2,
            y: mouseLocation.y - size.height
        )

        // Clamp to screen bounds
        origin.x = max(screenFrame.minX, min(origin.x, screenFrame.maxX - size.width))
        origin.y = max(screenFrame.minY, min(origin.y, screenFrame.maxY - size.height))

        setFrame(NSRect(origin: origin, size: size), display: true)
        makeKeyAndOrderFront(nil)
        makeFirstResponder(contentView)
    }

    func dismiss() {
        orderOut(nil)
    }

    // Allow the panel to become key so it receives keyboard events
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // Close on Escape
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            dismiss()
        } else {
            super.keyDown(with: event)
        }
    }

    // Close when clicking outside
    override func resignKey() {
        super.resignKey()
        dismiss()
    }
}
