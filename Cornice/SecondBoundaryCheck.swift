//
//  SecondBoundaryCheck.swift
//  Cornice
//

import AppKit
import OSLog

/// Asks macOS the one question an "always hidden" zone depends on: may two status items
/// belonging to the same process be wider than the menu bar at the same time?
///
/// The zone other managers offer is a second boundary, left of the first, that stays wide
/// for good. The first one widens over the top of it on demand and narrows again, and
/// through all of that the icons behind the second one have to stay gone. Nothing in
/// AppKit says whether that works. `NSStatusItem.length` is documented as a number, not as
/// a request, and the bar under pressure does things no header mentions.
///
/// So the shape is: four identical items, roles handed out by measuring where they landed
/// rather than by asking for positions, then widen the second, widen the first over it,
/// narrow the first, narrow the second, reading the frames at every step.
///
///     [ far ][ second boundary ][ mid ][ main boundary ]
///
/// `far` stands for something in the always hidden zone, `mid` for an ordinary icon that
/// the everyday toggle should hide and show. If `far` stays gone while `mid` comes back,
/// the feature is possible. If it does not, it is not, and that is a result too.
///
/// This is the only check in Cornice that creates status items, because the question is
/// about status items. It runs in its own instance behind `CORNICE_RUN_TWOWIDECHECK` and
/// puts the bar back the way the bar wants: narrow everything, wait, and only then let the
/// items go. Removing a wide item straight away makes macOS rebuild the layout and
/// whatever had been pushed off the edge stays off.
///
/// Nothing here is part of the product. See ARCHITECTURE.md.
@MainActor
enum SecondBoundaryCheck {

    /// Kept well away from `CorniceBoundary` and `CorniceToggle`. macOS stores an item's
    /// position under its autosave name, and the real boundary's position is the user's
    /// configuration: the one thing in this app that must never be written by accident.
    private static let autosaveNames = [
        "CorniceProbeA", "CorniceProbeB", "CorniceProbeC", "CorniceProbeD",
    ]

    private static let restingWidth: CGFloat = 24

    private struct Probe {
        let item: NSStatusItem
        var role = "?"

        var frame: CGRect? {
            guard let frame = item.button?.window?.frame, frame.width > 0 else { return nil }
            return frame
        }
    }

    /// One item at one moment. Taken as a snapshot rather than read again later, because
    /// the whole point is how the numbers differ between steps.
    private struct Reading {
        let role: String
        let asked: Int
        let frame: CGRect?
        let windowVisible: Bool

        /// Pushed off the left edge, or dropped by macOS altogether.
        var gone: Bool {
            guard let frame else { return true }
            return !windowVisible || frame.maxX <= 0
        }

        /// Wide enough that macOS clearly honoured the length rather than clamping it.
        var wide: Bool { (frame?.width ?? 0) > 200 }

        var line: String {
            let name = role.padding(toLength: 8, withPad: " ", startingAt: 0)
            guard let frame else { return "  \(name) asked=\(asked)  no frame" }
            return "  \(name) asked=\(asked)  x=\(Int(frame.minX)) w=\(Int(frame.width))"
                + "  window=\(windowVisible ? "visible" : "hidden")"
                + "  \(gone ? "GONE" : "on screen")"
        }
    }

    static func run() async {
        let saved = savedDomain()
        var report = "two wide status items check\n\n"
        report += "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        if let screen = NSScreen.main {
            report += "main screen \(Int(screen.frame.width))x\(Int(screen.frame.height))"
            report += ", menu bar \(Int(screen.frame.maxY - screen.visibleFrame.maxY)) tall\n"
        }
        report += "\n"

        var probes = autosaveNames.enumerated().map { index, name -> Probe in
            let item = NSStatusBar.system.statusItem(withLength: restingWidth)
            item.autosaveName = name
            let image = NSImage(
                systemSymbolName: "\(index + 1).circle.fill", accessibilityDescription: nil)
            image?.isTemplate = true
            item.button?.image = image
            item.button?.isEnabled = false
            return Probe(item: item)
        }

