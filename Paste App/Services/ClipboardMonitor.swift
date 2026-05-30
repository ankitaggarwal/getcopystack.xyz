//
//  ClipboardMonitor.swift
//  Copy Stack
//
//  Polls the system pasteboard while the stack window is open and turns each
//  new copy into a typed ClipboardItem. Content types are detected in priority
//  order (video → image → file → URL → text) with a short de-duplication window.
//
//  Created by Ankit Aggarwal
//

import Foundation
import AppKit
import Carbon
import AVFoundation

class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int
    private var lastClipboardContent: String?
    private let storage: ClipboardStorage
    private var ignoreNextChange = false
    private var isMonitoring = false

    // Public property to check monitoring state
    var isCurrentlyMonitoring: Bool {
        return isMonitoring
    }

    // Track recently added content to prevent duplicates within a time window
    private var recentContentHashes: [String: Date] = [:]
    private let deduplicationWindow: TimeInterval = 0.5 // 500ms window

    // File extension constants (defined once, used throughout)
    private let imageExtensions = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "heic", "heif", "webp", "ico", "svg"]
    private let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v", "mpg", "mpeg", "3gp", "ogv", "m2ts", "mts", "ts"]
    private let documentExtensions = ["pdf", "doc", "docx", "txt", "rtf", "pages", "xls", "xlsx", "numbers", "csv", "ppt", "pptx", "key", "md", "markdown", "html", "htm", "xml", "json", "yaml", "yml", "swift", "py", "js", "ts", "java", "cpp", "c", "h", "m", "rb", "go", "rs", "zip", "rar", "7z", "tar", "gz", "log", "cfg", "conf", "ini"]

    init(storage: ClipboardStorage) {
        self.storage = storage
        self.lastChangeCount = NSPasteboard.general.changeCount
        self.lastClipboardContent = NSPasteboard.general.string(forType: .string)
    }

    // Start monitoring clipboard
    func startMonitoring() {
        guard !isMonitoring else {
            print("ClipboardMonitor: Already monitoring, skipping start")
            return
        }
        print("ClipboardMonitor: Starting monitoring")
        isMonitoring = true

        // Poll clipboard every 50ms for maximum responsiveness
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        
        // Use a more reliable run loop mode
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    // Stop monitoring
    func stopMonitoring() {
        isMonitoring = false
        
        timer?.invalidate()
        timer = nil
    }
    
    // Used when manually copying items through the UI
    func ignoreNextClipboardChange() {
        ignoreNextChange = true
    }

    // Check if content is truly new (not seen recently)
    private func shouldAddContent(hash: String) -> Bool {
        let now = Date()

        // Clean up old entries first
        recentContentHashes = recentContentHashes.filter { now.timeIntervalSince($0.value) < deduplicationWindow }

        // Check if we've seen this content hash recently
        if let lastSeenTime = recentContentHashes[hash] {
            if now.timeIntervalSince(lastSeenTime) < deduplicationWindow {
                return false
            }
        }

        // New content - track it
        recentContentHashes[hash] = now
        return true
    }

    // Try to detect an image from the pasteboard using multiple methods
    private func detectImageFromPasteboard(_ pasteboard: NSPasteboard) -> NSImage? {
        // CRITICAL: First check if this is a video file to prevent false detection
        // Video files can have thumbnail/preview data that looks like images
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first {
            if url.isFileURL && videoExtensions.contains(url.pathExtension.lowercased()) {
                print("ClipboardMonitor: Skipping image detection - this is a video file")
                return nil
            }
        }

        // Method 1: Try reading NSImage directly (works for most apps)
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            print("ClipboardMonitor: Detected image via NSImage class")
            return image
        }

        // Method 2: Try reading file URLs (for WhatsApp, Finder, Slack, etc.)
        // BUT - only if it's an image file, not other file types
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first {
            if imageExtensions.contains(url.pathExtension.lowercased()),
               let image = NSImage(contentsOf: url) {
                print("ClipboardMonitor: Detected image from file URL: \(url.lastPathComponent)")
                return image
            }
        }

        // Method 3: Try reading TIFF data
        if let tiffData = pasteboard.data(forType: .tiff),
           let image = NSImage(data: tiffData) {
            print("ClipboardMonitor: Detected image via TIFF data")
            return image
        }

        // Method 4: Try reading PNG data
        if let pngData = pasteboard.data(forType: .png),
           let image = NSImage(data: pngData) {
            print("ClipboardMonitor: Detected image via PNG data")
            return image
        }

        // Method 5: Try reading HEIC data (common for WhatsApp/iPhone images)
        if let types = pasteboard.types {
            for type in types where type.rawValue.contains("heic") {
                if let heicData = pasteboard.data(forType: type),
                   let image = NSImage(data: heicData) {
                    print("ClipboardMonitor: Detected image via HEIC data")
                    return image
                }
            }
        }

        // Method 6: Try reading generic image data (including com.apple.uikit.image)
        if let types = pasteboard.types {
            for type in types where type.rawValue.contains("image") || type.rawValue.contains("picture") {
                if let imageData = pasteboard.data(forType: type),
                   !imageData.isEmpty,
                   let image = NSImage(data: imageData) {
                    print("ClipboardMonitor: Detected image via type: \(type.rawValue)")
                    return image
                }
            }
        }

        return nil
    }

    // Try to detect a file URL from the pasteboard
    private func detectFileFromPasteboard(_ pasteboard: NSPasteboard) -> URL? {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first {
            guard url.isFileURL else { return nil }
            guard !imageExtensions.contains(url.pathExtension.lowercased()) else { return nil }
            guard !videoExtensions.contains(url.pathExtension.lowercased()) else { return nil }

            let ext = url.pathExtension.lowercased()
            if documentExtensions.contains(ext) || ext.isEmpty {
                if FileManager.default.fileExists(atPath: url.path) {
                    print("ClipboardMonitor: Detected file: \(url.lastPathComponent)")
                    return url
                }
            }
        }
        return nil
    }

    // Copy video to permanent storage location if needed
    private func copyVideoToPermanentStorage(_ sourceURL: URL) -> URL {
        // Check if file is in a temporary directory
        let tmpPath = NSTemporaryDirectory()
        let isTemporary = sourceURL.path.starts(with: tmpPath) || sourceURL.path.contains("/tmp/") || sourceURL.path.contains("/Caches/")

        if !isTemporary {
            // File is already in a permanent location
            print("ClipboardMonitor: Video is in permanent location: \(sourceURL.path)")
            return sourceURL
        }

        // Copy to permanent storage
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let pasteAppDir = appSupport.appendingPathComponent("PasteApp/Videos", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: pasteAppDir, withIntermediateDirectories: true, attributes: nil)

        // Generate unique filename
        let filename = sourceURL.lastPathComponent
        let destURL = pasteAppDir.appendingPathComponent(filename)

        // If file already exists, add timestamp
        var finalDestURL = destURL
        if FileManager.default.fileExists(atPath: destURL.path) {
            let timestamp = Int(Date().timeIntervalSince1970)
            let nameWithoutExt = sourceURL.deletingPathExtension().lastPathComponent
            let ext = sourceURL.pathExtension
            finalDestURL = pasteAppDir.appendingPathComponent("\(nameWithoutExt)_\(timestamp).\(ext)")
        }

        // Copy the file
        do {
            try FileManager.default.copyItem(at: sourceURL, to: finalDestURL)
            print("ClipboardMonitor: Copied video from temporary location to: \(finalDestURL.path)")
            return finalDestURL
        } catch {
            print("ClipboardMonitor: ERROR - Failed to copy video: \(error)")
            return sourceURL // Fallback to original URL
        }
    }

    // Try to detect a video file from the pasteboard
    private func detectVideoFromPasteboard(_ pasteboard: NSPasteboard) -> (url: URL, thumbnail: NSImage?, rawData: [String: Data])? {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first {
            guard url.isFileURL else { return nil }
            guard videoExtensions.contains(url.pathExtension.lowercased()) else { return nil }
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }

            print("ClipboardMonitor: Detected video: \(url.lastPathComponent)")
            print("ClipboardMonitor: Available pasteboard types: \(pasteboard.types?.map { $0.rawValue } ?? [])")

            // Capture ALL raw pasteboard data for later restoration
            var rawData: [String: Data] = [:]
            if let types = pasteboard.types {
                for type in types {
                    if let data = pasteboard.data(forType: type) {
                        rawData[type.rawValue] = data
                        print("ClipboardMonitor: Captured pasteboard type: \(type.rawValue) (\(data.count) bytes)")
                    }
                }
            }

            // Generate thumbnail
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 200, height: 200)

            var thumbnail: NSImage?
            do {
                let time = CMTime(seconds: 1.0, preferredTimescale: 600)
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            } catch {
                print("ClipboardMonitor: Failed to generate video thumbnail: \(error)")
                thumbnail = NSWorkspace.shared.icon(forFile: url.path)
            }

            return (url, thumbnail, rawData)
        }
        return nil
    }

    // Try to detect a web URL from the pasteboard
    private func detectWebURLFromPasteboard(_ pasteboard: NSPasteboard) -> URL? {
        // First try to read URL objects directly
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first {
            // Must be http:// or https://
            if url.scheme == "http" || url.scheme == "https" {
                print("ClipboardMonitor: Detected web URL: \(url.absoluteString)")
                return url
            }
        }

        // Fallback: try to parse string as URL
        if let urlString = pasteboard.string(forType: .string),
           !urlString.isEmpty,
           let url = URL(string: urlString),
           (url.scheme == "http" || url.scheme == "https") {
            print("ClipboardMonitor: Detected web URL from string: \(url.absoluteString)")
            return url
        }

        return nil
    }

    // Monitor clipboard changes to detect new content
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // Skip if this change came from us loading an item back onto the clipboard
        if ignoreNextChange {
            ignoreNextChange = false
            lastClipboardContent = pasteboard.string(forType: .string)
            return
        }

        if captureClipboardItem() { return }

        // Nothing detected yet - some apps (WhatsApp, Slack) write data asynchronously,
        // placing placeholder types on the pasteboard before the real data is ready.
        // Retry with increasing delays until the pasteboard is populated.
        print("ClipboardMonitor: No content detected, scheduling retries")
        for (index, delay) in [0.05, 0.1, 0.2, 0.4].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.retryCapture(changeCount: currentChangeCount, attempt: index + 1)
            }
        }
    }

    // Delayed retry for slow apps whose pasteboard is empty at first read
    private func retryCapture(changeCount: Int, attempt: Int) {
        let pasteboard = NSPasteboard.general

        // Bail out if the clipboard moved on since this retry was scheduled
        guard pasteboard.changeCount == changeCount else {
            print("ClipboardMonitor: Clipboard changed again, skipping stale retry")
            return
        }

        // Still empty - let the remaining scheduled retries try later
        guard !(pasteboard.types?.isEmpty ?? true) else {
            print("ClipboardMonitor: Types still empty (attempt \(attempt)), will keep retrying")
            return
        }

        captureClipboardItem(retry: true)
    }

    // Detect the highest-priority content on the pasteboard and store it.
    // Returns true once a content type is recognized (whether or not it was a new,
    // non-duplicate item) so callers know to stop retrying.
    // Order matters: videos MUST be checked before images, since video files carry
    // thumbnail data that would otherwise be misread as an image.
    @discardableResult
    private func captureClipboardItem(retry: Bool = false) -> Bool {
        let pasteboard = NSPasteboard.general
        let suffix = retry ? " (retry)" : ""

        if let video = detectVideoFromPasteboard(pasteboard) {
            if shouldAddContent(hash: video.url.path) {
                lastClipboardContent = nil
                let permanentURL = copyVideoToPermanentStorage(video.url)
                storage.addItem(ClipboardItem(videoURL: permanentURL, thumbnail: video.thumbnail, rawPasteboardData: video.rawData))
                print("ClipboardMonitor: Added video to storage\(suffix): \(permanentURL.lastPathComponent)")
            }
            return true
        }

        if let image = detectImageFromPasteboard(pasteboard) {
            let hash = image.tiffRepresentation?.base64EncodedString() ?? "unknown_image_\(UUID().uuidString)"
            if shouldAddContent(hash: hash) {
                lastClipboardContent = nil
                storage.addItem(ClipboardItem(image: image))
                print("ClipboardMonitor: Added image to storage\(suffix)")
            }
            return true
        }

        if let fileURL = detectFileFromPasteboard(pasteboard) {
            if shouldAddContent(hash: fileURL.path) {
                lastClipboardContent = nil
                storage.addItem(ClipboardItem(fileURL: fileURL))
                print("ClipboardMonitor: Added file to storage\(suffix): \(fileURL.lastPathComponent)")
            }
            return true
        }

        if let webURL = detectWebURLFromPasteboard(pasteboard) {
            if shouldAddContent(hash: webURL.absoluteString) {
                lastClipboardContent = webURL.absoluteString
                storage.addItem(ClipboardItem(webURL: webURL))
                print("ClipboardMonitor: Added URL to storage\(suffix): \(webURL.absoluteString)")
            }
            return true
        }

        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            if shouldAddContent(hash: text) {
                lastClipboardContent = text
                storage.addItem(ClipboardItem(text: text))
                print("ClipboardMonitor: Added text to storage\(suffix): \(text.prefix(50))...")
            }
            return true
        }

        return false
    }
}

