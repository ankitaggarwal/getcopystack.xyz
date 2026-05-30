//
//  MonitoringManager.swift
//  Copy Stack
//
//  A thin coordinator that starts and stops the shared ClipboardMonitor, so
//  callers don't reach into the monitor directly. (Cmd+V handling lives in
//  HotkeyManager via the Carbon API, not here.)
//
//  Created by Ankit Aggarwal
//

import Foundation

class MonitoringManager {
    static let shared = MonitoringManager()

    private init() {}

    /// Start clipboard monitoring
    func startMonitoring() {
        if !Paste_AppApp.monitor.isCurrentlyMonitoring {
            Paste_AppApp.monitor.startMonitoring()
            print("MonitoringManager: Started clipboard monitoring")
        }
        // Note: Keyboard monitoring (Cmd+V detection) is now handled globally by HotkeyManager
    }

    /// Stop clipboard monitoring
    func stopMonitoring() {
        Paste_AppApp.monitor.stopMonitoring()
        print("MonitoringManager: Stopped clipboard monitoring")
        // Note: Keyboard hotkeys remain active globally
    }

    /// Check if monitoring is currently active
    var isMonitoring: Bool {
        return Paste_AppApp.monitor.isCurrentlyMonitoring
    }
}
