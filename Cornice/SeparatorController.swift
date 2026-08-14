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
/// Up to three items, and, this is the point: **they are unrelated in space**:
///
///     [ always hidden ][ ‖ ][ hidden ][ │ ][ visible ][ ❯ toggle ]
///
/// The dividers are where the user dragged them, and nothing ever moves them. The toggle
/// is wherever the user dragged *it*, usually over by the clock. A click on the toggle
/// widens the rightmost divider until everything on that side of it is off the screen.
/// The second divider, if the user asked for one, is wide the whole time, so what is
/// behind it stays gone even while the icons are revealed. It narrows only on request.
///
/// **Which divider does which job is read, never stored.** The leftmost is the always
/// hidden one, and that is the entire rule: dragging one past the other swaps their jobs,
/// which is the only behaviour that cannot surprise anybody. A divider's anchor is the
/// right edge of its window, and that does not move when the item widens: measured at 40
/// points and again at 942, the same item read 886 both times. The anchor is only taken
/// while the main divider is narrow, because a wide divider pushes its neighbour off the
/// edge and carries its coordinates away with it.
///
/// Earlier versions insisted the divider and the toggle sit side by side, so that one
/// glyph could look like the divider and be pressed. That requirement caused every failure
/// in this file's history: a status item cannot be placed next to another one on demand.
/// Its saved position is consulted when it is created and never again, the value written
/// and the position produced are not the same scale, feeding the error back diverges, and
/// a divider computed into place lands tens of points away, close enough to look right and
/// far enough that whatever sits in the gap never hides. Dropping the requirement deletes
/// all of it.
///
/// One item cannot do both jobs either. Six attempts were made to keep a chevron visible
/// on an item that widens, the last measuring correct while still drawing nothing:
/// `length=1218 buttonBounds=1218 chevronX=1190`, a glyph well inside the screen. macOS
/// appears not to render an item too wide for the bar at all: laid out for spacing,
/// skipped for display. Which is fine for a divider that has nothing to say, and is also
/// why a wide divider must never be clickable: it is an invisible strip most of the width
/// of the screen, and a click target that size would swallow other people's clicks.
///
/// Because it depends on nothing undocumented, this is also the part expected to survive
/// future macOS releases untouched. Keep it that way: no `CGEvent`, no `AXUIElement`,
/// no window IDs here. See ARCHITECTURE.md.
@MainActor
final class SeparatorController: NSObject {

    private static let toggleWidth: CGFloat = 28
    private static let dividerWidth: CGFloat = 10

    /// How far past the left edge of the screen a widened divider carries its own right
    /// edge.
    private static let overshoot: CGFloat = 40

    /// How long the bar takes to put everything back after a width changes, before its
    /// frames mean anything again.
    private static let settleTime: TimeInterval = 0.5

    /// The divider Cornice has always had. Never moved by Cornice.
    private let boundary: NSStatusItem

    /// The second divider, present only while the always hidden zone is switched on.
    /// A third permanent item costs a slot in the menu bar, which is the exact resource
    /// this application exists to save, so it is not created until it is asked for.
    private var extraDivider: NSStatusItem?

    /// The dividers, left to right. Jobs follow this order, see the note above.
    private var ordered: [NSStatusItem] = []

    /// Right edge of each divider, kept from the last time it could be read.
    private var anchors: [ObjectIdentifier: CGFloat] = [:]

    /// The chevron. Never resized, so it draws like any other status icon.
    private var toggle: NSStatusItem

    private let onToggle: (Bool) -> Void
    private var pinTimer: Timer?
    private var lastPinnedAt = Date.distantPast
    private var lastWidthChange = Date.distantPast
    private var expectedToggleX: CGFloat?

    /// Where the toggle starts out on a first run, measured from the right-hand end of
    /// the bar. Zero asks for the rightmost slot macOS will give a third-party item.
    /// After that it is the user's to move, like any other status icon.
    private static let togglePosition = 0.0
    private static let togglePositionKey = "NSStatusItem Preferred Position CorniceToggle"

