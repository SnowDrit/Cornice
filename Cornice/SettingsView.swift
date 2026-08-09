//
//  SettingsView.swift
//  Cornice
//

import SwiftUI

/// Cornice's only window.
///
/// The list is a *reading* of the menu bar, not a control for it. Which items are hidden
/// is decided by where the boundary sits, and the boundary is placed by dragging it —
/// Cornice cannot move anybody else's status item, and the mechanism that would let it
/// is both unreliable and due to be removed. Showing the arrangement by name is still
/// worth doing: without it there is no way to tell what is behind the boundary.
struct SettingsView: View {

    @Bindable var preferences = Preferences.shared
    let arrangement: () -> Arrangement

    @State private var snapshot = Arrangement(visible: [], hidden: [])
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    struct Arrangement {
        var visible: [MenuBarItem]
        var hidden: [MenuBarItem]
    }

    var body: some View {
        TabView {
            behaviour.tabItem { Label("Behaviour", systemImage: "slider.horizontal.3") }
            arrangementList.tabItem { Label("Menu Bar", systemImage: "menubar.rectangle") }
        }
        .frame(width: 460, height: 380)
        .task { snapshot = arrangement() }
    }

    private var behaviour: some View {
        Form {
            Section {
                Toggle("Start hidden", isOn: $preferences.startHidden)
                Text("Otherwise Cornice comes up the way you left it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Hide again automatically", isOn: $preferences.autoCollapse)
                if preferences.autoCollapse {
                    LabeledContent("After") {
                        HStack {
                            Slider(value: $preferences.autoCollapseDelay, in: 0.1...3, step: 0.1)
                            Text("\(preferences.autoCollapseDelay, specifier: "%.1f") s")
                                .monospacedDigit()
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                }
                Text("Counted from the moment the pointer leaves the menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, wanted in
                        if !LaunchAtLogin.set(wanted) {
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
            }
        }
        .formStyle(.grouped)
    }

    private var arrangementList: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                Section("Hidden — left of the divider") {
                    if snapshot.hidden.isEmpty {
                        Text("Nothing. Drag the divider left of the icons you want out of the way.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(snapshot.hidden) { item in row(item) }
                }
                Section("Visible — right of the divider") {
                    ForEach(snapshot.visible) { item in row(item) }
                }
            }
            Divider()
            HStack {
                Text("⌘-drag the divider to change what is hidden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Refresh") { snapshot = arrangement() }
            }
            .padding(10)
        }
    }

    private func row(_ item: MenuBarItem) -> some View {
        HStack {
            Text(item.ownerName)
            if let title = item.title {
                Text(title).foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.frame.map { "x \(Int($0.minX))" } ?? "off-screen")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.tertiary)
        }
    }
}
