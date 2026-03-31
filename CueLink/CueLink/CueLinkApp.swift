import SwiftUI
import UserNotifications

@main
struct CueLinkApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private static let menuBarImage: NSImage = {
        // Try loading from SPM resource bundle
        if let url = Bundle.module.url(forResource: "menubar_icon@2x", withExtension: "png", subdirectory: "Resources"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        // Try without subdirectory
        if let url = Bundle.module.url(forResource: "menubar_icon@2x", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        // Fallback: SF Symbol
        return NSImage(systemSymbolName: "music.note", accessibilityDescription: "CueLink")!
    }()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopover(
                openSettings: { openSettingsWindow() },
                openAbout: { openAboutWindow() },
                updateChecker: appDelegate.updateChecker
            )
            .environmentObject(appState)
        } label: {
            Image(nsImage: Self.menuBarImage)
        }
        .menuBarExtraStyle(.window)

        Window("CueLink Settings", id: "settings") {
            SettingsView()
                .environmentObject(appState)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    // Ensure the window becomes key and the app is fully activated
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NSApp.activate(ignoringOtherApps: true)
                        NSApp.windows.first { $0.title == "CueLink Settings" }?.makeKeyAndOrderFront(nil)
                    }
                }
                .onDisappear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if !self.hasVisibleWindows() {
                            NSApp.setActivationPolicy(.accessory)
                        }
                    }
                }
        }
        .defaultSize(width: 650, height: 450)
        .windowResizability(.contentSize)

        Window("About CueLink", id: "about") {
            AboutView()
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .onDisappear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if !self.hasVisibleWindows() {
                            NSApp.setActivationPolicy(.accessory)
                        }
                    }
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 300, height: 320)
    }

    private func openSettingsWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "settings")
    }

    private func openAboutWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "about")
    }

    private func hasVisibleWindows() -> Bool {
        NSApp.windows.contains { $0.isVisible && ($0.title == "CueLink Settings" || $0.title == "About CueLink") }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let updateChecker = UpdateChecker()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        requestNotificationPermission()
        Task { await updateChecker.checkForUpdates() }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("[CueLink] Notification permission error: \(error)")
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return true
    }
}