    private(set) var isHiding = false

    /// Whether the always hidden zone is currently open, meaning its divider is narrow.
    private(set) var isZoneOpen = false

    /// Shown on right-click. An agent with no Dock icon has no other way to reach its
    /// settings or to quit.
    var contextMenu: NSMenu?

    init(onToggle: @escaping (Bool) -> Void = { _ in }) {
        self.onToggle = onToggle

        // Put the toggle back at the right-hand end on every launch.
        //
        // Only here, and only before the item exists. Doing it while running means
        // destroying and recreating a status item from a timer, against a position macOS
        // is writing to at the same time, that was tried twice and lost the chevron
        // outright both times. Written once at startup it is just the value the item is
        // created with, which is the one moment the system reads it.
        //
        // So the toggle can be dragged anywhere during a session and comes back on the
        // next launch. Its position carries no meaning either way: the dividers stand
        // on their own, and where the switch sits changes nothing.
        UserDefaults.standard.set(Self.togglePosition, forKey: Self.togglePositionKey)
        toggle = NSStatusBar.system.statusItem(withLength: Self.toggleWidth)
        boundary = NSStatusBar.system.statusItem(withLength: Self.dividerWidth)
        super.init()

        toggle.autosaveName = "CorniceToggle"
        boundary.autosaveName = "CorniceBoundary"
        ordered = [boundary]

        // Nothing to press: a divider is a landmark, not a control.
        boundary.button?.isEnabled = false

        // Restored, not forced. A launch puts the zone back the way it was left, which is
        // the opposite of switching the feature on, where the zone has to start open.
        isZoneOpen = Preferences.shared.zoneOpen
        if Preferences.shared.alwaysHiddenEnabled { addExtraDivider(openingZone: false) }
        drawDividers()

        guard let button = toggle.button else {
            log.error("status item has no button; menu bar may be full")
            return
        }
        button.target = self
        button.action = #selector(buttonClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        updateIcon()

        // Once the bar has laid out: learn where the dividers are and put the always
        // hidden zone back the way it was left. Both need real frames, and a frame read
        // too early is a number that looks fine and is wrong.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            updateOrder()
            apply()
        }