        // Long enough for the bar to lay out. Everything below reads real frames, and a
        // frame read too early is the kind of wrong number that sends a week sideways.
        try? await Task.sleep(for: .seconds(2))

        guard probes.allSatisfy({ $0.frame != nil }) else {
            report += "not every probe got a frame. The bar is probably full;"
            report += " close some menu bar items and run this again.\n"
            await finish(report, probes, saved)
            return
        }

        // Roles come from where the items actually are. Asking for a position is what this
        // project has burned several attempts on: the value written and the position
        // produced are not the same scale, and the saved position is read once, when the
        // item is created. Reading is reliable, writing is not.
        probes.sort { ($0.frame?.minX ?? 0) < ($1.frame?.minX ?? 0) }
        for (index, role) in ["far", "second", "mid", "main"].enumerated() {
            probes[index].role = role
        }

        func read() -> [Reading] {
            probes.map {
                Reading(
                    role: $0.role,
                    asked: Int($0.item.length),
                    frame: $0.frame,
                    windowVisible: $0.item.button?.window?.isVisible ?? false)
            }
        }

        func record(_ title: String, _ readings: [Reading]) {
            report += "\(title)\n" + readings.map(\.line).joined(separator: "\n") + "\n\n"
        }

        let created = read()
        record("as created", created)

        if created.contains(where: \.gone) {
            report += "a probe was off the edge before anything was widened. Something is\n"
            report += "already hiding the bar, so nothing measured after this would mean\n"
            report += "anything. Reveal the menu bar and run this again.\n"
            await finish(report, probes, saved)
            return
        }

        let second = probes[1].item
        let main = probes[3].item

        // Step one: the second boundary goes wide and stays wide for the rest of the run.
        // Same arithmetic the product uses: carry the item's own right edge past the left
        // of the screen, which is exactly what it takes and no more.
        guard let secondRight = probes[1].frame?.maxX else {
            await finish(report + "lost the second boundary's frame\n", probes, saved)
            return
        }
        second.length = secondRight + 40
        try? await Task.sleep(for: .milliseconds(800))
        let secondWide = read()
        record("second boundary wide", secondWide)

        // Step two: the main boundary widens over the top of it. This is the moment two
        // items of one process are both asking for more room than the bar has.
        guard let mainRight = probes[3].frame?.maxX else {
            await finish(report + "lost the main boundary's frame\n", probes, saved)
            return
        }
        main.length = mainRight + 40
        try? await Task.sleep(for: .milliseconds(800))
        let bothWide = read()
        record("both wide", bothWide)

        // Step three, and the one the feature lives or dies on. The everyday toggle
        // narrows the main boundary, `mid` has to come back, and `far` has to stay gone.
        main.length = restingWidth
        try? await Task.sleep(for: .milliseconds(800))
        let mainNarrow = read()
        record("main narrow, second still wide", mainNarrow)

        // Step four: opening the always hidden zone, which is the second boundary
        // narrowing. Everything comes back.
        second.length = restingWidth
        try? await Task.sleep(for: .milliseconds(800))
        let bothNarrow = read()
        record("both narrow", bothNarrow)

        var results: [(String, Bool)] = []
        results.append(("second boundary widened at all", secondWide[1].wide))
        results.append(("it hid what was left of it", secondWide[0].gone))
        results.append(("it left the rest alone", !secondWide[2].gone && !secondWide[3].gone))
        results.append(("main boundary widened over a wide one", bothWide[3].wide))
        results.append(("main boundary hid the middle", bothWide[2].gone))
        results.append(("no probe was dropped while both were wide", bothWide.allSatisfy { $0.frame != nil }))
        results.append(("second boundary still wide after main narrowed", mainNarrow[1].wide))
        results.append(("the zone stayed hidden after main narrowed", mainNarrow[0].gone))
        results.append(("the middle came back after main narrowed", !mainNarrow[2].gone))
        results.append(("everything came back at the end", bothNarrow.allSatisfy { !$0.gone }))

        report += "results\n"
        for (name, passed) in results {
            report += "  \(passed ? "ok  " : "NO  ")\(name)\n"
        }

