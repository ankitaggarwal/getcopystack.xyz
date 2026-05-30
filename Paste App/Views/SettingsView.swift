//
//  SettingsView.swift
//  Copy Stack
//
//  The preferences window: General settings, the customizable copy shortcut,
//  clipboard history controls, and an About tab.
//
//  Created by Ankit Aggarwal
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var shortcutPreferences = ShortcutPreferences.shared
    @ObservedObject var generalPreferences = GeneralPreferences.shared
    @ObservedObject var clipboardStorage = ClipboardStorage.shared
    @State private var isRecording = false
    @State private var currentKeysPressed = ""
    @State private var selectedTab = "general"
    @State private var showClearConfirmation = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    SidebarMenuItem(
                        icon: "gearshape",
                        title: "General",
                        isSelected: selectedTab == "general"
                    ) {
                        selectedTab = "general"
                    }

                    SidebarMenuItem(
                        icon: "keyboard",
                        title: "Shortcuts",
                        isSelected: selectedTab == "shortcuts"
                    ) {
                        selectedTab = "shortcuts"
                    }

                    SidebarMenuItem(
                        icon: "info.circle",
                        title: "About",
                        isSelected: selectedTab == "about"
                    ) {
                        selectedTab = "about"
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 10)

                Spacer()
            }
            .frame(width: 180)
            .background(Color(nsColor: colorScheme == .dark ?
                NSColor(white: 0.15, alpha: 1.0) :
                NSColor(white: 0.96, alpha: 1.0)))

            // Right content area
            VStack(spacing: 0) {
                // Content
                ScrollView {
                    if selectedTab == "general" {
                        // General settings
                        VStack(spacing: 0) {
                            SettingToggleRow(
                                title: "Open at login",
                                isOn: $generalPreferences.openAtLogin,
                                colorScheme: colorScheme
                            )

                            Divider()
                                .padding(.leading, 30)

                            SettingToggleRow(
                                title: "Sound effects",
                                isOn: $generalPreferences.soundEffects,
                                colorScheme: colorScheme
                            )

                            Divider()
                                .padding(.leading, 30)

                            // History section
                            HistoryRow(
                                itemCount: clipboardStorage.items.count,
                                onClear: {
                                    showClearConfirmation = true
                                },
                                colorScheme: colorScheme
                            )
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 20)
                    } else if selectedTab == "shortcuts" {
                        // Shortcuts settings
                        VStack(spacing: 12) {
                            // Shortcut row container
                            VStack(spacing: 0) {
                                ShortcutRow(
                                    title: "Activate Paste Stack",
                                    isRecording: $isRecording,
                                    currentKeysPressed: $currentKeysPressed,
                                    shortcutDisplay: shortcutPreferences.getShortcutDisplayString(),
                                    onRecordTap: {
                                        if !isRecording {
                                            isRecording = true
                                            currentKeysPressed = "Press keys..."
                                        }
                                    },
                                    onClearTap: {
                                        // Clear shortcut if needed
                                    },
                                    colorScheme: colorScheme
                                )
                            }
                            .padding(.horizontal, 30)
                            .padding(.top, 16)
                        }
                    } else if selectedTab == "about" {
                        // About section
                        AboutView(colorScheme: colorScheme)
                    }
                }

                // Reset button (always at bottom right)
                if selectedTab == "shortcuts" {
                    HStack {
                        Spacer()
                        Button(action: {
                            shortcutPreferences.resetToDefault()
                        }) {
                            Text("Reset shortcuts to default...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(nsColor: colorScheme == .dark ?
                                            NSColor(white: 0.25, alpha: 1.0) :
                                            NSColor(white: 0.93, alpha: 1.0)))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(nsColor: .windowBackgroundColor))
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 700, height: 380)
        .background(
            ShortcutRecorderView(
                isRecording: $isRecording,
                currentKeysPressed: $currentKeysPressed
            ) { keyCode, modifiers in
                shortcutPreferences.updateShortcut(keyCode: keyCode, modifiers: modifiers)
            }
            .frame(width: 0, height: 0)
            .hidden()
        )
        .alert("Clear Clipboard History?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clipboardStorage.clearHistory()
            }
        } message: {
            Text("This will remove all \(clipboardStorage.items.count) items from your clipboard history. This action cannot be undone.")
        }
    }
}

// Setting toggle row component
struct SettingToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let colorScheme: ColorScheme

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.primary)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle())
                .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// Shortcut row component
struct ShortcutRow: View {
    let title: String
    @Binding var isRecording: Bool
    @Binding var currentKeysPressed: String
    let shortcutDisplay: String
    let onRecordTap: () -> Void
    let onClearTap: () -> Void
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: 12) {
                // Shortcut field
                Button(action: onRecordTap) {
                    Text(isRecording ? currentKeysPressed : shortcutDisplay)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .frame(minWidth: 90)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: colorScheme == .dark ?
                                    NSColor(white: 0.2, alpha: 1.0) :
                                    NSColor.white))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    Color(nsColor: colorScheme == .dark ?
                                        NSColor(white: 0.35, alpha: 1.0) :
                                        NSColor(white: 0.88, alpha: 1.0)),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)

                // Clear button
                Button(action: onClearTap) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: colorScheme == .dark ?
                    NSColor(white: 0.18, alpha: 1.0) :
                    NSColor(white: 0.97, alpha: 1.0)))
        )
    }
}

// Sidebar menu item component
struct SidebarMenuItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? .white : .primary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// History row component
struct HistoryRow: View {
    let itemCount: Int
    let onClear: () -> Void
    let colorScheme: ColorScheme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Clipboard history")
                    .font(.system(size: 15))
                    .foregroundColor(.primary)

                Text("\(itemCount) \(itemCount == 1 ? "item" : "items")")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onClear) {
                Text("Clear")
                    .font(.system(size: 12))
                    .foregroundColor(itemCount > 0 ? .red : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(nsColor: colorScheme == .dark ?
                                NSColor(white: 0.25, alpha: 1.0) :
                                NSColor(white: 0.93, alpha: 1.0)))
                    )
            }
            .buttonStyle(.plain)
            .disabled(itemCount == 0)
            .offset(x: 4)  // Move button 4 pixels to the right to align with toggles
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// About view component
struct AboutView: View {
    let colorScheme: ColorScheme

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 40)

            // App icon
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.accentColor)

            Spacer()
                .frame(height: 16)

            // App name
            Text("CopyStack")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.primary)

            // Tagline
            Text("A clipboard that remembers")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .padding(.top, 2)

            Spacer()
                .frame(height: 20)

            // Description
            Text("Copy everything first, then paste in order.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Spacer()
                .frame(height: 24)

            // Version
            Text("Version \(appVersion) (\(buildNumber))")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))

            Spacer()
                .frame(height: 32)

            // Link to the project on GitHub. Update the URL to your repository.
            Button(action: {
                if let url = URL(string: "https://github.com/YOUR_GITHUB_USERNAME/CopyStack") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.system(size: 12))
                    Text("View on GitHub")
                        .font(.system(size: 12))
                }
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 30)
    }
}

#Preview {
    SettingsView()
}
