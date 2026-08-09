//
//  SeparatorController.swift
//  Cornice
//

import AppKit
import OSLog

/// Owns Cornice's status items and hides others by taking up their space.
///
/// This is the one part of Cornice that needs **no permissions at all**: an application
/// may create and resize its own `NSStatusItem` freely. There is no call that hides
/// somebody else's item; what there is, is an item wide enough to leave them nowhere
/// to sit. Everything to its left goes past the edge of the screen.
///
/// Two items, and — this is the point — **they are unrelated in space**:
///
///     [ hidden items ][ │ boundary — grows ][ visible items ][ ❯ toggle ]
///
/// The boundary is where the user dragged it, and nothing ever moves it. The toggle is
/// wherever the user dragged *it*, usually over by the clock. A click on the toggle
/// widens the boundary until everything to its left is off the screen.
///
/// Earlier versions insisted the two sit side by side, so that one glyph could look like
/// the boundary and be pressed. That requirement caused every failure in this file's
/// history: a status item cannot be placed next to another one on demand. Its saved
/// position is consulted when it is created and never again, the value written and the
/// position produced are not the same scale, feeding the error back diverges, and a
/// divider computed into place lands tens of points away — close enough to look right
/// and far enough that whatever sits in the gap never hides. Dropping the requirement
/// deletes all of it.
///
/// One item cannot do both jobs either. Six attempts were made to keep a chevron visible
/// on an item that widens, the last measuring correct while still drawing nothing —
/// `length=1218 buttonBounds=1218 chevronX=1190`, a glyph well inside the screen. macOS
/// appears not to render an item too wide for the bar at all: laid out for spacing,
/// skipped for display. Which is fine for a boundary that has nothing to say.
///
/// Because it depends on nothing undocumented, this is also the part expected to survive
/// future macOS releases untouched. Keep it that way: no `CGEvent`, no `AXUIElement`,
/// no window IDs here. See ARCHITECTURE.md.
@MainActor
final class SeparatorController: NSObject {

    private static let toggleWidth: CGFloat = 28
    private static let boundaryWidth: CGFloat = 10

    /// Widens to swallow everything on its left. Never moved by Cornice.
    private let boundary: NSStatusItem

    /// The chevron. Never resized, so it draws like any other status icon.
    private let toggle: NSStatusItem

    private let onToggle: (Bool) -> Void

    /// Where the toggle starts out on a first run, measured from the right-hand end of
    /// the bar. Zero asks for the rightmost slot macOS will give a third-party item.
    /// After that it is the user's to move, like any other status icon.
    private static let togglePosition = 0.0
    private static let togglePositionKey = "NSStatusItem Preferred Position CorniceToggle"

    private(set) var isHiding = false

    /// Shown on right-click. An agent with no Dock icon has no other way to reach its
    /// settings or to quit.
    var contextMenu: NSMenu?

    init(onToggle: @escaping (Bool) -> Void = { _ in }) {
        self.onToggle = onToggle

        // Put the toggle back at the right-hand end on every launch.
        //
        // Only here, and only before the item exists. Doing it while running means
        // destroying and recreating a status item from a timer, against a position macOS
        // is writing to at the same time — that was tried twice and lost the chevron
        // outright both times. Written once at startup it is just the value the item is
        // created with, which is the one moment the system reads it.
        //
        // So the toggle can be dragged anywhere during a session and comes back on the
        // next launch. Its position carries no meaning either way: the boundary stands
        // on its own, and where the switch sits changes nothing.
        UserDefaults.standard.set(Self.togglePosition, forKey: Self.togglePositionKey)
        toggle = NSStatusBar.system.statusItem(withLength: Self.toggleWidth)
        boundary = NSStatusBar.system.statusItem(withLength: Self.boundaryWidth)
        super.init()

        toggle.autosaveName = "CorniceToggle"
        boundary.autosaveName = "CorniceBoundary"

        // Nothing to press: the boundary is a landmark, not a control.
        boundary.button?.isEnabled = false
        boundary.button?.image = Self.boundaryImage()

        guard let button = toggle.button else {
            log.error("status item has no button; menu bar may be full")
            return
        }
        button.target = self
        button.action = #selector(buttonClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        updateIcon()

        log.info("separator installed")
    }

    /// Where the boundary sits, in screen coordinates, or `nil` before layout.
    ///
    /// Read from the item's own window rather than through the accessibility API. Asking
    /// AX about an element in one's *own* process returns coordinates in a different
    /// space from the ones it reports for other applications — this item described
    /// itself as `x=7 y=888` while genuinely sitting near x=935.
    var boundaryFrame: CGRect? {
        guard let frame = boundary.button?.window?.frame, frame.width > 0 else { return nil }
        return frame
    }

    var controlFrame: CGRect? {
        toggle.button?.window?.frame
    }

    var geometry: String {
        let toggleX: String = controlFrame.map { String(Int($0.minX)) } ?? "?"
        var span = "?"
        if let frame = boundaryFrame { span = "\(Int(frame.minX))..\(Int(frame.maxX))" }
        return "toggle=\(toggleX) boundary=\(span) boundaryLength=\(Int(boundary.length))"
    }

    // MARK: - State

    func toggleHiding() {
        setHiding(!isHiding)
    }

    func setHiding(_ hiding: Bool) {
        guard hiding != isHiding else { return }
        isHiding = hiding
        apply()
        log.info("separator now \(hiding ? "hiding" : "revealing", privacy: .public)")
        onToggle(hiding)
    }

    private func apply() {
        if isHiding, let right = boundaryFrame?.maxX, right > 0 {
            // Enough to carry its own right edge past the left of the screen, which is
            // exactly what it takes to sweep everything on that side away. Asking for
            // more is not free: an item too wide for the bar stops being drawn, and
            // while that does not matter for a boundary, an absurd width makes the
            // frames unreadable when something goes wrong.
            boundary.length = right + 40
        } else {
            boundary.length = Self.boundaryWidth
        }
        updateIcon()
    }

    private func updateIcon() {
        // Points towards where the hidden items are: left when they are off-screen and a
        // click would bring them back, right when they are visible and a click puts them
        // away again.
        let symbol = isHiding ? "chevron.left" : "chevron.right"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Cornice")
        image?.isTemplate = true   // adopts the menu bar's light/dark appearance
        toggle.button?.image = image
    }

    /// A thin vertical bar, drawn rather than taken from SF Symbols so its weight does
    /// not change with the system's symbol styling.
    private static func boundaryImage() -> NSImage {
        let size = NSSize(width: boundaryWidth, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.setFill()
        NSBezierPath(
            roundedRect: NSRect(x: size.width / 2 - 0.75, y: 0, width: 1.5, height: size.height),
            xRadius: 0.75, yRadius: 0.75).fill()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    @objc private func buttonClicked() {
        // Right-click opens the menu, left-click toggles. Attaching the menu to the item
        // permanently would swallow the left click too, which is the one that matters.
        //
        // Shown directly rather than by assigning `menu` and calling `performClick`:
        // that re-enters this same handler, and the menu never appeared.
        if NSApp.currentEvent?.type == .rightMouseUp, let contextMenu, let button = toggle.button {
            contextMenu.popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: button.bounds.minY - 4),
                in: button)
            return
        }
        toggleHiding()
    }
}
