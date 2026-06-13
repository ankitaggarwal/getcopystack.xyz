//
//  WindowManager.swift
//  Copy Stack
//
//  Owns the floating stack window: builds it once, positions it near the menu
//  bar icon, and shows/hides it. Showing starts clipboard monitoring; hiding
//  stops it, so polling only runs while the stack is on screen. The window's
//  height tracks the number of items (up to a cap), growing as you copy and
//  shrinking as you paste.
//
//  Created by Ankit Aggarwal
//

import SwiftUI
import AppKit
import Combine

class WindowManager: NSObject {
    static let shared = WindowManager()
    private var window: NSWindow?
    private var itemsCancellable: AnyCancellable?

    // Notification for window visibility changes
    static let windowVisibilityChangedNotification = NSNotification.Name("WindowVisibilityChanged")

    // Layout metrics used to size the window to fit its contents.
    private enum Metrics {
        static let titlebar: CGFloat = 28   // transparent titlebar (holds the close button)
        static let header: CGFloat = 41     // count + paste-order toggle + clear, plus its divider
        static let listPadding: CGFloat = 12
        static let row: CGFloat = 42
        static let maxRows = 5              // beyond this the list scrolls
        static let emptyBody: CGFloat = 188
        static let width: CGFloat = 330
    }

    private override init() {
        super.init()
        // Initialize the window during construction
        createWindow()

        // Grow/shrink the window as items are added and pasted. This only
        // resizes the window — item ordering and paste logic are untouched.
        itemsCancellable = ClipboardStorage.shared.$items
            .map { $0.count }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateWindowHeight(animated: true)
            }
    }

    private func notifyVisibilityChanged() {
        NotificationCenter.default.post(
            name: WindowManager.windowVisibilityChangedNotification,
            object: nil,
            userInfo: ["isVisible": isStackWindowActive()]
        )
    }

    func showWindow() {
        // Ensure monitoring is started when window is shown (safe to call multiple times)
        MonitoringManager.shared.startMonitoring()

        // Small delay to ensure layout completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }

            // Size to current contents first, then anchor it near the menu bar.
            self.updateWindowHeight(animated: false)
            self.positionWindowBelowMenuBar()

            // Show the window without stealing focus from source app
            self.window?.orderFront(nil)

            // Notify observers of visibility change
            self.notifyVisibilityChanged()
        }
    }

    func hideWindow() {
        // Stop clipboard and keyboard monitoring when window is hidden
        MonitoringManager.shared.stopMonitoring()

        window?.orderOut(nil)

        // Notify observers of visibility change
        notifyVisibilityChanged()
    }

    func toggleWindow() {
        if window?.isVisible == true {
            hideWindow()
        } else {
            showWindow()
        }
    }

    func isStackWindowActive() -> Bool {
        return window?.isVisible == true
    }


    private func createWindow() {
        // Create a hosting controller with our clipboard view
        let hostingController = NSHostingController(
            rootView: ClipboardListView(
                storage: ClipboardStorage.shared,
                closeAction: { [weak self] in
                    self?.hideWindow()
                }
            )
        )

        // Calculate content size
        let contentRect = NSRect(x: 0, y: 0, width: Metrics.width, height: 320)

        // A titled window with a transparent titlebar so the SwiftUI header
        // reads as one continuous surface with it (no toolbar / "second bar").
        let styleMask: NSWindow.StyleMask = [.titled, .closable]
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        // Hide minimize and maximize buttons - keep only close button
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        // Configure window
        window.contentViewController = hostingController
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.level = .floating

        // Make window appear on all spaces/screens
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .fullScreenNone]

        // Visual effects
        window.isOpaque = false
        window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.98)

        // Prevent window from tabbing
        window.tabbingMode = .disallowed

        // Set delegate to handle window events
        window.delegate = self

        self.window = window

        // Hide window initially
        window.orderOut(nil)

        print("Window created and initialized")
    }

    // MARK: - Content-driven height

    private func targetHeight(for count: Int) -> CGFloat {
        if count == 0 {
            return Metrics.titlebar + Metrics.emptyBody
        }
        let rows = CGFloat(min(count, Metrics.maxRows))
        return Metrics.titlebar + Metrics.header + Metrics.listPadding + rows * Metrics.row
    }

    /// Resize the window to fit the current item count, keeping the top edge
    /// anchored so it grows downward from just below the menu bar.
    private func updateWindowHeight(animated: Bool) {
        guard let window = window else { return }
        let newHeight = targetHeight(for: ClipboardStorage.shared.items.count)

        var frame = window.frame
        guard abs(frame.height - newHeight) > 0.5 else { return }

        let top = frame.maxY  // keep the top fixed
        frame.size.height = newHeight
        frame.size.width = Metrics.width
        frame.origin.y = top - newHeight
        window.setFrame(frame, display: true, animate: animated)
    }

    private func positionWindowBelowMenuBar() {
        guard let window = self.window else { return }
        guard let screenFrame = NSScreen.main?.visibleFrame else { return }

        // Position near the menu bar icon (rightmost area of screen)
        let windowFrame = window.frame
        let menuBarHeight = NSStatusBar.system.thickness

        // The x position should be at the right edge of the screen minus the window width
        let xPosition = screenFrame.maxX - windowFrame.width - 20 // 20px buffer from right edge
        let yPosition = screenFrame.maxY - windowFrame.height - menuBarHeight - 10 // 10px buffer from menu bar

        window.setFrameOrigin(NSPoint(x: xPosition, y: yPosition))
    }
}

// MARK: - NSWindowDelegate
extension WindowManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            // Stop monitoring when window closes
            MonitoringManager.shared.stopMonitoring()

            // Clear clipboard stack when window is explicitly closed
            ClipboardStorage.shared.clearHistory()

            // Don't actually close the main window, just hide it
            window.orderOut(nil)

            // Notify observers of visibility change
            notifyVisibilityChanged()
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        // Window lost focus, but we want to keep monitoring as long as window is visible
        // Do nothing here - keep monitoring active
    }
}
