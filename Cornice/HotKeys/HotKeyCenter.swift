//
//  HotKeyCenter.swift
//  Cornice
//

import AppKit
import Carbon.HIToolbox
import OSLog

/// Which of Cornice's actions a hot key can be pointed at.
///
/// Deliberately short. Every entry here is something the menu bar half of Cornice can do
/// on its own, without Accessibility and without moving anybody's status item.
enum HotKeyAction: String, CaseIterable, Identifiable, Sendable {
    case toggleHiding
    case toggleAlwaysHidden
    case toggleAutoCollapse

    var id: String { rawValue }

    /// English, and therefore also the localisation key.
    var title: String {
        switch self {
        case .toggleHiding:       "Hide or reveal the icons"
        case .toggleAlwaysHidden: "Open or close the always hidden zone"
        case .toggleAutoCollapse: "Turn automatic hiding on or off"
        }
    }

    var storageKey: String { "hotKey.\(rawValue)" }
}

/// Registers Cornice's hot keys with the system and calls back when one is pressed.
///
/// Carbon's `RegisterEventHotKey` rather than a global event monitor, and that choice is
/// the whole point: a monitor would need Accessibility, and hiding the icons is the daily
/// path that Cornice promises works without asking for anything. Carbon hot keys need no
/// permission at all. The API is old and has been left alone for twenty years, which for
/// this purpose is a recommendation.
@MainActor
final class HotKeyCenter {

    /// Four letters identifying the owner of the hot key, as Carbon wants.
    private static let signature: OSType = {
        let chars = Array("CRNC".utf8)
        return chars.reduce(OSType(0)) { ($0 << 8) | OSType($1) }
    }()

    private struct Registration {
        let ref: EventHotKeyRef
        let action: HotKeyAction
    }

    private var registrations: [UInt32: Registration] = [:]
    private var handler: EventHandlerRef?
    private var nextID: UInt32 = 1

    /// Called on the main thread when a registered combination is pressed.
    var onAction: ((HotKeyAction) -> Void)?

    // MARK: - Wiring

    /// Reads every binding out of preferences and makes the system agree with it.
    ///
    /// Written as a full teardown and rebuild rather than a diff. There are two hot keys;
    /// working out which one changed costs more code than simply doing both, and a stale
    /// registration is the kind of bug that only shows up as somebody else's keyboard
    /// shortcut mysteriously not working.
    func refresh() {
        unregisterAll()
        installHandlerIfNeeded()

        for action in HotKeyAction.allCases {
            guard let hotKey = Preferences.shared.hotKey(for: action) else { continue }
            register(hotKey, for: action)
        }
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed))

        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return noErr }

            var id = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &id)
            guard status == noErr else { return noErr }

            // Carbon delivers on the main thread. Checked rather than assumed, because
            // `assumeIsolated` traps when it is wrong and a keyboard shortcut is not
            // worth crashing the app the user was typing into.
            guard Thread.isMainThread else { return noErr }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { center.fire(id.id) }
            return noErr
        }

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler)

        if status != noErr {
            log.error("could not install the hot key handler: \(status, privacy: .public)")
        }
    }

    private func register(_ hotKey: HotKey, for action: HotKeyAction) {
        let id = EventHotKeyID(signature: Self.signature, id: nextID)
        var ref: EventHotKeyRef?

        let status = RegisterEventHotKey(
            hotKey.keyCode,
            hotKey.modifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &ref)

        guard status == noErr, let ref else {
            // Almost always means somebody else already owns the combination. Nothing to
            // be done about it from here, and refusing loudly is worse than saying so in
            // the log and leaving the binding visibly unbound.
            log.error("""
                \(hotKey.label, privacy: .public) could not be registered, \
                status \(status, privacy: .public)
                """)
            return
        }

        registrations[nextID] = Registration(ref: ref, action: action)
        nextID += 1
        log.info("\(hotKey.label, privacy: .public) registered for \(action.rawValue, privacy: .public)")
    }

    private func unregisterAll() {
        for registration in registrations.values {
            UnregisterEventHotKey(registration.ref)
        }
        registrations.removeAll()
    }

    private func fire(_ id: UInt32) {
        guard let registration = registrations[id] else { return }
        onAction?(registration.action)
    }

    /// Reports whether a combination is free, by taking it and giving it straight back.
    ///
    /// There is no way to ask the system who owns a hot key, so the only honest test is to
    /// try to register it. Done at recording time so the user finds out immediately rather
    /// than by pressing it later and watching nothing happen.
    static func isAvailable(_ hotKey: HotKey) -> Bool {
        var ref: EventHotKeyRef?
        let probe = EventHotKeyID(signature: signature, id: UInt32.max)
        let status = RegisterEventHotKey(
            hotKey.keyCode, hotKey.modifiers, probe, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        UnregisterEventHotKey(ref)
        return true
    }
}
