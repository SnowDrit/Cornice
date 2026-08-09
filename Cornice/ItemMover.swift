//
//  ItemMover.swift
//  Cornice
//

import AppKit
import CoreGraphics
import OSLog

/// Moves another application's status item along the menu bar.
///
/// **This is the fragile part of Cornice.** Everything undocumented lives here and
/// nowhere else, so that when it stops working exactly one file has to change.
/// Nothing above this protocol may know how a move is performed.
///
/// It is also the *rare* path: repositioning happens when the user changes the
/// configuration, never during ordinary use. Collapsing and revealing go through
/// `SeparatorController`, which needs no permission and no synthetic events at all.
///
/// Known expiry: on macOS 27 a drag in the menu bar is claimed by Mission Control, and
/// Apple has published no replacement. See ARCHITECTURE.md.
protocol ItemMover {
    /// Drags `item` so that it comes to rest around `destinationX` (screen coordinates,
    /// origin top-left, matching what the accessibility API reports).
    func move(_ item: MenuBarItem, toX destinationX: CGFloat) async throws
}

extension ItemMover {
    /// Moves `item` and reports where it actually ended up.
    ///
    /// A drag can be posted successfully and still not move anything — the gesture may
    /// be swallowed, or the drop may land back where it started. Callers that care
    /// whether the arrangement changed must not infer it from the absence of a thrown
    /// error; twice during development a check reported success for a move that never
    /// happened. This does the re-read for them.
    @discardableResult
    func moveAndVerify(
        _ item: MenuBarItem,
        toX destinationX: CGFloat,
        using enumerator: ItemEnumerator
    ) async throws -> MenuBarItem? {
        try await move(item, toX: destinationX)
        let landed = enumerator.enumerateItems().first { $0.id == item.id }
        log.info("""
            \(item.id, privacy: .public) requested x=\(Int(destinationX), privacy: .public), \
            landed at \(landed?.frame.map { String(Int($0.minX)) } ?? "off-screen", privacy: .public)
            """)
        return landed
    }
}

enum MoveError: Error, CustomStringConvertible {
    case notTrusted
    case itemOffScreen
    case noEventSource

    var description: String {
        switch self {
        case .notTrusted:    "Accessibility permission is required to move items"
        case .itemOffScreen: "item has no on-screen frame, so there is nothing to grab"
        case .noEventSource: "could not create a CGEventSource"
        }
    }
}

/// Reproduces what a user does by hand: hold ⌘ and drag the item.
///
/// There is no API for this. The menu bar only rearranges in response to a ⌘-drag, so the
/// only way to move an item programmatically is to synthesise that gesture — press at the
/// item, drag across, release. Because the events are addressed by screen position rather
/// than by window, this needs no Screen Recording permission, only Accessibility.
struct CommandDragItemMover: ItemMover {

    /// A single jump from press to release is often not recognised as a drag; the
    /// intermediate points are what make the system treat it as one.
    ///
    /// The count has to follow the distance rather than being fixed. With a constant
    /// number of steps a longer drag simply moves faster, and past some speed the menu
    /// bar stops following it — a short swap between neighbours would succeed while a
    /// drag across a few items did nothing at all, with no error either way. Roughly one
    /// step every few points keeps the pointer speed constant however far it travels.
    private let pointsPerStep: CGFloat = 4
    private let minimumSteps = 12
    private let stepDelay = Duration.milliseconds(10)

    /// Vertical centre of the menu bar, in the top-left origin space `CGEvent` uses.
    ///
    /// `NSScreen` measures from the bottom, so the menu bar's height is what is left
    /// over above `visibleFrame`. Falls back to a plausible value rather than refusing
    /// to work if there is somehow no main screen.
    @MainActor
    private static var menuBarCentreY: CGFloat {
        guard let screen = NSScreen.main else { return 12 }
        let height = screen.frame.maxY - screen.visibleFrame.maxY
        return height > 0 ? height / 2 : 12
    }

    /// Overrides the vertical position of the synthesised gesture. Diagnostics only.
    var yOverride: CGFloat?

    /// Where synthesised events are injected.
    ///
    /// `.cghidEventTap` enters the stream as though from the hardware, ahead of every
    /// tap in the session; `.cgSessionEventTap` enters at the session level instead.
    /// Consumers do not all read from the same point, so which one works is a question
    /// about the consumer, not about the events.
    var tap: CGEventTapLocation = .cghidEventTap

