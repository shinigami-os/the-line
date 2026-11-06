# The Line

A Quickshell shell for Kira Linux, built on one line. The line crosses the top of the screen and tiles hang beneath it. Notifications, volume, workspaces and music all play out on the line, and the tiles grow into panels instead of opening popups.

Working name; the final name is not chosen yet.

## Status

Runs on Hyprland (FHT comes later). Done so far:

- `Theme` and `Anim` singletons (colours, fonts, the whole motion system)
- the line: end caps, workspace marker, volume/brightness gauge, notification pulse
- top-left tile at rest: workspace numerals and window title
- top-centre tile: clock, notification toast, notifications panel and calendar
- top-right tile: Wi-Fi, volume, battery, and quick settings (toggles, sliders, reduce motion, power)

Next: launcher, music, fullscreen, Super hints, Kira's voice.

## Run

```sh
qs -p /path/to/this/repo
THE_LINE_SCREENS=HDMI-A-1 qs -p /path/to/this/repo   # one screen only
```

Test from another terminal:

```sh
qs -p . ipc call line notify build "cargo build finished" "0 errors"
qs -p . ipc call line gauge vol 0.64
qs -p . ipc call line toggle eDP-1 tc    # open the notifications panel
qs -p . ipc call line close
```

## Layout

```
shell.qml         entry point and IPC
services/         singletons: Theme, Anim, Config, UiState, LineState, Notifs, Audio, Brightness, SystemStats, Network, NightLight, Power, Time
modules/common/   Tile (tile that grows into a panel), PanelItem, Toggle, LineSlider, Icon
modules/line/     the line and the per-screen surface
modules/tiles/    the three tiles and their panels
assets/           quotes and other static files
scripts/          helpers
```

## Config

`~/.config/the-line/config.json`, every key optional:

```json
{ "accent": "#9A5CFF", "reduceMotion": false, "motionScale": 1.0, "screens": [] }
```

## Needs

Quickshell 0.3 with Hyprland, PipeWire, UPower and Bluetooth support, Hyprland, NetworkManager (nmcli), brightnessctl, hyprlock, loginctl, and optionally hyprsunset for night light. Fonts: Raleway and IBM Plex Mono (JetBrains Mono is the fallback).

Hyprland layer rule to avoid its own fade on the surface: `noanim` for the `the-line` namespace.
