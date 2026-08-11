//
//  PinchRecognizer.swift
//  Cornice
//

import AppKit
import OSLog

/// Turns a stream of magnify events into at most one pinch.
///
/// Same shape as `SwipeRecognizer` and separate from it on purpose: a pinch arrives as a
/// different event type carrying a scale rather than a distance, and folding both into one
/// class would mean a state machine that is really two state machines sharing a variable.
///
/// Stateful, and therefore not thread safe. Only ever driven from the main thread by
/// `GestureController`.
final class PinchRecognizer {

    enum Direction {
        /// Fingers together.
        case close
        /// Fingers apart.
        case open
    }

    enum Step {
        case began
        case ongoing
        case ended(Direction?)
        case ignored
    }

    /// How much the fingers have to change the scale before this counts.
    ///
    /// `magnification` accumulates roughly as a fraction of the starting distance, so this
    /// is about a sixth. Small enough to be an easy movement, large enough that resting two
    /// fingers on the glass and drifting does nothing.
    private static let threshold: CGFloat = 0.16

    private var total: CGFloat = 0
    private var active = false

    func consume(_ event: NSEvent) -> Step {
        guard event.type == .magnify else { return .ignored }

        if event.phase.contains(.began) {
            total = 0
            active = true
            return .began
        }

        if event.phase.contains(.changed) {
            guard active else { return .ignored }
            total += event.magnification
            return .ongoing
        }

        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            guard active else { return .ignored }
            active = false

            var direction: Direction?
            if !event.phase.contains(.cancelled), abs(total) >= Self.threshold {
                direction = total > 0 ? .open : .close
            }
            gestureLog.info("""
                pinch ended, magnification \(self.total, format: .fixed(precision: 3)), \
                read as \(String(describing: direction), privacy: .public)
                """)
            total = 0
            return .ended(direction)
        }

        return .ignored
    }
}
