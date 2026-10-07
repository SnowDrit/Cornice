//
//  AppDelegate.swift
//  Cornice
//

import AppKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// Held for the lifetime of the app. Releasing this removes the status item
    /// from the menu bar, so it must not be a local variable.
    private var separator: SeparatorController?

    private let enumerator: ItemEnumerator = AXItemEnumerator()
    private var pointerWatcher: Timer?
    private var leftMenuBarAt: Date?
    private var startupHideTask: Task<Void, Never>?
    private var menuLanguage: Language?

    /// Whether the pointer has been in the menu bar since the icons were revealed.
    ///
    /// Without it, auto-collapse fires on a reveal the pointer was never near, which is
    /// every reveal made with the keyboard shortcut.
    private var visitedMenuBar = false

    /// Trackpad gestures. Constructed always, running only when the user has asked for it:
    /// an idle controller holds no event monitor and costs nothing.
    let gestures = GestureController()

    /// Keyboard shortcuts. Nothing is bound until the user binds it.
    let hotKeys = HotKeyCenter()

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("Cornice launched, build \(Bundle.main.shortVersion, privacy: .public)")

        let preferences = Preferences.shared

        // Insurance against dying while hidden. `cleanExit` is written true only from
        // `applicationWillTerminate`, which a crash never reaches, so finding it false
        // here means the previous run ended badly. Coming up revealed in that case costs
        // the user one keypress; coming up hidden would leave their icons parked off the
        // side of the screen with nothing running that knows how to bring them back.
        //
        // Read and written before the separator exists, because the separator reads these
        // when it is built and never asks again.
        let crashed = !preferences.cleanExit
        preferences.cleanExit = false
        if crashed {
            // The always hidden zone opens too, for the same reason and more so: it is
            // the one thing Cornice never opens by itself, so a user who cannot find
            // their icons has the fewest ways to guess where those went.
            preferences.zoneOpen = true
            log.error("previous run did not exit cleanly, coming up revealed")
        }

        let separator = SeparatorController { [weak self] hiding in
            Preferences.shared.wasHiding = hiding
            if !hiding {
                self?.leftMenuBarAt = nil
                self?.visitedMenuBar = false
            }
        }
        self.separator = separator

        installMenu()

        // Only language changes affect menu titles. Visibility and saved positions
        // also write defaults, but do not need a new menu.
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if self.menuLanguage != Preferences.shared.language {
                        self.installMenu()
                    }
                    // The gesture switch lives in the same preferences, so the same
                    // notification is what tells the module it was turned on or off.
                    self.gestures.refresh()
                    self.hotKeys.refresh()
                }
            }

        // Restore what the user left, unless they asked for a fixed starting state.
        let shouldHide = !crashed && (preferences.startHidden || preferences.wasHiding)
        if shouldHide {
            // Only after the bar has settled: the separator needs a position before it
            // can work out how wide to become.
            startupHideTask = Task { @MainActor in
                do { try await Task.sleep(for: .milliseconds(600)) }
                catch { return }
                separator.setHiding(true)
            }
        }

        startWatchingPointer()

        // Only does anything if the user switched gestures on in an earlier run. It never
        // prompts: a module that finds its permission missing stays quiet and stays off,
        // and the switch in Settings is the only thing allowed to ask.
        gestures.refresh()

        hotKeys.onAction = { [weak self] action in
            self?.perform(action)
        }
        hotKeys.refresh()

        checkForUpdatesIfAsked()

    }

    /// The newest release found, or `nil` when nothing has been found or looked for.
    ///
    /// Held here rather than inside the checker so there is exactly one copy of it, and so
    /// that a checker with no state stays a checker with no state.
    private(set) var availableUpdate: UpdateChecker.Release?

    /// One look at GitHub, a few seconds after launch, and only if the user asked for it.
    ///
    /// Delayed because launch is the busiest moment Cornice has and nothing here is
    /// urgent. A failure is silent on purpose: an application that cannot reach GitHub has
    /// nothing useful to say about it, and saying it in a dialog at startup would be worse
    /// than saying nothing.
    private func checkForUpdatesIfAsked() {
        guard Preferences.shared.checkForUpdatesAtLaunch else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard case .available(let release) = await UpdateChecker.check() else { return }
            availableUpdate = release
            installMenu()
            log.info("update available: \(release.version, privacy: .public)")
        }
    }

    /// What a bound key actually does.
    ///
    /// Both of these are things Cornice can do to itself. Neither reaches for anybody
    /// else's status item, which is why neither needs a permission and why the list is
    /// this short.
    private func perform(_ action: HotKeyAction) {
        switch action {
        case .toggleHiding:
            separator?.toggleHiding()
        case .toggleAlwaysHidden:
            separator?.toggleZone()
        case .toggleAutoCollapse:
            Preferences.shared.autoCollapse.toggle()
        }
    }

    /// The only place `cleanExit` is written true, which is what makes it mean anything.
    /// A crash, a force quit or a kill all skip this, and the next launch reads that.
    func applicationWillTerminate(_ notification: Notification) {
        // An event tap left registered at exit can outlive the process and cost the whole
        // machine, not just Cornice.
        gestures.shutdown()
        startupHideTask?.cancel()
        pointerWatcher?.invalidate()
        separator?.shutdown()

        Preferences.shared.cleanExit = true
        log.info("quitting cleanly")
    }

    /// Puts the icons away again once the pointer has left the menu bar.
    ///
    /// Polled rather than observed. A global event monitor would do it, but that is
    /// precisely the mechanism Apple has told developers not to rely on for status items
    /// - and this is the daily path, the half of Cornice that is meant to keep working.
    /// Five samples a second costs nothing and depends on nothing.
    private func startWatchingPointer() {
        pointerWatcher = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.checkPointer() }
        }
    }

    private func checkPointer() {
        separator?.checkClockHover()
        let preferences = Preferences.shared
        guard preferences.autoCollapse,
              let separator, !separator.isHiding, !separator.isRearranging
        else {
            leftMenuBarAt = nil
            visitedMenuBar = false
            return
        }

        let pointer = NSEvent.mouseLocation
        // The key window's screen need not contain the pointer. Limit each display
        // to its own top strip, including the taller bar around a camera cutout.
        let inMenuBar = NSScreen.screens.contains { screen in
            MenuBarPointerRegion.contains(
                point: pointer, screenFrame: screen.frame,
                menuBarHeight: max(NSStatusBar.system.thickness, screen.safeAreaInsets.top))
        }

        if inMenuBar {
            visitedMenuBar = true
            leftMenuBarAt = nil
            return
        }

        // Auto-collapse is a *leaving* gesture, so there has to have been an arriving one.
        // Revealing by keyboard shortcut leaves the pointer wherever it already was, and
        // without this the icons appear and vanish again a third of a second later, which
        // makes the shortcut useless to anyone who has this switched on. Clicking the
        // chevron sets this on the same tick, because the click happened in the menu bar.
        guard visitedMenuBar else {
            leftMenuBarAt = nil
            return
        }

        guard let since = leftMenuBarAt else {
            leftMenuBarAt = Date()
            return
        }
        if Date().timeIntervalSince(since) >= preferences.autoCollapseDelay {
            leftMenuBarAt = nil
            visitedMenuBar = false
            separator.setHiding(true)
        }
    }

    /// Right-click opens this; left-click toggles. Kept to two items because an agent
    /// with no Dock icon still needs a way to reach its settings and to quit.
    private func installMenu() {
        let menu = NSMenu()

        // An agent with no Dock icon and no window has nowhere else to put this. It opens
        // the release page and nothing more: Cornice does not install over itself.
        if let update = availableUpdate {
            menu.addItem(
                withTitle: L.t("Version") + " \(update.version) " + L.t("is available"),
                action: #selector(openReleasePage),
                keyEquivalent: "").target = self
            menu.addItem(.separator())
        }

        menu.addItem(withTitle: L.t("Settings…"), action: #selector(openSettings), keyEquivalent: ",")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L.t("Quit Cornice"), action: #selector(quit), keyEquivalent: "q")
            .target = self
        separator?.contextMenu = menu
        menuLanguage = Preferences.shared.language
    }

    @objc private func openReleasePage() {
        guard let update = availableUpdate else { return }
        NSWorkspace.shared.open(update.url)
    }

    private let settingsWindow = SettingsWindowController()

    @objc private func openSettings() {
        settingsWindow.show(SettingsView(
            arrangement: currentArrangement,
            foundAtLaunch: { [weak self] in self?.availableUpdate },
            gestures: gestures,
            hotKeys: hotKeys))
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    /// What the settings window lists. Split at the dividers rather than by any stored
    /// configuration, because the arrangement *is* the configuration.
    ///
    /// It used to split at the toggle, which sits at the right-hand end of the bar and
    /// means nothing: with the icons revealed that put almost everything in the hidden
    /// list. The dividers are what decides, so the dividers are what it reads.
    func currentArrangement() -> SettingsView.Arrangement {
        if #available(macOS 27, *) {
            // A collapsed bar no longer contains the original item geometry.
            // Use the same revealed snapshot that drives native visibility.
            return separator?.nativeArrangement ?? .init(visible: [], hidden: [])
        }
        let main = separator?.mainDividerAnchor ?? 0
        let zone = separator?.zoneDividerAnchor
        let items = enumerator.enumerateItems().filter {
            $0.ownerBundleID != Bundle.main.bundleIdentifier
        }
        func x(_ item: MenuBarItem) -> CGFloat { item.frame?.minX ?? -1 }

        return SettingsView.Arrangement(
            visible: items.filter { x($0) >= main },
            hidden: items.filter { x($0) < main && x($0) >= (zone ?? -.greatestFiniteMagnitude) },
            alwaysHidden: zone.map { anchor in items.filter { x($0) < anchor } } ?? [])
    }

    /// Reopening reveals the controls without creating an empty application window.
    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        // Opening Cornice from Finder is also a recovery path if macOS overflow has
        // swallowed its toggle. Reveal both zones without changing their arrangement.
        startupHideTask?.cancel()
        startupHideTask = nil
        leftMenuBarAt = nil
        visitedMenuBar = false
        separator?.revealAll()
        return false
    }
}

private extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}
