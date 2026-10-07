import AppKit

/// Keeps owned divider identities while removing their layout and hit-test width.
/// Capture anchors before collapse; restored frames require a settled layout.
@MainActor
final class CollapsedStatusItem {
    private struct Entry {
        let item: NSStatusItem
        let button: NSStatusBarButton
        let container: NSView
        let contentView: NSView
        let window: NSWindow
        let constraint: NSLayoutConstraint
        let wasActive: Bool

        var hasSameLayout: Bool {
            item.button === button && button.superview === container &&
                button.window === window && window.contentView === contentView &&
                container.window === window && constraint.firstItem === contentView &&
                constraint.secondItem === container
        }
    }

    private let restoredLength: CGFloat
    private var entries: [ObjectIdentifier: Entry] = [:]

    init(restoredLength: CGFloat = 10) {
        precondition(restoredLength.isFinite && restoredLength > 0)
        self.restoredLength = restoredLength
    }

    var hasCollapsedItems: Bool { !entries.isEmpty }

    func isCollapsed(_ item: NSStatusItem) -> Bool {
        entries[ObjectIdentifier(item)] != nil
    }

    /// True means the verified layout was updated, not that the renderer settled.
    /// On false the caller must keep a visible, inert divider, not a blank slot.
    @discardableResult
    func collapse(_ item: NSStatusItem) -> Bool {
        guard Bundle.main.bundleIdentifier == "io.github.snowdrit.Cornice",
              let name = item.autosaveName,
              ["CorniceBoundary", "CorniceAlwaysHidden"].contains(name) else { return false }
        let identifier = ObjectIdentifier(item)
        let entry: Entry
        if let existing = entries[identifier] {
            guard existing.hasSameLayout else {
                restore(item)
                return false
            }
            if !existing.constraint.isActive, item.length == 0, existing.window.frame.width == 0 {
                return true
            }
            entry = existing
        } else {
            guard let button = item.button,
                  let container = button.superview,
                  let window = button.window,
                  let content = window.contentView,
                  container.window === window,
                  container === content || container.isDescendant(of: content) else { return false }

            // Independently implemented from the layout verified by our probe.
            // Related technique in Ice2 (GPL-3.0-or-later), source reference:
            // https://github.com/teddychan/ice-2/blob/1afd4e91ff5826ddc8631e36cc120f4bb41a4067/Ice/MenuBar/ControlItem/ControlItem.swift
            let candidates = content.constraintsAffectingLayout(for: .horizontal).filter {
                $0.firstItem === content && $0.secondItem === container &&
                    $0.firstAttribute == .width && $0.secondAttribute == .width &&
                    $0.relation == .equal && $0.multiplier == 1 && $0.constant.isFinite
            }
            let unique = Dictionary(candidates.map { (ObjectIdentifier($0), $0) },
                                    uniquingKeysWith: { first, _ in first })
            guard unique.count == 1, let constraint = unique.values.first else { return false }
            entry = Entry(item: item, button: button, container: container,
                          contentView: content, window: window, constraint: constraint,
                          wasActive: constraint.isActive)
            entries[identifier] = entry
        }
        entry.constraint.isActive = false
        item.length = 0
        entry.window.setContentSize(NSSize(width: 0, height: entry.window.frame.height))
        return true
    }

    /// Restore before reading new anchors, entering arrangement, or using spacers.
    @discardableResult
    func restore(_ item: NSStatusItem) -> Bool {
        guard let entry = entries.removeValue(forKey: ObjectIdentifier(item)) else { return true }
        let sameLayout = entry.hasSameLayout
        if sameLayout { entry.constraint.isActive = entry.wasActive }
        item.length = restoredLength
        return sameLayout
    }

    /// Restores and releases retained layout objects before item removal.
    func release(_ item: NSStatusItem) {
        restore(item)
    }

    func restoreAll() {
        for entry in Array(entries.values) { restore(entry.item) }
    }
}
