//
//  TargetWindow.swift
//  Cornice
//

import ApplicationServices
import AppKit
import OSLog

/// The window a gesture is about to act on, found by where the pointer is.
///
/// Found through `AXUIElementCopyElementAtPosition` rather than the window list.
/// `CGWindowListCopyWindowInfo` would give bounds and owner directly, but macOS 26
/// restricts it to the caller's own windows unless Screen Recording is granted, and
/// Cornice has no other use for that permission. The same finding is what shaped the menu
/// bar reader, see ItemEnumerator.
///
/// Everything here returns `nil` rather than throwing or trapping. A gesture that cannot
/// find a window is a gesture that does nothing, which is the correct outcome and the only
/// acceptable one: this code runs on a global event monitor, so a crash here takes the
/// menu bar half of Cornice down with it.
struct TargetWindow {

    let element: AXUIElement
    /// Accessibility coordinates, so top left origin.
    let frame: CGRect

    /// How far down from the top edge still counts as the title bar.
    ///
    /// A standard macOS title bar is 28 points. Applications with a unified toolbar draw
    /// a taller bar, and the whole of it is draggable, but the extra height belongs to
    /// toolbar controls that may well handle a scroll themselves. Staying at 28 gives up a
    /// little reach in exchange for never stealing a gesture from something that wanted
    /// it, which is the right trade while nothing is being consumed anyway.
    static let titleBarHeight: CGFloat = 28

    private static let messagingTimeout: Float = 0.25

    /// The window under the pointer, but only when the pointer is on its title bar.
    ///
    /// Returns `nil` for anything Cornice should keep its hands off: its own windows,
    /// windows already in macOS full screen, and anything that is not a plain document or
    /// application window, which rules out sheets, popovers, panels and the desktop.
    static func underPointer() -> TargetWindow? {
        let pointer = ScreenGeometry.toAX(NSEvent.mouseLocation)

        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, messagingTimeout)

        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(
                systemWide, Float(pointer.x), Float(pointer.y), &hit) == .success,
              let hit
        else { return nil }

        guard let window = enclosingWindow(of: hit) else { return nil }

        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success, pid != getpid() else { return nil }

        AXUIElementSetMessagingTimeout(window, messagingTimeout)

        guard copyString(window, attribute: kAXSubroleAttribute) == kAXStandardWindowSubrole
        else { return nil }

        // "AXFullScreen" has no constant in the headers. Absent means not full screen,
        // which is the common case and the one worth proceeding on.
        if copyBool(window, attribute: "AXFullScreen") == true { return nil }

        guard let frame = copyFrame(window) else { return nil }
        guard pointer.y >= frame.minY, pointer.y <= frame.minY + titleBarHeight else {
            return nil
        }

        return TargetWindow(element: window, frame: frame)
    }

    /// Climbs from the element under the pointer to the window containing it.
    ///
    /// The hit element is usually a button or a text field several levels deep. The hop
    /// limit is there because a broken accessibility implementation that makes an element
    /// its own ancestor would otherwise spin forever inside an event handler.
    private static func enclosingWindow(of element: AXUIElement) -> AXUIElement? {
        var current = element
        for _ in 0..<16 {
            if copyString(current, attribute: kAXRoleAttribute) == kAXWindowRole {
                return current
            }
            guard let parent = copyElement(current, attribute: kAXParentAttribute) else {
                return nil
            }
            current = parent
        }
        return nil
    }

    /// Moves and resizes the window, and reports whether it landed.
    ///
    /// Size, then position, then size again. Applications clamp a requested size to their
    /// own minimum, and they clamp it against the display the window is currently on, so a
    /// window being sent to a narrower screen comes back the wrong width if size is only
    /// set once. Setting it again after the move re-runs the clamp in the right place.
    /// Rectangle arrived at the same order for the same reason.
    @discardableResult
    func setFrame(_ wanted: CGRect) -> Bool {
        guard isSettable(kAXPositionAttribute), isSettable(kAXSizeAttribute) else {
            gestureLog.info("window refuses position or size, leaving it alone")
            return false
        }

        var size = wanted.size
        var origin = wanted.origin

        set(kAXSizeAttribute, value: AXValueCreate(.cgSize, &size))
        set(kAXPositionAttribute, value: AXValueCreate(.cgPoint, &origin))
        set(kAXSizeAttribute, value: AXValueCreate(.cgSize, &size))

        return true
    }

    /// Sends the window to the Dock, and reports whether it went.
    ///
    /// No gesture reaches this any more: the pinch that used to has been removed, because
    /// macOS never delivered the events it needed. Kept because the headless check still
    /// exercises it, and because setting this attribute is the documented way to minimise
    /// a window, proven on this machine and worth not having to rediscover.
    @discardableResult
    func minimize() -> Bool {
        guard isSettable(kAXMinimizedAttribute) else {
            gestureLog.info("window cannot be minimised, leaving it alone")
            return false
        }
        let result = AXUIElementSetAttributeValue(
            element, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        if result != .success {
            gestureLog.info("minimising returned \(result.rawValue, privacy: .public)")
            return false
        }
        return true
    }

    private func set(_ attribute: String, value: AXValue?) {
        guard let value else { return }
        let result = AXUIElementSetAttributeValue(element, attribute as CFString, value)
        if result != .success {
            gestureLog.info("""
                setting \(attribute, privacy: .public) returned \
                \(result.rawValue, privacy: .public)
                """)
        }
    }

    private func isSettable(_ attribute: String) -> Bool {
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(
                element, attribute as CFString, &settable) == .success
        else { return false }
        return settable.boolValue
    }

    // MARK: - AX plumbing
    //
    // Same shape as the wrappers in ItemEnumerator. Duplicated rather than shared because
    // the gesture module is meant to be liftable out whole, and four short functions are a
    // smaller price than a dependency between the two halves of the app.

    private static func copyElement(_ element: AXUIElement, attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else { return nil }
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func copyString(_ element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else { return nil }
        return value as? String
    }

    private static func copyBool(_ element: AXUIElement, attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else { return nil }
        return value as? Bool
    }

    private static func copyFrame(_ element: AXUIElement) -> CGRect? {
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
