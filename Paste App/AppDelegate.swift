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

        // The stack always starts empty, so any video file left in our storage
        // directory from a previous run is orphaned - delete them to keep the
        // Application Support folder from growing forever.
        cleanupOrphanedVideoFiles()

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

    private func cleanupOrphanedVideoFiles() {
        DispatchQueue.global(qos: .utility).async {
            guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                return
            }
            let videosDir = appSupport.appendingPathComponent("PasteApp/Videos", isDirectory: true)
            guard let files = try? FileManager.default.contentsOfDirectory(at: videosDir, includingPropertiesForKeys: nil) else {
                return
            }
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
            if !files.isEmpty {
                print("AppDelegate: Cleaned up \(files.count) orphaned video file(s)")
            }
        }
    }

}

/// Checks GitHub for the latest release and, if it's newer than this build,
/// updates the app in place: downloads the DMG, verifies the new app is signed
/// by the same team as the running one, swaps the bundle, and relaunches.
/// Dependency-free. When auto-install isn't possible (running translocated /
/// from a read-only location, signature mismatch, no DMG asset) it falls back
/// to the manual download alert.
enum UpdateChecker {
    /// GitHub "owner/repo" whose Releases are checked for new versions.
    /// Set this to the repository you publish your tagged DMG releases to.
    static let repo = "ankitaggarwal/getcopystack.xyz"

    /// `silent` (automatic checks) installs a newer release without asking;
    /// when false (manual check) it confirms first and reports "up to date".
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
                    if silent {
                        autoUpdate(latest: latest, current: current, downloadURL: downloadURL)
                    } else {
                        confirmAndUpdate(latest: latest, current: current, downloadURL: downloadURL)
                    }
                } else if !silent {
                    showUpToDate(current: current)
                }
            }
        }.resume()
    }

    // MARK: - Auto-install

    /// Download the release DMG and install it. Any failure along the way
    /// degrades to the manual "Download" alert instead of erroring out.
    private static func autoUpdate(latest: String, current: String, downloadURL: String) {
        guard downloadURL.lowercased().hasSuffix(".dmg"),
              let url = URL(string: downloadURL),
              installableBundleURL() != nil else {
            showUpdateAvailable(latest: latest, current: current, downloadURL: downloadURL)
            return
        }
        print("UpdateChecker: downloading \(latest)")
        URLSession.shared.downloadTask(with: url) { tmp, _, _ in
            let fallback = { DispatchQueue.main.async {
                showUpdateAvailable(latest: latest, current: current, downloadURL: downloadURL)
            } }
            guard let tmp else { fallback(); return }
            let dmg = FileManager.default.temporaryDirectory
                .appendingPathComponent("CopyStack-update-\(latest).dmg")
            try? FileManager.default.removeItem(at: dmg)
            guard (try? FileManager.default.moveItem(at: tmp, to: dmg)) != nil,
                  installAndRelaunch(dmg: dmg) else {
                fallback()
                return
            }
        }.resume()
    }

    private static func confirmAndUpdate(latest: String, current: String, downloadURL: String) {
        let alert = NSAlert()
        alert.messageText = "A new version of CopyStack is available"
        alert.informativeText = "You have \(current). CopyStack will download \(latest), install it, and restart."
        alert.addButton(withTitle: "Update and Restart")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            autoUpdate(latest: latest, current: current, downloadURL: downloadURL)
        }
    }

    /// Mount the DMG, verify the new app, hand off to a detached shell script
    /// that swaps the bundle once this process exits, and terminate.
    private static func installAndRelaunch(dmg: URL) -> Bool {
        let attach = run("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-readonly", "-plist"])
        guard attach.status == 0, let mount = mountPoint(fromPlist: attach.stdout) else { return false }
        let detach = { _ = run("/usr/bin/hdiutil", ["detach", mount, "-quiet"]) }

        guard let appName = (try? FileManager.default.contentsOfDirectory(atPath: mount))?
                  .first(where: { $0.hasSuffix(".app") }),
              let target = installableBundleURL()?.path else {
            detach(); return false
        }
        let newApp = mount + "/" + appName

        // Refuse anything that fails verification or isn't signed by the same
        // team as the running build - a hijacked download must not install.
        guard run("/usr/bin/codesign", ["--verify", "--deep", "--strict", newApp]).status == 0,
              let newTeam = teamID(of: newApp),
              let ourTeam = teamID(of: Bundle.main.bundlePath),
              newTeam == ourTeam else {
            print("UpdateChecker: downloaded app failed signature checks, not installing")
            detach(); return false
        }

        let pid = ProcessInfo.processInfo.processIdentifier
        let script = """
        while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.2; done
        /bin/rm -rf "\(target)"
        /usr/bin/ditto "\(newApp)" "\(target)"
        /usr/bin/hdiutil detach "\(mount)" -quiet
        /bin/rm -f "\(dmg.path)"
        /usr/bin/open "\(target)"
        """
        let updater = Process()
        updater.executableURL = URL(fileURLWithPath: "/bin/bash")
        updater.arguments = ["-c", script]
        guard (try? updater.run()) != nil else { detach(); return false }

        print("UpdateChecker: installing update and restarting")
        DispatchQueue.main.async { NSApp.terminate(nil) }
        return true
    }

    /// The running bundle's URL if we can swap it in place: a real .app that is
    /// not Gatekeeper-translocated and whose parent directory is writable.
    private static func installableBundleURL() -> URL? {
        let url = Bundle.main.bundleURL
        guard url.pathExtension == "app",
              !url.path.contains("/AppTranslocation/"),
              FileManager.default.isWritableFile(atPath: url.deletingLastPathComponent().path)
        else { return nil }
        return url
    }

    private static func mountPoint(fromPlist plist: String) -> String? {
        guard let data = plist.data(using: .utf8),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let entities = dict["system-entities"] as? [[String: Any]]
        else { return nil }
        return entities.compactMap { $0["mount-point"] as? String }.first
    }

    private static func teamID(of path: String) -> String? {
        // codesign prints signing info on stderr; "TeamIdentifier=not set" means unsigned/ad-hoc.
        let res = run("/usr/bin/codesign", ["-dvv", path])
        guard let line = res.stderr.split(separator: "\n").first(where: { $0.hasPrefix("TeamIdentifier=") })
        else { return nil }
        let id = String(line.dropFirst("TeamIdentifier=".count))
        return id == "not set" ? nil : id
    }

    private static func run(_ tool: String, _ args: [String]) -> (status: Int32, stdout: String, stderr: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        do { try p.run() } catch { return (1, "", "") }
        let o = out.fileHandleForReading.readDataToEndOfFile()
        let e = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus,
                String(data: o, encoding: .utf8) ?? "",
                String(data: e, encoding: .utf8) ?? "")
    }

    // MARK: - Fallback alerts

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
