//
//  Paste_AppApp.swift
//  Copy Stack
//
//  App entry point. Runs as a menu bar (accessory) app and wires up the
//  shared clipboard storage, the preferences, and the menu bar commands.
//
//  Created by Ankit Aggarwal
//

import SwiftUI
import Carbon
import AppKit
import Combine

// Helper class to observe window visibility changes
class WindowVisibilityObserver: ObservableObject {
    @Published var isVisible = false
    private var cancellable: AnyCancellable?

    init() {
        cancellable = NotificationCenter.default.publisher(for: WindowManager.windowVisibilityChangedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let isVisible = notification.userInfo?["isVisible"] as? Bool {
                    self?.isVisible = isVisible
                }
            }
    }
}

@main
struct Paste_AppApp: App {
    // Use the shared storage instance
    @StateObject private var storage = ClipboardStorage.shared

    // Observe general preferences
    @StateObject private var generalPreferences = GeneralPreferences.shared

    // Track window visibility for dynamic menu text
    @StateObject private var windowVisibility = WindowVisibilityObserver()

    // Make the monitor static so it can be accessed from anywhere
    static let monitor = ClipboardMonitor(storage: ClipboardStorage.shared)

    // Create an AppDelegate instance
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Don't start monitoring automatically - only when stack window is active

        // Set activation policy to accessory (menu bar only app)
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    func showSettingsWindow() {
        // Activate the application
        NSApplication.shared.activate(ignoringOtherApps: true)

        // Open settings window
        if let settingsWindow = NSApplication.shared.windows.first(where: { $0.title == "Settings" }) {
            // Show the window first, then center it
            settingsWindow.makeKeyAndOrderFront(nil)
            centerWindow(settingsWindow)
        } else {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 380),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Settings"
            window.contentViewController = hostingController
            window.isReleasedWhenClosed = false
            window.makeKeyAndOrderFront(nil)

            // Center after the window is shown
            centerWindow(window)
        }
    }

    private func centerWindow(_ window: NSWindow) {
        DispatchQueue.main.async {
            window.center()
        }
    }
    
    var body: some Scene {
        MenuBarExtra("Clipboard", systemImage: "clipboard") {
            Button(windowVisibility.isVisible ? "Hide Stack" : "Show Stack") {
                // Bring the app forward before triggering the copy + stack window
                NSRunningApplication.current.activate()

                // Small delay to ensure activation, then trigger the same behavior as hotkey
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // This will copy selected content and show/hide the window
                    HotkeyManager.shared.handleCopyAndShowStack()
                }
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

            Divider()

            Button("Settings...") {
                showSettingsWindow()
            }
            .keyboardShortcut(",", modifiers: [.command])

            Button("Check for Updates...") {
                UpdateChecker.check(silent: false)
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
        .menuBarExtraStyle(.menu)

        // Hidden main window - only shows if accessed directly
        WindowGroup {
            EmptyView()
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "never-match"))
    }
}
