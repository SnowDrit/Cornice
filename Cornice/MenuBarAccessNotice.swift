//
//  MenuBarAccessNotice.swift
//  Cornice
//

import AppKit

/// Shown only after an explicit menu-bar action. Background permission checks
/// never interrupt the user or request additional access.
@MainActor
final class MenuBarAccessNotice {
    private var isPresenting = false

    func show(_ issue: MenuBarAccessIssue) {
        // NSAlert runs a nested event loop; a shortcut can arrive while it is open.
        guard !isPresenting else { return }
        isPresenting = true
        defer { isPresenting = false }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L.t(issue.title)
        alert.informativeText = L.t(issue.explanation)
        if issue == .accessibilityRequired {
            alert.addButton(withTitle: L.t("Open Accessibility settings"))
            alert.addButton(withTitle: L.t("Not Now"))
        } else {
            alert.addButton(withTitle: "OK")
        }

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        guard issue == .accessibilityRequired,
              response == .alertFirstButtonReturn else { return }
        // Register this build with macOS only after the user chooses the button.
        // The system permission itself is still granted by the user in Settings.
        AccessibilityPermission.request()
        AccessibilityPermission.openSettings()
    }
}
