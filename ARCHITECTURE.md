# Architecture

This document records *why* Cornice is shaped the way it is. The shape is driven almost
entirely by one fact: Apple provides no public API for managing other applications' menu
bar items, and the unofficial mechanisms are being closed off.

## The central decision

Cornice needs no permissions for what it does every day.

Hiding is not an operation on somebody else's item. It is Cornice's own status item
becoming wide enough that everything to its left has nowhere to sit and falls off the
edge of the screen. An application may resize its own status item freely, so this path
involves no accessibility API, no screen capture, no synthetic events, and nothing
undocumented.

| Mechanism | How | Permission | How often | Risk |
|-----------|-----|-----------|-----------|------|
| Hide, reveal | Width of Cornice's own status item | **none** | constantly | none known |
| List items by name | `AXExtrasMenuBar` | Accessibility | settings window only | Apple is tightening this |
| Reposition another item | Synthetic ⌘-drag via `CGEvent` | Accessibility | **not used** | broken, and removed in macOS 27 |

Everything above the first row is optional. If the second stops working, the settings
window loses the names; hiding still works. That is the property the whole design exists
to protect.

## Two items, unrelated in space

```
[ hidden items ][ │ boundary — grows ][ visible items ][ ❯ toggle ]
```

The **boundary** is where the user dragged it, and Cornice never moves it. Its position
*is* the configuration — macOS already persists that under `NSStatusItem Preferred
Position`, so there is nothing else to store.

The **toggle** is a switch. It is never resized, so its glyph draws like any other status
icon. Where it sits means nothing; it is placed at the right-hand end on each launch and
is otherwise the user's to move.

**They are deliberately not tied together.** Making them adjacent — so the pair could
read as one control — is what caused every failure this file's history records. A status
item cannot be placed next to another one on demand:

- its saved position is consulted when it is created, and at no other time, so changing
  its width does not make macOS look again
- the number written and the position produced are not on the same scale
- feeding the observed error back diverges, and the item ends up at the far left
- computed into place it lands tens of points away — close enough to look right, far
  enough that whatever sits in the gap never hides

Dropping the requirement deleted all of it, along with an alignment timer and a
rebuild-on-drift.

## One item cannot do both jobs

A status item wide enough to hide things does not render. Six approaches were tried to
keep a chevron visible on it — centring the image, padding the image to the item's width,
disabling image scaling, a right-aligned title, a right-aligned paragraph style, and a
hand-positioned subview. The last measured correct and still drew nothing:

    length=1218  buttonBounds=1218  window=1234  chevronX=1190

A glyph 28 points from the trailing edge of a 1218 point button lands on screen. macOS
appears simply not to render an item too wide for the bar: laid out for spacing, skipped
for display. No amount of drawing code changes that, which is why the switch and the
boundary are separate items.

## Module boundaries

```
SeparatorController  own status items; width toggling. No permissions.
                     The daily path. Keep it free of dependencies on anything below.

ItemEnumerator       reads the menu bar via AXExtrasMenuBar.
                     Feeds the settings window's list, nothing else.

ItemMover            repositions another app's item.
                     NOT USED BY THE PRODUCT. Kept behind its protocol because the
                     knowledge in it is expensive and was hard won.

Preferences          behaviour and appearance. Pure data.

SettingsView         SwiftUI. Talks to Preferences, and to the enumerator only
                     through its protocol.
```

Do not let `ItemMover` details leak upward. No `CGEvent`, no window IDs, and no
`AXUIElement` in `Preferences` or `SettingsView`.

## Why ItemMover is not used

Moving another application's item is the only way to build a named configuration — "hide
Telegram" means putting Telegram to the left of the boundary. It was implemented, and it
worked: three consecutive runs dragged an item across the boundary and back on
macOS 26.5.

It then stopped, and never worked again. Not after a reboot, not after re-granting
Accessibility, and not when the exact commit that had passed was checked out and rebuilt.
Ruled out, each by measurement rather than assumption: the vertical coordinate (four
heights swept), pointer speed and step count, the calling thread, a stuck mouse button,
secure input mode, a competing menu bar manager, an oversized separator left in the bar,
⌘ as an event flag versus a real key press, and the event injection point. A real
trackpad ⌘-drag rearranges the menu bar perfectly throughout.

macOS 27 gives that gesture to Mission Control, so the feature had an expiry date
regardless. The configuration is positional instead, which needs none of it.

## Development notes

Things that cost hours and are not visible in the code:

- **The target must not be sandboxed.** Xcode's macOS app template sets
  `ENABLE_APP_SANDBOX = YES`, and there is no `.entitlements` file in the source tree and
  no literal "Sandbox" string in the project to grep for. A sandboxed build reports
  `AXIsProcessTrusted() == true`, enumerates without error, and finds exactly one item —
  its own. Check the shipped signature, not the project:

      codesign -d --entitlements - /path/to/Cornice.app

- **Sign with a real certificate.** The designated requirement then keys on bundle id and
  certificate rather than `cdhash`, so Accessibility survives rebuilds. Verified across
  three builds with differing `cdhash` and an unchanged requirement.

- **Cap the accessibility timeout.** `AXUIElementCopyAttributeValue` defaults to roughly
  six seconds per unanswered request, and a few slow processes serialise into what looks
  like a deadlock. Capped at 250ms per application.

- **A hidden item still has a frame**, at a large negative x — exactly as Bartender's
  hidden items do. Checking only whether an item is present reports nothing hidden while
  the screen plainly shows otherwise.

- **Do not ask AX where your own item is.** In-process it answers in a different
  coordinate space: this app's own item described itself as `x=7 y=888` while sitting near
  x=935. Read the item's window frame instead.

- **Narrowing restores the bar; removing does not.** Removing a status item makes macOS
  rebuild the bar, and items that had been pushed off stay off. Narrow first, let it
  settle, remove afterwards if at all.

- **Auto-collapse defaults to off.** On by default it reads as the toggle working only
  every other press: reveal, move the pointer away, and the icons vanish again half a
  second later.

- Any other menu bar manager running at the same time will fight Cornice for the same
  items. Quit them before testing.
