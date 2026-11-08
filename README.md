# The Line

The desktop shell of Kira Linux, built with Quickshell on one line. The line crosses the top of the screen and tiles hang beneath it. Notifications, volume, workspaces and music all play out on the line, and the tiles grow into panels instead of opening popups.

## Status

Runs on Hyprland (FHT comes later). Done so far:

- `Theme` and `Anim` singletons (colours, fonts, the whole motion system)
- the line: end caps, workspace marker, volume/brightness gauge, notification pulse
- top-left tile at rest: workspace numerals and window title
- top-centre tile: clock, notification toast, notifications panel and calendar
- top-right tile: performance summary, Wi-Fi, volume, battery. The summary opens the performance dashboard, the icons open quick settings (Wi-Fi, Bluetooth, night light, keep awake, sliders, reduce motion, power)

- top-left tile grows into the launcher: apps (most launched first), a calculator (qalc, on anything with an operator, a function or "to"; "=" forces it) and run in terminal; the panel height follows the results

- music part of the top-left tile (MPRIS) with its progress on the line; it grows into the music panel (cover, track ruler with seek, controls, player picker)

- fullscreen, in stages: the music part leaves, the tiles fold up into the line, the line withdraws into the screen edges. A notification or a level change draws the line back for the event, then it withdraws again

- Kira's voice on an empty workspace, behind the windows, from `assets/quotes.txt` plus `~/.config/the-line/quotes.txt`, with live `{placeholders}`

- notification daemon (org.freedesktop.Notifications) and the wallpaper: one for every screen or one per screen, a picture, an animated GIF or a video (mp4, webm, mkv, mov: looped, silent, played by Qt's ffmpeg); moving ones stop under a fullscreen window and, by default, on battery
- double tap Super: the workspace overview (ten small screens with live window thumbnails), grown from the same tile as the launcher; drag a window to another workspace to move it, click one to focus it
- optional app icons on the workspace ruler (`workspaceIcons` in the config)
- intro: each screen starts hidden and draws itself in once its wallpaper is shown

- volume, brightness and keyboard backlight keys step by `levelStep`; the clock tile shows which level the line is showing, and its value
- polkit agent: an app asking for an admin password gets The Line's dialog (the line drawn across the screen, the box opening on it)

- cheat sheet (SUPER+F1): every shortcut, read live (Hyprland's binds and their "Group: what it does" descriptions, the touchpad gestures, foot's and zsh's own bindings, yazi's keymap from its binary and your keymap.toml), in tabs

- power menu (CTRL+ALT+Delete, the power button): the line runs through it, hold to confirm

- clipboard history (SUPER+V) and emoji picker (SUPER+semicolon), both grown from the line, with search

- floating (SUPER+ALT+Space): a window floats at 75% of its tiled size, centred; floated apps are remembered with their size and place (`~/.config/the-line/hypr/floating.lua`)
- files: yazi in foot (SUPER+E), the default file manager (SUPER+SHIFT+E)
- screenshots with Flameshot on the focused screen; The Line's defaults for foot (black glass, VS Code-style keys) and Flameshot are installed on first login

- settings app (SUPER+I, `settings/`): its own window, a spine of sections and a search over every setting; done so far: network, Bluetooth, sound, displays (arrangement, resolution, scale, rotation, main screen, on / off; each change goes back after 15 s unless kept), input (layout, Caps Lock, key repeat, pointer, touchpad), appearance (wallpaper picker per screen, accent, accent from the main screen's wallpaper, motion), workspaces (apps on their workspace, remembered floating apps, ruler), shortcuts (your app keys, The Line's keys moved or turned off, conflicts refused), power and idle (with the battery limit), sign-in (howdy faces with a name, fingerprint), system (name, time, time zone, about), The Line's own settings

Next: the other settings sections, welcome screen, first-run welcome, launcher shortcuts section, easter eggs from the backlog.

## Session

`session/` holds everything to log into The Line from the greeter:

- `the-line.desktop`: the greeter entry, installed in `/usr/share/wayland-sessions/`
- `the-line-session`: environment, session bus, audio, then Hyprland (`/usr/bin/the-line-session`)
- `hyprland.lua`: The Line's Hyprland config (square, 1 px borders, the shell's curve and timings, the keys)
- `the-line-apply`: writes the files other programs read from `config.json` (`hypridle.conf` with your idle times, `hypr/workspaces.lua`), and `~/.config/the-line/README.md`
- `the-line-settings`: opens the settings app, or brings it forward (`the-line-settings power` opens a section)
- `the-line-settings-helper`: the settings app's root side (hostname, time zone, automatic time, clock, battery limit, howdy faces and face sign-in), run through pkexec; `org.kira.the-line.settings.policy` goes in `/usr/share/polkit-1/actions/`
- `the-line-shell`: runs the shell and starts it again if it crashes
- `apps.lua`: the default app keys (just the terminal), copied to `~/.config/the-line/hypr/` on first login

The shell is expected in `/usr/share/the-line` (or wherever `THE_LINE_DIR` points). Workspaces are shared out evenly between screens, left to right (2 screens: 1 and 5; 3 screens: 1, 4, 7; the main screen goes first: Settings > Displays, or `primary_monitor = "<name>"` in `custom.lua`). Your own Hyprland bits go in `~/.config/the-line/hypr/` (`monitors.lua`, `apps.lua`, `custom.lua`; The Line writes `floating.lua`); coming from Sleex, its monitors, app keys and custom general settings are copied there on the first login.

### Where your settings live

Everything you set lives in `~/.config/the-line/` (and state like launch counts in `~/.local/state/the-line/`); updates
only replace `/usr/share/the-line`. Each file says in its first lines whether it is yours or generated, and
`~/.config/the-line/README.md` (written at each login) lists them all. `config.json` is the source: the generated files
(`hypridle.conf`, `hypr/workspaces.lua`, `hypr/input.lua`, `hypr/keys.lua`, `hypr/floating.lua`) are rewritten from it.
Settings also edits two files that stay yours: in `hypr/apps.lua` it changes only the app-key lines it shows, in
`hypr/monitors.lua` only the line of a screen you change there.

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
qs -p . ipc call line power              # the power menu
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
  "wallpaper": "/usr/share/kira/wallpapers/default.png", "wallpapers": { "DP-2": "/path/to/its/own.mp4" },
  "wallpaperStillOnBattery": true, "primaryScreen": "", "workspaceIcons": false,
  "kiraVoice": true, "workspaceScrollInverted": false, "levelStep": 2,
  "clipboardMax": 200, "clipboardImages": true, "clipboardWipeOnLogin": false }
```

## Needs

Quickshell 0.3 with Hyprland, PipeWire, MPRIS, UPower and Bluetooth support, Qt Multimedia (ffmpeg backend) for video wallpapers, mpv for their thumbnails, Hyprland, NetworkManager (nmcli), brightnessctl, procps-ng top, hyprlock, loginctl, and optionally hyprsunset for night light. Fonts: Raleway and IBM Plex Mono (JetBrains Mono is the fallback).

Hyprland layer rule to avoid its own fade on the surface: `noanim` for the `the-line` namespace. The surface sits on the top layer, and on the overlay layer while its screen shows a fullscreen window.
