//
//  GestureController.swift
//  Cornice
//

import ApplicationServices
import AppKit
import OSLog

/// The gesture module's own log, so its chatter can be read without the menu bar's.
///
///     log stream --predicate 'subsystem == "io.github.snowdrit.Cornice"
///                             and category == "Gestures"' --level info
///
let gestureLog = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "io.github.snowdrit.Cornice",
    category: "Gestures")

/// Trackpad gestures for window management. The whole module hangs off this one switch.
///
/// Off until asked for, and asks for Accessibility only when switched on. That ordering is
/// the point: the menu bar half of Cornice deliberately needs no permission to do its
/// daily job, and a feature nobody enabled must not be the reason a permission dialog
/// appears.
///
/// Nothing in here is allowed to take the app down with it. It runs from a global event
/// monitor, on the main thread, on every scroll event the machine produces, so a mistake
/// here would be a mistake in the middle of the user's typing. Every accessibility call
/// reports failure by returning nothing, every failure means the gesture does nothing, and
/// no value from outside this process is unwrapped by force.
@MainActor
final class GestureController {

    private var monitor: Any?
    private let recognizer = SwipeRecognizer()

    /// The window the fingers came down on, decided at the start of the gesture.
    ///
    /// Captured at touch-down rather than at lift because the pointer can drift off the
    /// title bar during the swipe, and a gesture that starts on a title bar is a gesture
    /// the user aimed there.
    private var pending: TargetWindow?

    /// Where each window was before Cornice moved it, so a downward swipe can undo.
    private var previousFrames: [WindowKey: CGRect] = [:]

    /// Enough for any plausible number of windows in play, and bounded so a long session
    /// cannot grow this without limit. Windows that close leave a stale entry behind;
    /// dropping the oldest is a cheaper cure than watching for their destruction.
    private static let rememberedWindows = 32

    var isRunning: Bool { monitor != nil }

    // MARK: - The switch

    /// Brings the module in line with the preference. Safe to call as often as you like.
    func refresh() {
        Preferences.shared.gesturesEnabled ? start() : stop()
    }

    private func start() {
        guard monitor == nil else { return }
        guard AccessibilityPermission.isGranted else {
            gestureLog.info("gestures enabled but Accessibility missing, not starting")
            return
        }

        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            // Handled synchronously, on this thread, because `began` has to read the
            // pointer position before the pointer moves; hopping to a later turn of the
            // run loop would sample it after the swipe had already carried it away.
            //
            // AppKit delivers monitor callbacks on the main thread, so `assumeIsolated` is
            // the truth here. It is still guarded rather than asserted: `assumeIsolated`
            // traps when it is wrong, and this module is not allowed to be the thing that
            // takes Cornice down.
            guard Thread.isMainThread else {
                gestureLog.error("scroll event arrived off the main thread, ignoring it")
                return
            }
            MainActor.assumeIsolated { self?.handle(event) }
        }
        gestureLog.info("gesture monitor installed")
    }

    private func stop() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
        pending = nil
        previousFrames.removeAll()
        gestureLog.info("gesture monitor removed")
    }

    /// Turns the module on, asking for Accessibility if it is not there yet.
    ///
    /// Separate from `refresh` because this is the one path allowed to put a permission
    /// dialog in front of the user: they just asked for the feature that needs it.
    func enable() async {
        Preferences.shared.gesturesEnabled = true

        if !AccessibilityPermission.isGranted {
            AccessibilityPermission.request()
            AccessibilityPermission.openSettings()
            let granted = await AccessibilityPermission.waitUntilGranted()
            gestureLog.info("Accessibility for gestures granted: \(granted, privacy: .public)")
        }
        refresh()
    }

    func disable() {
        Preferences.shared.gesturesEnabled = false
        refresh()
    }

    // MARK: - Doing the thing

    private func handle(_ event: NSEvent) {
        switch recognizer.consume(event) {
        case .began:
            pending = TargetWindow.underPointer()
        case .ongoing, .ignored:
            break
        case .ended(let direction):
            defer { pending = nil }
            guard let window = pending, let direction else { return }
            apply(direction, to: window)
        }
    }

    private func apply(_ direction: SwipeRecognizer.Direction, to window: TargetWindow) {
        let key = WindowKey(window.element)

        if direction == .down {
            guard let restored = previousFrames.removeValue(forKey: key) else {
                gestureLog.info("nothing remembered for this window, leaving it where it is")
                return
            }
            window.setFrame(restored)
            return
        }

        let slot: WindowSlot
        switch direction {
        case .left:  slot = .leftHalf
        case .right: slot = .rightHalf
        case .up:    slot = .fill
        case .down:  return
        }

        guard let area = ScreenGeometry.workArea(forWindowAt: window.frame) else {
            gestureLog.info("no display found for this window")
            return
        }

        let target = slot.frame(in: area)
        // Only the frame from before the *first* move is worth keeping. Snapping left and
        // then right and then swiping down should restore the window the user last placed
        // by hand, not the left half it passed through on the way.
        if previousFrames[key] == nil {
            remember(window.frame, for: key)
        }
        window.setFrame(target)
    }

    private func remember(_ frame: CGRect, for key: WindowKey) {
        if previousFrames.count >= Self.rememberedWindows {
            previousFrames.removeValue(forKey: previousFrames.keys.first ?? key)
        }
        previousFrames[key] = frame
    }
}

/// A dictionary key for a window.
///
/// `AXUIElement` is a CoreFoundation type, so it carries `CFEqual` and `CFHash` but not
/// Swift's `Hashable`. Two elements fetched at different times for the same window compare
/// equal under `CFEqual`, which is exactly what remembering a frame across two separate
/// gestures needs.
private struct WindowKey: Hashable {

    let element: AXUIElement

    init(_ element: AXUIElement) {
        self.element = element
    }

    static func == (lhs: WindowKey, rhs: WindowKey) -> Bool {
        CFEqual(lhs.element, rhs.element)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(CFHash(element))
    }
}
