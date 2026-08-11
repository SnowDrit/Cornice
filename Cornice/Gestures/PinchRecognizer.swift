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
    /// Measured rather than guessed. Pinches that were meant and landed came in around
    /// 0.17 to 0.37; pinches that were meant and did not land sat at 0.10 to 0.15, and the
    /// only readings below that were single stray events at 0.001. A tenth therefore takes
    /// in every deliberate pinch seen so far and still leaves an order of magnitude before
    /// the noise. The gesture only counts over a title bar in the first place, so there is
    /// very little for a lower threshold to trigger on by accident.
    private static let threshold: CGFloat = 0.10

    private var total: CGFloat = 0
    private var carried = 0
    private var active = false

    func consume(_ event: NSEvent) -> Step {
        guard event.type == .magnify else { return .ignored }

        if event.phase.contains(.began) {
            total = 0
            carried = 0
            active = true
            // The opening event carries a real amount too, small but signed, and throwing
            // it away costs the one reading that says which way this is going.
            note(event)
            return .began
        }

        if event.phase.contains(.changed) {
            guard active else { return .ignored }
            note(event)
            return .ongoing
        }

        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            guard active else { return .ignored }
            active = false

            var direction: Direction?
            // A gesture that carried no amount at any point is not a pinch that was too
            // small, it is a pinch this process was never told the size of. Reading a
            // direction out of it would be inventing one.
            if !event.phase.contains(.cancelled), carried > 0, abs(total) >= Self.threshold {
                direction = total > 0 ? .open : .close
            }
            // Gestures that carried nothing at all are the other family arriving for the
            // same pinch, and there are a lot of them. Logging those would bury the line
            // that actually says what happened.
            if carried > 0 {
                gestureLog.info("""
                    pinch ended, total \(self.total, format: .fixed(precision: 3)) \
                    over \(self.carried, privacy: .public) events, \
                    read as \(String(describing: direction), privacy: .public)
                    """)
            }
            total = 0
            carried = 0
            return .ended(direction)
        }

        return .ignored
    }

    /// Adds an event's amount, and remembers whether there was one.
    ///
    /// macOS sends two different families of magnify event, told apart in the raw fields by
    /// one that reads 8 for the family carrying a real amount and 23 for the family whose
    /// `magnification` is zero in every single event, opening and closing ones included.
    /// Both arrive for the same physical pinch. Summing them together means a pinch lands
    /// on whichever family happened to finish last, which is exactly the "works sometimes"
    /// this started as. Counting only the events that carry an amount settles it without
    /// having to name the undocumented field the families differ in.
    private func note(_ event: NSEvent) {
        let amount = event.magnification
        guard amount != 0 else { return }
        total += amount
        carried += 1
    }
}
