<div align="center">
    <img src="docs/icon.png" width="180" height="180" alt="">
    <h1>Cornice</h1>
    <p><b>A free, open-source menu bar manager for macOS.</b></p>
</div>

<div align="center">

[![Download](https://img.shields.io/badge/download-latest-brightgreen?style=flat-square)](https://github.com/SnowDrit/Cornice/releases/latest)
![Platform](https://img.shields.io/badge/platform-macOS-blue?style=flat-square)
![Requirements](https://img.shields.io/badge/requirements-macOS%2026%2B-fa4e49?style=flat-square)
![Permissions](https://img.shields.io/badge/permissions-none%20required-brightgreen?style=flat-square)
[![License](https://img.shields.io/github/license/SnowDrit/Cornice?style=flat-square)](LICENSE)

</div>

A *cornice* is the horizontal moulding that runs along the top edge of a building.
The menu bar is the cornice of your screen.

## What it does

You place a divider in the menu bar. Everything to its left hides when you click the
chevron, and comes back when you click again.

```
[ hidden ]  │  [ visible ]  ❯
```

- Hide and reveal with one click
- You choose where the line falls: ⌘-drag the divider, and Cornice never moves it
- Optional auto-hide once the pointer leaves the menu bar
- A keyboard shortcut of your choosing, for hiding and for auto-hide
- Open at login
- Adjustable divider thickness and height, five chevron styles
- [Sixteen interface languages](#languages), switched without restarting

![Cornice settings, Behaviour tab](docs/settings-behaviour.png)

**No permissions are needed for any of that.** Hiding and revealing are done with Cornice's
own status item, which any application may resize freely, and the keyboard shortcuts use an
API that asks for nothing. Cornice does not request Accessibility at startup, or at all,
unless you turn on something that cannot work without it.

## Window gestures

Off by default. Turn them on in Settings, and only then does Cornice ask for Accessibility.

Put the pointer over a window's title bar and swipe two fingers on the trackpad. Title bars
are the whole trigger surface, which is what keeps this from colliding with anything else:
nothing scrolls a title bar.

| Gesture | Result |
|---|---|
| Swipe left or right | Left or right half |
| Swipe up | Fill the screen |
| Swipe down | Put the window back where it was |
| Swipe again, straight after | Narrows to a third, then two thirds |
| Swipe up or down after that | The quarter above or below |
| Pinch in | Send the window to the Dock |

![Cornice settings, Gestures tab](docs/settings-gestures.png)

Four movements, twelve positions. A second swipe within a second and a half refines the
first rather than replacing it; pause, and the next swipe starts over.

Cornice only ever watches these events. It cannot swallow one, so a gesture read wrong still
reaches the application under your pointer exactly as it would have.

## Making it yours

The divider is drawn, not an image, so its thickness and height are yours to set, and the
preview is at real size because two points is a visible difference in a menu bar.

![Cornice settings, Appearance tab](docs/settings-appearance.png)

## Installing

Open `Cornice.dmg` from the [latest release](https://github.com/SnowDrit/Cornice/releases)
and drag the app onto the Applications shortcut.

macOS will refuse to open it the first time. The builds are signed for development and not
notarised, which needs a paid Apple Developer account. Right-click the app in Applications,
choose Open, then Open again in the warning. Once is enough.

The same limitation has a second effect, and only if you use the gestures: because the
builds are ad-hoc signed, macOS ties the Accessibility grant to that exact build, so
updating means granting it again. The menu bar half is unaffected, since it never needed the
permission in the first place.

Requires macOS 26 (Tahoe) or later on Apple Silicon.

## What it deliberately does not do

Cornice does not move other applications' icons for you, so there is no checklist of things
to hide. The only way to do that is a synthesised ⌘-drag, which is unreliable on macOS 26
and which macOS 27 hands to Mission Control. Placing the divider is a one-off you do by
hand.

No second menu bar, no screen capture, no widgets, no triggers, no profiles, no menu bar
styling, no per-icon hotkeys. Those are what make the other tools large, and they are the
first things to break.

The gesture module stops at moving windows around one screen. No thirty-gesture catalogue,
no per-application rules, no gesture for closing a window: a trackpad is not precise enough
to be trusted with something that can take unsaved work with it.

## Why

Apple provides no public API for managing other applications' menu bar items. Every tool in
this category is built on accessibility APIs and undocumented behaviour, and every macOS
release moves the ground.

- **Ice** (29k stars): last stable release October 2024, repository untouched since
  September 2025, with two unfinished dev builds after it.
- **Thaw** (9.7k stars): an active fork of Ice, on Homebrew, in twenty languages, shipping
  release candidates this month. If you want the full feature set, use it. It reads the menu
  bar continuously and rearranges items for you, which is what makes it powerful and what
  makes Accessibility non-optional for it.
- **SaneBar**: [relicensed to MIT on 1 July 2026](https://github.com/sane-apps/SaneBar/releases/tag/sunset),
  when its author announced he was winding it down over macOS 27. Development has continued
  since, so read that as a change of footing rather than an ending.
- **Bartender**: commercial, and its macOS 27 build is an early technical preview with most
  features not yet restored.

Cornice's answer is to need almost none of it. The thing you do every day, hide and reveal,
touches nothing Apple has signalled it will change, and asks for no permission at all. The
cost is that Cornice will not arrange your icons for you: you place the divider yourself,
once, and that is the whole of it.

## Languages

Cornice speaks sixteen, switched from the settings window without restarting.

<table frame="void" rules="none">
    <tr>
        <th align="left">Language</th>
        <th align="center">Flag</th>
        <th align="left">Code</th>
        <th width="30"></th>
        <th align="left">Language</th>
        <th align="center">Flag</th>
        <th align="left">Code</th>
    </tr>
    <tr>
        <td><b>English</b></td>
        <td align="center">🇬🇧</td>
        <td><code>en</code></td>
        <td width="30"></td>
        <td><b>Русский</b></td>
        <td align="center">🇷🇺</td>
        <td><code>ru</code></td>
    </tr>
    <tr>
        <td><b>Українська</b></td>
        <td align="center">🇺🇦</td>
        <td><code>uk</code></td>
        <td width="30"></td>
        <td><b>Deutsch</b></td>
        <td align="center">🇩🇪</td>
        <td><code>de</code></td>
    </tr>
    <tr>
        <td><b>Français</b></td>
        <td align="center">🇫🇷</td>
        <td><code>fr</code></td>
        <td width="30"></td>
        <td><b>Español</b></td>
        <td align="center">🇪🇸</td>
        <td><code>es</code></td>
    </tr>
    <tr>
        <td><b>Português</b></td>
        <td align="center">🇵🇹</td>
        <td><code>pt</code></td>
        <td width="30"></td>
        <td><b>Italiano</b></td>
        <td align="center">🇮🇹</td>
        <td><code>it</code></td>
    </tr>
    <tr>
        <td><b>Nederlands</b></td>
        <td align="center">🇳🇱</td>
        <td><code>nl</code></td>
        <td width="30"></td>
        <td><b>Polski</b></td>
        <td align="center">🇵🇱</td>
        <td><code>pl</code></td>
    </tr>
    <tr>
        <td><b>Čeština</b></td>
        <td align="center">🇨🇿</td>
        <td><code>cs</code></td>
        <td width="30"></td>
        <td><b>Svenska</b></td>
        <td align="center">🇸🇪</td>
        <td><code>sv</code></td>
    </tr>
    <tr>
        <td><b>Türkçe</b></td>
        <td align="center">🇹🇷</td>
        <td><code>tr</code></td>
        <td width="30"></td>
        <td><b>日本語</b></td>
        <td align="center">🇯🇵</td>
        <td><code>ja</code></td>
    </tr>
    <tr>
        <td><b>한국어</b></td>
        <td align="center">🇰🇷</td>
        <td><code>ko</code></td>
        <td width="30"></td>
        <td><b>简体中文</b></td>
        <td align="center">🇨🇳</td>
        <td><code>zh</code></td>
    </tr>
</table>

English is the source: every string in the code *is* its English text, so nothing can go
missing from it. The other fifteen are machine-made and want a native reader's eye. They are
plain dictionaries in `Cornice/Localization.swift`, keyed by that English text, so correcting
a translation is a one-line change and needs no tooling, no string catalogue and no account
anywhere.

## Contributing

Fixing a translation is the most useful thing you can do here, and the cheapest: find the
English key in `Cornice/Localization.swift`, change the string beside it in your language,
open a pull request.

## Building

```bash
git clone https://github.com/SnowDrit/Cornice.git
cd Cornice
open Cornice.xcodeproj
```

Set your own signing team in the target settings. The app must not be sandboxed: Xcode's
template enables the sandbox, and a sandboxed build sees only its own status item while
reporting no error at all.

## License

GPL-3.0. See [LICENSE](LICENSE).

Cornice studies [Ice](https://github.com/jordanbaird/Ice) (GPL-3.0) as a reference for menu
bar item manipulation. GPL-3.0 keeps that relationship unambiguous.
