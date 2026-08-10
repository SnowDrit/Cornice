//
//  SettingsView.swift
//  Cornice
//

import SwiftUI

/// Cornice's only window.
///
/// The list is a *reading* of the menu bar, not a control for it. Which items are hidden
/// is decided by where the boundary sits, and the boundary is placed by dragging it:
/// Cornice cannot move anybody else's status item, and the mechanism that would let it
/// is both unreliable and due to be removed. Showing the arrangement by name is still
/// worth doing: without it there is no way to tell what is behind the boundary.
struct SettingsView: View {

    @Bindable var preferences = Preferences.shared
    let arrangement: () -> Arrangement
    let gestures: GestureController
    let hotKeys: HotKeyCenter

    @State private var snapshot = Arrangement(visible: [], hidden: [])
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var isChecking = false
    @State private var updateResult: UpdateChecker.Result?
    @State private var gesturesOn = Preferences.shared.gesturesEnabled
    @State private var accessibilityGranted = AccessibilityPermission.isGranted

    private func checkForUpdates() {
        isChecking = true
        updateResult = nil
        Task {
            let result = await UpdateChecker.check()
            await MainActor.run {
                updateResult = result
                isChecking = false
            }
        }
    }

    struct Arrangement {
        var visible: [MenuBarItem]
        var hidden: [MenuBarItem]
    }

    var body: some View {
        TabView {
            behaviour.tabItem { Label(L.t("Behaviour"), systemImage: "slider.horizontal.3") }
            appearance.tabItem { Label(L.t("Appearance"), systemImage: "paintbrush") }
            arrangementList.tabItem { Label(L.t("Menu Bar"), systemImage: "menubar.rectangle") }
            gestureSettings.tabItem { Label(L.t("Gestures"), systemImage: "hand.draw") }
        }
        // Wide enough for four tabs to sit side by side in every language Cornice speaks.
        // At 470 macOS gave up on fitting them and swept all four into a "more toolbar
        // items" chevron, which turned one click into two and hid the tabs behind a
        // control that names none of them.
        .frame(width: 620, height: 400)
        .task { snapshot = arrangement() }
    }

