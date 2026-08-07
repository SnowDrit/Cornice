//
//  AppDelegate.swift
//  Cornice
//

import AppKit
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate {

    /// Held for the lifetime of the app. Releasing this removes the status item
    /// from the menu bar, so it must not be a local variable.
    private var separator: SeparatorController?

    private let enumerator: ItemEnumerator = AXItemEnumerator()
    private let mover: ItemMover = CommandDragItemMover()

    /// Bundle id the stage 3 spike tries to move. Any third-party item will do; this one
    /// is simply always present on the machine being developed against.
    private static let spikeTargetBundleID = "ru.keepcoder.Telegram"

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("Cornice launched, build \(Bundle.main.shortVersion, privacy: .public)")

        separator = SeparatorController(onClick: { [weak self] in
            Task { await self?.runMoveSpike() }
        })

        Task { await requestAccessibilityIfNeeded() }
    }

    /// Cornice has no windows to reopen, so clicking the app in Finder while it is
    /// already running should do nothing rather than resurrect an empty window.
    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        false
    }

    // MARK: - Stage 2

    private func requestAccessibilityIfNeeded() async {
        // Written unconditionally, so that "no report" always means "the app did not
        // start", never "the app started but took a branch I did not expect".
        dumpMenuBar(reason: "launch")

        if AccessibilityPermission.isGranted {
            log.info("Accessibility already granted")
            // Stage 3 only: run the spike unattended so its verdict does not depend on
            // someone clicking at the right moment. Removed once the answer is recorded.
            if ProcessInfo.processInfo.environment["CORNICE_RUN_SPIKE"] != nil {
                try? await Task.sleep(for: .seconds(2))
                await runMoveSpike()
            }
            return
        }

        log.info("Accessibility missing, prompting")
        AccessibilityPermission.request()
        AccessibilityPermission.openSettings()

        if await AccessibilityPermission.waitUntilGranted() {
            log.info("Accessibility granted")
            dumpMenuBar(reason: "granted")
        } else {
            log.error("Accessibility not granted within timeout")
        }
    }

    // MARK: - Stage 3 spike

    /// Answers the only question stage 3 exists to answer: can Cornice move somebody
    /// else's status item on this version of macOS?
    ///
    /// Measures the target's position, drags it to the far side of Cornice's own
    /// separator, measures again, and records the verdict. A move that does not change
    /// the ordering means the named-item design is not viable and the fallback is
    /// positional hiding.
    private func runMoveSpike() async {
        let before = enumerator.enumerateItems()

        guard let separatorItem = before.first(where: {
            $0.ownerBundleID == Bundle.main.bundleIdentifier
        }), let separatorFrame = separatorItem.frame else {
            writeSpikeReport("FAILED: Cornice's own item is not on screen")
            return
        }

        let target = before.first { $0.ownerBundleID == Self.spikeTargetBundleID }
            ?? before.first {
                $0.frame != nil
                    && !$0.ownerBundleID.hasPrefix("com.apple")
                    && $0.ownerBundleID != Bundle.main.bundleIdentifier
            }

        guard let target, let targetFrame = target.frame else {
            writeSpikeReport("SKIPPED: no third-party item on screen to move")
            return
        }

        // Always drag to the *opposite* side of the separator from wherever the item
        // currently sits. Dragging towards a position it already occupies proves
        // nothing, and an earlier version of this spike did exactly that and still
        // reported success.
        let startsLeftOfSeparator = targetFrame.minX < separatorFrame.minX
        let destinationX = startsLeftOfSeparator
            ? separatorFrame.maxX + 40
            : separatorFrame.minX - 20

        var report = """
            stage 3 spike — synthetic command-drag
            target:    \(target.id) [\(target.ownerName)]
            before:    target x=\(Int(targetFrame.minX)), separator x=\(Int(separatorFrame.minX))
            drag to:   x=\(Int(destinationX))

            """

        do {
            try await mover.move(target, toX: destinationX)
        } catch {
            writeSpikeReport(report + "\nFAILED: \(error)\n")
            return
        }

        let after = enumerator.enumerateItems()
        let movedTarget = after.first { $0.id == target.id }
        let movedSeparator = after.first { $0.id == separatorItem.id }

        let targetX = movedTarget?.frame?.minX
        let separatorX = movedSeparator?.frame?.minX

        report += """
            after:     target x=\(targetX.map { String(Int($0)) } ?? "off-screen"), \
            separator x=\(separatorX.map { String(Int($0)) } ?? "off-screen")

            """

        // The only question that matters: did *this* drag change the ordering relative
        // to the separator? Absolute positions shift for unrelated reasons, so compare
        // which side of the separator the item sits on, before against after.
        let sideBefore = startsLeftOfSeparator
        let sideAfter = targetX.map { x in (separatorX ?? separatorFrame.minX) > x }

        switch sideAfter {
        case .some(let after) where after != sideBefore:
            report += "VERDICT: MOVED — crossed the separator "
            report += "(\(sideBefore ? "left→right" : "right→left")). Named hiding is viable.\n"
        case .some:
            let drift = (targetX ?? targetFrame.minX) - targetFrame.minX
            report += "VERDICT: NOT MOVED — same side of the separator, "
            report += "drift \(Int(drift))px.\n"
        case .none:
            report += "VERDICT: UNKNOWN — target is no longer on screen.\n"
        }

        report += "\n--- menu bar after ---\n"
        for item in after {
            let position = item.frame.map { "x=\(Int($0.minX))" } ?? "off-screen"
            report += "\(item.id)  [\(item.ownerName)]  \(position)\n"
        }
        writeSpikeReport(report)
    }

    private func writeSpikeReport(_ text: String) {
        log.info("\(text, privacy: .public)")
        Self.writeReport(text, named: "spike.txt")
    }

    /// Stage 2 has no settings window yet, so the enumerated menu bar is written both to
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

        for item in items {
            let position = item.frame.map { String(format: "x=%.0f w=%.0f", $0.minX, $0.width) }
                ?? "off-screen"
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
            log.error("could not write scan report: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}
