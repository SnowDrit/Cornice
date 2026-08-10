//
//  HotKey.swift
//  Cornice
//

import AppKit
import Carbon.HIToolbox

/// One key combination, as the user recorded it.
///
/// Stored as a key code rather than a character, because a key code is a physical position
/// on the keyboard and survives switching layouts. The label is stored alongside it, set at
/// the moment of recording, since turning a key code back into the right character means
/// asking the current layout and Cornice would rather show what the user actually pressed.
struct HotKey: Codable, Equatable, Sendable {

    /// Virtual key code, the `kVK_` values.
    let keyCode: UInt32
    /// Carbon modifier mask: `cmdKey`, `shiftKey`, `optionKey`, `controlKey`.
    let modifiers: UInt32
    /// What to print in the settings window, for example "⌥⌘H".
    let label: String

    /// Builds one from a recorded key press, or refuses it.
    ///
    /// Two modifiers at least, and at least one of them ⌘, ⌥ or ⌃.
    ///
    /// This is stricter than the system requires, deliberately. `RegisterEventHotKey`
    /// happily hands out ⌘Q, and a global hot key outranks the front application's menu,
    /// so taking it would break Quit in every program on the machine. It cannot warn about
    /// that either: registering succeeds, and the damage only shows up later. One modifier
    /// is the whole space of ordinary menu shortcuts, and ⇧ on its own is the space of
    /// capital letters, so both are ruled out and what is left is the range utilities
    /// actually live in.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        var carbon: UInt32 = 0
        var count = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey);     count += 1 }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey);   count += 1 }
        if flags.contains(.option)  { carbon |= UInt32(optionKey);  count += 1 }
        if flags.contains(.control) { carbon |= UInt32(controlKey); count += 1 }

        let hasRealModifier = flags.contains(.command)
            || flags.contains(.option)
            || flags.contains(.control)
        guard count >= 2, hasRealModifier else { return nil }

        self.keyCode = UInt32(event.keyCode)
        self.modifiers = carbon
        self.label = Self.label(for: UInt32(event.keyCode), flags: flags, event: event)
    }

    private static func label(
        for keyCode: UInt32, flags: NSEvent.ModifierFlags, event: NSEvent
    ) -> String {
        var text = ""
        // The order Apple prints them in, which is not the order they are tested in.
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option)  { text += "⌥" }
        if flags.contains(.shift)   { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        return text + keyName(keyCode, event: event)
    }

    /// Keys that have a symbol rather than a character, plus a fall back to whatever the
    /// keyboard produced without modifiers applied.
    private static func keyName(_ keyCode: UInt32, event: NSEvent) -> String {
        switch Int(keyCode) {
        case kVK_Space:           return "Space"
        case kVK_Return:          return "↩"
        case kVK_Tab:             return "⇥"
        case kVK_Delete:          return "⌫"
        case kVK_ForwardDelete:   return "⌦"
        case kVK_Escape:          return "⎋"
        case kVK_LeftArrow:       return "←"
        case kVK_RightArrow:      return "→"
        case kVK_UpArrow:         return "↑"
        case kVK_DownArrow:       return "↓"
        case kVK_Home:            return "↖"
        case kVK_End:             return "↘"
        case kVK_PageUp:          return "⇞"
        case kVK_PageDown:        return "⇟"
        case kVK_F1:              return "F1"
        case kVK_F2:              return "F2"
        case kVK_F3:              return "F3"
        case kVK_F4:              return "F4"
        case kVK_F5:              return "F5"
        case kVK_F6:              return "F6"
        case kVK_F7:              return "F7"
        case kVK_F8:              return "F8"
        case kVK_F9:              return "F9"
        case kVK_F10:             return "F10"
        case kVK_F11:             return "F11"
        case kVK_F12:             return "F12"
        default:
            let typed = event.charactersIgnoringModifiers ?? ""
            return typed.isEmpty ? "?" : typed.uppercased()
        }
    }
}