    private var behaviour: some View {
        Form {
            Section {
                Picker(L.t("Language"), selection: $preferences.language) {
                    ForEach(Language.allCases) { language in
                        Text(language.endonym).tag(language)
                    }
                }
            }
            Section {
                Toggle(L.t("Start hidden"), isOn: $preferences.startHidden)
                Text(L.t("Otherwise Cornice comes up the way you left it."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle(L.t("Hide again automatically"), isOn: $preferences.autoCollapse)
                if preferences.autoCollapse {
                    LabeledContent(L.t("After")) {
                        HStack {
                            Slider(value: $preferences.autoCollapseDelay, in: 0.1...3, step: 0.1)
                            Text("\(preferences.autoCollapseDelay, specifier: "%.1f") s")
                                .monospacedDigit()
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                }
                Text(L.t("Counted from the moment the pointer leaves the menu bar."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(L.t("Keyboard shortcuts")) {
                ForEach(HotKeyAction.allCases) { action in
                    LabeledContent(L.t(action.title)) {
                        HotKeyRecorder(action: action) { hotKeys.refresh() }
                    }
                }
                Text(L.t("Nothing is bound until you bind it. They work from any application."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle(L.t("Open at login"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, wanted in
                        if !LaunchAtLogin.set(wanted) {
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
            }
            Section {
                LabeledContent(L.t("Version")) {
                    Text(UpdateChecker.currentVersion).monospacedDigit()
                }
                HStack {
                    Button(L.t("Check for Updates")) { checkForUpdates() }
                        .disabled(isChecking)
                    if isChecking { ProgressView().controlSize(.small) }
                    Spacer()
                }
                switch updateResult {
                case .none:
                    EmptyView()
                case .upToDate:
                    Text(L.t("You have the latest version."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .available(let release):
                    // Deliberately a link rather than a download. Cornice does not
                    // install anything over itself; the release page says what changed
                    // and the decision stays with the reader.
                    Link(
                        L.t("Version") + " \(release.version) " + L.t("is available"),
                        destination: release.url)
                        .font(.caption)
                case .failed(let reason):
                    Text(L.t("Could not check:") + " \(reason)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    /// The gesture module's whole interface: one switch and a reminder of what it does.
    ///
    /// The list is not configurable yet, and saying so plainly beats an empty customiser.
    /// Four gestures fit on the screen; when chaining arrives and they become twelve, this
    /// becomes a table worth scrolling.
    private var gestureSettings: some View {
        Form {
            Section {
                Toggle(L.t("Move windows with trackpad gestures"), isOn: $gesturesOn)
                    .onChange(of: gesturesOn) { _, wanted in
                        // Turning it on is the one moment Cornice is allowed to ask for
                        // Accessibility, because it is the one moment the user has asked
                        // for something that cannot work without it.
                        Task {
                            if wanted {
                                await gestures.enable()
                            } else {
                                gestures.disable()
                            }
                            accessibilityGranted = AccessibilityPermission.isGranted
                        }
                    }
                Text(L.t("Off by default. Accessibility is asked for only when you turn this on."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if gesturesOn && !accessibilityGranted {
                Section {
                    Label(
                        L.t("Accessibility has not been granted, so gestures are not running."),
                        systemImage: "exclamationmark.triangle")
                        .font(.caption)
                    Button(L.t("Open Accessibility settings")) {
                        AccessibilityPermission.openSettings()
                    }
                }
            }

            Section(L.t("Two fingers, pointer on a window's title bar")) {
                gestureRow("arrow.left", L.t("Left half"))
                gestureRow("arrow.right", L.t("Right half"))
                gestureRow("arrow.up", L.t("Fill the screen"))
                gestureRow("arrow.down", L.t("Put it back where it was"))
            }
        }
        .formStyle(.grouped)
        // The permission can be granted in System Settings while this window is open, and
        // macOS says nothing when it happens.
        .onAppear { accessibilityGranted = AccessibilityPermission.isGranted }
    }

    private func gestureRow(_ symbol: String, _ meaning: String) -> some View {
        LabeledContent {
            Text(meaning)
        } label: {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 20)
        }
    }

    private var appearance: some View {
        Form {
            Section(L.t("Divider")) {
                LabeledContent(L.t("Thickness")) {
                    HStack {
                        Slider(value: $preferences.dividerThickness, in: 0.5...5, step: 0.5)
                        Text("\(preferences.dividerThickness, specifier: "%.1f")")
                            .monospacedDigit()
                            .frame(width: 32, alignment: .trailing)
                    }
                }
                LabeledContent(L.t("Height")) {
                    HStack {
                        Slider(value: $preferences.dividerHeight, in: 4...20, step: 1)
                        Text("\(Int(preferences.dividerHeight))")
                            .monospacedDigit()
                            .frame(width: 32, alignment: .trailing)
                    }
                }
                // Drawn at the real size so the sliders can be judged by eye rather than
                // by number; the menu bar is small and 2 points is a visible difference.
                LabeledContent(L.t("Preview")) {
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
            Section(L.t("Toggle")) {
                Picker(L.t("Symbol"), selection: $preferences.toggleSymbol) {
                    ForEach(Preferences.ToggleSymbol.allCases) { symbol in
                        Label(L.t(symbol.label), systemImage: symbol.symbolName(hiding: false))
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
                Section(L.t("Hidden, left of the divider")) {
                    if snapshot.hidden.isEmpty {
                        Text(L.t("Nothing. Drag the divider left of the icons you want out of the way."))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(snapshot.hidden) { item in row(item) }
                }
                Section(L.t("Visible, right of the divider")) {
                    ForEach(snapshot.visible) { item in row(item) }
                }
            }
            Divider()
            HStack {
                Text(L.t("⌘-drag the divider to change what is hidden."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(L.t("Refresh")) { snapshot = arrangement() }
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
            Text(item.frame.map { "x \(Int($0.minX))" } ?? L.t("off-screen"))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.tertiary)
        }
    }
}
