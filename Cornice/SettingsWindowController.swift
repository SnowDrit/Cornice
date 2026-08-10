//
//  SettingsWindowController.swift
//  Cornice
//

import AppKit
import SwiftUI

/// Owns the settings window.
///
/// Built by hand rather than through SwiftUI's `Settings` scene. That scene is opened by
/// sending `showSettingsWindow:` - a selector looked up by name, on an app that has no
/// Dock icon and no menu bar of its own, and nothing happened when it was sent. An
/// `NSWindow` created here opens because it was created; there is no lookup to fail.
@MainActor
final class SettingsWindowController {

    private var window: NSWindow?

    func show<Content: View>(_ content: Content) {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 452),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false)
            window.title = "Cornice"
            window.contentView = NSHostingView(rootView: AnyView(content))
            // An agent's windows are not recreated for it: closing must not deallocate
            // this one, or reopening lands on freed memory.
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        } else {
            window?.contentView = NSHostingView(rootView: AnyView(content))
        }

        // Without this the window opens behind whatever the user was looking at, since
        // an accessory app is never the active one.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
