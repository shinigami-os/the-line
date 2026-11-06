# The Line

The desktop shell of Kira Linux, built with Quickshell on one line. The line crosses the top of the screen and tiles hang beneath it. Notifications, volume, workspaces and music all play out on the line, and the tiles grow into panels instead of opening popups.

## Status

Runs on Hyprland (FHT comes later). Done so far:

- `Theme` and `Anim` singletons (colours, fonts, the whole motion system)
- the line: end caps, workspace marker, volume/brightness gauge, notification pulse
- top-left tile at rest: workspace numerals and window title
- top-centre tile: clock, notification toast, notifications panel and calendar
- top-right tile: performance summary, Wi-Fi, volume, battery. The summary opens the performance dashboard, the icons open quick settings (toggles, sliders, reduce motion, power)

- top-left tile grows into the launcher: apps (most launched first) and run in terminal; the panel height follows the results

- music part of the top-left tile (MPRIS) with its progress on the line; it grows into the music panel (cover, track ruler with seek, controls, player picker)

- fullscreen, in stages: the music part leaves, the tiles fold up into the line, the line withdraws into the screen edges. A notification or a level change draws the line back for the event, then it withdraws again

Next: Super hints, Kira's voice.

## Run

```sh
qs -p /path/to/this/repo
THE_LINE_SCREENS=HDMI-A-1 qs -p /path/to/this/repo   # one screen only
```

Test from another terminal:

```sh
qs -p . ipc call line notify build "cargo build finished" "0 errors"
qs -p . ipc call line gauge vol 0.64
qs -p . ipc call line toggle eDP-1 tc    # notifications (tl: launcher, tm: music, tr: quick settings, tp: performance)
qs -p . ipc call line close
qs -p . ipc call line clockFace         # the clock easter egg
qs -p . ipc call line search fire        # open the launcher with a search typed in
```

## Layout

```
shell.qml         entry point and IPC
services/         singletons: Theme, Anim, Config, UiState, LineState, Notifs, Audio, Brightness, SystemStats, Network, NightLight, Power, Media, Apps, Session, ClockFace, Time
modules/common/   Tile (tile that grows into a panel), PanelItem, Reading, Toggle, LineSlider, Icon
modules/line/     the line and the per-screen surface
modules/tiles/    the three tiles and their panels
assets/           quotes and other static files
scripts/          helpers
```

## Keybindings

The Line registers Hyprland global shortcuts under the `the-line` app id: `launcher`, `notifications`, `quicksettings`, `performance`. For example:

```lua
hl.bind("SUPER+SPACE", hl.dsp.global("the-line:launcher"))
hl.bind("SUPER+N", hl.dsp.global("the-line:notifications"))
hl.bind("SUPER+A", hl.dsp.global("the-line:quicksettings"))
```

## Config

`~/.config/the-line/config.json`, every key optional:

```json
{ "accent": "#9A5CFF", "reduceMotion": false, "motionScale": 1.0, "screens": [], "terminal": "foot" }
```

## Needs

Quickshell 0.3 with Hyprland, PipeWire, MPRIS, UPower and Bluetooth support, Hyprland, NetworkManager (nmcli), brightnessctl, procps-ng top, hyprlock, loginctl, and optionally hyprsunset for night light. Fonts: Raleway and IBM Plex Mono (JetBrains Mono is the fallback).

Hyprland layer rule to avoid its own fade on the surface: `noanim` for the `the-line` namespace. The surface sits on the top layer, and on the overlay layer while its screen shows a fullscreen window.
