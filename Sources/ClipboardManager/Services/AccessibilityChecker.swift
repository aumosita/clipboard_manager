import AppKit
import ApplicationServices

@MainActor
final class AccessibilityChecker {
    /// Returns true if the app already has accessibility permission
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Check permission and prompt user if not granted.
    /// Shows a system prompt the first time, and a custom alert on subsequent checks.
    static func checkAndPrompt() {
        if isTrusted { return }

        // First: trigger the system's own "would you like to grant access" dialog
        // Hardcoded key to avoid Swift 6 concurrency issue with C global kAXTrustedCheckOptionPrompt
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if !trusted {
            // Show our own explanatory alert after a short delay
            // (so it doesn't overlap the system dialog)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showPermissionAlert()
            }
        }
    }

    /// Periodically re-check (useful after user grants permission in System Settings)
    static func startMonitoring(onGranted: @MainActor @Sendable @escaping () -> Void) {
        Task { @MainActor in
            while !AXIsProcessTrusted() {
                try? await Task.sleep(for: .seconds(2))
            }
            onGranted()
        }
    }

    private static func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = String(localized: "accessibility.alert.title", bundle: .main)
        alert.informativeText = String(localized: "accessibility.alert.message", bundle: .main)
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "accessibility.alert.openSystemSettings", bundle: .main))
        alert.addButton(withTitle: String(localized: "accessibility.alert.later", bundle: .main))

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    /// Opens System Settings directly to the Accessibility pane
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
