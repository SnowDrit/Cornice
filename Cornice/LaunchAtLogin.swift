//
//  LaunchAtLogin.swift
//  Cornice
//

import ServiceManagement
import OSLog

/// Registers Cornice with macOS as a login item.
///
/// `SMAppService.mainApp` needs no helper bundle and no privileged install, the app
/// registers itself, and the user can revoke it from System Settings like any other
/// login item. Reading the status is cheap enough to do whenever the settings window
/// wants it, so nothing is cached.
enum LaunchAtLogin {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// - Returns: whether the request succeeded. macOS can refuse, most often because
    ///   the user has disabled the item in System Settings, which an app is not allowed
    ///   to override.
    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            log.error("""
                could not \(enabled ? "enable" : "disable", privacy: .public) launch at login: \
                \(error.localizedDescription, privacy: .public)
                """)
            return false
        }
    }
}
