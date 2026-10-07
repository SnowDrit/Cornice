//
//  MenuBarAccessIssue.swift
//  Cornice
//

/// Why the native menu bar cannot currently hide a group. This describes
/// readiness, independently of the user's saved visibility preferences.
enum MenuBarAccessIssue: Equatable {
    case accessibilityRequired
    case visibilityUnavailable

    static func detect(accessibilityGranted: Bool, visibilityAvailable: Bool) -> Self? {
        // Permission cannot repair a missing system API.
        if !visibilityAvailable { return .visibilityUnavailable }
        if !accessibilityGranted { return .accessibilityRequired }
        return nil
    }

    var title: String {
        switch self {
        case .accessibilityRequired: "Cornice needs Accessibility access"
        case .visibilityUnavailable: "Menu bar hiding is unavailable"
        }
    }

    var explanation: String {
        switch self {
        case .accessibilityRequired:
            "On macOS 27, Cornice cannot hide menu bar icons without Accessibility access. Open System Settings > Privacy & Security > Accessibility and enable Cornice.\n\nAfter an update, if Cornice is already enabled but hiding still does not work, remove its entry from that list and add Cornice from Applications again. Your Cornice settings and icon positions are kept."
        case .visibilityUnavailable:
            "macOS is not providing the menu bar controls Cornice needs. Icons will stay visible. Try reopening Cornice. If the problem continues, report it in Issues."
        }
    }
}
