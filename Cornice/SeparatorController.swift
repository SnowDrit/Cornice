//
//  SeparatorController.swift
//  Cornice
//

import AppKit
import OSLog

/// Owns Cornice's own status item — the separator — and hides items by growing it.
///
/// This is the one part of Cornice that needs **no permissions at all**: an application
/// may create and resize its own `NSStatusItem` freely. There is no call that hides
/// somebody else's item; what there is, is a wide item that leaves them nowhere to sit.
///
/// Status items are packed leftwards from the right edge of the screen. Widening this one
/// keeps its right edge where it is and drives its left edge far off-screen, taking every
/// item to its left with it. Narrowing it lets them slide back.
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

        // With a 10,000pt wide item a centred image sits thousands of points off the
        // left of the screen. Pinning the content to the trailing edge keeps the chevron
        // where the user expects it — and clickable — in both states.
        button.alignment = .right
        button.imagePosition = .imageOnly

        apply()
        log.info("separator installed")
    }

    /// Where the separator actually sits, in screen coordinates.
    ///
    /// Read from the item's own window rather than through the accessibility API. Asking
    /// AX about an element in one's *own* process returns coordinates in a different
    /// space from the ones it reports for other applications — on a 1440x900 display
    /// this separator described itself as `x=7 y=888` while genuinely sitting near
    /// x=935. Cornice owns this item; there is no reason to ask anybody where it is.
    var screenFrame: CGRect? {
        item.button?.window?.frame
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
        item.length = isHiding ? Self.expandedWidth : Self.collapsedWidth

        // Points towards where the hidden items are: left when they are off-screen and a
        // click would bring them back, right when they are visible and a click puts them
        // away again.
        let symbol = isHiding ? "chevron.left" : "chevron.right"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Cornice")
        image?.isTemplate = true   // adopts the menu bar's light/dark appearance
        item.button?.image = image
    }

    @objc private func buttonClicked() {
        toggle()
    }
}
