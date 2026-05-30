//
//  ClipboardStorage.swift
//  Copy Stack
//
//  The observable stack of collected clipboard items. Owns the add/remove
//  rules, the LIFO vs FIFO paste ordering, item trimming, and the copy sound.
//
//  Created by Ankit Aggarwal
//

import Foundation
import AppKit

class ClipboardStorage: ObservableObject {
    // Singleton instance
    static let shared = ClipboardStorage()

    @Published var items: [ClipboardItem] = []
    @Published var nextInSequence: ClipboardItem? = nil
    private let maxItems: Int

    init(maxItems: Int = 50) {
        self.maxItems = maxItems

        // Listen for stack direction changes to update nextInSequence
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStackDirectionChanged),
            name: NSNotification.Name("StackDirectionChanged"),
            object: nil
        )
    }

    @objc private func handleStackDirectionChanged() {
        // Pass syncClipboard=true to load clipboard AFTER nextInSequence update completes
        updateNextInSequence(syncClipboard: true)
    }

    // Update which item is next in sequence based on paste mode
    // syncClipboard: if true, loads the new nextInSequence to clipboard after update
    func updateNextInSequence(syncClipboard: Bool = false) {
        DispatchQueue.main.async {
            if GeneralPreferences.shared.stackGrowsFromTop {
                // LIFO mode: newest item (first in array) is next
                self.nextInSequence = self.items.first
            } else {
                // FIFO mode: oldest item (last in array) is next
                self.nextInSequence = self.items.last
            }

            // If requested, sync clipboard to match new nextInSequence
            // This ensures clipboard and visual highlight are in sync
            if syncClipboard, let next = self.nextInSequence {
                self.loadItemToClipboard(next)
            }
        }
    }

    // Add a new clipboard item
    func addItem(_ item: ClipboardItem) {
        DispatchQueue.main.async {
            // Send object change notification
            self.objectWillChange.send()

            // Insert new item at the beginning (index 0)
            self.items.insert(item, at: 0)

            // Trim items if we exceed the maximum
            if self.items.count > self.maxItems {
                if GeneralPreferences.shared.stackGrowsFromTop {
                    // LIFO mode: drop oldest items (at the end) - they're furthest from being pasted
                    self.items = Array(self.items.prefix(self.maxItems))
                } else {
                    // FIFO mode: drop the second-newest item to preserve both:
                    // - The new item the user just copied (index 0)
                    // - The oldest items waiting to be pasted (at the end)
                    // This prevents the "next" highlighted item from disappearing unexpectedly
                    if self.items.count > 1 {
                        self.items.remove(at: 1)
                    }
                }
            }

            // Update which item is next in sequence based on mode
            self.updateNextInSequence()

            // In FIFO mode, load the oldest item to clipboard (not the newest)
            // This ensures the first paste will be the oldest item
            if !GeneralPreferences.shared.stackGrowsFromTop && !self.items.isEmpty {
                if let oldestItem = self.items.last {
                    self.loadItemToClipboard(oldestItem)
                }
            }

            // Play copy sound
            self.playCopySound()
        }
    }
    
    // Clear all clipboard history
    func clearHistory() {
        DispatchQueue.main.async {
            self.objectWillChange.send()

            // Clean up video files before clearing items
            self.cleanupVideoFiles()

            self.items.removeAll()
            self.updateNextInSequence()  // Will set to nil since items is empty
        }
    }

    // Check if an item is next in sequence
    func isNextInSequence(_ item: ClipboardItem) -> Bool {
        return nextInSequence?.id == item.id
    }
    
    // Remove an item at specific index from the stack
    func removeItem(at index: Int) {
        guard index < items.count else { return }

        DispatchQueue.main.async {
            self.objectWillChange.send()

            self.items.remove(at: index)

            // Update next in sequence based on mode
            self.updateNextInSequence()
        }
    }

    // Remove the first item from the stack (used when item is consumed)
    func removeFirstItem() {
        removeItem(at: 0)
    }

    // Remove the current nextInSequence item (used during paste operation)
    func removeNextInSequence() {
        guard let next = nextInSequence else { return }

        DispatchQueue.main.async {
            self.objectWillChange.send()

            // Remove the item by ID
            self.items.removeAll { $0.id == next.id }

            // Update to new nextInSequence
            self.updateNextInSequence()
        }
    }

    // Load a specific item to the clipboard (public for use by HotkeyManager)
    func loadItemToClipboard(_ item: ClipboardItem) {
        // Tell the clipboard monitor to ignore this change
        Paste_AppApp.monitor.ignoreNextClipboardChange()

        // Copy to clipboard using shared helper
        ClipboardHelper.writeItemToPasteboard(item, pasteboard: NSPasteboard.general)
    }

    // MARK: - Video File Cleanup

    private func cleanupVideoFiles() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let videosDir = appSupport.appendingPathComponent("PasteApp/Videos", isDirectory: true)

        for item in items where item.type == .video {
            guard let videoURL = item.videoURL else { continue }

            // Only delete if file is in our app's storage directory
            if videoURL.path.starts(with: videosDir.path) {
                do {
                    try FileManager.default.removeItem(at: videoURL)
                    print("ClipboardStorage: Deleted video file: \(videoURL.lastPathComponent)")
                } catch {
                    print("ClipboardStorage: Failed to delete video file: \(error)")
                }
            }
        }
    }

    // MARK: - Sound Support

    private func playCopySound() {
        // Check if sound effects are enabled
        guard GeneralPreferences.shared.soundEffects else {
            return
        }

        // Only play custom sound - no fallback
        playCustomCopySound()
    }

    private func playCustomCopySound() {
        // First check the app bundle for the sound file
        if let soundPath = Bundle.main.path(forResource: "copy-sound", ofType: "mp3") {
            if let sound = NSSound(contentsOfFile: soundPath, byReference: false) {
                sound.play()
            }
        } else {
            // Fallback to checking other formats in bundle
            let formats = ["wav", "aiff", "m4a"]
            for format in formats {
                if let soundPath = Bundle.main.path(forResource: "copy-sound", ofType: format) {
                    if let sound = NSSound(contentsOfFile: soundPath, byReference: false) {
                        sound.play()
                        return
                    }
                }
            }
        }
    }
}
