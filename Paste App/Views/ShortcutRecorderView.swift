//
//  ShortcutRecorderView.swift
//  Copy Stack
//
//  A small control that captures a key combination from the user and saves it
//  as the copy shortcut in ShortcutPreferences.
//
//  Created by Ankit Aggarwal
//

import SwiftUI
import Carbon

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var currentKeysPressed: String
    var onShortcutCaptured: (UInt32, UInt32) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.onShortcutCaptured = onShortcutCaptured
        view.onRecordingChanged = { recording in
            DispatchQueue.main.async {
                isRecording = recording
            }
        }
        view.onKeysChanged = { keys in
            DispatchQueue.main.async {
                currentKeysPressed = keys
            }
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.isRecording = isRecording
    }
}

class ShortcutRecorderNSView: NSView {
    var isRecording = false {
        didSet {
            if isRecording {
                startRecording()
            } else {
                stopRecording()
            }
        }
    }

    var onShortcutCaptured: ((UInt32, UInt32) -> Void)?
    var onRecordingChanged: ((Bool) -> Void)?
    var onKeysChanged: ((String) -> Void)?

    private var localMonitor: Any?
    private var flagsMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func startRecording() {
        // Become first responder to receive key events
        window?.makeFirstResponder(self)

        // Monitor modifier flags for real-time feedback
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            guard let self = self else { return event }

            let flags = event.modifierFlags
            var displayString = ""

            if flags.contains(.control) {
                displayString += "⌃"
            }
            if flags.contains(.option) {
                displayString += "⌥"
            }
            if flags.contains(.shift) {
                displayString += "⇧"
            }
            if flags.contains(.command) {
                displayString += "⌘"
            }

            self.onKeysChanged?(displayString.isEmpty ? "Press keys..." : displayString)
            return nil
        }

        // Monitor local key events
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }

            // Get key code and modifiers
            let keyCode = UInt32(event.keyCode)
            var carbonModifiers: UInt32 = 0

            let flags = event.modifierFlags
            if flags.contains(.command) {
                carbonModifiers |= UInt32(cmdKey)
            }
            if flags.contains(.shift) {
                carbonModifiers |= UInt32(shiftKey)
            }
            if flags.contains(.option) {
                carbonModifiers |= UInt32(optionKey)
            }
            if flags.contains(.control) {
                carbonModifiers |= UInt32(controlKey)
            }

            // Show real-time feedback with the key
            var displayString = ""
            if flags.contains(.control) { displayString += "⌃" }
            if flags.contains(.option) { displayString += "⌥" }
            if flags.contains(.shift) { displayString += "⇧" }
            if flags.contains(.command) { displayString += "⌘" }
            displayString += KeyCodeMapper.keyCodeToString(keyCode: keyCode)
            self.onKeysChanged?(displayString)

            // Require at least one modifier
            if carbonModifiers != 0 {
                print("ShortcutRecorder: Captured - keyCode: \(keyCode), modifiers: \(carbonModifiers)")
                self.onShortcutCaptured?(keyCode, carbonModifiers)
                self.isRecording = false
                self.onRecordingChanged?(false)
                return nil
            }

            return nil
        }
    }

    private func stopRecording() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    deinit {
        stopRecording()
    }
}
