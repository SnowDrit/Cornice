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

        // The title has to sit at the item's trailing edge; centred, it would be
        // hundreds of points off the left of the screen once the item expands.
        button.alignment = .right

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

    /// Just wide enough to push everything left of the separator off the screen.
    ///
    /// Asking for more than fits is not free. The menu bar's item area ends where the
    /// application menus begin, and a status item too wide to be placed there is not
    /// clipped — it is dropped, and macOS parks its window above the top of the screen.
    /// That is what a 10,000 point item did, and then a screen-width one: the chevron
    /// did not move off-screen, it stopped being laid out at all. Three attempts at
    /// fixing the drawing were fixing the wrong thing.
    ///
    /// Everything to the left of the separator lies between the application menus and
    /// the separator's own left edge, so that distance plus a margin is all the width
    /// that is ever needed.
    private var expandedWidth: CGFloat {
        guard let left = item.button?.window?.frame.minX, left > 0 else {
            return Self.collapsedWidth
        }
        return left + Self.collapsedWidth + 40
    }

    private func apply() {
        let width = isHiding ? expandedWidth : Self.collapsedWidth
        item.length = width

        // Drawn as text, not as an image.
        //
        // An image is centred in the button, which at 1600 points wide puts it far off
        // the left of the screen. Padding the image to the item's width did not help,
        // nor did disabling image scaling — the glyph stayed invisible either way. Text
        // obeys `alignment`, so a trailing-aligned title stays at the item's right edge
        // whatever its width. It is also how Bartender's own separators are built: they
        // enumerate with titles like "❮", never images.
        // Alignment for an attributed string comes from its paragraph style, not from
        // the button's `alignment`. Setting only the latter leaves the glyph centred
        // across the item's whole width — which, expanded, puts it around x=577, in the
        // middle of the application menus, where it is invisible against them. That is
        // why the chevron kept "disappearing" while its item was demonstrably laid out.
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right

        let glyph = isHiding ? "❮" : "❯"
        item.button?.image = nil
        item.button?.attributedTitle = NSAttributedString(
            string: glyph,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph,
            ])
    }

    @objc private func buttonClicked() {
        toggle()
    }
}
