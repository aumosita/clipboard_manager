import SwiftUI
import SwiftData
import AppKit
import HotKey
import ServiceManagement

@MainActor
@Observable
final class AppState {
    var clipboardMonitor: ClipboardMonitor?
    var hotKey: HotKey?
    var panel: FloatingPanel?
    var isLaunchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    var hasAccessibility: Bool = AccessibilityChecker.isTrusted

    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: ClipboardItem.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    func start() {
        guard clipboardMonitor == nil else { return }

        // Setup clipboard monitor (always runs regardless of accessibility)
        let context = modelContainer.mainContext
        let monitor = ClipboardMonitor(modelContext: context)
        monitor.start()
        clipboardMonitor = monitor

        // Check accessibility and setup hotkey
        if AccessibilityChecker.isTrusted {
            hasAccessibility = true
            setupHotKey()
        } else {
            hasAccessibility = false
            AccessibilityChecker.checkAndPrompt()
            // Monitor until permission is granted
            AccessibilityChecker.startMonitoring { [weak self] in
                Task { @MainActor in
                    self?.hasAccessibility = true
                    self?.setupHotKey()
                }
            }
        }
    }

    private func setupHotKey() {
        guard hotKey == nil else { return }
        let hk = HotKey(key: .v, modifiers: [.command, .shift])
        hk.keyDownHandler = { [weak self] in
            Task { @MainActor in
                self?.togglePanel()
            }
        }
        hotKey = hk
    }

    func togglePanel() {
        if let existingPanel = panel {
            existingPanel.dismiss()
            panel = nil
            return
        }

        let listView = ClipboardListView(
            onPaste: { [weak self] text in
                self?.dismissPanel()
                self?.clipboardMonitor?.ignoreNextContent = text
                PasteService.paste(text)
            },
            onDismiss: { [weak self] in
                self?.dismissPanel()
            }
        )
        .modelContainer(modelContainer)

        let hostingView = NSHostingView(rootView: listView)
        let newPanel = FloatingPanel(contentView: hostingView)
        newPanel.showAtCursor()
        newPanel.makeKey()
        panel = newPanel
    }

    func dismissPanel() {
        panel?.dismiss()
        panel = nil
    }

    func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to toggle launch at login: \(error)")
            isLaunchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

@main
struct ClipboardManagerApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            if !appState.hasAccessibility {
                Label("⚠️ 접근성 권한 필요", systemImage: "exclamationmark.triangle")

                Button("시스템 설정 열기...") {
                    AccessibilityChecker.openAccessibilitySettings()
                }

                Divider()
            }

            Button("클립보드 히스토리 보기 (⌘⇧V)") {
                appState.togglePanel()
            }

            Divider()

            Toggle("로그인 시 자동 시작", isOn: Binding(
                get: { appState.isLaunchAtLogin },
                set: { appState.toggleLaunchAtLogin($0) }
            ))

            Divider()

            Button("종료") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Image(systemName: appState.hasAccessibility ? "clipboard" : "clipboard.fill")
                .task {
                    appState.start()
                }
        }
        .modelContainer(appState.modelContainer)
    }
}
