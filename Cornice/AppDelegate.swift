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

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("Cornice launched, build \(Bundle.main.shortVersion, privacy: .public)")

        separator = SeparatorController(onClick: { [weak self] in
            self?.dumpMenuBar(reason: "click")
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

        Self.writeReport(report)
    }

    private static func writeReport(_ text: String) {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let directory = base.appendingPathComponent("Cornice", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            try text.write(to: directory.appendingPathComponent("menubar-scan.txt"),
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
