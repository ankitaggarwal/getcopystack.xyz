//
//  ClipboardListView.swift
//  Copy Stack
//
//  The contents of the floating stack window: the list of collected items with
//  type icons and timestamps, highlighting whichever item will paste next.
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
        .frame(minWidth: 240, minHeight: 160)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - UI Components

    private var headerView: some View {
        HStack {
            Text("\(storage.items.count) \(storage.items.count == 1 ? "item" : "items")")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            // Clear all button
            Button(action: {
                storage.clearHistory()
            }) {
                Text("Clear")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(0.8)
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Color(nsColor: colorScheme == .dark
                ? NSColor(white: 0.12, alpha: 1.0)
                : NSColor(white: 0.97, alpha: 1.0))
        )
    }

    private var clipboardItemsSection: some View {
        Group {
            if storage.items.isEmpty {
                emptyStateView
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                                VStack(spacing: 0) {
                                    ClipboardItemRow(
                                        item: item,
                                        isNextInSequence: storage.isNextInSequence(item),
                                        colorScheme: colorScheme
                                    )
                                    .id(item.id)

                                    // Separator (except for last item)
                                    if index < displayItems.count - 1 {
                                        Divider()
                                            .padding(.leading, 48)
                                            .padding(.trailing, 16)
                                    }
                                }
                                .transition(.opacity)
                                .animation(.easeInOut(duration: 0.2), value: storage.isNextInSequence(item))
                            }
                        }
                        .padding(.vertical, 4)
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
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.secondary.opacity(0.6))

            VStack(spacing: 4) {
                Text("Stack is Empty")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)

                Text("Copy items to add them here")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - ClipboardItemRow
struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isNextInSequence: Bool
    let colorScheme: ColorScheme

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            typeIcon
                .frame(width: 20, height: 20)
                .foregroundColor(isNextInSequence ? .accentColor : .secondary)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(getDisplayName())
                    .font(.system(size: 13, weight: isNextInSequence ? .medium : .regular))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .truncationMode(.tail)

                // Timestamp
                Text(relativeTime(item.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
            }

            Spacer(minLength: 0)

            // Next indicator
            if isNextInSequence {
                Text("Next")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.accentColor)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
                .padding(.horizontal, 8)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var backgroundColor: Color {
        if isNextInSequence {
            return Color.accentColor.opacity(colorScheme == .dark ? 0.15 : 0.08)
        } else if isHovered {
            return Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04)
        }
        return Color.clear
    }

    private var typeIcon: some View {
        Group {
            switch item.type {
            case .text:
                Image(systemName: "doc.text")
                    .font(.system(size: 14, weight: .regular))
            case .image:
                Image(systemName: "photo")
                    .font(.system(size: 14, weight: .regular))
            case .video:
                Image(systemName: "video")
                    .font(.system(size: 14, weight: .regular))
            case .file:
                Image(systemName: "doc")
                    .font(.system(size: 14, weight: .regular))
            case .url:
                Image(systemName: "link")
                    .font(.system(size: 14, weight: .regular))
            }
        }
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

    private func relativeTime(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    ClipboardListView(storage: ClipboardStorage())
        .frame(width: 350, height: 500)
        .preferredColorScheme(.light)
}
