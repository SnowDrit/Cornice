# Cornice

A free, open-source menu bar manager for macOS.

A *cornice* is the horizontal moulding that runs along the top edge of a building.
The menu bar is the cornice of your screen.

## What it does

You place a divider in the menu bar. Everything to its left hides when you click the
chevron, and comes back when you click again.

```
[ hidden ]  │  [ visible ]  ❯
```

- **Hide and reveal** — one click, no delay
- **You decide where the line falls** — ⌘-drag the divider; Cornice never moves it
- **Auto-hide** — optionally put the icons away once the pointer leaves the menu bar
- **Open at login**
- **Appearance** — divider thickness and height, five choices of chevron
- **16 languages**, switched without restarting

**No permissions are needed to use it.** Hiding and revealing are done with Cornice's own
status item, which any application may resize freely. Accessibility is asked for once,
and only so the settings window can list your icons by name.

## What it deliberately does not do

Cornice does not move other applications' icons for you, so there is no checklist of
things to hide. The only way to do that is a synthesised ⌘-drag: it is unreliable on
macOS 26 today, and macOS 27 gives the gesture to Mission Control. Placing the divider is
a one-off, and you do it by hand.

No second menu bar, no screen capture, no widgets, no triggers, no profiles, no menu bar
styling, no per-icon hotkeys. Those are what make the other tools large, and they are the
first things to break.

## Why

Menu bar managers on macOS are in a bad way:

- **Ice** (29k stars) — last stable release October 2024, repository untouched since
  September 2025, 400+ open issues. Does not support macOS 26.
- **SaneBar** — [sunset by its author on 1 July 2026](https://github.com/sane-apps/SaneBar/releases/tag/sunset)
  and relicensed to MIT, because macOS 27 breaks it.
- **Bartender** — commercial, and its macOS 27 build is an early technical preview with
  most features not yet restored.

Apple provides **no public API** for managing other applications' menu bar items. Every
tool in this category is built on accessibility APIs and undocumented behaviour, and
every macOS release moves the ground.

Cornice's answer is to need almost none of it. The thing you do every day — hide, reveal
— touches nothing Apple has signalled it will change.

## Requirements

- macOS 26 (Tahoe) or later, Apple Silicon
- Accessibility permission, only for the settings window's item list

## macOS 27

The parts of Cornice that need permissions are the parts you use least. If macOS 27
withdraws them, the settings window loses its list of icon names; hiding and revealing
carry on, because that path asks the system for nothing.

## Releasing

Pushing a tag builds and publishes:

```bash
git tag -a v0.2.0 -m "Cornice 0.2.0"
git push --follow-tags origin main
```

The workflow in `.github/workflows/release.yml` builds on a macOS runner, refuses to
ship a sandboxed bundle, and attaches `Cornice.zip` to a pre-release.

Those builds are **ad-hoc signed**, because the runner has no certificate. macOS will
warn on first open, and — because the Accessibility permission is keyed to the signature —
it has to be granted again after each such update. A build signed on your own machine
does not have that problem. Adding a real certificate to the workflow via repository
secrets would fix it for everyone.

## Building

```bash
git clone https://github.com/SnowDrit/Cornice.git
cd Cornice
open Cornice.xcodeproj
```

Set your own signing team in the target settings. A real signing certificate is needed
rather than ad-hoc signing, otherwise macOS revokes the Accessibility permission on every
rebuild. The app must **not** be sandboxed — Xcode's template enables the sandbox, and a
sandboxed build sees only its own status item while reporting no error at all.

## Roadmap

| Stage | Goal | Status |
|-------|------|--------|
| 0 | Toolchain, signing, stable code signature | ✅ |
| 1 | Menu bar agent | ✅ |
| 2 | Read the menu bar by name | ✅ |
| 3 | Spike: reposition another app's item | ⚠️ passed once, does not reproduce |
| 4 | Divider, hide and reveal | ✅ |
| 5 | Settings, appearance, languages | ✅ |
| 6 | A second divider for an always-hidden zone | later |

Stage 3 was meant to be the go/no-go for moving items automatically. It worked three
times and then never again — not after a reboot, a fresh permission, or rebuilding the
exact commit that had passed. Nine explanations were tested and ruled out. The feature
was dropped rather than shipped on something that behaves like that; the code survives
behind `ItemMover` and nothing in the product calls it.

## License

GPL-3.0. See [LICENSE](LICENSE).

Cornice studies [Ice](https://github.com/jordanbaird/Ice) (GPL-3.0) as a reference for
menu bar item manipulation. GPL-3.0 keeps that relationship unambiguous.
