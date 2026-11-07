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

- Kira's voice on an empty workspace, behind the windows, from `assets/quotes.txt` plus `~/.config/the-line/quotes.txt`, with live `{placeholders}`

- notification daemon (org.freedesktop.Notifications) and the wallpaper
- double tap Super: the workspace overview (ten small screens with live window thumbnails), grown from the same tile as the launcher; drag a window to another workspace to move it, click one to focus it
- optional app icons on the workspace ruler (`workspaceIcons` in the config)
- intro: each screen starts hidden and draws itself in once its wallpaper is shown

- volume, brightness and keyboard backlight keys step by `levelStep`; the clock tile shows which level the line is showing, and its value
- polkit agent: an app asking for an admin password gets The Line's dialog (the line drawn across the screen, the box opening on it)

- cheat sheet (SUPER+F1): every shortcut, read live (Hyprland's binds and their "Group: what it does" descriptions, the touchpad gestures, foot's and zsh's own bindings), in tabs

Next: power menu, first-run welcome, launcher shortcuts section, easter eggs from the backlog.

## Session

`session/` holds everything to log into The Line from the greeter:

- `the-line.desktop`: the greeter entry, installed in `/usr/share/wayland-sessions/`
- `the-line-session`: environment, session bus, audio, then Hyprland (`/usr/bin/the-line-session`)
- `hyprland.lua`: The Line's Hyprland config (square, 1 px borders, the shell's curve and timings, the keys)
- `hypridle.conf`: dim at 10 min, lock (hyprlock) at 30, suspend at 1 h; screens never turned off, no hibernation
- `apps.lua`: the default app keys (just the terminal), copied to `~/.config/the-line/hypr/` on first login

The shell is expected in `/usr/share/the-line` (or wherever `THE_LINE_DIR` points). Workspaces are shared out evenly between screens, left to right (2 screens: 1 and 5; 3 screens: 1, 4, 7; `primary_monitor = "<name>"` in `custom.lua` puts a screen first). Your own Hyprland bits go in `~/.config/the-line/hypr/` (`monitors.lua`, `apps.lua`, `custom.lua`); coming from Sleex, its monitors, app keys and custom general settings are copied there on the first login.

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
qs -p . ipc call line overview           # the workspace overview
qs -p . ipc call line cheatsheet         # every shortcut (cheatsheetTab <n> opens a given tab)
```

## Layout

```
shell.qml         entry point and IPC
services/         singletons: Theme, Anim, Config, UiState, LineState, Notifs, Audio, Brightness, SystemStats, Network, NightLight, Power, Media, Apps, Session, ClockFace, Time
modules/common/   Tile (tile that grows into a panel), CenterDialog (dialog grown from the line), PanelItem, Reading, Toggle, LineSlider, Icon
modules/line/     the line and the per-screen surface
modules/tiles/    the three tiles and their panels
modules/desktop/  wallpaper, Kira's voice
assets/           quotes.txt (Kira's voice) and other static files
scripts/          helpers
```

## Cursor

`cursor/build.py` draws The Line's cursor theme (24 shapes plus the usual alias names, 24 to 64 px) and writes the XCursor files, with nothing but Python and Pillow. Flat and square: a dark fill with a light 1 px outline, a blade arrow with the logo's notch, the link pointer in the accent, the busy cursor as the three loading blades. A short dash runs around the arrow, the link pointer and the text cursor in a loop, like the pulse on the line.

```sh
python3 cursor/build.py ~/.local/share/icons/TheLine    # or /usr/share/icons/TheLine
```

The session sets it (`XCURSOR_THEME=TheLine`). `cursor/build/preview.png` shows every cursor on dark and light.

## Keybindings

The Line registers Hyprland global shortcuts under the `the-line` app id: `launcher`, `notifications`, `quicksettings`, `performance`. For example:

```lua
hl.bind("SUPER+SPACE", hl.dsp.global("the-line:launcher"))
hl.bind("SUPER+N", hl.dsp.global("the-line:notifications"))
hl.bind("SUPER+A", hl.dsp.global("the-line:quicksettings"))
hl.bind("SUPER+P", hl.dsp.global("the-line:performance"))
```

## Config

`~/.config/the-line/config.json`, every key optional:

```json
{ "accent": "#9A5CFF", "reduceMotion": false, "motionScale": 1.0, "screens": [], "terminal": "foot",
  "wallpaper": "/usr/share/kira/wallpapers/default.png", "workspaceIcons": false,
  "kiraVoice": true, "workspaceScrollInverted": false, "levelStep": 2 }
```

## Needs

Quickshell 0.3 with Hyprland, PipeWire, MPRIS, UPower and Bluetooth support, Hyprland, NetworkManager (nmcli), brightnessctl, procps-ng top, hyprlock, loginctl, and optionally hyprsunset for night light. Fonts: Raleway and IBM Plex Mono (JetBrains Mono is the fallback).

Hyprland layer rule to avoid its own fade on the surface: `noanim` for the `the-line` namespace. The surface sits on the top layer, and on the overlay layer while its screen shows a fullscreen window.
