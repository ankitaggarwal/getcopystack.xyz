//
//  ClipboardListView.swift
//  Copy Stack
//
//  The contents of the floating stack window: a numbered list of collected
//  items that reads as a paste queue. Each row shows its exact paste position,
//  a content preview (thumbnail for media, glyph otherwise), and the item that
//  pastes next is gently spotlighted.
//
//  Created by Ankit Aggarwal
//

import SwiftUI

struct ClipboardListView: View {
    @ObservedObject var storage: ClipboardStorage
    @ObservedObject private var generalPreferences = GeneralPreferences.shared
    @Environment(\.colorScheme) private var colorScheme

    var closeAction: (() -> Void)? = nil

    init(storage: ClipboardStorage, closeAction: (() -> Void)? = nil) {
        self.storage = storage
        self.closeAction = closeAction
    }

    private var displayItems: [ClipboardItem] {
        if generalPreferences.stackGrowsFromTop {
            // LIFO mode: newest at top, paste newest first
            return storage.items  // Normal order: [newest, ..., oldest]
        } else {
            // FIFO mode: oldest at top, paste oldest first
            return storage.items.reversed()  // Reversed order: [oldest, ..., newest]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with item count
            if !storage.items.isEmpty {
                headerView
            }

            // Items list
            clipboardItemsSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - UI Components

    private var headerView: some View {
        HStack(spacing: 4) {
            Text("\(storage.items.count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary.opacity(0.85))
                .animation(.easeInOut(duration: 0.25), value: storage.items.count)

            Text(storage.items.count == 1 ? "item" : "items")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Spacer()

            // Paste-order toggle (moved here from the window toolbar) + Clear.
            HStack(spacing: 10) {
                PasteOrderToggle(prefs: generalPreferences)
                ClearButton { storage.clearHistory() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06))
                .frame(height: 1)
        }
    }

    private var clipboardItemsSection: some View {
        Group {
            if storage.items.isEmpty {
                emptyStateView
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                                ClipboardItemRow(
                                    item: item,
                                    position: index + 1,
                                    isNextInSequence: storage.isNextInSequence(item),
                                    colorScheme: colorScheme
                                )
                                .id(item.id)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity.combined(with: .scale(scale: 0.92, anchor: .leading))
                                ))
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 6)
                        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: storage.items.count)
                        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: generalPreferences.stackGrowsFromTop)
                    }
                    .onChange(of: storage.items.count) { oldCount, newCount in
                        if newCount > oldCount {
                            // New item was added - always scroll to show the next item (at top)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                if let firstItem = displayItems.first {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        scrollProxy.scrollTo(firstItem.id, anchor: .top)
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: generalPreferences.stackGrowsFromTop) { _, _ in
                        // When mode changes, scroll to show the next item (always at top)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if let firstItem = displayItems.first {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    scrollProxy.scrollTo(firstItem.id, anchor: .top)
                                }
                            }
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Spacer()

            BreathingStackIcon()

            VStack(spacing: 5) {
                Text("Your stack is empty")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Every copy lands here, in order")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // The window is already open, so a normal copy is all it takes —
            // no need for the activation shortcut here.
            HStack(spacing: 5) {
                KeyCap(symbol: "⌘")
                KeyCap(symbol: "C")
                Text("to add an item")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
                    .padding(.leading, 2)
            }
            .padding(.top, 2)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
}

// MARK: - Header pieces

/// "Clear" text button that warms to red on hover (destructive intent stays
/// quiet until the cursor is on it).
private struct ClearButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text("Clear")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isHovered ? .red : .secondary)
        }
        .buttonStyle(.plain)
        .opacity(isHovered ? 1.0 : 0.8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

/// Paste-order toggle: arrow-down = paste newest first (LIFO), arrow-up =
/// paste oldest first (FIFO). Lives in the header now that the window has no
/// toolbar; toggling the shared preference drives the reordering exactly as
/// the old toolbar button did.
private struct PasteOrderToggle: View {
    @ObservedObject var prefs: GeneralPreferences
    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                prefs.stackGrowsFromTop.toggle()
            }
        } label: {
            Image(systemName: prefs.stackGrowsFromTop ? "arrow.down.circle" : "arrow.up.circle")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(isHovered ? .primary : .secondary)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .help(prefs.stackGrowsFromTop
            ? "Paste newest first • Click to paste oldest first"
            : "Paste oldest first • Click to paste newest first")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

/// A small keyboard-cap chip used to display shortcut glyphs.
private struct KeyCap: View {
    let symbol: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(symbol)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(.primary.opacity(0.8))
            .frame(minWidth: 20, minHeight: 20)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(nsColor: colorScheme == .dark
                        ? NSColor(white: 0.22, alpha: 1.0)
                        : NSColor.white))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.0 : 0.08), radius: 0.5, y: 0.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.12), lineWidth: 1)
            )
    }
}

