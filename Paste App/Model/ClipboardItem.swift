//
//  ClipboardItem.swift
//  Copy Stack
//
//  One item in the stack. A small enum-tagged value type that can hold text,
//  an image, a video (with raw pasteboard data for faithful re-pasting),
//  a file, or a web URL.
//
//  Created by Ankit Aggarwal
//

import Foundation
import AppKit

enum ClipboardItemType {
    case text
    case image
    case video
    case file
    case url
}

struct ClipboardItem: Identifiable {
    let id = UUID()
    let type: ClipboardItemType
    let text: String?
    let image: NSImage?
    let videoURL: URL?
    let videoFileName: String?
    let videoThumbnail: NSImage?
    let videoRawPasteboardData: [String: Data]?  // Raw pasteboard data, restored verbatim when pasting videos
    let fileURL: URL?
    let fileName: String?
    let webURL: URL?
    let timestamp: Date

    // Single designated initializer; the type-specific initializers below forward to it
    // so each only has to specify the fields it actually uses.
    private init(
        type: ClipboardItemType,
        timestamp: Date,
        text: String? = nil,
        image: NSImage? = nil,
        videoURL: URL? = nil,
        videoThumbnail: NSImage? = nil,
        videoRawPasteboardData: [String: Data]? = nil,
        fileURL: URL? = nil,
        webURL: URL? = nil
    ) {
        self.type = type
        self.timestamp = timestamp
        self.text = text
        self.image = image
        self.videoURL = videoURL
        self.videoFileName = videoURL?.lastPathComponent
        self.videoThumbnail = videoThumbnail
        self.videoRawPasteboardData = videoRawPasteboardData
        self.fileURL = fileURL
        self.fileName = fileURL?.lastPathComponent
        self.webURL = webURL
    }

    init(text: String, timestamp: Date = Date()) {
        self.init(type: .text, timestamp: timestamp, text: text)
    }

    init(image: NSImage, timestamp: Date = Date()) {
        self.init(type: .image, timestamp: timestamp, image: image)
    }

    init(videoURL: URL, thumbnail: NSImage? = nil, rawPasteboardData: [String: Data]? = nil, timestamp: Date = Date()) {
        self.init(type: .video, timestamp: timestamp, videoURL: videoURL,
                  videoThumbnail: thumbnail, videoRawPasteboardData: rawPasteboardData)
    }

    init(fileURL: URL, timestamp: Date = Date()) {
        self.init(type: .file, timestamp: timestamp, fileURL: fileURL)
    }

    init(webURL: URL, timestamp: Date = Date()) {
        self.init(type: .url, timestamp: timestamp, text: webURL.absoluteString, webURL: webURL)
    }
}
