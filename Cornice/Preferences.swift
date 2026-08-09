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
        defaults.register(defaults: [
            Key.autoCollapse: true,
            Key.autoCollapseDelay: 0.4,
            Key.startHidden: true,
        ])
    }

    private enum Key {
        static let autoCollapse = "autoCollapse"
        static let autoCollapseDelay = "autoCollapseDelay"
        static let startHidden = "startHidden"
        static let wasHiding = "wasHiding"
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
