# Cornice

A free, open-source menu bar manager for macOS.

A *cornice* is the horizontal moulding that runs along the top edge of a building.
The menu bar is the cornice of your screen.

> **Status: early development.** Nothing works yet. See [Roadmap](#roadmap).

## Why

Menu bar managers on macOS are in a bad way:

- **Ice** (29k stars) — last stable release October 2024, repository untouched since
  September 2025, 400+ open issues. Does not support macOS 26.
- **SaneBar** — [sunset by its author on 1 July 2026](https://github.com/sane-apps/SaneBar/releases/tag/sunset)
  and relicensed to MIT, because macOS 27 breaks it.
- **Bartender** — commercial, and its macOS 27 build is an early technical preview
  with most features not yet restored.

Apple provides **no public API** for managing other applications' menu bar items.
Every tool in this category is built on accessibility APIs and undocumented behaviour,
and every macOS release moves the ground.

Cornice does not try to be another full clone. It implements one thing well, and it is
deliberately built so that the fragile part is small and replaceable.

## What it does

- Hide menu bar items you don't need right now; click to reveal them
- You place the divider by ⌘-dragging it; everything to its left hides
- Auto-collapse once the pointer leaves the menu bar
- Launch at login
- A settings window that lists what is currently hidden, by name

Cornice does **not** move other applications' icons for you. It cannot: the only
mechanism for that is a synthesised ⌘-drag, which is unreliable today and is being
removed in macOS 27. Placing the divider is a one-off, and it is done by hand.

## What it deliberately does not do

No second menu bar, no screen capture, no widgets, no triggers, no profiles, no menu bar
styling, no per-icon hotkeys. Those features are what make the other tools large, and
they are the first things to break.

## Requirements

- macOS 26 (Tahoe) or later, Apple Silicon
- Accessibility permission (required to enumerate and reposition items)
- **No** Screen Recording permission — item icons come from the owning application,
  not from screenshots

## Known limitation: macOS 27

Repositioning another application's menu bar item is done by synthesising a ⌘-drag.
On macOS 27 "Golden Gate" that gesture is intercepted by Mission Control, and Apple has
published no replacement API
([developer forums](https://developer.apple.com/forums/thread/832823)).

When that lands, **changing** your configuration will stop working. Items already
arranged will keep hiding and revealing normally, because that path uses only Cornice's
own status items and requires no permissions at all.

The affected code is isolated behind a single interface — see [ARCHITECTURE.md](ARCHITECTURE.md).

## Roadmap

| Stage | Goal | Status |
|-------|------|--------|
| 0 | Toolchain, signing, stable code signature | ✅ done |
| 1 | Empty signed app, one status item | ✅ done |
| 2 | Accessibility, enumerate items by name | ✅ done |
| 3 | **Spike:** reposition an item | ✅ **passed** |
| 4 | Separator, collapse and reveal | ✅ **done** |
| 5 | Settings, auto-collapse, launch at login | ✅ done |
| 6 | Second divider for Always Hidden | later |

Stage 3 was the go/no-go: if synthesising a ⌘-drag did not work, the named-item approach
would not be viable and the design would fall back to positional hiding.

**It works on macOS 26.5.** Three consecutive runs moved another application's status
item across Cornice's separator and back, verified by comparing which side of the
separator the item sat on before and after each drag. No Screen Recording needed — the
events are addressed by screen position rather than by window id.

This says nothing about macOS 27, where the gesture is expected to be claimed by
Mission Control.

## Building

```bash
git clone https://github.com/SnowDrit/Cornice.git
cd Cornice
open Cornice.xcodeproj
```

Set your own signing team in the target settings. A real signing certificate (not
ad-hoc) is needed, otherwise macOS revokes the Accessibility permission on every rebuild.

## License

GPL-3.0. See [LICENSE](LICENSE).

Cornice studies [Ice](https://github.com/jordanbaird/Ice) (GPL-3.0) as a reference for
menu bar item manipulation. GPL-3.0 keeps that relationship unambiguous.
