//
//  GeneralPreferences.swift
//  Copy Stack
//
//  User-facing general settings backed by UserDefaults: launch at login,
//  sound effects, and the stack growth direction (LIFO vs FIFO).
//
//  Created by Ankit Aggarwal
//

import Foundation
import ServiceManagement

class GeneralPreferences: ObservableObject {
    static let shared = GeneralPreferences()

    @Published var openAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(openAtLogin, forKey: "OpenAtLogin")
            updateLoginItem()
        }
    }

    @Published var soundEffects: Bool {
        didSet {
            UserDefaults.standard.set(soundEffects, forKey: "SoundEffects")
        }
    }

    // Paste order mode: true = LIFO (stack), false = FIFO (queue)
    // - LIFO: Paste newest items first (last copied, first pasted)
    // - FIFO: Paste oldest items first (first copied, first pasted)
    // Note: Visual display always shows next-to-paste item at top with blue highlight
    @Published var stackGrowsFromTop: Bool {
        didSet {
            UserDefaults.standard.set(stackGrowsFromTop, forKey: "StackGrowsFromTop")
            NotificationCenter.default.post(name: NSNotification.Name("StackDirectionChanged"), object: nil)
        }
    }

    private init() {
        // Load saved preferences or use defaults
        self.openAtLogin = UserDefaults.standard.object(forKey: "OpenAtLogin") as? Bool ?? false
        self.soundEffects = UserDefaults.standard.object(forKey: "SoundEffects") as? Bool ?? true
        self.stackGrowsFromTop = UserDefaults.standard.object(forKey: "StackGrowsFromTop") as? Bool ?? true
    }

    private func updateLoginItem() {
        if #available(macOS 13.0, *) {
            do {
                if openAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update login item: \(error)")
            }
        }
    }
}