        let decisive = results[6].1 && results[7].1 && results[8].1
        report += "\n"
        report += decisive
            ? "TWO WIDE ITEMS WORK. An always hidden zone is possible.\n"
            : "TWO WIDE ITEMS DO NOT WORK. No always hidden zone.\n"
        if results.contains(where: { !$0.1 }) && decisive {
            report += "Some non-decisive checks failed; read the frames above before building on this.\n"
        }

        await finish(report, probes, saved)
    }

    // MARK: - The real thing

    /// Drives the real `SeparatorController` through every state the zone has, and checks
    /// the widths it ends up asking for.
    ///
    /// The check above proves macOS honours two wide items. This one proves Cornice asks
    /// for the right ones at the right times: which divider gets the always hidden job,
    /// that it stays wide while the other one comes and goes, that opening the zone
    /// reveals rather than quietly doing nothing behind a wide divider, and that switching
    /// the whole thing off leaves one narrow divider and no leftovers.
    ///
    /// It does not re-prove the hiding itself. That is the same widening the product has
    /// always done and the first check measured it directly.
    static func runController() async {
        let defaults = UserDefaults.standard
        let saved = savedDomain()

        var report = "always hidden zone, driven through the real controller\n\n"
        var failures: [String] = []

        defaults.set(false, forKey: "alwaysHiddenEnabled")
        defaults.set(false, forKey: "zoneOpen")
        defaults.set(false, forKey: "wasHiding")

        let controller = SeparatorController()
        try? await Task.sleep(for: .seconds(2))

        func step(_ title: String) {
            report += "\(title)\n  \(controller.geometry)\n"
        }

        func expect(_ name: String, _ condition: Bool) {
            report += "  \(condition ? "ok  " : "NO  ")\(name)\n"
            if !condition { failures.append(name) }
        }

        step("one divider, nothing hidden")
        expect("a single divider", controller.geometry.dividers == 1)
        expect("it is narrow", !controller.geometry.mainIsWide)

        Preferences.shared.alwaysHiddenEnabled = true
        try? await Task.sleep(for: .milliseconds(1500))
        step("zone switched on")
        expect("two dividers now", controller.geometry.dividers == 2)
        expect("the zone starts open, so nothing vanishes", controller.isZoneOpen)
        expect("neither divider is wide", !controller.geometry.zoneIsWide)

        // Which one got the always hidden job. Position decides, and nothing else does.
        let zoneAnchor = controller.geometry.zoneAnchor
        let mainAnchor = controller.geometry.mainAnchor
        expect(
            "the leftmost divider is the always hidden one",
            (zoneAnchor ?? 0) < (mainAnchor ?? 0))

        controller.setZoneOpen(false)
        try? await Task.sleep(for: .milliseconds(1200))
        step("zone closed")
        expect("the always hidden divider is wide", controller.geometry.zoneIsWide)
        expect("the main divider is not", !controller.geometry.mainIsWide)

        controller.setHiding(true)
        try? await Task.sleep(for: .milliseconds(1200))
        step("hiding, on top of a closed zone")
        expect("both dividers wide", controller.geometry.mainIsWide && controller.geometry.zoneIsWide)

        controller.setHiding(false)
        try? await Task.sleep(for: .milliseconds(1200))
        step("revealed again")
        expect("the main divider narrowed", !controller.geometry.mainIsWide)
        expect("the always hidden one did not", controller.geometry.zoneIsWide)
        expect("anchors did not drift", controller.geometry.zoneAnchor == zoneAnchor)

        // Opening from hidden has to reveal as well. Narrowing the second divider behind a
        // wide first one changes nothing anyone can see.
        controller.setHiding(true)
        try? await Task.sleep(for: .milliseconds(1200))
        controller.setZoneOpen(true)
        try? await Task.sleep(for: .milliseconds(1200))
        step("zone opened while hiding")
        expect("it revealed too", !controller.isHiding)
        expect("both dividers narrow", !controller.geometry.mainIsWide && !controller.geometry.zoneIsWide)

        // And hiding closes the zone again, or the next reveal shows more than was put there.
        controller.setHiding(true)
        try? await Task.sleep(for: .milliseconds(1200))
        step("hiding closes the zone")
        expect("the zone is shut", !controller.isZoneOpen)
        expect("both dividers wide", controller.geometry.mainIsWide && controller.geometry.zoneIsWide)

        controller.setHiding(false)
        try? await Task.sleep(for: .milliseconds(1200))

        Preferences.shared.alwaysHiddenEnabled = false
        try? await Task.sleep(for: .seconds(2))
        step("zone switched off")
        expect("back to one divider", controller.geometry.dividers == 1)
        expect("and it is narrow", !controller.geometry.mainIsWide)

        report += "\n"
        report += failures.isEmpty
            ? "ALL CHECKS PASSED\n"
            : "FAILED:\n" + failures.map { "  \($0)\n" }.joined()

        // Narrow, settle, and only then let go. The controller's items go with the process.
        controller.setHiding(false)
        controller.setZoneOpen(false)
        try? await Task.sleep(for: .seconds(1))

        restore(saved, report: report, named: "zone-check.txt")
    }

    // MARK: - Leaving nothing behind

    /// Everything in Cornice's own preferences, as it stands right now.
    ///
    /// The whole domain, not a list of keys the check believes it writes. It runs a real
    /// `SeparatorController`, and a status item writes its position under its own name
    /// whenever macOS lays the bar out, so the set of keys that can move is not something
    /// this file gets to decide. The first attempt did keep a list, and it lost the
    /// user's dragged boundary position, which is the one piece of configuration Cornice
    /// has. It also read the list with `object(forKey:)`, which falls through to the
    /// registered defaults, so a key that had never been set came back as the registration
    /// value and got written for real.
    private static func savedDomain() -> [String: Any] {
        let name = Bundle.main.bundleIdentifier ?? "io.github.snowdrit.Cornice"
        return UserDefaults.standard.persistentDomain(forName: name) ?? [:]
    }

    /// Puts the domain back exactly, says what had changed, and stops the process there.
    ///
    /// `exit` rather than `NSApp.terminate`, and this is the last thing either check does.
    /// Terminating properly tears the status items down through AppKit, and AppKit's answer
    /// to an item going away is to forget its saved position: with `terminate` the toggle's
    /// key was gone afterwards, restored domain or not, and on one run the boundary's key
    /// went with it. The preferences have just been written back and flushed, the bar was
    /// narrowed and left to settle a second ago, and there is nothing else left to do.
    private static func restore(
        _ saved: [String: Any], report: String, named filename: String
    ) -> Never {
        let name = Bundle.main.bundleIdentifier ?? "io.github.snowdrit.Cornice"
        let defaults = UserDefaults.standard
        let now = defaults.persistentDomain(forName: name) ?? [:]

        let changed = Set(saved.keys).union(now.keys).filter {
            String(describing: saved[$0]) != String(describing: now[$0])
        }.sorted()

        let full = report + "\n" + (changed.isEmpty
            ? "preferences: nothing moved\n"
            : "preferences put back, these had moved:\n"
                + changed.map { "  \($0)\n" }.joined())

        log.info("\(full, privacy: .public)")
        writeReport(full, named: filename)

        defaults.setPersistentDomain(saved, forName: name)
        defaults.synchronize()
        exit(0)
    }

    private static func finish(
        _ report: String, _ probes: [Probe], _ saved: [String: Any]
    ) async {
        // Narrowing is what restores the bar. Removing a wide item makes macOS rebuild the
        // layout and anything already pushed off the edge stays off, so the width goes
        // first, the bar gets a moment, and the items go after that.
        for probe in probes { probe.item.length = restingWidth }
        try? await Task.sleep(for: .seconds(1))
        for probe in probes { NSStatusBar.system.removeStatusItem(probe.item) }
        try? await Task.sleep(for: .milliseconds(500))

        // macOS writes each item's position under its autosave name as it lays out, and
        // the check's own names have no business outliving it. Putting the whole domain
        // back rather than deleting four keys, for the reason on `savedDomain`.
        restore(saved, report: report, named: "two-wide-check.txt")
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