/// Empty-state icon with a slow, subtle "breathing" idle motion.
private struct BreathingStackIcon: View {
    @State private var breathe = false

    var body: some View {
        Image(systemName: "square.stack.3d.up")
            .font(.system(size: 34, weight: .light))
            .foregroundColor(.secondary.opacity(0.55))
            .scaleEffect(breathe ? 1.04 : 0.98)
            .opacity(breathe ? 0.7 : 0.5)
            .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: breathe)
            .onAppear { breathe = true }
    }
}

// MARK: - ClipboardItemRow
struct ClipboardItemRow: View {
    let item: ClipboardItem
    let position: Int
    let isNextInSequence: Bool
    let colorScheme: ColorScheme

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 9) {
            // Paste-order number — the single strong signal of "what's next".
            positionBadge

            // Type indicator: a framed thumbnail for media, a quiet glyph otherwise.
            contentIndicator

            // Title
            Text(getDisplayName())
                .font(.system(size: 13, weight: isNextInSequence ? .semibold : .regular))
                .foregroundColor(isNextInSequence ? .primary : .primary.opacity(0.82))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            // Trailing: "Next" on the up-next item, else a quiet extension chip.
            if isNextInSequence {
                nextTag
            } else if let ext = fileExtension {
                extensionChip(ext)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isNextInSequence)
    }

    // MARK: Row pieces

    private var positionBadge: some View {
        ZStack {
            if isNextInSequence {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 22, height: 22)
            } else {
                Circle()
                    .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.11), lineWidth: 1)
                    .frame(width: 22, height: 22)
            }

            Text("\(position)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(isNextInSequence ? .white : .secondary)
        }
        .scaleEffect(isNextInSequence ? 1.0 : 0.92)
        .frame(width: 22)
    }

    @ViewBuilder
    private var contentIndicator: some View {
        switch item.type {
        case .image:
            if let image = item.image {
                thumbnail(image, play: false)
            } else {
                glyph("photo")
            }
        case .video:
            if let thumb = item.videoThumbnail {
                thumbnail(thumb, play: true)
            } else {
                glyph("video")
            }
        case .text:
            glyph("text.alignleft")
        case .file:
            glyph("doc")
        case .url:
            glyph("link")
        }
    }

    /// A framed preview for real media — the one place a small image earns a tile.
    private func thumbnail(_ image: NSImage, play: Bool) -> some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 22, height: 22)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .overlay {
                if play {
                    Image(systemName: "play.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.white)
                        .padding(2.5)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
            }
    }

    /// A quiet monochrome type hint — no background, so the row stays light.
    private func glyph(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .regular))
            .foregroundColor(isNextInSequence ? .accentColor : .secondary.opacity(0.75))
            .frame(width: 22, height: 22)
    }

    /// Quiet accent chip. The filled number badge is the bold highlight, so this
    /// stays soft — it names the action without competing for attention.
    private var nextTag: some View {
        Text("Next")
            .font(.system(size: 9, weight: .semibold))
            .kerning(0.2)
            .foregroundColor(.accentColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(Capsule().fill(Color.accentColor.opacity(colorScheme == .dark ? 0.24 : 0.14)))
            .transition(.scale.combined(with: .opacity))
    }

    private func extensionChip(_ ext: String) -> some View {
        Text(ext.uppercased())
            .font(.system(size: 8, weight: .semibold))
            .kerning(0.3)
            .foregroundColor(.secondary.opacity(0.9))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.06))
            )
    }

    private var backgroundColor: Color {
        if isNextInSequence {
            return Color.accentColor.opacity(colorScheme == .dark ? 0.13 : 0.07)
        } else if isHovered {
            return Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.045)
        }
        return Color.clear
    }

    // MARK: Derived display values

    private var fileExtension: String? {
        let name: String?
        switch item.type {
        case .video: name = item.videoFileName
        case .file: name = item.fileName
        default: return nil
        }
        guard let ext = name.map({ ($0 as NSString).pathExtension }), !ext.isEmpty else { return nil }
        return ext
    }

    private func getDisplayName() -> String {
        switch item.type {
        case .text:
            // Show first line or first 50 characters
            if let text = item.text {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
                return firstLine.count > 50 ? String(firstLine.prefix(50)) + "..." : firstLine
            }
            return "Text"
        case .image:
            return "Image"
        case .video:
            return item.videoFileName ?? "Video"
        case .file:
            return item.fileName ?? "File"
        case .url:
            // Show domain instead of full URL
            if let url = item.webURL, let host = url.host {
                return host
            }
            return item.webURL?.absoluteString ?? "Link"
        }
    }
}

#Preview {
    ClipboardListView(storage: ClipboardStorage())
        .frame(width: 320, height: 500)
        .preferredColorScheme(.light)
}
