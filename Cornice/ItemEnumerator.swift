//
//  ItemEnumerator.swift
//  Cornice
//

import ApplicationServices
import AppKit
import OSLog

/// Reads the current contents of the menu bar.
///
/// Behind a protocol because the mechanism is not guaranteed: macOS 26 restricts
/// `CGWindowListCopyWindowInfo` to the caller's own windows unless Screen Recording is
/// granted, which left the accessibility API as the only route that does not demand a
/// permission Cornice has no other use for.
protocol ItemEnumerator {
    func enumerateItems() -> [MenuBarItem]
}

enum EnumerationError: Error {
    case notTrusted
}

/// Reads the menu bar through `AXExtrasMenuBar`.
///
/// Every application that owns status items exposes them as children of its
/// `AXExtrasMenuBar` element. Walking all running applications therefore yields the
/// whole menu bar, including items currently pushed off-screen, which is precisely why
/// this works as a source of truth even after Cornice has hidden things.
struct AXItemEnumerator: ItemEnumerator {

    /// Per-application budget for accessibility calls.
    ///
    /// The default is around six seconds, applied *per unanswered request*. An
    /// application that is busy, paused in a debugger, or simply slow to service its
    /// accessibility connection will therefore stall the whole scan, and a machine with
    /// a few of those turns a scan into tens of seconds. Nothing here is worth waiting
    /// for: an application that cannot answer promptly is treated as having no items.
    private static let messagingTimeout: Float = 0.25

    func enumerateItems() -> [MenuBarItem] {
        guard AccessibilityPermission.isGranted else {
            log.error("enumerate called without Accessibility; returning empty")
            return []
        }

        let started = ContinuousClock.now
        var items: [MenuBarItem] = []

        for app in NSWorkspace.shared.runningApplications {
            // Agents and regular apps can both own status items; only fully background
            // processes without a bundle id are uninteresting.
            guard let bundleID = app.bundleIdentifier else { continue }

            let element = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
            guard let extras = copyElement(element, attribute: "AXExtrasMenuBar") else {
                continue
            }
            guard let children = copyElements(extras, attribute: kAXChildrenAttribute) else {
                continue
            }

            for (index, child) in children.enumerated() {
                // An item macOS itself has hidden: Control Center's own toggles, say:
                // still answers the accessibility query, but reports a zero-sized frame
                // at the origin. It is not laid out anywhere, so treating that as a
                // position invites nonsense: every such item compares as being further
                // left than everything else. `nil` says what is actually true.
                var frame = copyFrame(child)
                if let box = frame, box.width <= 0 || box.height <= 0 { frame = nil }

                items.append(MenuBarItem(
                    ownerBundleID: bundleID,
                    ownerName: app.localizedName ?? bundleID,
                    index: index,
                    title: copyString(child, attribute: kAXTitleAttribute),
                    frame: frame))
            }
        }

        // Right to left on screen; off-screen items (already hidden) sort last.
        items.sort { lhs, rhs in
            switch (lhs.frame?.minX, rhs.frame?.minX) {
            case let (l?, r?): return l > r
            case (nil, _?):    return false
            case (_?, nil):    return true
            case (nil, nil):   return lhs.id < rhs.id
            }
        }

        let elapsed = ContinuousClock.now - started
        log.info("""
            enumerated \(items.count, privacy: .public) menu bar items \
            in \(elapsed.description, privacy: .public)
            """)
        return items
    }

    // MARK: - AX plumbing
    //
    // AXUIElementCopyAttributeValue is a C API returning CFTypeRef through an out
    // parameter. These wrappers keep that shape out of the code above.

    private func copyElement(_ element: AXUIElement, attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else { return nil }
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private func copyElements(_ element: AXUIElement, attribute: String) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else { return nil }
        return value as? [AXUIElement]
    }

    private func copyString(_ element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else { return nil }
        let string = value as? String
        return (string?.isEmpty ?? true) ? nil : string
    }

    /// Position and size arrive as `AXValue` boxes rather than plain types.
    private func copyFrame(_ element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
                element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(
                element, kAXSizeAttribute as CFString, &sizeValue) == .success
        else { return nil }

        var origin = CGPoint.zero
        var size = CGSize.zero
        guard let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID(),
              AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        else { return nil }

        return CGRect(origin: origin, size: size)
    }
}
