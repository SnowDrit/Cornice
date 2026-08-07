//
//  MenuBarItem.swift
//  Cornice
//

import Foundation

/// One status item belonging to some application.
///
/// Deliberately a plain value: no `AXUIElement`, no window id, nothing that ties it to
/// the mechanism that produced it. Configuration and the settings UI work with these and
/// stay unaware of how the menu bar was read. See ARCHITECTURE.md.
struct MenuBarItem: Equatable, Hashable, Identifiable, Sendable {

    /// Bundle identifier of the owning application.
    let ownerBundleID: String

    /// Localised application name, for display.
    let ownerName: String

    /// Position among *this application's* items, left to right as the accessibility
    /// API reports them. Applications with several items (CleanShot X has two) are
    /// distinguished by this.
    let index: Int

    /// Accessibility title, when the application provides one. Often empty.
    let title: String?

    /// Where the item currently sits, in screen coordinates. Absent if the item is
    /// off-screen, which is exactly what happens once it is hidden.
    let frame: CGRect?

    /// Stable identity used in the configuration file.
    ///
    /// Same scheme Bartender writes to its preferences, e.g.
    /// `pl.maketheweb.cleanshotx-Item-0`. Keeping the format identical is what makes
    /// importing an existing Bartender setup a straight mapping rather than guesswork.
    var id: String { "\(ownerBundleID)-Item-\(index)" }

    var isOnScreen: Bool { frame != nil }
}
