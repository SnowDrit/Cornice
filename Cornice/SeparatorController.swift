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
    private let onToggle: (Bool) -> Void

    /// Exists only while hiding.
    ///
    /// Keeping it around permanently, even one point wide and disabled, put a second
    /// draggable thing in the menu bar: findable by feel, movable with ⌘-drag, and once
    /// moved away from the control the chevron stopped hiding anything. Two objects
    /// where the user thinks there is one is a design fault, not a rough edge. Created
    /// on hide and destroyed on reveal, there is nothing to find.
    private var spacer: NSStatusItem?

    /// `true` when items to the left of the spacer are pushed off-screen.
    ///
    /// Starts `false` deliberately. A fresh install has no configuration, and coming up
    /// already hiding would make Cornice's first act be to remove menu bar items the
    /// user never asked it to touch. Stage 5 restores the saved state instead.
    private(set) var isHiding = false

    init(onToggle: @escaping (Bool) -> Void = { _ in }) {
        self.onToggle = onToggle

        control = NSStatusBar.system.statusItem(withLength: Self.controlWidth)
        super.init()

        control.autosaveName = "CorniceControl"

        guard let button = control.button else {
            log.error("status item has no button; menu bar may be full")
            return
        }
        button.target = self
        button.action = #selector(buttonClicked)

        updateIcon()
        log.info("separator installed")
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
        guard let frame = spacer?.button?.window?.frame, frame.width > 0 else {
            // While revealed there is no spacer; the control's own left edge is where
            // the boundary would be.
            return controlFrame
        }
        return frame
    }

    var controlFrame: CGRect? {
        control.button?.window?.frame
    }

    var geometry: String {
        let controlX: String = controlFrame.map { String(Int($0.minX)) } ?? "?"
        var spacerSpan = "none"
        if let frame = spacer?.button?.window?.frame {
            spacerSpan = "\(Int(frame.minX))..\(Int(frame.maxX))"
        }
        let length: String = spacer.map { String(Int($0.length)) } ?? "-"
        return "control=\(controlX) spacer=\(spacerSpan) spacerLength=\(length)"
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
        if isHiding {
            installSpacer()
        } else if let spacer {
            // Narrow first, and only remove once the bar has settled.
            //
            // Narrowing is what actually brings the icons back: they slide into the
            // space it gives up. Removing the item does not do that — it makes macOS
            // rebuild the bar from scratch, and the icons that were pushed off simply
            // stayed off. So the width change has to happen first and be given time to
            // take effect; the removal afterwards is housekeeping nobody is waiting on,
            // and it is what keeps a stray draggable object out of the menu bar.
            spacer.length = Self.spacerCollapsedWidth
            self.spacer = nil
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1500))
                NSStatusBar.system.removeStatusItem(spacer)
            }
        }
        updateIcon()
    }

    private func updateIcon() {
        // Points towards where the hidden items are: left when they are off-screen and a
        // click would bring them back, right when they are visible and a click puts them
        // away again. The control never changes width, so this draws like any icon.
        let symbol = isHiding ? "chevron.left" : "chevron.right"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Cornice")
        image?.isTemplate = true   // adopts the menu bar's light/dark appearance
        control.button?.image = image
    }

    /// Creates the spacer immediately to the left of the control, and widens it.
    ///
    /// `NSStatusItem` offers no way to say "put this next to that", but macOS stores each
    /// item's placement under `NSStatusItem Preferred Position <autosaveName>` in the
    /// owning application's defaults, measured from the right-hand end of the bar.
    /// Bartender's own saved values read that way: 213, 249, 5297, 10351, 15367, with the
    /// gaps matching the widths of the 5002-point separators between them. The spacer's
    /// place is therefore the control's, and writing it before the item exists is what
    /// makes it land there — the value is read at creation.
    private func installSpacer() {
        guard let screen = NSScreen.main, let controlFrame else { return }

        UserDefaults.standard.set(
            screen.frame.maxX - controlFrame.minX,
            forKey: "NSStatusItem Preferred Position CorniceSpacer")

        let item = NSStatusBar.system.statusItem(withLength: Self.spacerCollapsedWidth)
        item.autosaveName = "CorniceSpacer"
        item.button?.isEnabled = false
        spacer = item

        // Widen only once it has been placed. Its own left edge decides how much width
        // is needed, and asking for more than the bar can hold makes macOS stop drawing
        // the item entirely — so the position has to be real before it is used.
        //
        // A freshly created status item does not have a positioned window yet, and a
        // single turn of the run loop is not always enough: the first attempt read a
        // left edge of zero and skipped the widening, leaving a one point spacer that
        // hid nothing. Poll briefly instead of assuming.
        // Width is measured from the *control*, not from the spacer.
        //
        // The spacer does not always land immediately beside the control — macOS may
        // place it a slot further left, leaving one item stranded between the two. Sized
        // against the spacer's own edge, that item is to the right of the boundary and
        // stays put, which reads as "the icon next to the arrow never hides". Sized
        // against the control, everything to the control's left is pushed off however
        // the spacer happened to be placed.
        let target = controlFrame.minX + 40
        Task { @MainActor in
            for _ in 0..<20 {
                if let left = item.button?.window?.frame.minX, left > 0 {
                    item.length = target
                    log.info("""
                        spacer placed at \(Int(left), privacy: .public), \
                        width \(Int(target), privacy: .public)
                        """)
                    return
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
            log.error("spacer never got a position; nothing will hide")
        }
    }

    @objc private func buttonClicked() {
        toggle()
    }
}
