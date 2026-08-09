//
//  Preferences.swift
//  Cornice
//

import Foundation
import Observation

/// Everything the user can change, and the only thing that persists between launches.
///
/// Deliberately small. Cornice's configuration is mostly *positional* — where the user
/// dragged the boundary is the configuration, and macOS already remembers that under
/// `NSStatusItem Preferred Position`. What is left is behaviour, and behaviour is a
/// handful of values.
@Observable
final class Preferences {

    static let shared = Preferences()

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Auto-collapse is off until asked for. On by default it reads as a bug: the
        // icons are revealed, the pointer moves away, and half a second later they are
        // gone again — which looks exactly like the toggle working only every other
        // press. Bartender's 0.4 seconds is kept as the default *delay*, but it belongs
        // to a hover interaction, not to a click.
        defaults.register(defaults: [
            Key.autoCollapse: false,
            Key.autoCollapseDelay: 0.4,
            Key.startHidden: true,
            Key.dividerThickness: 1.5,
            Key.dividerHeight: 14.0,
            Key.toggleSymbol: ToggleSymbol.chevron.rawValue,
        ])
    }

    private enum Key {
        static let autoCollapse = "autoCollapse"
        static let autoCollapseDelay = "autoCollapseDelay"
        static let startHidden = "startHidden"
        static let wasHiding = "wasHiding"
        static let dividerThickness = "dividerThickness"
        static let dividerHeight = "dividerHeight"
        static let toggleSymbol = "toggleSymbol"
    }

    /// Which pair of glyphs the toggle uses. The pair matters, not the single icon: it
    /// has to point one way while hiding and the other while revealing.
    enum ToggleSymbol: String, CaseIterable, Identifiable {
        case chevron, chevronCompact, arrow, triangle, sidebar

        var id: String { rawValue }

        var label: String {
            switch self {
            case .chevron:        "Chevron"
            case .chevronCompact: "Chevron, compact"
            case .arrow:          "Arrow"
            case .triangle:       "Triangle"
            case .sidebar:        "Sidebar"
            }
        }

        func symbolName(hiding: Bool) -> String {
            switch self {
            case .chevron:        hiding ? "chevron.left" : "chevron.right"
            case .chevronCompact: hiding ? "chevron.compact.left" : "chevron.compact.right"
            case .arrow:          hiding ? "arrow.left" : "arrow.right"
            case .triangle:       hiding ? "arrowtriangle.left.fill" : "arrowtriangle.right.fill"
            case .sidebar:        hiding ? "sidebar.left" : "sidebar.right"
            }
        }
    }

    /// Width of the bar drawn for the divider, in points.
    var dividerThickness: Double {
        get { access(keyPath: \.dividerThickness); return defaults.double(forKey: Key.dividerThickness) }
        set { withMutation(keyPath: \.dividerThickness) { defaults.set(newValue, forKey: Key.dividerThickness) } }
    }

    /// How tall the divider is. Shorter reads as a hairline, taller as a wall.
    var dividerHeight: Double {
        get { access(keyPath: \.dividerHeight); return defaults.double(forKey: Key.dividerHeight) }
        set { withMutation(keyPath: \.dividerHeight) { defaults.set(newValue, forKey: Key.dividerHeight) } }
    }

    var toggleSymbol: ToggleSymbol {
        get {
            access(keyPath: \.toggleSymbol)
            let raw = defaults.string(forKey: Key.toggleSymbol) ?? ""
            return ToggleSymbol(rawValue: raw) ?? .chevron
        }
        set { withMutation(keyPath: \.toggleSymbol) { defaults.set(newValue.rawValue, forKey: Key.toggleSymbol) } }
    }

    /// Put the icons away again once the pointer leaves the menu bar.
    var autoCollapse: Bool {
        get { access(keyPath: \.autoCollapse); return defaults.bool(forKey: Key.autoCollapse) }
        set { withMutation(keyPath: \.autoCollapse) { defaults.set(newValue, forKey: Key.autoCollapse) } }
    }

    /// How long to wait after the pointer leaves. Matches the delay this was built
    /// against — Bartender's `MouseExitDelay` was 0.4 seconds.
    var autoCollapseDelay: Double {
        get { access(keyPath: \.autoCollapseDelay); return defaults.double(forKey: Key.autoCollapseDelay) }
        set { withMutation(keyPath: \.autoCollapseDelay) { defaults.set(newValue, forKey: Key.autoCollapseDelay) } }
    }

    /// Come up hiding rather than showing everything.
    ///
    /// Off on a fresh install: with no configuration yet, hiding on first launch would
    /// remove items the user never asked Cornice to touch.
    var startHidden: Bool {
        get { access(keyPath: \.startHidden); return defaults.bool(forKey: Key.startHidden) }
        set { withMutation(keyPath: \.startHidden) { defaults.set(newValue, forKey: Key.startHidden) } }
    }

    /// The state at the last quit, used when `startHidden` is off so a restart is not
    /// visible to the user.
    var wasHiding: Bool {
        get { defaults.bool(forKey: Key.wasHiding) }
        set { defaults.set(newValue, forKey: Key.wasHiding) }
    }
}
