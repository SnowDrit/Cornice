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
    /// What the launch check found, if it ran and found anything. Read when the window
    /// opens, so a user who has the switch on does not have to press the button to be
    /// told what Cornice already knows.
    let foundAtLaunch: () -> UpdateChecker.Release?
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
        var alwaysHidden: [MenuBarItem] = []
    }

    /// A number in the language the window is written in, not the one the machine is set
    /// to. `"\(value, specifier: "%.1f")"` follows the system locale, which put "1,5"
    /// beside the word "Thickness" on a Russian machine showing the English interface.
    private func oneDecimal(_ value: Double) -> String {
        value.formatted(
            .number.precision(.fractionLength(1)).locale(preferences.language.locale))
    }

    /// Which tab opens first.
    ///
    /// Only ever anything but `.behaviour` when `CORNICE_SETTINGS_TAB` names another one,
    /// which is how the README pictures are taken: three launches, no clicking, and the
    /// same tab every time whoever runs it. Driving a `TabView` from outside needs a
    /// selection, and a selection needs tags, which is all this adds.
    enum Tab: String {
        case behaviour, appearance, menuBar, gestures

        static var requested: Tab {
            let asked = ProcessInfo.processInfo.environment["CORNICE_SETTINGS_TAB"] ?? ""
            return Tab(rawValue: asked) ?? .behaviour
        }

        /// How tall this tab needs to be, so the window follows the tab rather than one
        /// size serving none of them.
        ///
        /// One fixed height cannot do it any more: Behaviour needs about twice what
        /// Appearance does, and it grew again this release. Held at the tallest, half of
        /// Appearance is empty; held anywhere shorter, the update switch at the bottom of
        /// Behaviour falls below the fold, which is the worst of the two because it hides
        /// a control rather than showing nothing.
        ///
        /// Measured, not guessed, and worth re-measuring when a section is added: open
        /// each tab with `CORNICE_SETTINGS_TAB` and look at where the last box ends.
        var height: CGFloat {
            switch self {
            case .behaviour:  750
            case .appearance: 370
            case .menuBar:    460
            case .gestures:   600
            }
        }
    }

    @State private var tab = Tab.requested

    var body: some View {
        TabView(selection: $tab) {
            behaviour
                .tabItem { Label(L.t("Behaviour"), systemImage: "slider.horizontal.3") }
                .tag(Tab.behaviour)
            appearance
                .tabItem { Label(L.t("Appearance"), systemImage: "paintbrush") }
                .tag(Tab.appearance)
            arrangementList
                .tabItem { Label(L.t("Menu Bar"), systemImage: "menubar.rectangle") }
                .tag(Tab.menuBar)
            gestureSettings
                .tabItem { Label(L.t("Gestures"), systemImage: "hand.draw") }
                .tag(Tab.gestures)
        }
        // Wide enough for four tabs to sit side by side in every language Cornice speaks.
        // At 470 macOS gave up on fitting them and swept all four into a "more toolbar
        // items" chevron, which turned one click into two and hid the tabs behind a
        // control that names none of them. Width is fixed for that reason; height is not,
        // because the tabs are nothing like the same length.
        .frame(width: 620, height: tab.height)
        .task {
            snapshot = arrangement()
            accessibilityGranted = AccessibilityPermission.isGranted
            if let found = foundAtLaunch() { updateResult = .available(found) }
        }
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
                Toggle(L.t("Start with the icons hidden"), isOn: $preferences.startHidden)
                Text(L.t("Otherwise Cornice comes up the way you left it."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle(L.t("Hide again when the pointer leaves the menu bar"), isOn: $preferences.autoCollapse)
                if preferences.autoCollapse {
                    LabeledContent(L.t("After")) {
                        HStack {
                            // Starts at 0.2 because the pointer is sampled every 0.2
                            // seconds, so anything below that is a number the mechanism
                            // cannot honour, and offering it is a small lie.
                            Slider(value: $preferences.autoCollapseDelay, in: 0.2...3, step: 0.1)
                            Text(oneDecimal(preferences.autoCollapseDelay) + " s")
                                .monospacedDigit()
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                }
                Text(L.t("A short wait, so brushing past the top of the screen does not put them away."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle(
                    L.t("Keep a second divider, for icons you never want to see"),
                    isOn: $preferences.alwaysHiddenEnabled)
                Text(L.t("It costs one more slot in the menu bar. ⌘-drag it left of the first divider: whatever ends up behind it stays hidden even while the rest are revealed."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if preferences.alwaysHiddenEnabled {
                    Text(L.t("⌥-click the toggle button to open it, or bind a shortcut below."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                Toggle(
                    L.t("Check at launch"),
                    isOn: $preferences.checkForUpdatesAtLaunch)
                Text(L.t("One request to GitHub, carrying nothing. Cornice never installs anything over itself."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

            Section(L.t("Swipe again straight after, and it refines instead of starting over")) {
                gestureRow("arrow.left", "arrow.left", L.t("Narrower: a third, then two thirds"))
                gestureRow("arrow.left", "arrow.up", L.t("Top quarter of that side"))
                gestureRow("arrow.left", "arrow.down", L.t("Bottom quarter of that side"))
                Text(L.t("Right works the same. Pause for a moment and the next swipe starts fresh."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                gestureRow("arrow.down.right.and.arrow.up.left", L.t("Send the window to the Dock"))
                Text(L.t("Pinch in, on the title bar. It never closes anything."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        // The permission can be granted in System Settings while this window is open, and
        // macOS says nothing when it happens.
        .onAppear { accessibilityGranted = AccessibilityPermission.isGranted }
    }

    /// Arrow and meaning sit next to each other, not at opposite edges of the window.
    ///
    /// `LabeledContent` pushes its two halves apart, which is right for a setting and its
    /// control and wrong for a picture and its caption: at this width it left the arrow
    /// stranded on the left with the words against the far right, and the eye had to cross
    /// an empty gap to connect them.
    private func gestureRow(_ symbol: String, _ meaning: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            Text(meaning)
            Spacer(minLength: 0)
        }
    }

    /// Two arrows for the chained gestures, so the pair reads as one movement followed by
    /// another rather than as two separate entries.
    private func gestureRow(_ first: String, _ second: String, _ meaning: String) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                Image(systemName: first)
                Image(systemName: second)
            }
            .foregroundStyle(.secondary)
            .frame(width: 44, alignment: .leading)
            Text(meaning)
            Spacer(minLength: 0)
        }
    }

    private var appearance: some View {
        Form {
            Section(L.t("Divider")) {
                LabeledContent(L.t("Thickness")) {
                    HStack {
                        Slider(value: $preferences.dividerThickness, in: 0.5...5, step: 0.5)
                        Text(oneDecimal(preferences.dividerThickness))
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
                    HStack(spacing: 8) {
                        if preferences.alwaysHiddenEnabled {
                            // Two bars share the width of one divider, so past a point
                            // they thin out instead of the item growing wider.
                            dividerSwatch(bars: 2)
                        }
                        dividerSwatch(bars: 1)
                    }
                }
            }
            Section(L.t("Toggle button")) {
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

    /// One divider as it will be drawn. Two bars means the always hidden one, which is
    /// the only thing that tells the pair apart once they are both in the bar.
    private func dividerSwatch(bars: Int) -> some View {
        let thickness = bars == 2
            ? min(preferences.dividerThickness, 4)
            : preferences.dividerThickness
        return ZStack {
            RoundedRectangle(cornerRadius: 4).fill(.quaternary)
            HStack(spacing: 2) {
                ForEach(0..<bars, id: \.self) { _ in
                    Capsule().frame(width: thickness, height: preferences.dividerHeight)
                }
            }
        }
        .frame(width: 60, height: 24)
    }

    private var arrangementList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cornice no longer asks for Accessibility on launch, because hiding and
            // revealing never needed it. Reading the bar by name does, so this is the one
            // place the absence shows, and an empty list with no explanation would read as
            // a broken window rather than a missing permission.
            if !accessibilityGranted {
                HStack {
                    Text(L.t("Listing the icons by name needs Accessibility. Hiding them does not."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(L.t("Open Accessibility settings")) {
                        AccessibilityPermission.openSettings()
                    }
                }
                .padding(10)
                Divider()
            }
            List {
                if preferences.alwaysHiddenEnabled {
                    Section(L.t("Always hidden, left of the second divider")) {
                        if snapshot.alwaysHidden.isEmpty {
                            Text(L.t("Nothing. Drag the second divider left of the icons you never want to see."))
                                .foregroundStyle(.secondary)
                        }
                        ForEach(snapshot.alwaysHidden) { item in row(item) }
                    }
                }
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
