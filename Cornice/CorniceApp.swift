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
        // (see INFOPLIST_KEY_LSUIElement in the build settings).
        //
        // SwiftUI still requires at least one scene, so this is an empty
        // Settings scene for now. The real settings UI arrives in stage 5.
        Settings {
            EmptyView()
        }
    }
}
