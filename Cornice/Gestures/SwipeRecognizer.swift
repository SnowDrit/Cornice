//
//  SwipeRecognizer.swift
//  Cornice
//

import AppKit
import OSLog

/// Turns a stream of scroll events into at most one swipe.
///
/// A two finger swipe on a trackpad arrives as ordinary scroll events, distinguished from
/// a mouse wheel by carrying precise deltas and a phase. The phase is what makes a gesture
/// recognisable at all: it marks where the fingers touched down and where they lifted, so
/// the travel between those two points is one gesture rather than an arbitrary window over
/// a continuous stream.
///
/// Stateful, and therefore not thread safe. Only ever driven from the main thread by
/// `GestureController`.
final class SwipeRecognizer {

    enum Direction {
        case left, right, up, down
    }

    enum Step {
        /// Fingers down. The moment to decide which window this gesture is about, before
        /// the pointer has any chance to drift off the title bar.
        case began
        case ongoing
        /// Fingers up. `nil` when the travel was too short or too diagonal to call.
        case ended(Direction?)
        case ignored
    }

    /// How far the fingers must travel before this counts as a swipe rather than a nudge.
    ///
    /// Low enough to feel like a flick, high enough that brushing the trackpad while
    /// reaching for a key does nothing.
    private static let minimumTravel: CGFloat = 40

    /// How far one axis must beat the other.
    ///
    /// Nobody swipes exactly along an axis. Requiring a clear winner is what keeps a
    /// sloppy leftward swipe from registering as upward, and refusing to guess on a true
    /// diagonal is better than picking one of the two at random.
    private static let dominance: CGFloat = 1.5

    private var travel = CGVector.zero
    private var active = false

    func consume(_ event: NSEvent) -> Step {
        // A real mouse wheel has no precise deltas and no phase. Neither should ever move
        // a window: the gesture is a trackpad gesture, and a wheel over a title bar is
        // somebody scrolling something else.
        guard event.hasPreciseScrollingDeltas else { return .ignored }

        // Momentum is the coasting that continues after the fingers have left the glass.
        // Counting it would double the measured travel and, worse, keep a gesture alive
        // long after it visibly ended.
        guard event.momentumPhase.isEmpty else { return .ignored }

        if event.phase.contains(.began) {
            travel = .zero
            active = true
            return .began
        }

        if event.phase.contains(.changed) {
            guard active else { return .ignored }
            travel.dx += fingerDX(event)
            travel.dy += fingerDY(event)
            return .ongoing
        }

        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            guard active else { return .ignored }
            active = false
            let direction = event.phase.contains(.cancelled) ? nil : decide()
            gestureLog.info("""
                swipe ended, travel \(self.travel.dx, format: .fixed(precision: 1)) \
                \(self.travel.dy, format: .fixed(precision: 1)), \
                inverted \(event.isDirectionInvertedFromDevice, privacy: .public), \
                read as \(String(describing: direction), privacy: .public)
                """)
            travel = .zero
            return .ended(direction)
        }

        return .ignored
    }

    private func decide() -> Direction? {
        let horizontal = abs(travel.dx)
        let vertical = abs(travel.dy)

        if horizontal >= Self.minimumTravel, horizontal >= vertical * Self.dominance {
            return travel.dx > 0 ? .right : .left
        }
        if vertical >= Self.minimumTravel, vertical >= horizontal * Self.dominance {
            return travel.dy > 0 ? .up : .down
        }
        return nil
    }

    // MARK: - Which way the fingers actually went
    //
    // Scroll deltas describe how the *content* should move, not how the fingers did, and
    // the relationship between the two flips with the "Natural scrolling" setting.
    // `isDirectionInvertedFromDevice` reports that setting per event, which is the only
    // reading that stays correct when the user changes it while Cornice is running.
    //
    // The two axes are normalised separately because AppKit's sign conventions for them
    // are not mirror images of each other. The log line above prints the raw travel and
    // the direction it was read as, so one swipe each way confirms or corrects this.

    /// Positive means the fingers moved right.
    private func fingerDX(_ event: NSEvent) -> CGFloat {
        event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
    }

    /// Positive means the fingers moved up.
    private func fingerDY(_ event: NSEvent) -> CGFloat {
        event.isDirectionInvertedFromDevice ? -event.scrollingDeltaY : event.scrollingDeltaY
    }
}
