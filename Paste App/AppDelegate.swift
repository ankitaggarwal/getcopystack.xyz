//
//  AppDelegate.swift
//  Copy Stack
//
//  Application lifecycle hooks: registers global hotkeys on launch, schedules
//  the periodic update check, and tears everything down on quit.
//
//  Created by Ankit Aggarwal
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var clipboardStorage: ClipboardStorage!
    private var updateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("AppDelegate: Application finished launching")

        // Initialize shared storage reference
        clipboardStorage = ClipboardStorage.shared

        // Initialize managers early to ensure proper startup flow
        let _ = WindowManager.shared

        // Register global hotkeys
        HotkeyManager.shared.registerHotkeys()

        // Don't start monitoring automatically - only when stack window is shown
        print("AppDelegate: Monitoring will start when stack window is activated")

        // Check GitHub for a newer release on launch, then every 24 hours.
        UpdateChecker.check()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { _ in
            UpdateChecker.check()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Stop monitoring if it's running
        MonitoringManager.shared.stopMonitoring()

        // Unregister hotkeys when app terminates
        HotkeyManager.shared.unregisterHotkeys()

        updateTimer?.invalidate()
    }

}

/// Checks GitHub for the latest release and, if it's newer than this build,
/// offers a direct download. Works with ad-hoc signing — no extra dependencies.
enum UpdateChecker {
    /// GitHub "owner/repo" whose Releases are checked for new versions.
    /// Set this to the repository you publish your tagged DMG releases to.
    static let repo = "YOUR_GITHUB_USERNAME/CopyStack"

    /// `silent` (automatic checks) shows nothing unless an update exists;
    /// when false (manual check) it also reports "up to date" or errors.
    static func check(silent: Bool = true) {
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String,
                  let page = json["html_url"] as? String else {
                if !silent { DispatchQueue.main.async { showCouldNotCheck() } }
                return
            }

            // Direct .dmg link if present, else the release page.
            let assets = json["assets"] as? [[String: Any]] ?? []
            let downloadURL = assets
                .compactMap { $0["browser_download_url"] as? String }
                .first { $0.lowercased().hasSuffix(".dmg") } ?? page

            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

            DispatchQueue.main.async {
                if latest.compare(current, options: .numeric) == .orderedDescending {
                    showUpdateAvailable(latest: latest, current: current, downloadURL: downloadURL)
                } else if !silent {
                    showUpToDate(current: current)
                }
            }
        }.resume()
    }

    private static func showUpdateAvailable(latest: String, current: String, downloadURL: String) {
        let alert = NSAlert()
        alert.messageText = "A new version of CopyStack is available"
        alert.informativeText = "You have \(current). Version \(latest) is available to download."
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn, let url = URL(string: downloadURL) {
            NSWorkspace.shared.open(url)
        }
    }

    private static func showUpToDate(current: String) {
        let alert = NSAlert()
        alert.messageText = "You're up to date"
        alert.informativeText = "CopyStack \(current) is the latest version."
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private static func showCouldNotCheck() {
        let alert = NSAlert()
        alert.messageText = "Couldn't check for updates"
        alert.informativeText = "Please check your internet connection and try again."
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
