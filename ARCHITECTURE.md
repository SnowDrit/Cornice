# Architecture

This document records *why* Cornice is shaped the way it is. The shape is driven almost
entirely by one fact: Apple provides no public API for managing other applications' menu
bar items, and the unofficial mechanisms are being closed off.

## The central constraint

There are three distinct mechanisms involved, and they have wildly different risk profiles.
Keeping them apart is the main architectural decision.

| Mechanism | How | Permission | How often | macOS 27 |
|-----------|-----|-----------|-----------|----------|
| Collapse / reveal | Width of Cornice's **own** `NSStatusItem` | **none** | constantly | survives |
| Enumerate items | `AXExtrasMenuBar` via Accessibility | Accessibility | opening settings | at risk |
| Reposition an item | Synthetic ⌘-drag via `CGEvent` | Accessibility | on config change only | **breaks** |

The daily path — collapse and reveal — touches nothing that requires permission and
nothing that Apple has signalled it will change. An item that has already been positioned
stays positioned; the system persists that in `NSStatusItem Preferred Position`.

Therefore: **a macOS 27 regression degrades Cornice, it does not kill it.** Changing the
configuration stops working; using the existing configuration does not.

That property is only preserved if the fragile mechanism stays behind a boundary.

## Module boundaries

```
SeparatorController  own NSStatusItems; width toggling. No permissions.
                     This is the daily path. Keep it free of dependencies
                     on the two modules below.

ItemEnumerator       reads the menu bar via AXExtrasMenuBar.
                     Needed to show a named list in settings.

ItemMover            repositions another app's item.
                     THE FRAGILE PART. Everything undocumented lives here
                     and nowhere else.

Configuration        zones, hide-by-default rule, persistence, Bartender import.
                     Pure data and logic; no system calls.

SettingsUI           SwiftUI. Talks to Configuration, and to the two AX modules
                     only through their protocols.
```

`ItemMover` is a protocol with a single conforming implementation. When macOS 27 breaks
it, exactly one file is rewritten, or one implementation is swapped for another. Nothing
above it changes.

Do not let `ItemMover` details leak upward. No `CGEvent`, no window IDs, and no
`AXUIElement` in `Configuration` or `SettingsUI`.

## How hiding actually works

Hiding another application's item is not directly possible. What is possible:

1. Cornice owns a status item that acts as a **separator**.
2. Items to the left of the separator are pushed off the edge of the screen when the
   separator expands to fill the available width.
3. Which items end up to the left is decided by *position*, so a named configuration
   ("hide Telegram") is implemented as: move Telegram to the left of the separator, once.

A second separator marks the **Always Hidden** zone — items left of it are not revealed
even when the first separator collapses.

This is why the named model depends on repositioning, and therefore on the one mechanism
that is going away. The positional model would not, but it cannot express
"hide anything I have not explicitly allowed", which is the rule that keeps a menu bar
from silently filling up again.

## Zones

```
[ Always Hidden ][ sep2 ][ Hidden ][ sep1 ][ Visible ]
                                                      ← screen edge
```

- `sep1` collapsed → Hidden items pushed off screen
- `sep1` expanded → Hidden items visible, Always Hidden still off screen
- `sep2` is only moved deliberately, from settings

Default rule is **deny**: an item not listed as Visible is treated as Hidden. A newly
installed application disappears from the menu bar without the user doing anything.

## Deliberate omissions

Every one of these exists in Bartender, Ice or SaneBar, and every one is excluded here on
purpose:

- **Second menu bar** — needs a floating window and item imagery
- **Screenshot-based icons** — needs Screen Recording; application icons are enough
- **Rearranging by drag inside the menu bar** — the broken gesture, and not needed
- **Triggers, widgets, profiles, groups, search, styling, spacing, per-icon hotkeys** —
  surface area with no corresponding benefit for the intended use

The point is not minimalism for its own sake. Ice and SaneBar did not die because hiding
became impossible; they died because they depended on many mechanisms at once, and Apple
removed several of them. Fewer mechanisms means fewer ways to die.

## Testing notes

- Bartender, Ice, or any other menu bar manager running at the same time will fight
  Cornice for the same items. Quit them before testing.
- macOS 26 hides some Control Center items natively
  (`defaults read com.apple.controlcenter`). Those never appear in the menu bar at all
  and are not Cornice's to manage.
- A rebuild that changes the code signature causes macOS to revoke Accessibility. A real
  signing certificate keeps the designated requirement stable across rebuilds; ad-hoc
  signing does not.
