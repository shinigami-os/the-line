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

- hold Super: key hints hang from the tiles on threads (`superHints` in the config to turn off)
- Kira's voice on an empty workspace, behind the windows, from `assets/quotes.txt` plus `~/.config/the-line/quotes.txt`, with live `{placeholders}`

- notification daemon (org.freedesktop.Notifications) and the wallpaper

Next: polkit agent, Super+F1 cheat sheet, first-run welcome, launcher shortcuts section, easter eggs from the backlog.

## Session

`session/` holds everything to log into The Line from the greeter:

- `the-line.desktop`: the greeter entry, installed in `/usr/share/wayland-sessions/`
- `the-line-session`: environment, session bus, audio, then Hyprland (`/usr/bin/the-line-session`)
- `hyprland.lua`: The Line's Hyprland config (square, 1 px borders, the shell's curve and timings, the keys)

The shell is expected in `/usr/share/the-line` (or wherever `THE_LINE_DIR` points). Your own Hyprland bits go in `~/.config/the-line/hypr/` (`monitors.lua`, `apps.lua`, `custom.lua`); coming from Sleex, its monitors, app keys and custom general settings are copied there on the first login.

To try it from a checkout before it is packaged:

```sh
sudo ln -s ~/Documents/Kira-Linux/the-line /usr/share/the-line
sudo cp session/the-line-session /usr/bin/
sudo cp session/the-line.desktop /usr/share/wayland-sessions/
```

## Run (development)

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
qs -p . ipc call line say "hello"        # Kira says a line on top of the windows
```

## Layout

```
shell.qml         entry point and IPC
services/         singletons: Theme, Anim, Config, UiState, LineState, Notifs, Audio, Brightness, SystemStats, Network, NightLight, Power, Media, Apps, Session, ClockFace, Time
modules/common/   Tile (tile that grows into a panel), PanelItem, Reading, Toggle, LineSlider, Icon
modules/line/     the line and the per-screen surface
modules/tiles/    the three tiles and their panels
modules/desktop/  Kira's voice, Super key hints
assets/           quotes.txt (Kira's voice) and other static files
scripts/          helpers
```

## Keybindings

The Line registers Hyprland global shortcuts under the `the-line` app id: `launcher`, `notifications`, `quicksettings`, `performance`, `hints`. For example:

```lua
hl.bind("SUPER+SPACE", hl.dsp.global("the-line:launcher"))
hl.bind("SUPER+N", hl.dsp.global("the-line:notifications"))
hl.bind("SUPER+A", hl.dsp.global("the-line:quicksettings"))
hl.bind("SUPER+P", hl.dsp.global("the-line:performance"))
-- hold Super for the key hints (press and release)
hl.bind("SUPER_L", hl.dsp.global("the-line:hints"), { ignore_mods = true, transparent = true })
hl.bind("SUPER_L", hl.dsp.global("the-line:hints"), { ignore_mods = true, transparent = true, release = true })
```

## Config

`~/.config/the-line/config.json`, every key optional:

```json
{ "accent": "#9A5CFF", "reduceMotion": false, "motionScale": 1.0, "screens": [], "terminal": "foot",
  "wallpaper": "/usr/share/kira/wallpapers/default.png", "superHints": true }
```

## Needs

Quickshell 0.3 with Hyprland, PipeWire, MPRIS, UPower and Bluetooth support, Hyprland, NetworkManager (nmcli), brightnessctl, procps-ng top, hyprlock, loginctl, and optionally hyprsunset for night light. Fonts: Raleway and IBM Plex Mono (JetBrains Mono is the fallback).

Hyprland layer rule to avoid its own fade on the surface: `noanim` for the `the-line` namespace. The surface sits on the top layer, and on the overlay layer while its screen shows a fullscreen window.
