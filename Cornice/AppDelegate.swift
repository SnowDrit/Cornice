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
    private let mover: ItemMover = CommandDragItemMover()

    /// Items the stage 4 check arranges behind the separator. Any third-party items will
    /// do; these are simply the ones always present on the machine being developed
    /// against. Stage 5 replaces this with real configuration.
    private static let testSubjects = [
        "ru.keepcoder.Telegram",
        "com.anthropic.claudefordesktop",
    ]

    private var pointerWatcher: Timer?
    private var leftMenuBarAt: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("Cornice launched, build \(Bundle.main.shortVersion, privacy: .public)")

        let separator = SeparatorController { hiding in
            Preferences.shared.wasHiding = hiding
        }
        self.separator = separator

        installMenu()

        // Restore what the user left, unless they asked for a fixed starting state.
        let preferences = Preferences.shared
        let shouldHide = preferences.startHidden || preferences.wasHiding
        if shouldHide {
            // Only after the bar has settled: the separator needs a position before it
            // can work out how wide to become.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                separator.setHiding(true)
            }
        }

        startWatchingPointer()

        Task { await start() }
    }

    /// Puts the icons away again once the pointer has left the menu bar.
    ///
    /// Polled rather than observed. A global event monitor would do it, but that is
    /// precisely the mechanism Apple has told developers not to rely on for status items
    /// — and this is the daily path, the half of Cornice that is meant to keep working.
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
            return
        }

        let pointer = NSEvent.mouseLocation
        let menuBarBottom = screen.frame.maxY - (screen.frame.maxY - screen.visibleFrame.maxY)
        let inMenuBar = pointer.y >= menuBarBottom

        if inMenuBar {
            leftMenuBarAt = nil
            return
        }
        guard let since = leftMenuBarAt else {
            leftMenuBarAt = Date()
            return
        }
        if Date().timeIntervalSince(since) >= preferences.autoCollapseDelay {
            leftMenuBarAt = nil
            separator.setHiding(true)
        }
    }

    /// Right-click opens this; left-click toggles. Kept to two items because an agent
    /// with no Dock icon still needs a way to reach its settings and to quit.
    private func installMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Cornice", action: #selector(quit), keyEquivalent: "q")
            .target = self
        separator?.contextMenu = menu
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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

    private func start() async {
        guard AccessibilityPermission.isGranted else {
            log.info("Accessibility missing, prompting")
            AccessibilityPermission.request()
            AccessibilityPermission.openSettings()
            if await AccessibilityPermission.waitUntilGranted() {
                log.info("Accessibility granted")
                dumpMenuBar(reason: "granted")
            } else {
                log.error("Accessibility not granted within timeout")
            }
            return
        }

        dumpMenuBar(reason: "launch")

        // Development only: run the stage check unattended so its result does not depend
        // on someone clicking at the right moment. Goes away with the settings UI.
        if ProcessInfo.processInfo.environment["CORNICE_RUN_TEST"] != nil {
            try? await Task.sleep(for: .seconds(2))
            await runHideCheck()
        }
        if ProcessInfo.processInfo.environment["CORNICE_RUN_DRAGTEST"] != nil {
            try? await Task.sleep(for: .seconds(2))
            await runIsolatedDragCheck()
        }
        if ProcessInfo.processInfo.environment["CORNICE_RUN_HIDEONLY"] != nil {
            // Long enough for the spacer to have been pulled alongside the control.
            try? await Task.sleep(for: .seconds(10))
            await runHideOnlyCheck()
        }
    }

    /// The smallest possible question: does a drag still move anything at all?
    ///
    /// Stage 3 proved it did. Stage 4 changed several things at once — the separator
    /// gained an explicit width and alignment, the enumerator started discarding
    /// zero-sized frames, and this class became `@MainActor` — and moves stopped
    /// landing. This bisects all of that away: no separator, no destination arithmetic,
    /// just an item and 100 points to the left.
    private func runIsolatedDragCheck() async {
        var report = "isolated drag check\n\n"
        let before = enumerator.enumerateItems()

        guard let target = before.first(where: {
            $0.ownerBundleID == Self.testSubjects[0] && $0.frame != nil
        }) ?? before.first(where: {
            $0.frame != nil
                && !$0.ownerBundleID.hasPrefix("com.apple")
                && $0.ownerBundleID != Bundle.main.bundleIdentifier
        }), let frame = target.frame else {
            writeCheckReport(report + "no movable item on screen\n")
            return
        }

        report += "target: \(target.id) at x=\(Int(frame.minX)) y=\(Int(frame.midY))\n"
        report += "dragging 100pt left, to x=\(Int(frame.midX - 100))\n\n"

        // Before anything else: does warping the pointer actually work? Every synthetic
        // gesture is built on it, so if this is a no-op nothing above it can succeed.
        let cursorStart = CGEvent(source: nil)?.location
        CGWarpMouseCursorPosition(CGPoint(x: frame.midX, y: frame.midY))
        try? await Task.sleep(for: .milliseconds(120))
        let cursorWarped = CGEvent(source: nil)?.location
        report += "cursor before warp: \(cursorStart.map { "(\(Int($0.x)), \(Int($0.y)))" } ?? "?")\n"
        report += "cursor after warp:  \(cursorWarped.map { "(\(Int($0.x)), \(Int($0.y)))" } ?? "?")\n"
        report += "warp target:        (\(Int(frame.midX)), \(Int(frame.midY)))\n"
        report += "left button held:   "
        report += "\(CGEventSource.buttonState(.combinedSessionState, button: .left))\n\n"

        // Sweep the menu bar vertically instead of testing one guess per rebuild.
        //
        // The accessibility frame puts the item's centre at a negative y, which the
        // system clamps to 0 — the very top row of pixels. Whether that row is live is
        // not something to reason about; four attempts across the bar's height answer it
        // outright, and a working value identifies itself by the item moving.
        var current = frame
        let attempts: [(String, CGFloat, CGEventTapLocation)] = [
            ("hid   y=ax", frame.midY, .cghidEventTap),
            ("hid   y=15", 15, .cghidEventTap),
            ("session y=ax", frame.midY, .cgSessionEventTap),
            ("session y=15", 15, .cgSessionEventTap),
        ]
        for (label, candidateY, candidateTap) in attempts {
            var attempt = CommandDragItemMover()
            attempt.yOverride = candidateY
            attempt.tap = candidateTap
            let from = current.midX
            let to = from - 60
            do {
                try await attempt.move(
                    MenuBarItem(ownerBundleID: target.ownerBundleID,
                                ownerName: target.ownerName,
                                index: target.index,
                                title: target.title,
                                frame: current),
                    toX: to)
            } catch {
                report += "\(label): threw \(error)\n"
                continue
            }
            let after = enumerator.enumerateItems().first { $0.id == target.id }
            let newX = after?.frame?.minX
            let moved = newX != current.minX
            report += "\(label): \(Int(from)) → \(Int(to)) "
            report += "landed \(newX.map { String(Int($0)) } ?? "off-screen") "
            report += moved ? "MOVED\n" : "no change\n"
            if moved, let after, let newFrame = after.frame {
                report += "\nDRAG WORKS — \(label)\n"
                writeCheckReport(report)
                return
            }
            if let after, let f = after.frame { current = f }
        }

        report += "\nDRAG DEAD in every configuration tried.\n"
        writeCheckReport(report)
    }

    /// Does widening the separator hide anything?
    ///
    /// Takes the arrangement as it finds it — wherever the user has dragged the chevron
    /// — and only toggles. No moves, so nothing here depends on the broken mechanism.
    /// This is the whole of stage 4 as a question.
    private func runHideOnlyCheck() async {
        guard let separator else { return }
        var report = "hide-only check\n\n"

        separator.setHiding(false)
        try? await Task.sleep(for: .milliseconds(500))
        let boundary = separator.boundaryFrame
        let visible = enumerator.enumerateItems().filter { ($0.frame?.minX ?? -1) >= 0 }
        report += "boundary while revealed: \(boundary.map { "\($0)" } ?? "not laid out")\n"
        report += "geometry revealed: \(separator.geometry)\n"
        report += "on screen before: \(visible.count)\n"
        for item in visible {
            report += "  \(item.id) x=\(Int(item.frame!.minX))\n"
        }

        separator.setHiding(true)
        try? await Task.sleep(for: .milliseconds(800))
        report += "\nboundary while hiding: "
        report += separator.boundaryFrame.map { "\($0)" } ?? "NO WINDOW — item dropped"
        report += "\ngeometry hiding: \(separator.geometry)\n"
        // "Gone" means pushed past the left edge, not absent. A hidden item keeps
        // answering the accessibility query and keeps a frame — with a large negative x,
        // exactly as Bartender's hidden items do. Checking only for presence therefore
        // reports nothing hidden while the screen plainly shows otherwise, which is what
        // it did.
        let afterHide = enumerator.enumerateItems()
        let vanished = visible.filter { subject in
            let x = afterHide.first { $0.id == subject.id }?.frame?.minX
            return x == nil || x! < 0
        }
        report += "\non screen after hiding: \(afterHide.filter { ($0.frame?.minX ?? -1) >= 0 }.count)\n"
        report += "vanished: \(vanished.isEmpty ? "nothing" : vanished.map(\.id).joined(separator: ", "))\n"

        separator.setHiding(false)
        try? await Task.sleep(for: .seconds(3))
        let afterReveal = enumerator.enumerateItems()
        let returned = vanished.filter { subject in
            (afterReveal.first { $0.id == subject.id }?.frame?.minX ?? -1) >= 0
        }
        report += "on screen after revealing: \(afterReveal.filter { ($0.frame?.minX ?? -1) >= 0 }.count)\n"
        report += "came back: \(returned.count) of \(vanished.count)\n\n"

        if vanished.isEmpty {
            report += "NOTHING HIDDEN — either the separator has nothing to its left, "
            report += "or widening does not push items off.\n"
        } else if returned.count == vanished.count {
            report += "HIDING WORKS — \(vanished.count) items left and all came back.\n"
        } else {
            report += "PARTIAL — \(vanished.count) hidden, only \(returned.count) returned.\n"
        }
        writeCheckReport(report)
    }

    // MARK: - Stage 4 check

    /// Arranges a couple of items behind the separator, then hides and reveals them,
    /// checking at each step that they actually left and returned.
    ///
    /// This is the first check that exercises what Cornice is for, and it deliberately
    /// combines the two mechanisms: `ItemMover` puts items in place (needs Accessibility,
    /// expected to break on macOS 27) and `SeparatorController` hides them (needs
    /// nothing, expected to keep working). The second half passing while the first fails
    /// is exactly the degradation ARCHITECTURE.md predicts.
    private func runHideCheck() async {
        var report = "stage 4 check — hide by widening the separator\n\n"

        guard let separator else {
            writeCheckReport(report + "FAILED: no separator\n")
            return
        }

        // Start from a known state: everything visible.
        separator.setHiding(false)
        try? await Task.sleep(for: .milliseconds(400))

        // 1. Move the subjects to the left of the separator, which is where "hidden"
        //    physically means something.
        for bundleID in Self.testSubjects {
            let items = enumerator.enumerateItems()
            guard let separatorFrame = separator.boundaryFrame else {
                report += "separator has no window frame yet\n"
                continue
            }
            guard let target = items.first(where: { $0.ownerBundleID == bundleID }),
                  let targetFrame = target.frame else {
                report += "skipped \(bundleID): not on screen\n"
                continue
            }
            if targetFrame.minX < separatorFrame.minX {
                report += "already behind: \(target.id) at x=\(Int(targetFrame.minX))\n"
                continue
            }
            do {
                let destination = separatorFrame.minX - 20
                report += "  drag \(target.id): "
                report += "from x=\(Int(targetFrame.minX)) (mid \(Int(targetFrame.midX)), "
                report += "y \(Int(targetFrame.midY))) to x=\(Int(destination))\n"
                let landed = try await mover.moveAndVerify(
                    target, toX: destination, using: enumerator)
                let landedX = landed?.frame?.minX
                let ok = (landedX ?? .infinity) < separatorFrame.minX
                report += ok ? "moved behind: " : "MOVE DID NOT LAND: "
                report += "\(target.id) x=\(Int(targetFrame.minX)) → "
                report += "\(landedX.map { String(Int($0)) } ?? "off-screen") "
                report += "(separator was at \(Int(separatorFrame.minX)))\n"
            } catch {
                report += "move failed for \(target.id): \(error)\n"
            }
        }

        let arranged = enumerator.enumerateItems()
        let separatorX = separator.boundaryFrame?.minX ?? 0
        let behind = arranged.filter {
            guard let frame = $0.frame else { return false }
            return $0.ownerBundleID != Bundle.main.bundleIdentifier && frame.minX < separatorX
        }
        report += "\nbehind the separator: \(behind.map(\.id).joined(separator: ", "))\n"

        guard !behind.isEmpty else {
            writeCheckReport(report + "\nINCONCLUSIVE: nothing ended up behind it\n")
            return
        }

        // 2. Hide, and confirm they left the screen.
        separator.setHiding(true)
        try? await Task.sleep(for: .milliseconds(600))
        let hidden = enumerator.enumerateItems()
        let stillVisible = behind.filter { subject in
            (hidden.first { $0.id == subject.id }?.frame?.minX ?? -.infinity) > 0
        }
        report += "\nafter hiding — still on screen: "
        report += stillVisible.isEmpty ? "none\n" : "\(stillVisible.map(\.id))\n"

        // 3. Reveal, and confirm they came back.
        separator.setHiding(false)
        try? await Task.sleep(for: .milliseconds(600))
        let revealed = enumerator.enumerateItems()
        let missing = behind.filter { subject in
            (revealed.first { $0.id == subject.id }?.frame?.minX ?? -1) <= 0
        }
        report += "after revealing — still off screen: "
        report += missing.isEmpty ? "none\n" : "\(missing.map(\.id))\n"

        report += "\n"
        if stillVisible.isEmpty && missing.isEmpty {
            report += "VERDICT: WORKS — items left on hide and returned on reveal.\n"
        } else if stillVisible.isEmpty {
            report += "VERDICT: PARTIAL — hiding works, revealing does not.\n"
        } else {
            report += "VERDICT: BROKEN — widening the separator did not push items off.\n"
        }

        report += "\n--- menu bar, revealed (raw AX frames) ---\n"
        for item in revealed {
            report += "\(item.id)  [\(item.ownerName)]  "
            report += item.frame.map {
                "x=\(Int($0.minX)) y=\(Int($0.minY)) w=\(Int($0.width)) h=\(Int($0.height))"
            } ?? "off-screen"
            report += "\n"
        }
        if let screen = NSScreen.main {
            report += "\nNSScreen.main.frame: \(screen.frame)\n"
            report += "visibleFrame: \(screen.visibleFrame)\n"
        }
        writeCheckReport(report)
    }

    private func writeCheckReport(_ text: String) {
        log.info("\(text, privacy: .public)")
        Self.writeReport(text, named: "check.txt")
    }

    // MARK: - Diagnostics

    /// Stage 4 has no settings window yet, so the enumerated menu bar is written both to
    /// the unified log and to a plain text file.
    ///
    /// The file is redundant on a normal machine, but `log show` is not always reachable
    /// — it returns nothing at all under some restricted shells — and a scan that cannot
    /// be read is a scan that cannot be checked. Removed once the settings UI exists.
    private func dumpMenuBar(reason: String) {
        let items = enumerator.enumerateItems()
        log.info("--- menu bar (\(reason, privacy: .public)): \(items.count, privacy: .public) items ---")

        var report = "scan: \(reason)  at \(Date().formatted(date: .omitted, time: .standard))\n"
        report += "bundle: \(Bundle.main.bundlePath)\n"
        report += "accessibility: \(AccessibilityPermission.isGranted)\n"
        report += "items: \(items.count)\n\n"

        if let screen = NSScreen.main {
            report += "NSScreen.frame:   \(screen.frame)\n"
            report += "NSScreen.visible: \(screen.visibleFrame)\n"
            report += "NSScreen.backingScaleFactor: \(screen.backingScaleFactor)\n"
        }
        report += "CGDisplayBounds:  \(CGDisplayBounds(CGMainDisplayID()))\n"
        report += "CGDisplay pixels: \(CGDisplayPixelsWide(CGMainDisplayID()))"
        report += "x\(CGDisplayPixelsHigh(CGMainDisplayID()))\n"
        report += "NSScreen count: \(NSScreen.screens.count)\n"
        for (n, s) in NSScreen.screens.enumerated() {
            report += "  screen \(n): \(s.frame)\n"
        }
        report += "NSStatusBar thickness: \(NSStatusBar.system.thickness)\n"
        report += "spacer  (boundary): \(separator?.boundaryFrame.map { "\($0)" } ?? "none")\n"
        report += "control (chevron): \("(same item)")\n"
        report += "hiding: \(separator?.isHiding.description ?? "?")\n\n"

        for item in items {
            let position = item.frame.map {
                String(format: "x=%.0f y=%.0f w=%.0f h=%.0f",
                       $0.minX, $0.minY, $0.width, $0.height)
            } ?? "off-screen"
            let line = "\(item.id)  [\(item.ownerName)]  \(item.title ?? "-")  \(position)"
            log.info("\(line, privacy: .public)")
            report += line + "\n"
        }

        Self.writeReport(report, named: "menubar-scan.txt")
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
