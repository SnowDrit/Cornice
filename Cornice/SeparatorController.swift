//
//  SeparatorController.swift
//  Cornice
//

import AppKit
import OSLog

/// Owns Cornice's own status items and hides others by taking up their space.
///
/// This is the one part of Cornice that needs **no permissions at all**: an application
/// may create and resize its own `NSStatusItem` freely. There is no call that hides
/// somebody else's item; what there is, is an item wide enough to leave them nowhere
/// to sit.
///
/// Two items, not one:
///
///     [ hidden items ][ spacer — grows ][ control ‹ ][ visible items ]
///
/// The spacer does the work, growing until everything to its left is past the edge of
/// the screen. The control carries the chevron and stays narrow, so it remains visible
/// and clickable in both states.
///
/// A single item cannot do both jobs. A status item 10,000 points wide draws its image
/// in the middle of that width — thousands of points off-screen — so the chevron simply
/// vanishes the first time it is clicked, taking the only way back with it. `alignment`
/// does not rescue it; that governs text, not the image.
///
/// Because it depends on nothing undocumented, this is also the part expected to survive
/// future macOS releases untouched. Keep it that way: no `CGEvent`, no `AXUIElement`,
/// no window IDs here. See ARCHITECTURE.md.
@MainActor
final class SeparatorController: NSObject {

    /// Wide enough to push a full menu bar off any display Cornice supports, and no
    /// wider — the value ends up in the item's frame, and absurd numbers make the
    /// diagnostics harder to read. Bartender uses ~5000 for the same reason.
    private static let expandedWidth: CGFloat = 10_000

    /// Not zero: an item with no width can be dropped from the layout altogether, and
    /// then there is no boundary to hide things behind.
    private static let collapsedWidth: CGFloat = 1

    private static let controlWidth: CGFloat = 28

    private let spacer: NSStatusItem
    private let control: NSStatusItem
    private let onToggle: (Bool) -> Void

    /// `true` when items to the left of the spacer are pushed off-screen.
    ///
    /// Starts `false` deliberately. A fresh install has no configuration, and coming up
    /// already hiding would make Cornice's first act be to remove menu bar items the
    /// user never asked it to touch. Stage 5 restores the saved state instead.
    private(set) var isHiding = false

    init(onToggle: @escaping (Bool) -> Void = { _ in }) {
        self.onToggle = onToggle

        // Created control-first so the spacer is inserted to its left, which is the
        // side the hidden items live on.
        control = NSStatusBar.system.statusItem(withLength: Self.controlWidth)
        spacer = NSStatusBar.system.statusItem(withLength: Self.collapsedWidth)
        super.init()

        control.autosaveName = "CorniceControl"
        spacer.autosaveName = "CorniceSpacer"

        // The spacer is scenery: no image, and nothing to click.
        spacer.button?.isEnabled = false

        guard let button = control.button else {
            log.error("status item has no button; menu bar may be full")
            return
        }
        button.target = self
        button.action = #selector(buttonClicked)

        apply()
        log.info("separator installed")
    }

    /// Where the boundary between hidden and visible currently sits, in screen
    /// coordinates, or `nil` before the items have been laid out.
    ///
    /// Read from the item's own window rather than through the accessibility API. Asking
    /// AX about an element in one's *own* process returns coordinates in a different
    /// space from the ones it reports for other applications — this separator described
    /// itself as `x=7 y=888` while genuinely sitting near x=935. Cornice owns this item;
    /// there is no reason to ask anybody where it is.
    var boundaryFrame: CGRect? {
        guard let frame = spacer.button?.window?.frame, frame.width > 0 else { return nil }
        return frame
    }

    /// Where the clickable chevron sits. Kept separate from `boundaryFrame` because the
    /// two diverge by 10,000 points the moment anything is hidden.
    var controlFrame: CGRect? {
        control.button?.window?.frame
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

    private func apply() {
        spacer.length = isHiding ? Self.expandedWidth : Self.collapsedWidth

        // Points towards where the hidden items are: left when they are off-screen and a
        // click would bring them back, right when they are visible and a click puts them
        // away again.
        let symbol = isHiding ? "chevron.left" : "chevron.right"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Cornice")
        image?.isTemplate = true   // adopts the menu bar's light/dark appearance
        control.button?.image = image
    }

    @objc private func buttonClicked() {
        toggle()
    }
}
