//
//  WindowManager.swift
//  Copy Stack
//
//  Owns the floating stack window: builds it once, positions it near the menu
//  bar icon, and shows/hides it. Showing starts clipboard monitoring; hiding
//  stops it, so polling only runs while the stack is on screen.
//
//  Created by Ankit Aggarwal
//

import SwiftUI
import AppKit

class WindowManager: NSObject {
    static let shared = WindowManager()
    private var window: NSWindow?
    private weak var stackDirectionButton: NSButton?

    // Notification for window visibility changes
    static let windowVisibilityChangedNotification = NSNotification.Name("WindowVisibilityChanged")

    private override init() {
        super.init()
        // Initialize the window during construction
        createWindow()

        // Listen for stack direction changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStackDirectionChanged),
            name: NSNotification.Name("StackDirectionChanged"),
            object: nil
        )
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

            // Position the window near the menu bar icon
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
        
        // Create the toolbar
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.showsBaselineSeparator = false
        
        // Calculate content size
        let contentRect = NSRect(x: 0, y: 0, width: 300, height: 320)
        
        // Create a standard window with a title bar
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .resizable]
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
        window.toolbar = toolbar

        // Make window appear on all spaces/screens
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .fullScreenNone]
        
        // Set minimum size (wider to ensure toolbar button is always visible)
        window.minSize = NSSize(width: 240, height: 160)
        
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

    // MARK: - Paste Order Toggle

    private func createStackDirectionIcon(growsFromTop: Bool) -> NSImage {
        // Use arrows to indicate temporal paste direction
        // ↓ = Going backward in time (newest first - LIFO)
        // ↑ = Going forward in time (oldest first - FIFO)
        let symbolName = growsFromTop ? "arrow.down.circle" : "arrow.up.circle"
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        return NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)!
            .withSymbolConfiguration(config)!
    }

    private func updateTooltip(growsFromTop: Bool) {
        // Dynamic tooltip showing current mode and what clicking will do
        stackDirectionButton?.toolTip = growsFromTop ?
            "Paste newest first • Click to paste oldest first" :
            "Paste oldest first • Click to paste newest first"
    }

    @objc private func handleStackDirectionChanged() {
        let growsFromTop = GeneralPreferences.shared.stackGrowsFromTop
        stackDirectionButton?.image = createStackDirectionIcon(growsFromTop: growsFromTop)
        updateTooltip(growsFromTop: growsFromTop)
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

// MARK: - NSToolbarDelegate
extension WindowManager: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case NSToolbarItem.Identifier("stackDirection"):
            let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
            let button = NSButton()
            button.image = createStackDirectionIcon(growsFromTop: GeneralPreferences.shared.stackGrowsFromTop)
            button.bezelStyle = .accessoryBarAction
            button.isBordered = false
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(toggleStackDirectionAction)
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)

            // Store button reference for updates
            self.stackDirectionButton = button

            // Use constraints instead of deprecated minSize/maxSize
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 28),
                button.heightAnchor.constraint(equalToConstant: 28)
            ])

            toolbarItem.view = button
            toolbarItem.label = ""
            // Set initial tooltip dynamically based on current mode
            updateTooltip(growsFromTop: GeneralPreferences.shared.stackGrowsFromTop)
            return toolbarItem
        default:
            return nil
        }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.flexibleSpace, NSToolbarItem.Identifier("stackDirection")]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.flexibleSpace, NSToolbarItem.Identifier("stackDirection")]
    }

    @objc private func toggleStackDirectionAction() {
        GeneralPreferences.shared.stackGrowsFromTop.toggle()
        let mode = GeneralPreferences.shared.stackGrowsFromTop ? "newest first" : "oldest first"
        print("WindowManager: Paste order toggled to \(mode)")
    }
}
