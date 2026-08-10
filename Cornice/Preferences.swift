//
//  Preferences.swift
//  Cornice
//

import Foundation
import Observation

/// Everything the user can change, and the only thing that persists between launches.
///
/// Deliberately small. Cornice's configuration is mostly *positional* - where the user
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
        // gone again, which looks exactly like the toggle working only every other
        // press. Bartender's 0.4 seconds is kept as the default *delay*, but it belongs
        // to a hover interaction, not to a click.
        defaults.register(defaults: [
            Key.autoCollapse: false,
            Key.autoCollapseDelay: 0.4,
            Key.startHidden: true,
            Key.dividerThickness: 1.5,
            Key.dividerHeight: 14.0,
            Key.toggleSymbol: ToggleSymbol.chevron.rawValue,
            Key.gesturesEnabled: false,
            // True, so that a first launch is not mistaken for a crashed one. Only a run
            // that actually started and then died leaves this false.
            Key.cleanExit: true,
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
        static let language = "language"
        static let gesturesEnabled = "gesturesEnabled"
        static let cleanExit = "cleanExit"
    }

    /// Interface language. Defaults to whichever of Cornice's languages the system asks
    /// for first, and to English if it asks for none of them.
    var language: Language {
        get {
            access(keyPath: \.language)
            let raw = defaults.string(forKey: Key.language) ?? ""
            return Language(rawValue: raw) ?? .systemDefault
        }
        set { withMutation(keyPath: \.language) { defaults.set(newValue.rawValue, forKey: Key.language) } }
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
    /// against: Bartender's `MouseExitDelay` was 0.4 seconds.
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

    /// Trackpad gestures for window management.
    ///
    /// Off on a fresh install and off after an update that introduces it. The gesture
    /// module is the only part of Cornice that needs Accessibility to do its everyday job,
    /// and a permission dialog for a feature nobody asked for is exactly the kind of
    /// welcome this app is trying not to give.
    var gesturesEnabled: Bool {
        get { access(keyPath: \.gesturesEnabled); return defaults.bool(forKey: Key.gesturesEnabled) }
        set { withMutation(keyPath: \.gesturesEnabled) { defaults.set(newValue, forKey: Key.gesturesEnabled) } }
    }

    /// The combination bound to an action, or `nil` when the user has not set one.
    ///
    /// Nothing is bound out of the box. Cornice is not important enough to claim a
    /// keyboard shortcut on a machine it was just installed on, and a shortcut the user
    /// chose is one they will remember.
    func hotKey(for action: HotKeyAction) -> HotKey? {
        guard let data = defaults.data(forKey: action.storageKey) else { return nil }
        return try? JSONDecoder().decode(HotKey.self, from: data)
    }

    func setHotKey(_ hotKey: HotKey?, for action: HotKeyAction) {
        guard let hotKey else {
            defaults.removeObject(forKey: action.storageKey)
            return
        }
        guard let data = try? JSONEncoder().encode(hotKey) else { return }
        defaults.set(data, forKey: action.storageKey)
    }

    /// Whether the previous run ended by being quit rather than by dying.
    ///
    /// Written `true` from `applicationWillTerminate`, which a crash never reaches, and set
    /// back to `false` immediately on launch. Reading `false` at startup therefore means
    /// the last run did not finish, and Cornice comes up revealed no matter what the other
    /// preferences say. Without it a crash while hiding leaves the icons parked off the
    /// side of the screen, and the app that put them there is no longer running to bring
    /// them back.
    var cleanExit: Bool {
        get { defaults.bool(forKey: Key.cleanExit) }
        set { defaults.set(newValue, forKey: Key.cleanExit) }
    }
}
