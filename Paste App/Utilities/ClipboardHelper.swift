//
//  ClipboardHelper.swift
//  Copy Stack
//
//  Shared helper for writing a ClipboardItem back onto the system pasteboard,
//  including restoring a video's raw pasteboard data verbatim so it pastes
//  correctly into apps like WhatsApp and Slack.
//
//  Created by Ankit Aggarwal
//

import Foundation
import AppKit

class ClipboardHelper {
    /// Write any clipboard item to the pasteboard
    static func writeItemToPasteboard(_ item: ClipboardItem, pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        switch item.type {
        case .text:
            if let text = item.text {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            if let image = item.image {
                pasteboard.writeObjects([image])
            }
        case .video:
            writeVideoToPasteboard(item, pasteboard: pasteboard)
        case .file:
            if let fileURL = item.fileURL, FileManager.default.fileExists(atPath: fileURL.path) {
                pasteboard.writeObjects([fileURL as NSURL])
            }
        case .url:
            if let webURL = item.webURL {
                pasteboard.writeObjects([webURL as NSURL])
                // Also write as string for compatibility
                pasteboard.setString(webURL.absoluteString, forType: .string)
            }
        }
    }

    /// Write a video item to the pasteboard with all its raw data
    private static func writeVideoToPasteboard(_ item: ClipboardItem, pasteboard: NSPasteboard) {
        guard let videoURL = item.videoURL else { return }

        print("ClipboardHelper: Loading video to clipboard: \(videoURL.path)")
        print("ClipboardHelper: Video exists: \(FileManager.default.fileExists(atPath: videoURL.path))")

        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            print("ClipboardHelper: ERROR - Video file no longer exists at path!")
            return
        }

        // CRITICAL: Restore ALL original pasteboard data if available
        if let rawData = item.videoRawPasteboardData {
            print("ClipboardHelper: Restoring \(rawData.count) pasteboard types from raw data")

            for (typeString, data) in rawData {
                let type = NSPasteboard.PasteboardType(rawValue: typeString)
                pasteboard.setData(data, forType: type)
                print("ClipboardHelper: Restored type: \(typeString) (\(data.count) bytes)")
            }
        } else {
            // Fallback: Write just the URL if we don't have raw data
            print("ClipboardHelper: No raw data available, writing URL only")
            pasteboard.writeObjects([videoURL as NSURL])
        }

        print("ClipboardHelper: Video written to pasteboard")

        // Debug: Print what types were written
        if let types = pasteboard.types {
            print("ClipboardHelper: Pasteboard now contains types: \(types.map { $0.rawValue })")
        }
    }
}
