//
//  HotkeyManager.swift
//  Copy Stack
//
//  Registers the global hotkeys via the Carbon Event Manager: Cmd+Shift+C to
//  copy and toggle the stack window, and a system-wide Cmd+V intercept that
//  pastes the next stack item (or falls through to a normal paste when empty).
//
//  Created by Ankit Aggarwal
//

import Foundation
import AppKit
import Carbon
import ApplicationServices

class HotkeyManager {
    static let shared = HotkeyManager()

    // Event handler for our hotkey
    private var eventHandler: EventHandlerRef?

    // Hotkey for Cmd+Shift+C (copy and show stack)
    private var copyHotKeyID = EventHotKeyID()
    private var copyHotKeyRef: EventHotKeyRef?

    // Hotkey for Cmd+V (paste from stack)
    private var pasteHotKeyID = EventHotKeyID()
    private var pasteHotKeyRef: EventHotKeyRef?

    // Get current shortcut from preferences
    private var currentKeyCode: UInt32 {
        return ShortcutPreferences.shared.currentKeyCode
    }

    private var currentModifiers: UInt32 {
        return ShortcutPreferences.shared.currentModifiers
    }

    private init() {
        // Generate unique IDs for hotkeys
        copyHotKeyID.signature = OSType("PAPP".utf16.reduce(0, {$0 << 8 + UInt32($1)}))
        copyHotKeyID.id = 1

        pasteHotKeyID.signature = OSType("PAPP".utf16.reduce(0, {$0 << 8 + UInt32($1)}))
        pasteHotKeyID.id = 2

        // Listen for shortcut preference changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShortcutPreferencesChanged),
            name: NSNotification.Name("ShortcutPreferencesChanged"),
            object: nil
        )
    }

    @objc private func handleShortcutPreferencesChanged() {
        print("HotkeyManager: Shortcut preferences changed, re-registering hotkey")
        unregisterHotkeys()
        registerHotkeys()
    }
    
    func registerHotkeys() {
        // Install the Carbon event handler
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)

        // Create a handler that will call our callback when the hotkey is pressed
        InstallEventHandler(GetApplicationEventTarget(), { (_, eventRef, _) -> OSStatus in
            let hotKeyManager = HotkeyManager.shared

            var hotkeyID = EventHotKeyID()
            GetEventParameter(eventRef, UInt32(kEventParamDirectObject), UInt32(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)

            if hotkeyID.id == hotKeyManager.copyHotKeyID.id {
                print("HotkeyManager: [Carbon] Copy hotkey received (Cmd+Shift+C)")
                // Cmd+Shift+C: Copy and show stack window
                hotKeyManager.handleCopyAndShowStack()
            } else if hotkeyID.id == hotKeyManager.pasteHotKeyID.id {
                print("HotkeyManager: [Carbon] Paste hotkey received (Cmd+V)")
                // Cmd+V: Paste from stack
                hotKeyManager.handlePasteFromStack()
            }

            return noErr
        }, 1, &eventType, nil, &eventHandler)

        // Register Cmd+Shift+C hotkey (copy and show stack)
        let copyResult = RegisterEventHotKey(
            currentKeyCode,
            currentModifiers,
            copyHotKeyID,
            GetApplicationEventTarget(),
            0,
            &copyHotKeyRef
        )

        if copyResult == noErr {
            print("HotkeyManager: Successfully registered copy hotkey - keyCode: \(currentKeyCode), modifiers: \(currentModifiers)")
        } else {
            print("HotkeyManager: Failed to register copy hotkey - error code: \(copyResult)")
        }

        // Register Cmd+V hotkey (paste from stack)
        // V key = 0x09, Cmd = cmdKey (0x0100)
        let pasteResult = RegisterEventHotKey(
            0x09,  // V key
            UInt32(cmdKey),  // Command modifier
            pasteHotKeyID,
            GetApplicationEventTarget(),
            0,
            &pasteHotKeyRef
        )

        if pasteResult == noErr {
            print("HotkeyManager: Successfully registered Cmd+V paste hotkey")
        } else {
            print("HotkeyManager: Failed to register Cmd+V paste hotkey - error code: \(pasteResult)")
        }
    }
    
    // Handle the hotkey press - toggle stack window visibility
    func handleCopyAndShowStack() {
        // Check if window is currently visible
        if WindowManager.shared.isStackWindowActive() {
            // Window is visible → hide it
            print("HotkeyManager: Hotkey pressed - hiding stack")
            WindowManager.shared.hideWindow()
        } else {
            // Window is hidden → show it with copy operation
            print("HotkeyManager: Hotkey pressed - triggering copy and showing stack")

            // Start monitoring BEFORE simulating Cmd+C so we can detect the clipboard change
            MonitoringManager.shared.startMonitoring()

            // Simulate Cmd+C to copy the currently selected content
            triggerCopyOperation()

            // Show the stack window after a delay to allow copy to complete and be detected
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("HotkeyManager: Showing window")
                WindowManager.shared.showWindow()
            }
        }
    }

    // Flag to prevent re-entrant handling of Cmd+V
    private var isPasting = false

    // Handle Cmd+V paste from stack
    func handlePasteFromStack() {
        // Prevent re-entrant calls (from our own simulated Cmd+V)
        guard !isPasting else {
            print("HotkeyManager: Ignoring re-entrant Cmd+V")
            return
        }

        let storage = ClipboardStorage.shared

        // If stack is empty, simulate normal Cmd+V
        guard !storage.items.isEmpty else {
            print("HotkeyManager: Stack is empty, simulating normal paste")
            isPasting = true
            simulateNormalPaste()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isPasting = false
            }
            return
        }

        print("HotkeyManager: Pasting from stack (\(storage.items.count) items)")

        // The current item is already in the clipboard (loaded when window was shown or after previous paste)
        // So we just need to simulate Cmd+V, then advance to the next item
        isPasting = true
        simulateNormalPaste()

        // After paste completes, handle stack operation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.isPasting = false
            self.handleStackPasteOperation()
        }
    }

    // Handle advancing through the stack after a paste
    private func handleStackPasteOperation() {
        let storage = ClipboardStorage.shared

        guard !storage.items.isEmpty else {
            return
        }

        // Remove the item that was just pasted (which was nextInSequence)
        storage.removeNextInSequence()

        // Play paste sound
        if GeneralPreferences.shared.soundEffects {
            NSSound(named: "Tink")?.play()
        }

        // Load next item to clipboard after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let nextItem = storage.nextInSequence {
                // Tell clipboard monitor to ignore the next clipboard change
                Paste_AppApp.monitor.ignoreNextClipboardChange()

                // Load next item to clipboard
                storage.loadItemToClipboard(nextItem)
            }
        }
    }

    // Post Cmd + <key> through the session event tap (used to simulate copy/paste)
    private func postCommandKey(_ virtualKey: CGKeyCode) {
        let cmdDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: true)  // Command down
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: virtualKey, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: virtualKey, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: false)   // Command up

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        cmdDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
        cmdUp?.post(tap: .cgAnnotatedSessionEventTap)
    }

    // Simulate a normal Cmd+V paste operation
    private func simulateNormalPaste() {
        guard AXIsProcessTrusted() else {
            print("HotkeyManager: ERROR - Cannot simulate paste without accessibility permission!")
            return
        }
        postCommandKey(0x09) // V
    }

    // Simulate Cmd+C keypress to copy selected content
    private func triggerCopyOperation() {
        postCommandKey(0x08) // C
    }

    func unregisterHotkeys() {
        if let copyRef = copyHotKeyRef {
            UnregisterEventHotKey(copyRef)
            self.copyHotKeyRef = nil
        }

        if let pasteRef = pasteHotKeyRef {
            UnregisterEventHotKey(pasteRef)
            self.pasteHotKeyRef = nil
        }

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
}
