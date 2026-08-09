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

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("Cornice launched, build \(Bundle.main.shortVersion, privacy: .public)")

        separator = SeparatorController()

        Task { await start() }
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

        report += "main thread at call site: \(Thread.isMainThread)\n\n"

        // Run the drag off the main thread. Stage 3 drove it from a background task and
        // it worked; this class later became `@MainActor`, and the only other change to
        // the mover was diagnostics. Detaching is the one difference left to test.
        let mover = self.mover
        do {
            try await Task.detached(priority: .userInitiated) {
                try await mover.move(target, toX: frame.midX - 100)
            }.value
        } catch {
            writeCheckReport(report + "threw: \(error)\n")
            return
        }

        let after = enumerator.enumerateItems().first { $0.id == target.id }
        let newX = after?.frame?.minX
        report += "after: x=\(newX.map { String(Int($0)) } ?? "off-screen")\n"
        report += (newX != frame.minX)
            ? "\nDRAG WORKS — position changed.\n"
            : "\nDRAG DEAD — position unchanged.\n"
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
            report += "screen: \(screen.frame)  visible: \(screen.visibleFrame)\n"
        }
        report += "separator (own window frame): "
        report += separator?.boundaryFrame.map { "\($0)" } ?? "none"
        report += "\n\n"

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
