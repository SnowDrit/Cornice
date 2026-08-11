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
    private let pinches = PinchRecognizer()
    private var tap: GestureEventTap?

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

    /// A run of swipes on one window that are refining a single position.
    private struct Chain {
        let key: WindowKey
        let slot: WindowSlot
        let at: ContinuousClock.Instant
    }

    private var chain: Chain?

    /// How long a chain stays open.
    ///
    /// Long enough to swipe twice without hurrying, short enough that going back to a
    /// window minutes later starts from scratch rather than continuing something the user
    /// has forgotten about. Also what makes a lone downward swipe mean undo: past this,
    /// there is no chain for it to belong to.
    private static let chainWindow: Duration = .milliseconds(1500)

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

        // Separate mechanism, separate reason: the monitor above is handed scroll events
        // but never gesture ones, so pinches need a tap of their own. Listen only, so it
        // cannot take an event away from whatever was going to receive it.
        let tap = GestureEventTap { [weak self] event in
            self?.handlePinch(event)
        }
        tap.start()
        self.tap = tap
    }

    /// Puts everything down. Each piece is released on its own terms, with no early
    /// return: an event tap that outlived the monitor because of some ordering mistake
    /// would be exactly the leftover that hurts the whole machine rather than this app.
    private func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
            gestureLog.info("gesture monitor removed")
        }
        tap?.stop()
        tap = nil
        pending = nil
        chain = nil
        previousFrames.removeAll()
    }

    /// Called when Cornice is quitting, whatever the preference says. A tap still
    /// registered at exit is the case macOS 26 handles badly: the entry outlives the
    /// process and WindowServer can end up spinning on it.
    func shutdown() {
        stop()
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

    /// Pinching in puts the window in the Dock.
    ///
    /// Minimising rather than closing, and that is deliberate: a window in the Dock comes
    /// back with one click and loses nothing, while a window closed on a gesture read
    /// wrong can take unsaved work with it.
    private func handlePinch(_ event: NSEvent) {
        switch pinches.consume(event) {
        case .began:
            pending = TargetWindow.underPointer()
        case .ongoing, .ignored:
            break
        case .ended(let direction):
            defer { pending = nil }
            guard let window = pending, direction == .close else { return }
            chain = nil
            window.minimize()
        }
    }

    private func apply(_ direction: SwipeRecognizer.Direction, to window: TargetWindow) {
        let key = WindowKey(window.element)
        let running = openChain(for: key)

        guard let slot = WindowSlot.next(after: running, swipe: direction) else {
            // No chain and a downward swipe: the one gesture that means undo.
            chain = nil
            guard let restored = previousFrames.removeValue(forKey: key) else {
                gestureLog.info("nothing remembered for this window, leaving it where it is")
                return
            }
            window.setFrame(restored)
            return
        }

        guard let area = ScreenGeometry.workArea(forWindowAt: window.frame) else {
            gestureLog.info("no display found for this window")
            return
        }

        // Only the frame from before the *first* move is worth keeping. Snapping left and
        // then right and then swiping down should restore the window the user last placed
        // by hand, not the left half it passed through on the way.
        if previousFrames[key] == nil {
            remember(window.frame, for: key)
        }

        window.setFrame(slot.frame(in: area))
        chain = Chain(key: key, slot: slot, at: ContinuousClock.now)
    }

    /// The slot this window is being refined towards, or `nil` to start over.
    ///
    /// Tied to the window as well as to the clock. Swiping one window and then another
    /// within the second and a half is two separate intentions, and continuing the first
    /// window's chain on the second would put it somewhere nobody asked for.
    private func openChain(for key: WindowKey) -> WindowSlot? {
        guard let chain, chain.key == key else { return nil }
        guard ContinuousClock.now - chain.at <= Self.chainWindow else { return nil }
        return chain.slot
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
