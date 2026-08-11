//
//  GestureEventTap.swift
//  Cornice
//

import AppKit
import OSLog

/// Watches trackpad gesture events, which a global `NSEvent` monitor never sees.
///
/// Scroll events reach an ordinary monitor and swipes are built on those. Magnify events do
/// not: with `.magnify` in the monitor's mask and a log written on arrival, a real pinch on
/// a real trackpad produced nothing at all. An event tap is the only way to be handed them.
///
/// Everything here is shaped around not being the reason something else breaks.
///
/// **Listen only.** `.listenOnly` means the tap is physically incapable of modifying or
/// swallowing an event, so a pinch Cornice reads wrong still reaches the application under
/// the pointer exactly as it would have. This is the single most important line in the
/// file, and it is why a tap is acceptable here at all.
///
/// **Gestures only.** The mask covers gesture events and nothing else. Swipes keep using
/// the monitor that already works. A tap that never sees a keystroke or a click cannot
/// leak one.
///
/// **Re-armed when the system switches it off.** macOS disables a tap whose callback was
/// too slow, and says so by delivering `tapDisabledByTimeout`. Left alone the feature would
/// quietly stop working until the next relaunch.
///
/// **Taken down cleanly, always.** macOS 26 changed how a tap left behind at exit is
/// handled: a tap that is not disabled, unhooked from the run loop and invalidated can
/// leave an entry that sends WindowServer into a spin, which is a way to hurt the whole
/// machine rather than just this app. `stop()` does all three in order and is called both
/// when the module switches off and when Cornice quits.
@MainActor
final class GestureEventTap {

    /// `NSEventType.gesture` is 29 and `.magnify` is 30. Neither has a `CGEventType` case,
    /// because CoreGraphics never named the gesture types, but the tap masks them by the
    /// same numbers the AppKit types use. Both are needed: 29 is the raw stream that
    /// arrives every eight milliseconds, 30 is the one carrying the phases a pinch is
    /// recognised from.
    private static let mask: CGEventMask = (1 << 29) | (1 << 30)

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    /// Called on the main thread for every gesture event, already converted.
    private let onEvent: (NSEvent) -> Void

    init(onEvent: @escaping (NSEvent) -> Void) {
        self.onEvent = onEvent
    }

    var isRunning: Bool { tap != nil }

    func start() {
        guard tap == nil else { return }

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }

            // The run loop source is on the main run loop, so this is the main thread.
            // Checked rather than asserted: `assumeIsolated` traps when it is wrong, and a
            // trap inside an event tap callback is the worst place in the app to have one.
            guard Thread.isMainThread else { return Unmanaged.passUnretained(event) }

            let owner = Unmanaged<GestureEventTap>.fromOpaque(userInfo).takeUnretainedValue()
            MainActor.assumeIsolated { owner.receive(type: type, event: event) }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: Self.mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque())
        else {
            // Almost always a missing Accessibility grant. Nothing to do about it here and
            // nothing worth interrupting the user over: the pinch simply is not available.
            gestureLog.error("could not create the gesture event tap, pinches unavailable")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.source = source
        gestureLog.info("gesture event tap installed, listen only")
    }

    /// Disable, unhook, invalidate. In that order, and never partially.
    ///
    /// The order matters: disabling first stops events arriving while the source is being
    /// removed, and invalidating last makes sure nothing is still pointing at a mach port
    /// that has gone away.
    func stop() {
        guard let tap else { return }

        CGEvent.tapEnable(tap: tap, enable: false)
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CFMachPortInvalidate(tap)

        self.source = nil
        self.tap = nil
        gestureLog.info("gesture event tap removed")
    }

    private func receive(type: CGEventType, event: CGEvent) {
        // The two ways macOS says it has switched the tap off. Timeout means the callback
        // took too long and is worth re-arming; user input means something else took over
        // and is worth re-arming too, since by the time this arrives it is already over.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            let reason = type == .tapDisabledByTimeout ? "timeout" : "user input"
            gestureLog.error("tap disabled by \(reason, privacy: .public), re-arming")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }

        guard let converted = NSEvent(cgEvent: event) else { return }
        onEvent(converted)
    }
}
