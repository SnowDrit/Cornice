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
            appearance.tabItem { Label("Appearance", systemImage: "paintbrush") }
            arrangementList.tabItem { Label("Menu Bar", systemImage: "menubar.rectangle") }
        }
        .frame(width: 470, height: 400)
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

    private var appearance: some View {
        Form {
            Section("Divider") {
                LabeledContent("Thickness") {
                    HStack {
                        Slider(value: $preferences.dividerThickness, in: 0.5...5, step: 0.5)
                        Text("\(preferences.dividerThickness, specifier: "%.1f")")
                            .monospacedDigit()
                            .frame(width: 32, alignment: .trailing)
                    }
                }
                LabeledContent("Height") {
                    HStack {
                        Slider(value: $preferences.dividerHeight, in: 4...20, step: 1)
                        Text("\(Int(preferences.dividerHeight))")
                            .monospacedDigit()
                            .frame(width: 32, alignment: .trailing)
                    }
                }
                // Drawn at the real size so the sliders can be judged by eye rather than
                // by number; the menu bar is small and 2 points is a visible difference.
                LabeledContent("Preview") {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                        Capsule()
                            .frame(
                                width: preferences.dividerThickness,
                                height: preferences.dividerHeight)
                    }
                    .frame(width: 60, height: 24)
                }
            }
            Section("Toggle") {
                Picker("Symbol", selection: $preferences.toggleSymbol) {
                    ForEach(Preferences.ToggleSymbol.allCases) { symbol in
                        Label(symbol.label, systemImage: symbol.symbolName(hiding: false))
                            .tag(symbol)
                    }
                }
                .pickerStyle(.inline)
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
