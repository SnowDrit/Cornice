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
/// Two items, each with one job:
///
///     [ hidden items ][ | divider — grows ][ ❯ control ][ visible items ]
///
/// The control is never resized, so its chevron draws like any other status icon, and it
/// is what the user drags to choose where the boundary goes. The divider does the
/// widening. It is *visible* — a thin bar — because an invisible one is worse than a
/// second visible one: it can still be found by feel and moved with a ⌘-drag, and once
/// moved the chevron silently stops hiding anything.
///
/// The divider cannot be made undraggable; macOS offers no way to opt out of that
/// gesture. It can be made not to *stay* moved, which comes to the same thing from the
/// outside: its position is sampled and it is put back beside the control.
///
/// One item cannot do both jobs. Six attempts were made to keep a chevron visible on an
/// item that widens, and the last measured correct while still drawing nothing —
/// `length=1218 buttonBounds=1218 chevronX=1190`, a glyph well inside the screen. macOS
/// appears not to render an item too wide for the bar at all: laid out for spacing,
/// skipped for display.
///
/// Creating the divider only while hiding was tried too, to keep the bar tidy, and it
/// loses a race: the position written before creation is read at creation, and macOS may
/// then reapply the previous session's saved position afterwards, which is what made
/// icons vanish and come straight back.
///
/// Because it depends on nothing undocumented, this is also the part expected to survive
/// future macOS releases untouched. Keep it that way: no `CGEvent`, no `AXUIElement`,
/// no window IDs here. See ARCHITECTURE.md.
@MainActor
final class SeparatorController: NSObject {

    private static let controlWidth: CGFloat = 28
    private static let dividerWidth: CGFloat = 10

    private let control: NSStatusItem
    private var divider: NSStatusItem
    private let onToggle: (Bool) -> Void
    private var keepAdjacent: Timer?

    /// `true` when items to the left of the divider are pushed off-screen.
    private(set) var isHiding = false

    /// Shown on right-click. An agent with no Dock icon has no other way to reach its
    /// settings or to quit.
    var contextMenu: NSMenu?

    init(onToggle: @escaping (Bool) -> Void = { _ in }) {
        self.onToggle = onToggle

        // Control first so the divider is inserted to its left, which is the side the
        // hidden items live on.
        control = NSStatusBar.system.statusItem(withLength: Self.controlWidth)
        divider = NSStatusBar.system.statusItem(withLength: Self.dividerWidth)
        super.init()

        control.autosaveName = "CorniceControl"
        divider.autosaveName = "CorniceDivider"
        divider.button?.isEnabled = false
        divider.button?.image = Self.dividerImage()

        guard let button = control.button else {
            log.error("status item has no button; menu bar may be full")
            return
        }
        button.target = self
        button.action = #selector(buttonClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        updateIcon()

        // There is no notification for a status item being dragged, so the divider's
        // position is sampled. Twice a second is well under the rate anyone drags
        // something and costs nothing measurable.
        keepAdjacent = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.restoreDividerPosition() }
        }

        log.info("separator installed")
    }

    deinit {
        keepAdjacent?.invalidate()
    }

    /// Where the boundary sits, in screen coordinates, or `nil` before layout.
    ///
    /// Read from the item's own window rather than through the accessibility API. Asking
    /// AX about an element in one's *own* process returns coordinates in a different
    /// space from the ones it reports for other applications — this item described
    /// itself as `x=7 y=888` while genuinely sitting near x=935.
    var boundaryFrame: CGRect? {
        guard let frame = divider.button?.window?.frame, frame.width > 0 else { return nil }
        return frame
    }

    var controlFrame: CGRect? {
        control.button?.window?.frame
    }

    var geometry: String {
        let controlX: String = controlFrame.map { String(Int($0.minX)) } ?? "?"
        var span = "?"
        if let frame = boundaryFrame { span = "\(Int(frame.minX))..\(Int(frame.maxX))" }
        return "control=\(controlX) divider=\(span) dividerLength=\(Int(divider.length))"
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
        // Width is measured from the *control*, not from the divider. The divider does
        // not always sit exactly beside it, and sized against its own edge one item is
        // left stranded on the visible side — which reads as "the icon next to the arrow
        // never hides".
        if isHiding, let controlLeft = controlFrame?.minX, controlLeft > 0 {
            divider.length = controlLeft + 40
        } else {
            divider.length = Self.dividerWidth
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

    /// Puts the divider back beside the control if it has been dragged away.
    ///
    /// macOS stores each item's placement under `NSStatusItem Preferred Position
    /// <autosaveName>` in the owning application's defaults, measured from the
    /// right-hand end of the bar. Bartender's own saved values read that way — 213, 249,
    /// 5297, 10351, 15367, the gaps matching its 5002-point separators.
    private func restoreDividerPosition() {
        guard !isHiding,
              let screen = NSScreen.main,
              let controlFrame,
              let dividerFrame = boundaryFrame
        else { return }

        // Already adjacent, within rounding.
        if abs(dividerFrame.maxX - controlFrame.minX) < 6 { return }

        // Written from the control's position each time, not corrected iteratively.
        // Feeding the observed error back was tried and diverged — the stored value and
        // the resulting position are not the same scale — and the divider ended up at
        // the far left of the bar. This lands it within a few tens of points, which is
        // close enough for the width, computed from the control, to cover the gap.
        UserDefaults.standard.set(
            screen.frame.maxX - controlFrame.minX,
            forKey: "NSStatusItem Preferred Position CorniceDivider")
        log.info("""
            divider drifted to \(Int(dividerFrame.minX), privacy: .public), \
            control at \(Int(controlFrame.minX), privacy: .public); rebuilding it
            """)

        // The position is read when the item is created, and only then. Changing its
        // width does not make macOS look at the value again — that was tried, and the
        // divider stayed where it had been dragged. So the item is replaced.
        let old = divider
        divider = makeDivider()
        NSStatusBar.system.removeStatusItem(old)
    }

    private func makeDivider() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: Self.dividerWidth)
        item.autosaveName = "CorniceDivider"
        // Not a button: clicks on the divider should do nothing at all, so there is only
        // ever one thing to press.
        item.button?.isEnabled = false
        item.button?.image = Self.dividerImage()
        return item
    }

    /// A thin vertical bar, drawn rather than taken from SF Symbols so its weight does
    /// not change with the system's symbol styling.
    private static func dividerImage() -> NSImage {
        let size = NSSize(width: dividerWidth, height: 14)
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
        // Shown directly rather than by assigning `control.menu` and calling
        // `performClick`: that re-enters this same handler, and the menu never appeared.
        if NSApp.currentEvent?.type == .rightMouseUp, let contextMenu, let button = control.button {
            contextMenu.popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: button.bounds.minY - 4),
                in: button)
            return
        }
        toggle()
    }
}
