//
//  SeparatorController.swift
//  Cornice
//

import AppKit
import OSLog

/// Owns Cornice's own status item — the separator.
///
/// This is the one part of Cornice that needs **no permissions at all**: an application
/// may create and resize its own `NSStatusItem` freely. Hiding neighbouring items is
/// ultimately just this item growing wide enough to push them past the screen edge.
///
/// Because it depends on nothing undocumented, this is also the part expected to survive
/// future macOS releases untouched. Keep it that way: no `CGEvent`, no `AXUIElement`,
/// no window IDs here. See ARCHITECTURE.md.
@MainActor
final class SeparatorController: NSObject {

    private let item: NSStatusItem

    /// Placeholder for stage 4. For now it only swaps the icon so that a click is
    /// visibly doing something.
    private var isCollapsed = false

    override init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        // macOS persists where the user ⌘-drags this item, under the key
        // "NSStatusItem Preferred Position CorniceSeparator" in our own defaults.
        // Stage 4 relies on that position being stable across launches.
        item.autosaveName = "CorniceSeparator"

        guard let button = item.button else {
            log.error("status item has no button; menu bar may be full")
            return
        }

        button.target = self
        button.action = #selector(buttonClicked)
        updateIcon()

        log.info("separator installed")
    }

    @objc private func buttonClicked() {
        isCollapsed.toggle()
        updateIcon()
        log.info("separator clicked, collapsed=\(self.isCollapsed, privacy: .public)")
    }

    private func updateIcon() {
        let symbol = isCollapsed ? "chevron.right" : "chevron.left"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Cornice")
        // Template images adopt the menu bar's light/dark appearance automatically.
        image?.isTemplate = true
        item.button?.image = image
    }
}