        // Watch for the toggle being dragged, and put it back.
        //
        // Detection compares the item's *observed* position against where it was last
        // seen sitting correctly, not the value in defaults. macOS writes an item's
        // real position back to that key as it lays out, so comparing against the key
        // sees a difference immediately after writing one, rebuilds, and never stops.
        // That loop is how the chevron disappeared entirely, twice.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            expectedToggleX = controlFrame?.minX
            pinTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.remeasure()
                    self?.pinToggle()
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refreshAppearance() }
            }

        log.info("separator installed")
    }

    deinit {
        pinTimer?.invalidate()
    }

    /// Keeps the jobs on the right dividers while the user drags them about.
    ///
    /// The moment one divider passes the other their jobs swap, and a reading taken once
    /// at startup would leave Cornice disagreeing with what is on the screen. Shares the
    /// toggle's timer, costs two frame reads a second, and depends on nothing.
    private func remeasure() {
        guard ordered.count > 1, settled else { return }

        let before = ordered
        updateOrder()
        applyLengths()

        guard !zip(ordered, before).allSatisfy({ $0 === $1 }) else { return }
        // They changed places, so the bars they draw have to change with them.
        drawDividers()
        log.info("dividers swapped places; the leftmost is now the always hidden one")
    }

    private func pinToggle() {
        guard !isHiding,
              let expected = expectedToggleX,
              let current = controlFrame?.minX
        else { return }

        guard abs(current - expected) > 10 else { return }
        guard Date().timeIntervalSince(lastPinnedAt) > 3 else { return }
        lastPinnedAt = Date()

        log.info("""
            toggle moved from \(Int(expected), privacy: .public) \
            to \(Int(current), privacy: .public); putting it back
            """)

        // Remove before creating: two items sharing an autosave name fight over one
        // stored position and the newcomer can end up with none at all.
        NSStatusBar.system.removeStatusItem(toggle)
        UserDefaults.standard.set(Self.togglePosition, forKey: Self.togglePositionKey)

        let replacement = NSStatusBar.system.statusItem(withLength: Self.toggleWidth)
        replacement.autosaveName = "CorniceToggle"
        replacement.button?.target = self
        replacement.button?.action = #selector(buttonClicked)
        replacement.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        toggle = replacement
        updateIcon()

        // Learn where it actually landed, so the next comparison is against reality
        // rather than against the number that was asked for.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            expectedToggleX = controlFrame?.minX
        }
    }

    // MARK: - Which divider is which

    /// The divider the toggle widens: the rightmost one.
    private var mainDivider: NSStatusItem { ordered.last ?? boundary }

    /// The divider that stays wide: the leftmost one, and only when there are two.
    private var zoneDivider: NSStatusItem? { ordered.count > 1 ? ordered.first : nil }

    /// Whether the bar can be believed about where things are.
    ///
    /// Two conditions, and the first one cost a run of the check to find. A wide divider
    /// pushes its neighbour past the left edge and the neighbour's frame goes with it, so
    /// nothing can be read while the main divider is wide. But the frames do not snap back
    /// the instant a width is set either: measured in the same tick as the narrowing, the
    /// always hidden divider still read `x=-309` from where it had just been shoved, and
    /// that number got remembered as its home. So: nothing wide, and nothing resized in
    /// the last half second.
    ///
    /// Note this asks what the bar looks like *now*, not what it is about to look like.
    /// Testing the state being moved to is what produced the wrong answer.
    private var settled: Bool {
        mainDivider.length <= Self.dividerWidth
            && Date().timeIntervalSince(lastWidthChange) > Self.settleTime
    }

    /// Sorts the dividers by where they actually are, and remembers their anchors.
    ///
    /// Call only when `settled` says so.
    private func updateOrder() {
        guard let extraDivider else {
            ordered = [boundary]
            if let anchor = anchor(reading: boundary) {
                anchors[ObjectIdentifier(boundary)] = anchor
            }
            return
        }

        let measured = [boundary, extraDivider].compactMap { item -> (NSStatusItem, CGFloat)? in
            guard let anchor = anchor(reading: item) else { return nil }
            return (item, anchor)
        }
        // Keep the last good order rather than guessing from half the picture.
        guard measured.count == 2 else { return }

        for (item, anchor) in measured { anchors[ObjectIdentifier(item)] = anchor }
        ordered = measured.sorted { $0.1 < $1.1 }.map(\.0)
    }

    private func anchor(reading item: NSStatusItem) -> CGFloat? {
        guard let frame = item.button?.window?.frame, frame.width > 0 else { return nil }
        return frame.maxX
    }

    private func anchor(of item: NSStatusItem) -> CGFloat? {
        anchors[ObjectIdentifier(item)]
    }

    /// Right edge of the divider the toggle widens, or `nil` before layout.
    ///
    /// Read from the items' own windows rather than through the accessibility API. Asking
    /// AX about an element in one's *own* process returns coordinates in a different
    /// space from the ones it reports for other applications, this item described
    /// itself as `x=7 y=888` while genuinely sitting near x=935.
    var mainDividerAnchor: CGFloat? { anchor(of: mainDivider) }

    /// Right edge of the always hidden divider, or `nil` when there is not one.
    var zoneDividerAnchor: CGFloat? { zoneDivider.flatMap { anchor(of: $0) } }

    var controlFrame: CGRect? {
        toggle.button?.window?.frame
    }

    /// Everything about the current arrangement in one read, for the check that drives
    /// this controller through its states. Nothing in the product uses it.
    struct Geometry: CustomStringConvertible {
        var dividers = 0
        var mainAnchor: CGFloat?
        var mainLength: CGFloat = 0
        var zoneAnchor: CGFloat?
        var zoneLength: CGFloat?
        var isHiding = false
        var isZoneOpen = false

        /// A divider is doing its job when it is wide enough to have carried its own right
        /// edge off the screen. Anything near the resting width is not.
        static let wideEnough: CGFloat = 200

        var mainIsWide: Bool { mainLength > Self.wideEnough }
        var zoneIsWide: Bool { (zoneLength ?? 0) > Self.wideEnough }

        var description: String {
            let main = mainAnchor.map { String(Int($0)) } ?? "?"
            let zone = zoneAnchor.map { String(Int($0)) } ?? "none"
            let zoneLen = zoneLength.map { String(Int($0)) } ?? "none"
            return "dividers=\(dividers) main=\(main)/\(Int(mainLength))"
                + " alwaysHidden=\(zone)/\(zoneLen)"
                + " hiding=\(isHiding) zoneOpen=\(isZoneOpen)"
        }
    }

    var geometry: Geometry {
        Geometry(
            dividers: ordered.count,
            mainAnchor: mainDividerAnchor,
            mainLength: mainDivider.length,
            zoneAnchor: zoneDividerAnchor,
            zoneLength: zoneDivider?.length,
            isHiding: isHiding,
            isZoneOpen: isZoneOpen)
    }

    // MARK: - State

    func toggleHiding() {
        setHiding(!isHiding)
    }

    func setHiding(_ hiding: Bool) {
        guard hiding != isHiding else { return }
        isHiding = hiding

        // Putting the icons away puts the always hidden zone away too. Leaving it open
        // behind a wide divider means the next reveal shows more than the user put there,
        // and they would not have asked for a zone if they wanted to see into it.
        if hiding, isZoneOpen {
            isZoneOpen = false
            Preferences.shared.zoneOpen = false
        }

        apply()
        log.info("separator now \(hiding ? "hiding" : "revealing", privacy: .public)")
        onToggle(hiding)
    }

    func toggleZone() {
        setZoneOpen(!isZoneOpen)
    }

    /// Opens or closes the always hidden zone, which is the second divider narrowing.
    ///
    /// Opening reveals first. Narrowing the second divider while the main one is wide
    /// would change nothing anyone can see: everything to the left of the main divider is
    /// off the screen either way, so the zone would appear to open and do nothing.
    func setZoneOpen(_ open: Bool) {
        guard extraDivider != nil, open != isZoneOpen else { return }
        if open { setHiding(false) }
        isZoneOpen = open
        Preferences.shared.zoneOpen = open
        apply()
        log.info("always hidden zone \(open ? "open" : "closed", privacy: .public)")
    }

    private func apply() {
        if settled { updateOrder() }
        applyLengths()
        updateIcon()
        drawDividers()
    }

    /// Sets both dividers to the width the current state asks for, from the remembered
    /// anchors. Never measures: measuring belongs to `updateOrder`, which has to wait for
    /// the bar to hold still, and this runs the instant the user clicks.
    private func applyLengths() {
        if let zoneDivider {
            setLength(zoneDivider, isZoneOpen ? Self.dividerWidth : widened(zoneDivider))
        }
        setLength(mainDivider, isHiding ? widened(mainDivider) : Self.dividerWidth)
    }

    /// Enough to carry the item's own right edge past the left of the screen, which is
    /// exactly what it takes to sweep that side away. Asking for more is not free: an item
    /// too wide for the bar stops being drawn, and while that does not matter for a
    /// divider, an absurd width makes the frames unreadable when something goes wrong.
    private func widened(_ item: NSStatusItem) -> CGFloat {
        guard let right = anchor(of: item), right > 0 else { return Self.dividerWidth }
        return right + Self.overshoot
    }

    private func setLength(_ item: NSStatusItem, _ length: CGFloat) {
        guard item.length != length else { return }
        item.length = length
        lastWidthChange = Date()
    }

    private func updateIcon() {
        // Points towards where the hidden items are: left when they are off-screen and a
        // click would bring them back, right when they are visible and a click puts them
        // away again.
        let symbol = Preferences.shared.toggleSymbol.symbolName(hiding: isHiding)
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Cornice")
        image?.isTemplate = true   // adopts the menu bar's light/dark appearance
        toggle.button?.image = image
    }

    /// Redraws everything from the current preferences, and creates or removes the second
    /// divider to match the switch.
    ///
    /// Driven by `UserDefaults.didChangeNotification` rather than by the settings window
    /// calling back, so appearance follows the stored value however it was changed:
    /// including from the command line, which is how it gets tested.
    func refreshAppearance() {
        if Preferences.shared.alwaysHiddenEnabled {
            addExtraDivider(openingZone: true)
        } else {
            removeExtraDivider()
        }
        drawDividers()
        updateIcon()
    }

    /// One bar for the divider the toggle works, two for the one that stays wide. They do
    /// different jobs and there is no other way to tell them apart at a glance.
    private func drawDividers() {
        mainDivider.button?.image = Self.dividerImage(doubled: false)
        zoneDivider?.button?.image = Self.dividerImage(doubled: true)
    }

    // MARK: - The second divider

    private func addExtraDivider(openingZone: Bool) {
        guard extraDivider == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: Self.dividerWidth)
        item.autosaveName = "CorniceAlwaysHidden"
        item.button?.isEnabled = false
        extraDivider = item

        // Switched on, the zone starts open. Where a new status item lands is macOS's
        // decision, and if it landed to the left of things the user meant to keep, they
        // would disappear at the moment of turning the switch on with no way to see what
        // went. Open, nothing moves, and the divider can be dragged into place first.
        if openingZone {
            isZoneOpen = true
            Preferences.shared.zoneOpen = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            updateOrder()
            apply()
        }
        log.info("always hidden divider added")
    }

    private func removeExtraDivider() {
        guard let item = extraDivider else { return }
        extraDivider = nil
        ordered = [boundary]
        isZoneOpen = false

        // Everything narrow before anything is removed. Removing a status item makes macOS
        // rebuild the bar, and anything already pushed off the edge stays off; narrowing
        // is what puts a layout back. So both dividers shrink, the bar gets a moment, and
        // only then does the item go.
        setLength(item, Self.dividerWidth)
        setLength(boundary, Self.dividerWidth)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            NSStatusBar.system.removeStatusItem(item)
            try? await Task.sleep(for: .milliseconds(400))
            updateOrder()
            apply()
        }
        log.info("always hidden divider removed")
    }

    /// A thin vertical bar, drawn rather than taken from SF Symbols so its weight does
    /// not change with the system's symbol styling. Doubled, it is the always hidden one.
    private static func dividerImage(doubled: Bool) -> NSImage {
        let height = CGFloat(Preferences.shared.dividerHeight)
        let asked = CGFloat(Preferences.shared.dividerThickness)
        let gap: CGFloat = 2
        // Two bars have to share the width of one divider, so at the thickest setting
        // they thin out rather than the item growing. A divider that changed width with
        // its weight would shift every icon left of it.
        let thickness = doubled ? min(asked, (dividerWidth - gap) / 2) : asked
        let total = doubled ? thickness * 2 + gap : thickness

        let size = NSSize(width: dividerWidth, height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.setFill()
        var x = (size.width - total) / 2
        for _ in 0..<(doubled ? 2 : 1) {
            NSBezierPath(
                roundedRect: NSRect(x: x, y: 0, width: thickness, height: height),
                xRadius: thickness / 2, yRadius: thickness / 2).fill()
            x += thickness + gap
        }
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
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp, let contextMenu, let button = toggle.button {
            contextMenu.popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: button.bounds.minY - 4),
                in: button)
            return
        }

        // ⌥-click reaches the always hidden zone. It goes on the toggle because the
        // divider itself cannot be clicked: widened, it is an invisible strip most of the
        // width of the screen, and anything clickable that size eats other people's
        // clicks. There is a keyboard shortcut for the same action.
        if event?.modifierFlags.contains(.option) == true, extraDivider != nil {
            toggleZone()
            return
        }

        toggleHiding()
    }
}
