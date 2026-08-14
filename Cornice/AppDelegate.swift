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

        // The geometry check runs headless: no status item, no menu, no preferences
        // written. That is what makes it safe to run while the installed copy is going
        // about its business, and removing a status item is the one thing that must not
        // happen behind the user's back, because macOS rebuilds the bar around it and
        // leaves anything already pushed off the edge pushed off the edge.
        if ProcessInfo.processInfo.environment["CORNICE_RUN_GESTURECHECK"] != nil {
            Task {
                await runGestureCheck()
                NSApp.terminate(nil)
            }
            return
        }

        // The one check that does put items in the menu bar, because what it is asking
        // about is menu bar items: whether two of them belonging to one process can both
        // be wider than the bar at once. Its items are its own, under their own autosave
        // names, and it narrows them and waits before letting go of them. Still worth
        // running with the real Cornice revealed rather than hiding.
        if ProcessInfo.processInfo.environment["CORNICE_RUN_TWOWIDECHECK"] != nil {
            Task {
                await SecondBoundaryCheck.run()
                NSApp.terminate(nil)
            }
            return
        }

        // Opens the settings window on its own, so its layout can be looked at without
        // clicking a status item. Headless for the same reason as the gesture check: this
        // instance must not touch the menu bar the real one is managing.
        if ProcessInfo.processInfo.environment["CORNICE_SHOW_SETTINGS"] != nil {
            openSettings()
            return
        }

        let separator = SeparatorController { hiding in
            Preferences.shared.wasHiding = hiding
        }
        self.separator = separator

        installMenu()

        // The menu's titles are built once, so they would keep the language they were
        // built in. Rebuilt whenever a preference changes, which is the only way the
        // language can change.
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.installMenu()
                    // The gesture switch lives in the same preferences, so the same
                    // notification is what tells the module it was turned on or off.
                    self?.gestures.refresh()
                    self?.hotKeys.refresh()
                }
            }

        let preferences = Preferences.shared

        // Insurance against dying while hidden. `cleanExit` is written true only from
        // `applicationWillTerminate`, which a crash never reaches, so finding it false
        // here means the previous run ended badly. Coming up revealed in that case costs
        // the user one keypress; coming up hidden would leave their icons parked off the
        // side of the screen with nothing running that knows how to bring them back.
        let crashed = !preferences.cleanExit
        preferences.cleanExit = false
        if crashed {
            log.error("previous run did not exit cleanly, coming up revealed")
        }

        // Restore what the user left, unless they asked for a fixed starting state.
        let shouldHide = !crashed && (preferences.startHidden || preferences.wasHiding)
        if shouldHide {
            // Only after the bar has settled: the separator needs a position before it
            // can work out how wide to become.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
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
            Task { @MainActor in self?.checkPointer() }
        }
    }

    private func checkPointer() {
        let preferences = Preferences.shared
        guard preferences.autoCollapse,
              let separator, !separator.isHiding,
              let screen = NSScreen.main
        else {
            leftMenuBarAt = nil
            visitedMenuBar = false
            return
        }

        let pointer = NSEvent.mouseLocation
        // `visibleFrame` starts below the menu bar, so its top edge is the menu bar's
        // bottom edge. The Dock is excluded too, which does not matter here.
        let inMenuBar = pointer.y >= screen.visibleFrame.maxY

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
        menu.addItem(withTitle: L.t("Settings…"), action: #selector(openSettings), keyEquivalent: ",")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L.t("Quit Cornice"), action: #selector(quit), keyEquivalent: "q")
            .target = self
        separator?.contextMenu = menu
    }

    private let settingsWindow = SettingsWindowController()

    @objc private func openSettings() {
        settingsWindow.show(SettingsView(
            arrangement: currentArrangement, gestures: gestures, hotKeys: hotKeys))
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    /// What the settings window lists. Split at the boundary rather than by any stored
    /// configuration, because the arrangement *is* the configuration.
    func currentArrangement() -> SettingsView.Arrangement {
        let boundary = separator?.controlFrame?.minX ?? 0
        let items = enumerator.enumerateItems().filter {
            $0.ownerBundleID != Bundle.main.bundleIdentifier
        }
        return SettingsView.Arrangement(
            visible: items.filter { ($0.frame?.minX ?? -1) >= boundary },
            hidden: items.filter { ($0.frame?.minX ?? -1) < boundary })
    }

    /// Cornice has no windows to reopen, so clicking the app in Finder while it is
    /// already running should do nothing rather than resurrect an empty window.
    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        false
    }

    /// Snaps somebody's window to the left half without anyone touching the trackpad.
    ///
    /// The recogniser needs real fingers to test, but everything downstream of it does
    /// not, and everything downstream of it is where the mistakes live: the flip between
    /// Accessibility's top-left origin and AppKit's bottom-left one, and the order the
    /// size and position have to be written in. This drives that half directly and checks
    /// the window landed where the arithmetic said it would.
    ///
    /// Development only, in the same way as the checks above, and goes the same way.
    private func runGestureCheck() async {
        var report = "gesture geometry check\n\n"

        guard AccessibilityPermission.isGranted else {
            report += "no Accessibility, nothing to check\n"
            Self.writeReport(report, named: "gesture-check.txt")
            log.info("\(report, privacy: .public)")
            return
        }

        // Naming a bundle id keeps the check off the user's real windows: point it at a
        // throwaway document and only that document moves. Without one it takes whatever
        // regular application answers first, which is fine on a test machine and rude on
        // a working one.
        let wanted = ProcessInfo.processInfo.environment["CORNICE_GESTURECHECK_BUNDLE"]
        report += "target bundle: \(wanted ?? "(first regular app)")\n"

        var found: (name: String, element: AXUIElement, frame: CGRect)?
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular
            && app.processIdentifier != ProcessInfo.processInfo.processIdentifier
            && (wanted == nil || app.bundleIdentifier == wanted) {

            let element = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(element, 0.25)

            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                    element, kAXFocusedWindowAttribute as CFString, &value) == .success,
                  let value, CFGetTypeID(value) == AXUIElementGetTypeID()
            else { continue }

            let window = value as! AXUIElement
            guard let frame = Self.frameOf(window) else { continue }
            found = (app.localizedName ?? "?", window, frame)
            break
        }

        guard let found else {
            Self.writeReport(report + "no window found to test with\n", named: "gesture-check.txt")
            return
        }

        report += "window: \(found.name)\n"
        report += "before (AX): \(found.frame)\n"

        guard let area = ScreenGeometry.workArea(forWindowAt: found.frame) else {
            Self.writeReport(report + "no display matched that window\n", named: "gesture-check.txt")
            return
        }
        report += "work area (AX): \(area)\n\n"

        let target = TargetWindow(element: found.element, frame: found.frame)

        // The same run of swipes a hand would make, driven straight through the transition
        // table. This checks two different things at once: that chaining lands on the slot
        // it claims to, and that the slot's arithmetic survives the trip through
        // Accessibility into a real window.
        let script: [(String, SwipeRecognizer.Direction)] = [
            ("left",        .left),
            ("left again",  .left),
            ("left again",  .left),
            ("up",          .up),
            ("down",        .down),
        ]

        var slot: WindowSlot?
        var failures: [String] = []

        for (name, direction) in script {
            guard let next = WindowSlot.next(after: slot, swipe: direction) else {
                failures.append("\(name): chain unexpectedly ended")
                break
            }
            slot = next

            let wantedFrame = next.frame(in: area)
            target.setFrame(wantedFrame)
            try? await Task.sleep(for: .milliseconds(350))

            guard let actual = Self.frameOf(found.element) else {
                failures.append("\(name): could not read the frame back")
                continue
            }

            report += "\(name)\n"
            report += "  slot:   \(next)\n"
            report += "  wanted: \(Self.brief(wantedFrame))\n"
            report += "  actual: \(Self.brief(actual))\n"

            // The origin is the part Cornice controls outright. Size gets clamped by
            // applications with their own minimums, so it is reported but not judged.
            if abs(actual.minX - wantedFrame.minX) > 2 || abs(actual.minY - wantedFrame.minY) > 2 {
                failures.append("\(name): origin landed wrong")
            }
        }

        // Independent of the arithmetic above: the fractions have to *be* fractions. This
        // is what would catch a third that is really a quarter, which comparing the code
        // against itself never would.
        report += "\nfractions of the work area\n"
        let checks: [(String, WindowSlot, CGFloat, Bool)] = [
            ("left half",       .leftHalf,                                                    1.0 / 2, true),
            ("left third",      WindowSlot(column: .left, width: .third, row: .whole),         1.0 / 3, true),
            ("left two thirds", WindowSlot(column: .left, width: .twoThirds, row: .whole),     2.0 / 3, true),
            ("top left half",   WindowSlot(column: .left, width: .half, row: .top),            1.0 / 2, false),
        ]
        for (name, candidate, fraction, horizontal) in checks {
            let box = candidate.frame(in: area)
            let got = horizontal ? box.width / area.width : box.height / area.height
            let ok = abs(got - fraction) < 0.01
            report += "  \(name): \(horizontal ? "width" : "height") \(String(format: "%.3f", got))"
            report += " expected \(String(format: "%.3f", fraction))\(ok ? "" : "  WRONG")\n"
            if !ok { failures.append("\(name): fraction is \(got)") }
        }

        // Quarters sit in the half of the screen they are named after.
        let topLeft = WindowSlot(column: .left, width: .half, row: .top).frame(in: area)
        let bottomLeft = WindowSlot(column: .left, width: .half, row: .bottom).frame(in: area)
        report += "  top quarter y: \(Int(topLeft.minY)) (area starts \(Int(area.minY)))\n"
        report += "  bottom quarter y: \(Int(bottomLeft.minY)) (area middle \(Int(area.midY)))\n"
        if abs(topLeft.minY - area.minY) > 1 { failures.append("top quarter is not at the top") }
        if abs(bottomLeft.minY - area.midY) > 1 { failures.append("bottom quarter is not at the middle") }

        // No gesture calls this any more, but the call itself is proven working and cheap
        // to keep proven. There and back again, so the check leaves nothing in the Dock.
        report += "\nminimise round trip\n"
        if target.minimize() {
            try? await Task.sleep(for: .milliseconds(500))
            let went = Self.boolOf(found.element, attribute: kAXMinimizedAttribute)
            report += "  minimised: \(String(describing: went))\n"
            if went != true { failures.append("minimise did not take") }

            AXUIElementSetAttributeValue(
                found.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            try? await Task.sleep(for: .milliseconds(500))
            let back = Self.boolOf(found.element, attribute: kAXMinimizedAttribute)
            report += "  restored: \(String(describing: back == false))\n"
            if back != false { failures.append("window did not come back out of the Dock") }
        } else {
            failures.append("minimise was refused outright")
        }

        report += failures.isEmpty
            ? "\nALL CHECKS PASSED\n"
            : "\nFAILED:\n" + failures.map { "  \($0)\n" }.joined()

        log.info("\(report, privacy: .public)")
        Self.writeReport(report, named: "gesture-check.txt")
    }

    private static func boolOf(_ element: AXUIElement, attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
                element, attribute as CFString, &value) == .success
        else { return nil }
        return value as? Bool
    }

    private static func brief(_ rect: CGRect) -> String {
        "x=\(Int(rect.minX)) y=\(Int(rect.minY)) w=\(Int(rect.width)) h=\(Int(rect.height))"
    }

    private static func frameOf(_ element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
                element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(
                element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID()
        else { return nil }

        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private static func writeReport(_ text: String, named filename: String) {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let directory = base.appendingPathComponent("Cornice", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            try text.write(to: directory.appendingPathComponent(filename),
                           atomically: true, encoding: .utf8)
        } catch {
            log.error("could not write report: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}
