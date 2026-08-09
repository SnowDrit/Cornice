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
/// Two items, each with exactly one job:
///
///     [ hidden items ][ spacer — grows ][ ❯ control ][ visible items ]
///
/// The control is **never** resized. It stays 28 points wide, so its chevron draws like
/// any other status icon, and it is the thing the user drags to choose where the
/// boundary goes. The spacer does the widening and shows nothing, so having no visible
/// content is not a defect.
///
/// One item cannot do both. Six attempts were made to keep a chevron visible on an item
/// that widens — centring the image, padding it to the item's width, disabling image
/// scaling, a right-aligned title, a paragraph style, and finally a hand-positioned
/// subview — and the last of these measured correct while still drawing nothing:
///
///     length=1218  buttonBounds=1218  window=1234  chevronX=1190
///
/// A glyph 28 points from the trailing edge of a 1218 point button lands on screen. It
/// was not drawn, which points at macOS declining to render an item too wide for the
/// bar at all: laid out for spacing, skipped for display. Nothing about the drawing code
/// was going to change that.
///
/// Because it depends on nothing undocumented, this is also the part expected to survive
/// future macOS releases untouched. Keep it that way: no `CGEvent`, no `AXUIElement`,
/// no window IDs here. See ARCHITECTURE.md.
@MainActor
final class SeparatorController: NSObject {

    private static let controlWidth: CGFloat = 28

    /// Not zero: an item with no width can be dropped from the layout altogether, and
    /// then there is no boundary to hide things behind.
    private static let spacerCollapsedWidth: CGFloat = 1

    private let control: NSStatusItem
    private let spacer: NSStatusItem
    private let onToggle: (Bool) -> Void
    private var followTimer: Timer?

    /// `true` when items to the left of the spacer are pushed off-screen.
    ///
    /// Starts `false` deliberately. A fresh install has no configuration, and coming up
    /// already hiding would make Cornice's first act be to remove menu bar items the
    /// user never asked it to touch. Stage 5 restores the saved state instead.
    private(set) var isHiding = false

    init(onToggle: @escaping (Bool) -> Void = { _ in }) {
        self.onToggle = onToggle

        control = NSStatusBar.system.statusItem(withLength: Self.controlWidth)
        spacer = NSStatusBar.system.statusItem(withLength: Self.spacerCollapsedWidth)
        super.init()

        control.autosaveName = "CorniceControl"
        spacer.autosaveName = "CorniceSpacer"
        spacer.button?.isEnabled = false

        guard let button = control.button else {
            log.error("status item has no button; menu bar may be full")
            return
        }
        button.target = self
        button.action = #selector(buttonClicked)

        apply()
        alignSpacerToControl()

        // The user moves the control; the spacer has to come along, or the boundary ends
        // up somewhere they did not put it. There is no notification for a status item
        // being dragged, so its position is sampled instead. Once a second is far below
        // the rate at which anyone drags something, and costs nothing measurable.
        followTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.alignSpacerToControl() }
        }

        log.info("separator installed")
    }

    deinit {
        followTimer?.invalidate()
    }

    /// Where the boundary between hidden and visible sits, in screen coordinates, or
    /// `nil` before the items have been laid out.
    ///
    /// Read from the item's own window rather than through the accessibility API. Asking
    /// AX about an element in one's *own* process returns coordinates in a different
    /// space from the ones it reports for other applications — this item described
    /// itself as `x=7 y=888` while genuinely sitting near x=935. Cornice owns it; there
    /// is no reason to ask anybody where it is.
    var boundaryFrame: CGRect? {
        guard let frame = spacer.button?.window?.frame, frame.width > 0 else { return nil }
        return frame
    }

    var controlFrame: CGRect? {
        control.button?.window?.frame
    }

    var geometry: String {
        "control=\(controlFrame.map { "\(Int($0.minX))" } ?? "?") "
            + "spacer=\(boundaryFrame.map { "\(Int($0.minX))..\(Int($0.maxX))" } ?? "?") "
            + "spacerLength=\(spacer.length)"
    }

    // MARK: - State

    func toggle() {
        setHiding(!isHiding)
    }

    func setHiding(_ hiding: Bool) {
        guard hiding != isHiding else { return }
        isHiding = hiding
        apply()
        log.info("separator now \(hiding ? "hiding" : "revealing", privacy: .public)")
        onToggle(hiding)
    }

    /// Just wide enough to push everything left of the spacer off the screen.
    ///
    /// Asking for more than fits is not free: the menu bar's item area ends where the
    /// application menus begin, and an item too wide to be placed there stops being
    /// drawn. Everything to the left of the spacer lies between the application menus
    /// and the spacer's own left edge, so that distance plus a margin is all that is
    /// ever needed.
    private var spacerExpandedWidth: CGFloat {
        guard let left = boundaryFrame?.minX, left > 0 else { return Self.spacerCollapsedWidth }
        return left + 40
    }

    private func apply() {
        spacer.length = isHiding ? spacerExpandedWidth : Self.spacerCollapsedWidth

        // Points towards where the hidden items are: left when they are off-screen and a
        // click would bring them back, right when they are visible and a click puts them
        // away again. The control never changes width, so this draws like any icon.
        let symbol = isHiding ? "chevron.left" : "chevron.right"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Cornice")
        image?.isTemplate = true   // adopts the menu bar's light/dark appearance
        control.button?.image = image
    }

    /// Keeps the spacer immediately to the left of the control.
    ///
    /// `NSStatusItem` offers no way to say "put this next to that", but macOS stores each
    /// item's placement under `NSStatusItem Preferred Position <autosaveName>` in the
    /// owning application's defaults, measured from the right-hand end of the bar.
    /// Bartender's own saved values read that way: 213, 249, 5297, 10351, 15367, with
    /// the gaps matching the widths of the 5002-point separators sitting between them.
    ///
    /// So the spacer's place is the control's place plus the control's width. Writing
    /// that is only half the job — the value is read when the item is created — so the
    /// spacer is rebuilt whenever it has drifted out of position.
    private func alignSpacerToControl() {
        guard !isHiding,
              let screen = NSScreen.main,
              let controlFrame,
              let spacerFrame = spacer.button?.window?.frame
        else { return }

        // Already adjacent, within a point or two of rounding.
        if abs(spacerFrame.maxX - controlFrame.minX) < 4 { return }

        let desired = screen.frame.maxX - controlFrame.minX
        let key = "NSStatusItem Preferred Position CorniceSpacer"
        UserDefaults.standard.set(desired, forKey: key)
        log.info("""
            re-placing spacer: control at \(Int(controlFrame.minX), privacy: .public), \
            spacer at \(Int(spacerFrame.minX), privacy: .public), \
            writing position \(Int(desired), privacy: .public)
            """)

        // Re-reading the position needs a fresh item; nudging the length is enough to
        // make macOS lay it out again against the value just written.
        spacer.length = Self.spacerCollapsedWidth + 1
        DispatchQueue.main.async { [spacer] in
            spacer.length = Self.spacerCollapsedWidth
        }
    }

    @objc private func buttonClicked() {
        toggle()
    }
}
