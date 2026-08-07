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
    private let dragSteps = 14
    private let stepDelay = Duration.milliseconds(8)

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
        let start = CGPoint(x: frame.midX, y: frame.midY)
        let end = CGPoint(x: destinationX, y: frame.midY)
        let cursorBefore = CGEvent(source: nil)?.location

        log.info("""
            CG display bounds \(String(describing: CGDisplayBounds(CGMainDisplayID())), privacy: .public), \
            dragging at y=\(Int(frame.midY), privacy: .public)
            """)

        log.info("""
            moving \(item.id, privacy: .public) \
            from x=\(start.x, privacy: .public) to x=\(end.x, privacy: .public)
            """)

        // The cursor has to be where the press happens; the menu bar tracks the pointer,
        // not just the event stream.
        CGWarpMouseCursorPosition(start)

        post(.leftMouseDown, at: start, source: source)
        for step in 1...dragSteps {
            let t = CGFloat(step) / CGFloat(dragSteps)
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
        event.post(tap: .cghidEventTap)
    }
}
