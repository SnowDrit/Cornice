//
//  HotKeyRecorder.swift
//  Cornice
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A field that shows a key combination and records a new one when clicked.
///
/// Listens with a **local** event monitor, which only sees events aimed at Cornice's own
/// window and therefore needs no permission. A global monitor would see the whole machine
/// and would need Accessibility, for no gain: the user is looking at this field when they
/// press the keys.
struct HotKeyRecorder: View {

    let action: HotKeyAction
    /// Called after the binding is stored, so the owner can re-register with the system.
    let onChange: () -> Void

    @State private var hotKey: HotKey?
    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var rejected: String?

    var body: some View {
        HStack(spacing: 8) {
            Button(action: toggleRecording) {
                Text(caption)
                    .font(.body.monospaced())
                    .frame(minWidth: 96)
            }
            .buttonStyle(.bordered)
            .help(L.t("Click, then press the combination you want."))

            if hotKey != nil && !isRecording {
                Button(action: clear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(L.t("Remove this shortcut"))
            }

            if let rejected {
                Text(rejected)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { hotKey = Preferences.shared.hotKey(for: action) }
        // A recorder left listening after its window closed would swallow the next key
        // press anywhere in Cornice.
        .onDisappear(perform: stopRecording)
    }

    private var caption: String {
        if isRecording { return L.t("Press keys…") }
        return hotKey?.label ?? L.t("Not set")
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        rejected = nil
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            handle(event)
            // Swallowed, so the key press being recorded does not also reach whatever
            // control had focus.
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handle(_ event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape {
            stopRecording()
            return
        }

        guard let candidate = HotKey(event: event) else {
            rejected = L.t("Use at least two modifiers, one of them ⌘, ⌥ or ⌃.")
            return
        }
        guard HotKeyCenter.isAvailable(candidate) else {
            rejected = L.t("Something else already uses that.")
            return
        }

        hotKey = candidate
        rejected = nil
        Preferences.shared.setHotKey(candidate, for: action)
        stopRecording()
        onChange()
    }

    private func clear() {
        hotKey = nil
        rejected = nil
        Preferences.shared.setHotKey(nil, for: action)
        onChange()
    }
}
