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
                VStack(spacing: 4) {
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
                        VStack(alignment: .leading, spacing: 18) {
                            SectionLabel("General")

                            // Behaviour group
                            SettingsCard {
                                SettingToggleRow(
                                    title: "Open at login",
                                    subtitle: "Launch CopyStack when you sign in",
                                    isOn: $generalPreferences.openAtLogin
                                )
                                CardDivider()
                                SettingToggleRow(
                                    title: "Sound effects",
                                    subtitle: "Play a sound on copy and paste",
                                    isOn: $generalPreferences.soundEffects
                                )
                            }

                            // History group
                            SettingsCard {
                                HistoryRow(
                                    itemCount: clipboardStorage.items.count,
                                    onClear: { showClearConfirmation = true }
                                )
                            }
                        }
                        .padding(.horizontal, 26)
                        .padding(.top, 22)
                        .padding(.bottom, 24)
                    } else if selectedTab == "shortcuts" {
                        VStack(alignment: .leading, spacing: 18) {
                            SectionLabel("Shortcuts")

                            SettingsCard {
                                ShortcutRow(
                                    title: "Activate Paste Stack",
                                    subtitle: "Copy the selection and open the stack",
                                    isRecording: $isRecording,
                                    currentKeysPressed: $currentKeysPressed,
                                    shortcutDisplay: shortcutPreferences.getShortcutDisplayString(),
                                    onRecordTap: {
                                        if !isRecording {
                                            isRecording = true
                                            currentKeysPressed = "Press keys…"
                                        }
                                    },
                                    colorScheme: colorScheme
                                )
                            }
                        }
                        .padding(.horizontal, 26)
                        .padding(.top, 22)
                    } else if selectedTab == "about" {
                        AboutView(colorScheme: colorScheme)
                    }
                }

                // Reset button (always at bottom right)
                if selectedTab == "shortcuts" {
                    HStack {
                        Spacer()
                        ResetButton {
                            shortcutPreferences.resetToDefault()
                        }
                    }
                    .padding(.horizontal, 26)
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

// MARK: - Reusable building blocks

/// Quiet uppercase label that introduces a settings section.
private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .kerning(0.6)
    }
}

/// Rounded container that visually groups related rows (Law of Common Region).
private struct SettingsCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: colorScheme == .dark ?
                    NSColor(white: 0.17, alpha: 1.0) :
                    NSColor(white: 0.975, alpha: 1.0)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.06), lineWidth: 1)
        )
    }
}

/// Hairline divider inset to align beneath a row's text.
private struct CardDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, 16)
    }
}

// Setting toggle row component
struct SettingToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle())
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// Shortcut row component
struct ShortcutRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isRecording: Bool
    @Binding var currentKeysPressed: String
    let shortcutDisplay: String
    let onRecordTap: () -> Void
    let colorScheme: ColorScheme

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Shortcut field
            Button(action: onRecordTap) {
                Text(isRecording ? currentKeysPressed : shortcutDisplay)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(isRecording ? .accentColor : .primary)
                    .frame(minWidth: 84)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: colorScheme == .dark ?
                                NSColor(white: 0.24, alpha: 1.0) :
                                NSColor.white))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isRecording ? Color.accentColor.opacity(0.8) :
                                    Color(nsColor: colorScheme == .dark ?
                                        NSColor(white: 0.38, alpha: 1.0) :
                                        NSColor(white: 0.86, alpha: 1.0)),
                                lineWidth: isRecording ? 1.5 : 1
                            )
                    )
            }
            .buttonStyle(.plain)
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .animation(.easeInOut(duration: 0.15), value: isRecording)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// Sidebar menu item component
struct SidebarMenuItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .white : .primary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected
                        ? Color.accentColor
                        : (isHovered ? Color.primary.opacity(0.07) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
        }
    }
}

// History row component
struct HistoryRow: View {
    let itemCount: Int
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Clipboard history")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                Text("\(itemCount) \(itemCount == 1 ? "item" : "items") in the stack")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            ClearHistoryButton(enabled: itemCount > 0, action: onClear)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// Destructive "Clear" pill that only lights up red on hover when enabled.
private struct ClearHistoryButton: View {
    let enabled: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text("Clear")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(!enabled ? .secondary : (isHovered ? .white : .red))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(fillColor)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hovering in
            guard enabled else { return }
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    private var fillColor: Color {
        if !enabled {
            return Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.06)
        }
        if isHovered { return .red }
        return Color.red.opacity(colorScheme == .dark ? 0.18 : 0.10)
    }
}

/// Subtle text button for resetting the shortcut to its default.
private struct ResetButton: View {
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text("Reset shortcut to default")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: colorScheme == .dark ?
                            NSColor(white: isHovered ? 0.30 : 0.25, alpha: 1.0) :
                            NSColor(white: isHovered ? 0.90 : 0.93, alpha: 1.0)))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
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
                .frame(height: 44)

            // App icon in a soft rounded tile
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 10, y: 4)

                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundColor(.white)
            }

            Spacer()
                .frame(height: 18)

            // App name
            Text("CopyStack")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.primary)

            // Tagline
            Text("A clipboard that remembers")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .padding(.top, 3)

            Spacer()
                .frame(height: 18)

            // Description
            Text("Copy everything first, then paste in order.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Spacer()
                .frame(height: 22)

            // Version
            Text("Version \(appVersion) (\(buildNumber))")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))

            Spacer()
                .frame(height: 26)

            // Link to the project on GitHub. Update the URL to your repository.
            GitHubLink()

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 30)
    }
}

/// "View on GitHub" link with a quiet hover treatment.
private struct GitHubLink: View {
    @State private var isHovered = false

    var body: some View {
        Button(action: {
            if let url = URL(string: "https://github.com/ankitaggarwal/getcopystack.xyz") {
                NSWorkspace.shared.open(url)
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: "globe")
                    .font(.system(size: 12))
                Text("View on GitHub")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color.accentColor.opacity(isHovered ? 0.14 : 0.0))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

#Preview {
    SettingsView()
}
