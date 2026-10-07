//
//  SeparatorController.swift
//  Cornice
//

import AppKit
import OSLog

/// The dividers mark groups; the separate toggle controls their visibility.
/// Positions belong to the user and are never rewritten by this controller.
/// The leftmost of two dividers always marks the always-hidden group.
///
/// macOS 26 uses expanded status items to displace their neighbours. macOS 27
/// uses native visibility for both groups. Dividers never expand on macOS 27.
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

    /// The divider retained when the optional zone is disabled. Its native
    /// autosave identity stays with the item when the user swaps divider roles.
    private var boundary: NSStatusItem

    private enum DividerSlot: String {
        case original = "CorniceBoundary"
        case secondary = "CorniceAlwaysHidden"

        var other: DividerSlot { self == .original ? .secondary : .original }
    }

    static let retainedDividerIdentityKey = "retainedDividerAutosaveName"

    /// Only single-divider mode needs a durable object identity. Its remaining
    /// divider can be dragged beyond the inactive slot's old saved position.
    /// With two dividers, roles always follow actual frames and ignore this key.
    /// Older versions always retained CorniceBoundary, so missing data uses it.
    static func initialMainAutosaveName(alwaysHiddenEnabled: Bool,
                                        persistentDomain: [String: Any]) -> String {
        guard !alwaysHiddenEnabled,
              let name = persistentDomain[retainedDividerIdentityKey] as? String,
              let slot = DividerSlot(rawValue: name) else { return DividerSlot.original.rawValue }
        return slot.rawValue
    }

    /// The second divider, present only while the always hidden zone is switched on.
    /// A third permanent item costs a slot in the menu bar, which is the exact resource
    /// this application exists to save, so it is not created until it is asked for.
    private var extraDivider: NSStatusItem?

    /// A divider remains reusable until its delayed removal actually happens.
    /// Otherwise a rapid off/on creates two owners of the same autosave name.
    private var retiringDivider: NSStatusItem?
    /// macOS 27 removes autosaved positions asynchronously when uninstalling an
    /// item. Keep the disabled optional slot at zero width until it is reused.
    /// It is outside group ordering and consumes no window or button width.
    private var dormantDivider: NSStatusItem?
    private var dividerLifecycleTask: Task<Void, Never>?
    private var dividerLifecycleGeneration = 0
    private var isChangingDividers: Bool { dividerLifecycleTask != nil }
    private let collapsedDividers = CollapsedStatusItem(restoredLength: dividerWidth)

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

    private struct AppearancePreferences: Equatable {
        let alwaysHiddenEnabled: Bool
        let dividerThickness: Double
        let dividerHeight: Double
        let toggleSymbol: Preferences.ToggleSymbol

        init() {
            let preferences = Preferences.shared
            alwaysHiddenEnabled = preferences.alwaysHiddenEnabled
            dividerThickness = preferences.dividerThickness
            dividerHeight = preferences.dividerHeight
            toggleSymbol = preferences.toggleSymbol
        }
    }
    private var lastAppearancePreferences: AppearancePreferences?

    // macOS 27 stops laying out oversized spacers. Measure only with
    // every item revealed, then retain group membership while the bar collapses.
    private let visibilityAssertion = MenuBarVisibilityAssertion()
    private var nativeRecords: [MacOS27MenuBarSnapshot.Record]?
    private var nativeClassificationScope: MenuBarClassificationScope?
    private var nativeScanTask: Task<Void, Never>?
    private var nativeScanGeneration = 0
    private var nativeLayoutNeedsRefresh = false
    private(set) var isRearranging = false
    private var isFinishingRearrangement = false
    private var nativeAppliedSignature: String?
    private var nativeClockFrames: [CGRect] = []
    private var clockLastVisited: Date?
    private var usesNativeVisibility = false
    private var isShuttingDown = false
    private var lastAccessibilityGranted = AccessibilityPermission.isGranted
    private var clockMouseMonitor: Any?
    private var localMouseMonitor: Any?

    private var visibilityMode = "spacing"

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

        // Pick a default only on first launch. A dragged position belongs to the user.
        if UserDefaults.standard.object(forKey: Self.togglePositionKey) == nil {
            UserDefaults.standard.set(Self.togglePosition, forKey: Self.togglePositionKey)
        }
        toggle = NSStatusBar.system.statusItem(withLength: Self.toggleWidth)
        boundary = NSStatusBar.system.statusItem(withLength: Self.dividerWidth)
        super.init()

        toggle.autosaveName = "CorniceToggle"
        let domain = Bundle.main.bundleIdentifier ?? "io.github.snowdrit.Cornice"
        boundary.autosaveName = Self.initialMainAutosaveName(
            alwaysHiddenEnabled: Preferences.shared.alwaysHiddenEnabled,
            persistentDomain: UserDefaults.standard.persistentDomain(forName: domain) ?? [:])
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
        lastAppearancePreferences = AppearancePreferences()

        // Once the bar has laid out: learn where the dividers are and put the always
        // hidden zone back the way it was left. Both need real frames, and a frame read
        // too early is a number that looks fine and is wrong.
        Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(500)) }
            catch { return }
            guard let self, !isShuttingDown, !isChangingDividers else { return }
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
        Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(2)) }
            catch { return }
            guard let self, !isShuttingDown else { return }
            expectedToggleX = controlFrame?.minX
            pinTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.remeasure()
                    self?.pinToggle()
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refreshAppearance() }
            }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.nativeScanTask?.cancel()
                    self.nativeScanTask = nil
                    self.isFinishingRearrangement = false
                    self.nativeRecords = nil
                    self.nativeClassificationScope = nil
                    self.nativeClockFrames = []
                    self.releaseNativeVisibility()
                    self.apply()
                }
            }

        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: name, object: nil, queue: .main) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self, #available(macOS 27, *) else { return }
                        // New or removed apps can change the revealed layout. Keep
                        // the current grouping until it is safe to measure again.
                        self.nativeLayoutNeedsRefresh = true
                        self.applyNativeVisibility()
                    }
                }
        }
        if #available(macOS 27, *) {
            // Pointer hover is already sampled by AppDelegate. Avoid scheduling
            // a main-actor task for every high-frequency mouse-move event.
            let observe: (NSEvent) -> Void = { [weak self] event in
                // Preserve the event's origin before asynchronous delivery. A
                // drag entering the bar from a window must not begin editing.
                let downPoint = event.type == .leftMouseDown ? event.cgEvent?.location : nil
                let commandDown = event.modifierFlags.contains(.command)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let downPoint {
                        self.observeRearrangementMouseDown(at: downPoint, commandDown: commandDown)
                    }
                    self.checkClockHover()
                }
            }
            clockMouseMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.flagsChanged, .leftMouseDown, .leftMouseUp], handler: observe)
            localMouseMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.flagsChanged, .leftMouseDown, .leftMouseUp]) { event in
                observe(event)
                return event
            }
        }

        log.info("separator installed")
    }

    deinit {
        dividerLifecycleTask?.cancel()
        pinTimer?.invalidate()
        if let clockMouseMonitor { NSEvent.removeMonitor(clockMouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
    }

    /// Keeps the jobs on the right dividers while the user drags them about.
    ///
    /// The moment one divider passes the other their jobs swap, and a reading taken once
    /// at startup would leave Cornice disagreeing with what is on the screen. Shares the
    /// toggle's timer, costs two frame reads a second, and depends on nothing.
    private func remeasure() {
        guard !isShuttingDown, !isChangingDividers else { return }
        if #available(macOS 27, *) {
            checkClockHover()
            let granted = AccessibilityPermission.isGranted
            if granted != lastAccessibilityGranted {
                lastAccessibilityGranted = granted
                nativeRecords = nil
                nativeClassificationScope = nil
                applyNativeVisibility()
                return
            }
            return
        }
        guard settled else { return }

        let before = ordered
        updateOrder()
        applyLengths()

        guard !zip(ordered, before).allSatisfy({ $0 === $1 }) else { return }
        // They changed places, so the bars they draw have to change with them.
        drawDividers()
        log.info("dividers swapped places; the leftmost is now the always hidden one")
    }

    private func pinToggle() {
        guard !isShuttingDown, !isChangingDividers else { return }
        // On macOS 27 overflow changes the reported position without a user drag.
        // Recreating the control in response can put it inside the overflow menu.
        if #available(macOS 27, *) { return }
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
        Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(400)) }
            catch { return }
            guard let self, !isShuttingDown else { return }
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
        !collapsedDividers.isCollapsed(boundary)
            && !(extraDivider.map { collapsedDividers.isCollapsed($0) } ?? false)
            && mainDivider.length <= Self.dividerWidth
            && Date().timeIntervalSince(lastWidthChange) > Self.settleTime
    }

    /// Sorts the dividers by where they actually are, and remembers their anchors.
    ///
    /// Call only when `settled` says so.
    private func updateOrder() {
        // Collapsed slots and newly restored frames cannot establish physical order.
        guard settled else { return }
        // Overflowed items on macOS 27 retain visible-looking, overlapping frames.
        // Their coordinates cannot establish divider order until both are narrow.
        if #available(macOS 27, *),
           boundary.length > Self.dividerWidth
            || (extraDivider?.length ?? 0) > Self.dividerWidth {
            return
        }
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
        guard !collapsedDividers.isCollapsed(item),
              let frame = item.button?.window?.frame, frame.width > 0 else { return nil }
        if #available(macOS 27, *) { return frame.midX }
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

    var nativeArrangement: SettingsView.Arrangement? {
        guard #available(macOS 27, *), let records = nativeRecords,
              let main = mainDividerAnchor else { return nil }
        return NativeMenuBarArrangement.make(
            records: records, mainAnchor: main, zoneAnchor: zoneDividerAnchor,
            classificationScope: nativeClassificationScope)
    }

    var controlFrame: CGRect? {
        toggle.button?.window?.frame
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
        guard !isShuttingDown, extraDivider != nil, open != isZoneOpen else { return }
        if open { isHiding = false }
        isZoneOpen = open
        Preferences.shared.zoneOpen = open
        apply()
        // A newly opened zone is a new reveal interaction even when the ordinary
        // group was already open. Reset its previous auto-collapse countdown.
        if open { onToggle(false) }
        log.info("always hidden zone \(open ? "open" : "closed", privacy: .public)")
    }

    func revealAll() {
        if extraDivider != nil { setZoneOpen(true) }
        else { setHiding(false) }
    }

    private func apply() {
        guard !isShuttingDown else { return }
        guard !isChangingDividers else {
            updateIcon()
            drawDividers()
            return
        }
        if #available(macOS 27, *) {
            applyNativeVisibility()
            updateIcon()
            drawDividers()
            return
        }
        if settled { updateOrder() }
        applyLengths()
        updateIcon()
        drawDividers()
    }

    // MARK: - macOS 27 visibility

    private func releaseNativeVisibility() {
        visibilityAssertion.release()
        nativeAppliedSignature = nil
        usesNativeVisibility = false
    }

    private func restoreDivider(_ item: NSStatusItem) {
        let wasCollapsed = collapsedDividers.isCollapsed(item)
        collapsedDividers.restore(item)
        if wasCollapsed { lastWidthChange = Date() }
        setLength(item, Self.dividerWidth)
    }

    private func narrowDividers() {
        restoreDivider(boundary)
        if let extraDivider { restoreDivider(extraDivider) }
        if let retiringDivider { restoreDivider(retiringDivider) }
    }

    private func applyNativeVisibility() {
        guard !isShuttingDown, !isRearranging, !isChangingDividers else { return }
        let fullyRevealed = !isHiding && (isZoneOpen || extraDivider == nil)
        if fullyRevealed {
            releaseNativeVisibility()
            narrowDividers()
            visibilityMode = "revealed"
            toggle.button?.toolTip = "Cornice"
        }

        guard AccessibilityPermission.isGranted, visibilityAssertion.isAvailable else {
            nativeScanTask?.cancel()
            nativeScanTask = nil
            releaseNativeVisibility()
            narrowDividers()
            visibilityMode = "unavailable"
            toggle.button?.toolTip = L.t("On macOS 27, allow Accessibility in Cornice settings to hide icons.")
            return
        }

        // Ordinary toggles do not change group membership. Reuse the snapshot so
        // a reveal followed by a hide never waits for another AX scan.
        if fullyRevealed && nativeLayoutNeedsRefresh {
            nativeRecords = nil
            nativeClassificationScope = nil
        }
        if nativeRecords == nil || nativeClassificationScope == nil {
            guard nativeScanTask == nil else { return }
            releaseNativeVisibility()
            narrowDividers()
            scanNativeLayout(after: .milliseconds(1500))
            return
        }
        commitNativeVisibility()
    }

    private func commitNativeVisibility() {
        guard let records = nativeRecords, let main = mainDividerAnchor,
              !isShuttingDown, !isRearranging, !isChangingDividers else { return }
        let runningBundleIDs = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let plan = MacOS27VisibilityPlan(
            records: records, mainAnchor: main, zoneAnchor: zoneDividerAnchor,
            hiding: isHiding, isZoneOpen: isZoneOpen,
            classificationScope: nativeClassificationScope, runningBundleIDs: runningBundleIDs)
        if !plan.hasHiddenItems {
            releaseNativeVisibility()
            visibilityMode = "revealed"
        } else {
            if let visited = clockLastVisited, Date().timeIntervalSince(visited) < 0.6 {
                return
            }
            let ownID = Bundle.main.bundleIdentifier ?? "io.github.snowdrit.Cornice"
            var allowed = runningBundleIDs
            allowed.subtract(plan.hiddenBundleIDs)
            allowed.formUnion([ownID, "com.apple.MenuBarAgent", "com.apple.controlcenter"])
            let signature = allowed.sorted().joined(separator: ",")
                + ":" + plan.allowedSystemItems.map(String.init).joined(separator: ",")
            guard signature != nativeAppliedSignature else { return }
            nativeAppliedSignature = signature
            usesNativeVisibility = true
            visibilityMode = "native-pending"
            visibilityAssertion.apply(allowedBundleIDs: allowed.sorted(),
                                      allowedSystemItems: plan.allowedSystemItems) { [weak self] error in
                guard let self else { return }
                if let error {
                    self.releaseNativeVisibility()
                    self.visibilityMode = "unavailable"
                    self.drawDividers()
                    self.logVisibility(error.localizedDescription)
                } else {
                    self.visibilityMode = "native"
                    self.logVisibility("applied")
                }
            }
        }
        drawDividers()
        logVisibility("state changed")
    }

    /// The assessment assertion blocks Notification Center even when its clock is
    /// allowed. Suspend it only inside the clock's actual frame, then restore it
    /// after the pointer leaves. Empty space must not become a reveal control.
    func checkClockHover() {
        guard #available(macOS 27, *), !isShuttingDown else { return }
        let pointer = NSEvent.mouseLocation
        let inMenuBar = NSScreen.screens.contains { screen in
            MenuBarPointerRegion.contains(
                point: pointer, screenFrame: screen.frame,
                menuBarHeight: max(NSStatusBar.system.thickness, screen.safeAreaInsets.top))
        }
        updateRearrangement(commandDown: NSEvent.modifierFlags.contains(.command),
                            mouseButtons: NSEvent.pressedMouseButtons, inMenuBar: inMenuBar)
        guard !isRearranging else { return }
        let point = ScreenGeometry.toAX(pointer)
        if MenuBarHitTest.containsClock(point: point, frames: nativeClockFrames, inMenuBar: inMenuBar) {
            clockLastVisited = Date()
            if usesNativeVisibility {
                releaseNativeVisibility()
                visibilityMode = "clock"
                logVisibility("pointer entered clock")
            }
        } else if let visited = clockLastVisited,
                  Date().timeIntervalSince(visited) >= 0.6 {
            clockLastVisited = nil
            commitNativeVisibility()
        }
    }

    private func observeRearrangementMouseDown(at axPoint: CGPoint, commandDown: Bool) {
        let inMenuBar = NSScreen.screens.contains { screen in
            let frame = ScreenGeometry.toAX(screen.frame)
            return CGRect(x: frame.minX, y: frame.minY, width: frame.width,
                          height: max(NSStatusBar.system.thickness, screen.safeAreaInsets.top)).contains(axPoint)
        }
        updateRearrangement(commandDown: commandDown, mouseButtons: 1,
                            inMenuBar: inMenuBar, leftMouseDownBegan: true)
    }

    /// Only a new Command mouse-down inside the bar starts editing. Polling and
    /// modifier changes can finish an edit, but never reveal a group themselves.
    func updateRearrangement(commandDown: Bool, mouseButtons: Int, inMenuBar: Bool,
                             leftMouseDownBegan: Bool = false) {
        guard #available(macOS 27, *), !isShuttingDown, !isChangingDividers else { return }
        let leftMouseDown = mouseButtons & 1 != 0
        if leftMouseDownBegan && commandDown && leftMouseDown && inMenuBar
            && (!isRearranging || isFinishingRearrangement) {
            nativeScanGeneration += 1
            nativeScanTask?.cancel()
            nativeScanTask = nil
            nativeRecords = nil
            nativeClassificationScope = nil
            isRearranging = true
            isFinishingRearrangement = false
            clockLastVisited = nil
            releaseNativeVisibility()
            narrowDividers()
            visibilityMode = "arranging"
            drawDividers()
        } else if isRearranging && !isFinishingRearrangement && !leftMouseDown {
            isFinishingRearrangement = true
            scanNativeLayout(after: .milliseconds(600))
        }
    }

    /// Capture only while the owned dividers are restored for measurement.
    /// Collapsed windows deliberately have zero width; ordinary toggles reuse
    /// this scope together with their saved anchors and snapshot.
    private func captureClassificationScope() -> MenuBarClassificationScope? {
        guard let mainWindow = mainDivider.button?.window, let screen = mainWindow.screen,
              let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        var zoneFrame: CGRect?
        if let zoneDivider {
            guard let zoneWindow = zoneDivider.button?.window,
                  let zoneScreen = zoneWindow.screen,
                  let zoneNumber = zoneScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  zoneNumber == screenNumber else { return nil }
            zoneFrame = ScreenGeometry.toAX(zoneWindow.frame)
        }
        return MenuBarClassificationScope(
            screenID: screenNumber.uint32Value, screenFrame: ScreenGeometry.toAX(screen.frame),
            menuBarHeight: max(NSStatusBar.system.thickness, screen.safeAreaInsets.top),
            mainWindowFrame: ScreenGeometry.toAX(mainWindow.frame), zoneWindowFrame: zoneFrame)
    }

    private func scanNativeLayout(after delay: Duration, attempt: Int = 0) {
        guard !isShuttingDown, !isChangingDividers else { return }
        narrowDividers()
        nativeScanTask?.cancel()
        nativeScanGeneration += 1
        let generation = nativeScanGeneration
        nativeScanTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: delay) }
            catch { return }
            guard let self, !self.isShuttingDown else { return }
            self.updateOrder()
            let main = self.mainDividerAnchor
            let zone = self.zoneDividerAnchor
            let scope = self.captureClassificationScope()
            self.nativeLayoutNeedsRefresh = false
            let records = await MacOS27MenuBarSnapshot.capture()
            guard !Task.isCancelled, !self.isShuttingDown,
                  !self.isChangingDividers, generation == self.nativeScanGeneration else { return }
            self.updateOrder()
            if self.nativeLayoutNeedsRefresh
                || scope == nil || scope != self.captureClassificationScope()
                || main != self.mainDividerAnchor || zone != self.zoneDividerAnchor {
                if attempt < 3 {
                    self.scanNativeLayout(after: .milliseconds(600), attempt: attempt + 1)
                    return
                }
                self.nativeScanTask = nil
                self.isRearranging = false
                self.isFinishingRearrangement = false
                self.visibilityMode = "unavailable"
                self.drawDividers()
                return
            }
            self.nativeScanTask = nil
            self.isRearranging = false
            self.isFinishingRearrangement = false
            guard main != nil, let scope, !records.isEmpty else {
                self.visibilityMode = "unavailable"
                self.logVisibility("no usable menu-bar snapshot")
                self.drawDividers()
                return
            }
            self.nativeRecords = records
            self.nativeClassificationScope = scope
            NotificationCenter.default.post(name: NativeMenuBarArrangement.didRefresh, object: nil)
            self.nativeClockFrames = records.compactMap {
                $0.identifier == "com.apple.menuextra.clock" ? $0.frame : nil
            }
            self.commitNativeVisibility()
            self.drawDividers()
        }
    }

    private func logVisibility(_ message: String) {
        log.info("menu visibility \(self.visibilityMode, privacy: .public): \(message, privacy: .public)")
    }

    func shutdown() {
        isShuttingDown = true
        cancelDividerLifecycle()
        nativeScanTask?.cancel()
        nativeScanTask = nil
        releaseNativeVisibility()
        narrowDividers()
        if let dormantDivider {
            restoreDivider(dormantDivider)
            dormantDivider.button?.image = Self.dividerImage(doubled: true)
        }
        drawDividers()
        pinTimer?.invalidate()
        if let clockMouseMonitor {
            NSEvent.removeMonitor(clockMouseMonitor)
            self.clockMouseMonitor = nil
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
    }

    /// Sets both dividers to the width the current state asks for, from the remembered
    /// anchors. Never measures: measuring belongs to `updateOrder`, which has to wait for
    /// the bar to hold still, and this runs the instant the user clicks.
    private func applyLengths() {
        if #available(macOS 27, *) {
            narrowDividers()
            return
        }
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
        guard !isShuttingDown else { return }
        let appearance = AppearancePreferences()
        guard appearance != lastAppearancePreferences
                || appearance.alwaysHiddenEnabled != (extraDivider != nil) else { return }
        lastAppearancePreferences = appearance
        // This filters only defaults notifications. Visibility, ordering and
        // recreated controls still draw directly from their state transitions.
        if appearance.alwaysHiddenEnabled {
            addExtraDivider(openingZone: true)
        } else {
            removeExtraDivider()
        }
        drawDividers()
        updateIcon()
    }

    /// Closed native groups remove their divider slot as well as its image. A
    /// failed layout match leaves a visible inert landmark, never a blank hit area.
    private func drawDividers() {
        var dividers: [(NSStatusItem, Bool)] = [(mainDivider, false)]
        if let zoneDivider { dividers.append((zoneDivider, true)) }
        // An added or retiring item is temporarily outside the last measured order.
        // Keep it visible while lifecycle changes restore and settle the whole bar.
        for item in [extraDivider, retiringDivider].compactMap({ $0 }) {
            if !dividers.contains(where: { $0.0 === item }) { dividers.append((item, true)) }
        }
        if let dormantDivider, !isShuttingDown {
            // Feature-off slots stay outside scans and arrangement. Revalidate
            // their existing layout without reopening them on ordinary toggles.
            if collapsedDividers.collapse(dormantDivider) {
                dormantDivider.button?.image = nil
            } else {
                restoreDivider(dormantDivider)
                dormantDivider.button?.image = Self.dividerImage(doubled: true)
            }
        }
        for (item, doubled) in dividers {
            let requestedClosed = item !== retiringDivider && (isHiding || (doubled && !isZoneOpen))
            if #available(macOS 27, *) {
                let mayCollapse = !isShuttingDown && nativeRecords != nil && nativeScanTask == nil
                    && !isChangingDividers && !isRearranging && visibilityMode != "unavailable"
                let wasCollapsed = collapsedDividers.isCollapsed(item)
                let previousLength = item.length
                if mayCollapse && requestedClosed && collapsedDividers.collapse(item) {
                    if !wasCollapsed || previousLength != item.length { lastWidthChange = Date() }
                    item.button?.image = nil
                } else {
                    // collapse can itself restore after an AppKit hierarchy change.
                    if wasCollapsed { lastWidthChange = Date() }
                    restoreDivider(item)
                    item.button?.image = Self.dividerImage(doubled: doubled)
                }
            } else if !isRearranging && requestedClosed {
                item.button?.image = nil
            } else {
                item.button?.image = Self.dividerImage(doubled: doubled)
            }
        }
    }

    // MARK: - The second divider

    private func cancelDividerLifecycle() {
        dividerLifecycleGeneration += 1
        dividerLifecycleTask?.cancel()
        dividerLifecycleTask = nil
    }

    private func beginDividerLifecycle() -> Int {
        cancelDividerLifecycle()
        nativeScanGeneration += 1
        nativeScanTask?.cancel()
        nativeScanTask = nil
        isRearranging = false
        isFinishingRearrangement = false
        nativeRecords = nil
        nativeClassificationScope = nil
        nativeClockFrames = []
        nativeLayoutNeedsRefresh = true
        releaseNativeVisibility()
        narrowDividers()
        return dividerLifecycleGeneration
    }

    private func addExtraDivider(openingZone: Bool) {
        guard !isShuttingDown, extraDivider == nil else { return }
        let generation = beginDividerLifecycle()
        if UserDefaults.standard.object(forKey: Self.retainedDividerIdentityKey) != nil {
            UserDefaults.standard.removeObject(forKey: Self.retainedDividerIdentityKey)
        }

        let item: NSStatusItem
        if let retiringDivider {
            // The pending removal has not happened. Reuse the exact same item,
            // retaining its native position and one owner of its autosave name.
            item = retiringDivider
            self.retiringDivider = nil
        } else if let dormantDivider {
            item = dormantDivider
            self.dormantDivider = nil
            restoreDivider(item)
        } else {
            item = NSStatusBar.system.statusItem(withLength: Self.dividerWidth)
            let retainedSlot = boundary.autosaveName.flatMap(DividerSlot.init(rawValue:)) ?? .original
            item.autosaveName = retainedSlot.other.rawValue
            item.button?.isEnabled = false
        }
        extraDivider = item

        // Switched on, the zone starts open. Where a new status item lands is macOS's
        // decision, and if it landed to the left of things the user meant to keep, they
        // would disappear at the moment of turning the switch on with no way to see what
        // went. Open, nothing moves, and the divider can be dragged into place first.
        if openingZone {
            isHiding = false
            isZoneOpen = true
            Preferences.shared.zoneOpen = true
            onToggle(false)
        }

        dividerLifecycleTask = Task { @MainActor [weak self, weak item] in
            do { try await Task.sleep(for: .milliseconds(600)) }
            catch { return }
            guard let self, let item, !self.isShuttingDown,
                  generation == self.dividerLifecycleGeneration,
                  self.extraDivider === item else { return }
            self.dividerLifecycleTask = nil
            self.updateOrder()
            self.apply()
        }
        log.info("always hidden divider added")
    }

    /// Group membership is already known while the bar is collapsed. Disabling
    /// the left group does not require revealing and measuring that same layout.
    @available(macOS 27, *)
    private func disableExtraDividerUsingCachedLayout() -> Bool {
        guard nativeRecords != nil, nativeClassificationScope != nil,
              !nativeLayoutNeedsRefresh, nativeScanTask == nil,
              !isChangingDividers, !isRearranging, !isFinishingRearrangement,
              Date().timeIntervalSince(lastWidthChange) > Self.settleTime,
              retiringDivider == nil, dormantDivider == nil, let extraDivider,
              ordered.count == 2, let main = ordered.last, let zone = ordered.first,
              Set(ordered.map(ObjectIdentifier.init))
                == Set([ObjectIdentifier(boundary), ObjectIdentifier(extraDivider)]),
              let mainAnchor = anchor(of: main), let zoneAnchor = anchor(of: zone),
              mainAnchor.isFinite, zoneAnchor.isFinite, zoneAnchor < mainAnchor else { return false }

        // Keep the slow recovery path if AppKit cannot verify this owned layout.
        let wasCollapsed = collapsedDividers.isCollapsed(zone)
        guard collapsedDividers.collapse(zone) else { return false }
        if !wasCollapsed { lastWidthChange = Date() }
        zone.button?.image = nil
        boundary = main
        dormantDivider = zone
        self.extraDivider = nil
        ordered = [main]
        isZoneOpen = false
        Preferences.shared.zoneOpen = false
        persistSingleDividerIdentity()
        // The cached records remain valid. Their old left-group members now
        // belong to the ordinary hidden group under the same main anchor.
        NotificationCenter.default.post(name: NativeMenuBarArrangement.didRefresh, object: nil)
        apply()
        log.info("always hidden divider disabled using cached layout")
        return true
    }

    private func removeExtraDivider() {
        guard !isShuttingDown, let extraDivider else { return }
        if #available(macOS 27, *), disableExtraDividerUsingCachedLayout() { return }
        let generation = beginDividerLifecycle()
        // Roles follow the last fully revealed geometry, not creation order.
        // Keep the rightmost item with its own name and retire the leftmost one.
        let item: NSStatusItem
        if ordered.count == 2, let main = ordered.last, let zone = ordered.first {
            boundary = main
            item = zone
        } else {
            item = extraDivider
        }
        retiringDivider = item
        self.extraDivider = nil
        ordered = [boundary]
        persistSingleDividerIdentity()
        isZoneOpen = false
        Preferences.shared.zoneOpen = false

        // Reveal both before deciding which native object is on the left. On
        // macOS 27 that object becomes a zero-width dormant slot; uninstalling it
        // can asynchronously delete its autosaved position after a local restore.
        setLength(item, Self.dividerWidth)
        setLength(boundary, Self.dividerWidth)

        dividerLifecycleTask = Task { @MainActor [weak self, weak item] in
            do { try await Task.sleep(for: .milliseconds(600)) }
            catch { return }
            guard let self, let item, !self.isShuttingDown,
                  generation == self.dividerLifecycleGeneration,
                  self.retiringDivider === item else { return }
            // A setting can change before the previous Command-drag scan has
            // settled. Both items have now been narrow and revealed for 600ms.
            let retired = self.resolveRetiringDividerOrder() ?? item
            if #available(macOS 27, *) {
                // Even an unknown future layout must retain the native object:
                // uninstalling it is known to delete its saved position later.
                self.dormantDivider = retired
                if self.collapsedDividers.collapse(retired) {
                    retired.button?.image = nil
                    self.lastWidthChange = Date()
                } else {
                    self.restoreDivider(retired)
                    retired.button?.image = Self.dividerImage(doubled: true)
                }
            } else {
                self.removeDividerPreservingPosition(retired)
            }
            self.retiringDivider = nil
            self.anchors.removeValue(forKey: ObjectIdentifier(retired))
            do { try await Task.sleep(for: .milliseconds(600)) }
            catch { return }
            guard !self.isShuttingDown, generation == self.dividerLifecycleGeneration else { return }
            self.dividerLifecycleTask = nil
            self.updateOrder()
            self.apply()
        }
        log.info("always hidden divider disabled")
    }

    private func resolveRetiringDividerOrder() -> NSStatusItem? {
        guard let retiringDivider else { return nil }
        if let kept = boundary.button?.window?.frame,
           let removed = retiringDivider.button?.window?.frame,
           kept.width >= Self.dividerWidth, removed.width >= Self.dividerWidth,
           kept.midX.isFinite, removed.midX.isFinite,
           kept.midX < removed.midX {
            let previous = boundary
            boundary = retiringDivider
            self.retiringDivider = previous
        }
        ordered = [boundary]
        persistSingleDividerIdentity()
        return self.retiringDivider
    }

    private func persistSingleDividerIdentity() {
        guard !Preferences.shared.alwaysHiddenEnabled,
              let name = boundary.autosaveName, DividerSlot(rawValue: name) != nil,
              UserDefaults.standard.string(forKey: Self.retainedDividerIdentityKey) != name else { return }
        UserDefaults.standard.set(name, forKey: Self.retainedDividerIdentityKey)
    }

    private func removeDividerPreservingPosition(_ item: NSStatusItem) {
        collapsedDividers.release(item)
        guard let autosaveName = item.autosaveName, !autosaveName.isEmpty else {
            NSStatusBar.system.removeStatusItem(item)
            return
        }
        let defaults = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier ?? "io.github.snowdrit.Cornice"
        let key = "NSStatusItem Preferred Position \(autosaveName)"
        // Read immediately before removal, so a user's latest drag wins. Do not
        // read registered defaults or reset autosaveName: nil clears saved data.
        let saved = defaults.persistentDomain(forName: domain)?[key]
        NSStatusBar.system.removeStatusItem(item)
        // AppKit can delete its position when removing the item. Restore only
        // that deletion, never a concurrently written replacement (zero is valid).
        if let saved, defaults.persistentDomain(forName: domain)?[key] == nil {
            defaults.set(saved, forKey: key)
        }
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
