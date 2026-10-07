//
//  MacOS27MenuBarSnapshot.swift
//  Cornice
//

import AppKit
import ApplicationServices

/// Reads only status-item accessibility trees. It never opens menus, requests
/// permission, or examines application windows.
@MainActor
enum MacOS27MenuBarSnapshot {
    struct Record: Sendable {
        let ownerBundleID: String
        let identifier: String?
        /// Accessibility coordinates: origin at the top-left of the primary screen.
        let frame: CGRect
        let title: String?
        let description: String?
    }

    private struct Application: Sendable {
        let pid: pid_t
        let bundleID: String
    }

    /// A missing permission, nonresponsive process, or unlaid-out item contributes
    /// no records. Callers must retain previous classification for missing items.
    static func capture() async -> [Record] {
        guard AXIsProcessTrusted() else { return [] }
        var seen = Set<pid_t>()
        // Explicit lookup also covers the agent if Workspace omits it from its
        // ordinary application list on a later system build.
        let running = NSWorkspace.shared.runningApplications
            + NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent")
        let applications = running.compactMap { app -> Application? in
            guard let bundleID = app.bundleIdentifier,
                  seen.insert(app.processIdentifier).inserted else { return nil }
            return Application(pid: app.processIdentifier, bundleID: bundleID)
        }
        return await withTaskGroup(of: [Record].self, returning: [Record].self) { group in
            for application in applications {
                group.addTask { Self.scan(application) }
            }
            var records: [Record] = []
            for await result in group { records.append(contentsOf: result) }
            return records.sorted {
                if $0.frame.minX != $1.frame.minX { return $0.frame.minX < $1.frame.minX }
                return $0.ownerBundleID < $1.ownerBundleID
            }
        }
    }

    /// Native raw values on 26A428 (MIT source):
    /// https://raw.githubusercontent.com/happy666End/MenuBarHider/main/MenuBarHider/Services/SystemItems.swift
    /// AX identifier strings verified in the same build's executable at
    /// /System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter.
    /// In particular, native "volume" uses "sound", and "screenMirroring"
    /// uses "screen-mirroring"; legacy menu-extra names are not aliases here.
    nonisolated static func systemItemIdentifier(for accessibilityIdentifier: String?) -> Int? {
        switch accessibilityIdentifier {
        case "com.apple.menuextra.battery": return 0
        case "com.apple.menuextra.bluetooth": return 1
        case "com.apple.menuextra.clock": return 2
        case "com.apple.menuextra.display": return 3
        case "com.apple.menuextra.keyboard-brightness": return 4
        case "com.apple.menuextra.sound": return 5
        case "com.apple.menuextra.wifi": return 6
        case "com.apple.menuextra.screen-mirroring": return 7
        case "com.apple.menuextra.controlcenter": return 8
        default: return nil
        }
    }

    /// These extras were observed to disappear under an assertion even with
    /// every system identifier and their owning bundle allowed on 26A428.
    /// An unknown extra must not be assumed to have the same behavior.
    nonisolated static func isImplicitlyHiddenSystemItem(_ accessibilityIdentifier: String?) -> Bool {
        switch accessibilityIdentifier {
        case "com.apple.menuextra.airdrop", "com.apple.menuextra.user",
             "com.apple.menuextra.audiovideo": return true
        default: return false
        }
    }

    nonisolated private static func scan(_ app: Application) -> [Record] {
        guard !Task.isCancelled else { return [] }
        let application = AXUIElementCreateApplication(app.pid)
        AXUIElementSetMessagingTimeout(application, 0.08)
        var extrasValue: CFTypeRef?
        let extrasError = AXUIElementCopyAttributeValue(application, "AXExtrasMenuBar" as CFString,
                                                        &extrasValue)
        let extras: AXUIElement?
        if extrasError == .success, let extrasValue, CFGetTypeID(extrasValue) == AXUIElementGetTypeID() {
            extras = (extrasValue as! AXUIElement)
        } else {
            extras = nil
        }
        let isMenuBarAgent = app.bundleID == "com.apple.MenuBarAgent"
        // Only the renderer gets an application-root fallback. Ordinary apps
        // must have AXExtrasMenuBar, otherwise their application menus/windows
        // would be mistaken for status items.
        guard extras != nil || (isMenuBarAgent && extrasError != .cannotComplete) else { return [] }
        let deadline = ContinuousClock.now.advanced(by: .milliseconds(500))
        var stopped = false
        var visited = 0
        var records: [Record] = []

        func canRead() -> Bool {
            !stopped && !Task.isCancelled && visited < 128 && ContinuousClock.now < deadline
        }

        func children(_ element: AXUIElement) -> [AXUIElement] {
            guard canRead() else { return [] }
            AXUIElementSetMessagingTimeout(element, 0.08)
            var value: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
            if error == .cannotComplete { stopped = true }
            guard error == .success else { return [] }
            return value as? [AXUIElement] ?? []
        }

        func visit(_ element: AXUIElement, depth: Int, systemIdentifiersOnly: Bool = false) {
            guard depth <= 3, canRead() else { return }
            visited += 1
            AXUIElementSetMessagingTimeout(element, 0.08)
            let attributes = [kAXRoleAttribute, kAXIdentifierAttribute, kAXPositionAttribute,
                              kAXSizeAttribute, kAXTitleAttribute, kAXDescriptionAttribute] as CFArray
            var values: CFArray?
            let error = AXUIElementCopyMultipleAttributeValues(element, attributes, [], &values)
            if error == .cannotComplete { stopped = true }
            guard error == .success, let values, CFArrayGetCount(values) == 6 else { return }
            let fields = values as [AnyObject]
            let role = fields[0] as? String
            let identifier = fields[1] as? String
            let isSystemItem = identifier?.hasPrefix("com.apple.menuextra.") == true
            let isItem = isSystemItem || (!systemIdentifiersOnly && role == kAXMenuBarItemRole)
            if isItem {
                guard let frame = frame(position: fields[2], size: fields[3]) else { return }
                records.append(Record(ownerBundleID: app.bundleID, identifier: identifier, frame: frame,
                                      title: fields[4] as? String, description: fields[5] as? String))
                return
            }
            // MenuBarAgent wraps system items in hosting groups, unlike ordinary
            // app extras. Bounded traversal covers both without reading submenus.
            guard role != kAXMenuRole, role != kAXMenuBarItemRole, depth < 3 else { return }
            for child in children(element) {
                visit(child, depth: depth + 1, systemIdentifiersOnly: systemIdentifiersOnly)
            }
        }

        if let extras {
            for child in children(extras) { visit(child, depth: 1) }
        }
        if isMenuBarAgent && records.isEmpty && canRead() {
            // Some macOS 27 builds expose the renderer's hosting groups only
            // through AXChildren. This reads no AXWindows or application menu.
            for child in children(application) { visit(child, depth: 1, systemIdentifiersOnly: true) }
        }
        return records
    }

    nonisolated private static func frame(position: AnyObject, size: AnyObject) -> CGRect? {
        guard CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else {
            return nil
        }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &dimensions),
              point.x.isFinite, point.y.isFinite, dimensions.width.isFinite, dimensions.height.isFinite,
              dimensions.width > 0, dimensions.height > 0 else { return nil }
        return CGRect(origin: point, size: dimensions)
    }
}
