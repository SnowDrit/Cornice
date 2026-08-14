//
//  CorniceApp.swift
//  Cornice
//

import SwiftUI

@main
struct CorniceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Cornice is a menu bar agent: it has no main window and no Dock icon
        // (see INFOPLIST_KEY_LSUIElement in the build settings). The settings window is
        // the only window it ever shows, and only when asked.
        Settings {
            SettingsView(
                arrangement: appDelegate.currentArrangement,
                foundAtLaunch: { appDelegate.availableUpdate },
                gestures: appDelegate.gestures,
                hotKeys: appDelegate.hotKeys)
        }
    }
}
