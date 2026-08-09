//
//  SeparatorController.swift
//  Cornice
//

import AppKit
import OSLog

/// Owns Cornice's status item and hides others by taking up their space.
///
/// This is the one part of Cornice that needs **no permissions at all**: an application
/// may create and resize its own `NSStatusItem` freely. There is no call that hides
/// somebody else's item; what there is, is an item wide enough to leave them nowhere
/// to sit. Everything to its left goes past the edge of the screen.
///
/// One item, not two. A spacer separate from the chevron seems tidier and is worse:
/// the boundary is then invisible, so the person who has to decide where the boundary
/// goes cannot see or drag it, and moving the chevron moves nothing that matters.
/// Whatever the user drags must *be* the boundary.
///
/// The reason to split it was that a very wide status item draws its image in the middle
/// of that width, thousands of points off-screen, so clicking the chevron made the
/// chevron vanish. That is solved here instead by padding the image: the picture is as
/// wide as the item, with the glyph at its trailing edge, so centring it puts the glyph
/// exactly where it belongs.
///
/// Because it depends on nothing undocumented, this is also the part expected to survive
/// future macOS releases untouched. Keep it that way: no `CGEvent`, no `AXUIElement`,
/// no window IDs here. See ARCHITECTURE.md.
@MainActor
final class SeparatorController: NSObject {

    /// Just the chevron.
    private static let collapsedWidth: CGFloat = 28

    private let item: NSStatusItem
    private let onToggle: (Bool) -> Void

    /// `true` when items to the left of the separator are pushed off-screen.
    ///
    /// Starts `false` deliberately. A fresh install has no configuration, and coming up
    /// already hiding would make Cornice's first act be to remove menu bar items the
    /// user never asked it to touch. Stage 5 restores the saved state instead.
    private(set) var isHiding = false

    init(onToggle: @escaping (Bool) -> Void = { _ in }) {
        self.onToggle = onToggle
        item = NSStatusBar.system.statusItem(withLength: Self.collapsedWidth)
        super.init()

        // macOS persists where the user ⌘-drags this item, under the key
        // "NSStatusItem Preferred Position CorniceSeparator" in our own defaults.
        item.autosaveName = "CorniceSeparator"

        guard let button = item.button else {
            log.error("status item has no button; menu bar may be full")
            return
        }
        button.target = self
        button.action = #selector(buttonClicked)

        apply()
        log.info("separator installed")
    }

    /// Where the boundary between hidden and visible sits, in screen coordinates, or
    /// `nil` before the item has been laid out.
    ///
    /// Read from the item's own window rather than through the accessibility API. Asking
    /// AX about an element in one's *own* process returns coordinates in a different
    /// space from the ones it reports for other applications — this item described
    /// itself as `x=7 y=888` while genuinely sitting near x=935. Cornice owns it; there
    /// is no reason to ask anybody where it is.
    var boundaryFrame: CGRect? {
        guard let frame = item.button?.window?.frame, frame.width > 0 else { return nil }
        return frame
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

    /// Wide enough to push a full menu bar off the widest attached display, and no wider.
    ///
    /// A round 10,000 was the first guess and it is needlessly large: the image has to
    /// match this width, and a 10,000 point wide bitmap costs several megabytes to draw
    /// for no benefit. Anything past the screen is already off it.
    private var expandedWidth: CGFloat {
        let widest = NSScreen.screens.map(\.frame.width).max() ?? 2000
        return widest + 200
    }

    private func apply() {
        let width = isHiding ? expandedWidth : Self.collapsedWidth
        item.length = width

        // Points towards where the hidden items are: left when they are off-screen and a
        // click would bring them back, right when they are visible and a click puts them
        // away again.
        let symbol = isHiding ? "chevron.left" : "chevron.right"
        item.button?.image = Self.trailingAligned(symbol: symbol, width: width)
    }

    /// A template image `width` points wide with the symbol drawn at its trailing edge.
    private static func trailingAligned(symbol: String, width: CGFloat) -> NSImage? {
        guard let glyph = NSImage(
            systemSymbolName: symbol, accessibilityDescription: "Cornice") else { return nil }

        // No padding needed while collapsed; skip the drawing entirely.
        guard width > glyph.size.width else {
            glyph.isTemplate = true
            return glyph
        }

        let canvas = NSImage(size: NSSize(width: width, height: glyph.size.height))
        canvas.lockFocus()
        glyph.draw(
            at: NSPoint(x: width - glyph.size.width, y: 0),
            from: .zero,
            operation: .sourceOver,
            fraction: 1)
        canvas.unlockFocus()
        canvas.isTemplate = true   // adopts the menu bar's light/dark appearance
        return canvas
    }

    @objc private func buttonClicked() {
        toggle()
    }
}
