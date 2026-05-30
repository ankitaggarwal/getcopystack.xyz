//
//  ShortcutPreferences.swift
//  Copy Stack
//
//  Stores the customizable copy shortcut (key code + modifiers) in UserDefaults
//  and broadcasts changes so HotkeyManager can re-register the global hotkey.
//
//  Created by Ankit Aggarwal
//

import Foundation
import Carbon

class ShortcutPreferences: ObservableObject {
    static let shared = ShortcutPreferences()

    @Published var currentKeyCode: UInt32
    @Published var currentModifiers: UInt32

    private let keyCodeKey = "CustomShortcutKeyCode"
    private let modifiersKey = "CustomShortcutModifiers"

    // Default shortcut: Command+Shift+C
    static let defaultKeyCode: UInt32 = UInt32(kVK_ANSI_C)
    static let defaultModifiers: UInt32 = UInt32(cmdKey | shiftKey)

    private init() {
        // Load saved shortcut or use default
        if UserDefaults.standard.object(forKey: keyCodeKey) != nil {
            self.currentKeyCode = UInt32(UserDefaults.standard.integer(forKey: keyCodeKey))
            self.currentModifiers = UInt32(UserDefaults.standard.integer(forKey: modifiersKey))
        } else {
            self.currentKeyCode = ShortcutPreferences.defaultKeyCode
            self.currentModifiers = ShortcutPreferences.defaultModifiers
        }
    }

    func updateShortcut(keyCode: UInt32, modifiers: UInt32) {
        self.currentKeyCode = keyCode
        self.currentModifiers = modifiers

        // Save to UserDefaults
        UserDefaults.standard.set(Int(keyCode), forKey: keyCodeKey)
        UserDefaults.standard.set(Int(modifiers), forKey: modifiersKey)

        print("ShortcutPreferences: Updated shortcut - keyCode: \(keyCode), modifiers: \(modifiers)")

        // Notify HotkeyManager to re-register
        NotificationCenter.default.post(name: NSNotification.Name("ShortcutPreferencesChanged"), object: nil)
    }

    func resetToDefault() {
        updateShortcut(keyCode: ShortcutPreferences.defaultKeyCode, modifiers: ShortcutPreferences.defaultModifiers)
    }

    func getShortcutDisplayString() -> String {
        var components: [String] = []

        // Add modifier symbols
        if currentModifiers & UInt32(controlKey) != 0 {
            components.append("⌃")
        }
        if currentModifiers & UInt32(optionKey) != 0 {
            components.append("⌥")
        }
        if currentModifiers & UInt32(shiftKey) != 0 {
            components.append("⇧")
        }
        if currentModifiers & UInt32(cmdKey) != 0 {
            components.append("⌘")
        }

        // Add key character
        components.append(KeyCodeMapper.keyCodeToString(keyCode: currentKeyCode))

        return components.joined()
    }
}
