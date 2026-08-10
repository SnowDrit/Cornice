//
//  AccessibilityPermission.swift
//  Cornice
//

import ApplicationServices
import AppKit
import OSLog

/// Accessibility is the only permission Cornice asks for.
///
/// It is needed to *read* the menu bar and to *reposition* items, that is, to change the
/// configuration. It is deliberately **not** needed to collapse and reveal, which is the
/// path used every day. If the user refuses, or if a future macOS revokes it, Cornice
/// keeps working with whatever arrangement already exists.
enum AccessibilityPermission {

    /// Non-prompting check. Safe to call as often as you like.
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Asks macOS to show the "…would like to control this computer" alert.
    ///
    /// The alert appears at most once per app identity; afterwards macOS silently
    /// returns the stored answer, so this cannot be used to nag. Granting the permission
    /// does not notify the app, the state has to be polled, hence `waitUntilGranted`.
    @discardableResult
    static func request() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Opens the exact System Settings pane, because finding it by hand is tedious.
    static func openSettings() {
        let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }

    /// Polls until the permission appears, or the timeout expires.
    ///
    /// macOS posts no notification when the user flips the switch, so polling is the
    /// only option. One second is frequent enough to feel immediate and far too slow
    /// to cost anything.
    static func waitUntilGranted(timeout: Duration = .seconds(120)) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if isGranted { return true }
            try? await Task.sleep(for: .seconds(1))
        }
        return isGranted
    }
}