    func move(_ item: MenuBarItem, toX destinationX: CGFloat) async throws {
        guard AccessibilityPermission.isGranted else { throw MoveError.notTrusted }
        guard let frame = item.frame, frame.width > 0 else { throw MoveError.itemOffScreen }
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw MoveError.noEventSource
        }

        // Both coordinates come from the accessibility frame, including the vertical one
        // — even though it looks wrong.
        //
        // Menu bar extras report a centre line around y = -47 on a display that AppKit
        // describes as (0, 0, 1440, 900), so the obvious correction is to substitute the
        // menu bar's own geometry, y = 15. That was tried, and it does not work: the
        // drag is ignored. The accessibility value does work. `CGEvent` evidently reads
        // the same space the accessibility API reports in, and it is not AppKit's.
        //
        // Whatever the offset is, it is consistent, and both sides of this transaction
        // agree with each other. Do not "fix" this without a failing case to point at.
        let y = yOverride ?? frame.midY
        let start = CGPoint(x: frame.midX, y: y)
        let end = CGPoint(x: destinationX, y: y)
        let cursorBefore = CGEvent(source: nil)?.location

        log.info("""
            CG display bounds \(String(describing: CGDisplayBounds(CGMainDisplayID())), privacy: .public), \
            dragging at y=\(Int(frame.midY), privacy: .public)
            """)

        log.info("""
            moving \(item.id, privacy: .public) \
            from x=\(start.x, privacy: .public) to x=\(end.x, privacy: .public)
            """)

        // Clear any button the system still believes is held.
        //
        // A drag that is interrupted between its press and its release — a hang, a
        // crash, a cancelled task — leaves the session thinking the left button is
        // down. Every subsequent synthetic drag is then ignored, silently and
        // permanently, until something releases it. That is not a hypothetical: it is
        // how this stopped working.
        if CGEventSource.buttonState(.combinedSessionState, button: .left) {
            log.error("left button was stuck down; releasing before dragging")
            post(.leftMouseUp, at: CGEvent(source: nil)?.location ?? start, source: source)
            try? await Task.sleep(for: .milliseconds(80))
        }

        // The cursor has to be where the press happens; the menu bar tracks the pointer,
        // not just the event stream.
        CGWarpMouseCursorPosition(start)

        // Actually hold ⌘, rather than only flagging the mouse events.
        //
        // Tagging each mouse event with `.maskCommand` describes the modifier without
        // setting it: the session's global modifier state stays clear, so anything that
        // consults it — as the menu bar's rearrange gesture appears to — sees no ⌘ at
        // all. A real key event is the difference between the drag being honoured and
        // being silently ignored, which is exactly how a working drag stopped working.
        setCommandKey(down: true, source: source)
        try? await Task.sleep(for: .milliseconds(40))
        defer { setCommandKey(down: false, source: source) }

        let steps = max(minimumSteps, Int(abs(end.x - start.x) / pointsPerStep))
        log.info("dragging in \(steps, privacy: .public) steps")

        post(.leftMouseDown, at: start, source: source)
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let point = CGPoint(x: start.x + (end.x - start.x) * t, y: start.y)
            CGWarpMouseCursorPosition(point)
            post(.leftMouseDragged, at: point, source: source)
            try? await Task.sleep(for: stepDelay)
        }
        post(.leftMouseUp, at: end, source: source)

        // Warping leaves the pointer dissociated from the physical mouse until this is
        // called; skipping it makes the cursor appear frozen.
        if let cursorBefore { CGWarpMouseCursorPosition(cursorBefore) }
        CGAssociateMouseAndMouseCursorPosition(1)

        // Let the menu bar settle before anyone re-reads positions.
        try? await Task.sleep(for: .milliseconds(250))
    }

    /// Virtual key code for the left Command key.
    private static let commandKeyCode: CGKeyCode = 0x37

    private func setCommandKey(down: Bool, source: CGEventSource) {
        guard let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: Self.commandKeyCode,
            keyDown: down)
        else {
            log.error("could not create ⌘ key event")
            return
        }
        event.flags = down ? .maskCommand : []
        event.post(tap: tap)
    }

    private func post(_ type: CGEventType, at point: CGPoint, source: CGEventSource) {
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: .left)
        else {
            log.error("could not create \(String(describing: type), privacy: .public)")
            return
        }
        // ⌘ is what distinguishes "rearrange the menu bar" from "click this item".
        event.flags = .maskCommand
        event.post(tap: tap)
    }
}
