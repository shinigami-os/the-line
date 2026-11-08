-- The Line: Hyprland configuration. Part of The Line: every update replaces this file, don't change it.
-- Square corners, 1px borders, one curve (quartic ease-out) shared with the shell's motion.
-- Your own settings go in ~/.config/the-line/hypr/: monitors.lua, apps.lua (your app keys), custom.lua (loaded last).
-- Settings writes input.lua and keys.lua there (from config.json); see ~/.config/the-line/README.md.

local HOME = os.getenv("HOME")
local SHELL = os.getenv("THE_LINE_DIR") or "/usr/share/the-line"
local QS = "qs -p " .. SHELL

-- A setting from The Line's own config (~/.config/the-line/config.json, written by the shell and its settings).
-- Only true / false values are read here; nil when unset. The shell reloads Hyprland when one of them changes.
local function the_line_setting(key)
    local f = io.open(HOME .. "/.config/the-line/config.json", "r")
    if not f then
        return nil
    end
    local text = f:read("*a")
    f:close()
    local v = text:match('"' .. key .. '"%s*:%s*(%a+)')
    if v == "true" then return true end
    if v == "false" then return false end
    return nil
end

-- A text setting from the same file ("accent": "#9A5CFF"), or `default`.
local function the_line_text(key, default)
    local f = io.open(HOME .. "/.config/the-line/config.json", "r")
    if not f then
        return default
    end
    local text = f:read("*a")
    f:close()
    return text:match('"' .. key .. '"%s*:%s*"([^"]*)"') or default
end

local function load_user(name)
    local path = HOME .. "/.config/the-line/hypr/" .. name .. ".lua"
    local f = io.open(path, "r")
    if f then
        f:close()
        dofile(path)
    end
end

-- Keyboard layout from the console keymap, like the rest of Kira.
local layout = "us"
local vconsole = io.open("/etc/vconsole.conf", "r")
if vconsole then
    for line in vconsole:lines() do
        local match = line:match("^%s*[Kk][Ee][Yy][Mm][Aa][Pp]%s*=%s*(.-)%s*$")
        if match then
            layout = match:gsub("^['\"]", ""):gsub("['\"]$", ""):lower()
            break
        end
    end
    vconsole:close()
end

------------- Environment -------------

hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("XCURSOR_THEME", "TheLine")   -- The Line's cursors (cursor/build.py)
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "TheLine")   -- the same theme in hyprcursor form: Hyprland animates that one
hl.env("HYPRCURSOR_SIZE", "24")

------------- Look -------------

hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 12,   -- around a group of windows; gaps_in is between windows of the same group
        border_size = 1,
        col = {
            -- the accent (config.json); a change applies live, through session/the-line-apply accent
            active_border = "rgba(" .. the_line_text("accent", "#9A5CFF"):gsub("#", ""):lower() .. "ff)",
            inactive_border = "rgba(3a3631ff)", -- border
        },
        resize_on_border = true,
        no_focus_fallback = true,
        allow_tearing = true,
    },
    decoration = {
        rounding = 0,
        shadow = { enabled = false },
        -- Glass for content windows that ask for transparency (the terminal).
        blur = {
            enabled = true,
            size = 8,
            passes = 2,
            noise = 0.07,
            contrast = 1,
            brightness = 1,
            new_optimizations = true,
            popups = false,
        },
        dim_inactive = false,
    },
    dwindle = {
        preserve_split = true,
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        background_color = "rgba(000000ff)",
        vrr = 1,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
        animate_manual_resizes = false,
        animate_mouse_windowdragging = false,
        on_focus_under_fullscreen = 2,
        allow_session_lock_restore = true,
        initial_workspace_tracking = false,
        focus_on_activate = true,
        disable_xdg_env_checks = true,
    },
    input = {
        kb_layout = layout,
        numlock_by_default = true,
        repeat_delay = 250,
        repeat_rate = 35,
        follow_mouse = 1,
        touchpad = {
            natural_scroll = false,
            disable_while_typing = true,
            clickfinger_behavior = true,
            scroll_factor = 0.5,
        },
    },
    xwayland = {
        force_zero_scaling = true,
    },
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
})

------------- Motion -------------
-- One curve everywhere, the shell's quartic ease-out. Speeds are in tenths of a second and match the shell's
-- tokens: window open 260 ms, close 180 ms, relayout 260 ms, workspace switch 340 ms, border colour 120 ms.

hl.curve("line", { type = "bezier", points = { { 0.25, 1 }, { 0.5, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })

hl.config({ animations = { enabled = true } })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.6, bezier = "line", style = "popin 96%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.8, bezier = "line", style = "popin 96%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.6, bezier = "line", style = "slide" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.8, bezier = "line" })
hl.animation({ leaf = "border", enabled = true, speed = 1.2, bezier = "linear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.4, bezier = "line", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.6, bezier = "line", style = "slidevert" })

-- The shell animates itself: no compositor fade on its surfaces.
hl.layer_rule({ match = { namespace = "^the-line" }, no_anim = true })

------------- Workspaces across screens -------------
-- The ten workspaces are shared out evenly: each screen starts on its own one, from left to right
-- (2 screens: 1 and 5; 3 screens: 1, 4 and 7). The main screen goes first: Settings > Displays
-- ("primaryScreen" in config.json), or `primary_monitor = "DP-2"` in custom.lua.
-- Global: Settings runs it again when the main screen changes.

function the_line_spread_workspaces()
    local setting = the_line_text("primaryScreen", "")
    local primary = setting ~= "" and setting or primary_monitor
    local monitors = hl.get_monitors()
    table.sort(monitors, function(a, b)
        if a.name == primary then return true end
        if b.name == primary then return false end
        if a.x ~= b.x then return a.x < b.x end
        return a.y < b.y
    end)
    local count = #monitors
    for i, m in ipairs(monitors) do
        local ws = 1 + math.floor((i - 1) * 9 / count)
        hl.workspace_rule({ workspace = tostring(ws), monitor = m.name, default = true })
        hl.dispatch(hl.dsp.focus({ monitor = m.name }))
        hl.dispatch(hl.dsp.focus({ workspace = ws }))
    end
    if count > 0 then
        hl.dispatch(hl.dsp.focus({ monitor = monitors[1].name }))
    end
end

hl.on("monitor.added", the_line_spread_workspaces)
hl.on("monitor.removed", the_line_spread_workspaces)

------------- Startup -------------

hl.on("hyprland.start", function()
    the_line_spread_workspaces()
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("hyprctl setcursor TheLine 24")
    hl.exec_cmd(SHELL .. "/session/the-line-shell")   -- the shell, started again if it ever crashes
    hl.exec_cmd(SHELL .. "/session/the-line-clipboard --login")   -- clipboard history, with its settings
    hl.exec_cmd(SHELL .. "/session/the-line-apply idle")     -- hypridle, with your idle times (config.json)
    hl.exec_cmd(SHELL .. "/session/the-line-apply readme")   -- ~/.config/the-line/README.md: what each file holds
end)

------------- Keys -------------
-- The list these come from, with what each one does: Kira-Linux/THE_LINE_SHORTCUTS.md (the owner's choices).
-- Every desc is "Group: what it does": the cheat sheet (SUPER+F1) reads them live from Hyprland and groups them.
-- A bind without a group lands in "Apps".
-- U / H / J / K mirror the arrows (up / left / down / right) wherever arrows are used.
-- Settings > Shortcuts can move any of them to other keys, or turn them off: keys.lua (written from config.json)
-- sets `the_line_keys`, original keys to new ones ("" = off), and bind() below follows it.

load_user("keys")
local rebinds = the_line_keys or {}

-- "ctrl+super+n" and "SUPER+CTRL+N" are the same keys: modifiers in one order and case, the key as written.
local mod_order = { SUPER = 1, CTRL = 2, CONTROL = 2, ALT = 3, SHIFT = 4 }
local function canon(combo)
    local mods, key = {}, nil
    for part in combo:gmatch("[^+]+") do
        local up = part:upper()
        if mod_order[up] then
            mods[#mods + 1] = up == "CONTROL" and "CTRL" or up
        else
            key = part
        end
    end
    table.sort(mods, function(a, b) return mod_order[a] < mod_order[b] end)
    mods[#mods + 1] = key
    return table.concat(mods, "+")
end

local function bind(combo, action, opts)
    local to = rebinds[canon(combo)]
    if to == "" then
        return
    end
    hl.bind(to or combo, action, opts)
end

local dirs = {
    { "Up", "U", "up", 0, -40 },
    { "Left", "H", "left", -40, 0 },
    { "Down", "J", "down", 0, 40 },
    { "Right", "K", "right", 40, 0 },
}

-- The Line
bind("SUPER+Super_L", hl.dsp.global("the-line:launcherTap"), { release = true, desc = "The Line: launcher (tap Super)" })
bind("SUPER+N", hl.dsp.global("the-line:notifications"), { desc = "The Line: notifications and calendar" })
bind("SUPER+A", hl.dsp.global("the-line:quicksettings"), { desc = "The Line: quick settings" })
bind("SUPER+P", hl.dsp.global("the-line:performance"), { desc = "The Line: performance" })
-- the-line-shell starts it again; without it running (a session from before it existed), start it
bind("SUPER+End", hl.dsp.exec_cmd("pkill -f '^qs -p " .. SHELL .. "$'; pgrep -f '^/bin/sh .*/session/the-line-shell$' >/dev/null || " .. SHELL .. "/session/the-line-shell"), { desc = "The Line: restart the shell" })
-- Coming with their features (the keys are reserved already):
bind("SUPER+F1", hl.dsp.global("the-line:cheatsheet"), { desc = "The Line: every shortcut, in one sheet" })
bind("SUPER+V", hl.dsp.global("the-line:clipboard"), { desc = "The Line: clipboard history" })
bind("SUPER+T", hl.dsp.global("the-line:wallpapers"), { desc = "The Line: wallpaper picker" })
bind("SUPER+semicolon", hl.dsp.global("the-line:emoji"), { desc = "The Line: emoji picker" })
bind("SUPER+I", hl.dsp.exec_cmd(SHELL .. "/session/the-line-settings"), { desc = "The Line: settings" })
bind("CTRL+ALT+Delete", hl.dsp.global("the-line:power"), { desc = "The Line: power menu" })
bind("XF86PowerOff", hl.dsp.global("the-line:powerButton"), { locked = true, desc = "The Line: power menu (asks first)" })

-- Session
bind("SUPER+L", hl.dsp.exec_cmd("hyprlock"), { desc = "Session: Lock" })

-- Volume and brightness: the line itself shows the level, no popup.
bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, desc = "Volume and brightness: Mute" })
bind("SUPER+XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, desc = "Volume and brightness: Mute the microphone" })
-- The step size is the shell's "levelStep" setting (2% by default).
local LINE = QS .. " ipc call line "
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(LINE .. "volumeStep 1"), { locked = true, repeating = true, desc = "Volume and brightness: Volume up" })
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(LINE .. "volumeStep -1"), { locked = true, repeating = true, desc = "Volume and brightness: Volume down" })
bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(LINE .. "brightnessStep 1"), { locked = true, repeating = true, desc = "Volume and brightness: Brightness up" })
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(LINE .. "brightnessStep -1"), { locked = true, repeating = true, desc = "Volume and brightness: Brightness down" })
bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd(LINE .. "kbdStep 1"), { locked = true, repeating = true, desc = "Volume and brightness: Keyboard backlight up" })
bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd(LINE .. "kbdStep -1"), { locked = true, repeating = true, desc = "Volume and brightness: Keyboard backlight down" })

-- Media
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, desc = "Media: Play / pause" })
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, desc = "Media: Play / pause" })
bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, desc = "Media: Next track" })
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, desc = "Media: Previous track" })

-- Screenshots and tools
bind("Print", hl.dsp.exec_cmd("grim - | wl-copy"), { locked = true, desc = "Screenshots and tools: Screenshot to the clipboard" })
bind("SUPER+SHIFT+S", hl.dsp.exec_cmd(SHELL .. "/session/the-line-shot"), { desc = "Screenshots and tools: Screenshot (Flameshot, on this screen)" })
bind("CTRL+Print", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | tesseract - - | wl-copy"), { desc = "Screenshots and tools: Text from an area (OCR) to the clipboard" })
bind("ALT+Print", hl.dsp.exec_cmd("hyprpicker -a"), { desc = "Screenshots and tools: Colour picker to the clipboard" })
bind("SUPER+ALT+R", hl.dsp.exec_cmd("pkill -INT -x wf-recorder || { mkdir -p ~/Videos/Recordings && wf-recorder -g \"$(slurp)\" -f ~/Videos/Recordings/$(date +%Y-%m-%d_%H.%M.%S).mp4; }"), { desc = "Screenshots and tools: Record an area (again to stop)" })

-- Windows
bind("SUPER+Q", hl.dsp.window.close(), { desc = "Windows: Close the window" })
bind("SUPER+SHIFT+Q", hl.dsp.exec_cmd("hyprctl kill"), { desc = "Windows: Kill a window (pick it)" })
bind("SUPER+F", hl.dsp.window.fullscreen(), { desc = "Windows: Fullscreen" })
bind("SUPER+ALT+Space", hl.dsp.exec_cmd(LINE .. "toggleFloat"), { desc = "Windows: Float / tile (floated apps are remembered)" })
bind("SUPER+SHIFT+Space", hl.dsp.window.center(), { desc = "Windows: Centre a floating window" })
bind("SUPER+Y", hl.dsp.layout("togglesplit"), { desc = "Windows: Toggle split" })
-- SUPER+SHIFT+arrow: a tiled window moves in the layout (past the edge of a screen, to the next screen);
-- a floating one goes straight to the screen that way, at the same place on it.
local function move_window(dir)
    return function()
        local w = hl.get_active_window()
        if w and w.floating then
            -- named by address: Hyprland then keeps its place on the new screen
            hl.dispatch(hl.dsp.window.move({ monitor = dir:sub(1, 1), window = "address:" .. w.address }))
        else
            hl.dispatch(hl.dsp.window.move({ direction = dir }))
        end
    end
end

for _, d in ipairs(dirs) do
    local arrow, letter, dir = d[1], d[2], d[3]
    for _, key in ipairs({ arrow, letter }) do
        bind("SUPER+" .. key, hl.dsp.focus({ direction = dir }), { desc = "Windows: Focus " .. dir })
        bind("SUPER+SHIFT+" .. key, move_window(dir), { desc = "Windows: Move the window " .. dir })
    end
end
bind("SUPER+mouse:272", hl.dsp.window.drag(), { mouse = true, desc = "Windows: Move with the mouse" })
bind("SUPER+mouse:273", hl.dsp.window.resize(), { mouse = true, desc = "Windows: Resize with the mouse" })

-- Resize mode: SUPER+R, then arrows (or U/H/J/K) resize, Esc / Enter / SUPER+R leave.
-- While it is on, The Line draws a loading ring around the focused window (modules/desktop/ResizeRing.qml).
bind("SUPER+R", hl.dsp.submap("resize"), { desc = "Windows: Resize mode" })
hl.define_submap("resize", function()
    for _, d in ipairs(dirs) do
        for _, key in ipairs({ d[1], d[2] }) do
            bind(key, hl.dsp.window.resize({ x = d[4], y = d[5], relative = true }), { repeating = true, desc = "Resize mode: Resize " .. d[3] })
        end
    end
    bind("Escape", hl.dsp.submap("reset"), { desc = "Resize mode: Leave" })
    bind("Return", hl.dsp.submap("reset"), { desc = "Resize mode: Leave" })
    bind("SUPER+R", hl.dsp.submap("reset"), { desc = "Resize mode: Leave" })
end)

-- Settings > Shortcuts listens for a new shortcut in this empty submap: no bind fires, every key reaches the app.
-- The app leaves it as soon as it has the keys (or after 15 s, even if it closed meanwhile). Hyprland only knows a
-- submap with a bind in it: its one bind is a way out nobody would want as a shortcut.
hl.define_submap("the-line-keys", function()
    hl.bind("SUPER+CTRL+ALT+SHIFT+Escape", hl.dsp.submap("reset"))
end)

-- Workspaces 1-10 (keys 1 to 0): Super to go, Super+Ctrl to send the window there, Super+Shift to send and follow.
for i = 1, 10 do
    local code = (i % 10) + 9
    bind("SUPER+code:" .. code, hl.dsp.focus({ workspace = i }), { desc = "Workspaces: Go to workspace " .. i })
    bind("SUPER+CTRL+code:" .. code, hl.dsp.window.move({ workspace = i, follow = false }), { desc = "Workspaces: Send the window to workspace " .. i })
    bind("SUPER+SHIFT+code:" .. code, hl.dsp.window.move({ workspace = i, follow = true }), { desc = "Workspaces: Send the window to workspace " .. i .. " and follow" })
end
-- Next / previous workspace: one step per scroll notch or key press. Scroll up goes to the next one, unless the
-- "workspaceScrollInverted" setting is on.
local scroll_inverted = the_line_setting("workspaceScrollInverted") == true
bind(scroll_inverted and "SUPER+mouse_down" or "SUPER+mouse_up", hl.dsp.focus({ workspace = "r+1" }), { desc = "Workspaces: Next workspace" })
bind(scroll_inverted and "SUPER+mouse_up" or "SUPER+mouse_down", hl.dsp.focus({ workspace = "r-1" }), { desc = "Workspaces: Previous workspace" })
for _, key in ipairs({ "Right", "K" }) do
    bind("SUPER+ALT+" .. key, hl.dsp.focus({ workspace = "r+1" }), { desc = "Workspaces: Next workspace" })
end
for _, key in ipairs({ "Left", "H" }) do
    bind("SUPER+ALT+" .. key, hl.dsp.focus({ workspace = "r-1" }), { desc = "Workspaces: Previous workspace" })
end

-- Touchpad: 4 fingers sideways for workspaces, up or down for fullscreen.
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "vertical", action = "fullscreen" })

------------- Yours -------------

load_user("monitors")
load_user("input")      -- written by The Line from config.json (Settings > Input)
load_user("apps")
-- The settings app floats at the size it is drawn for, centred.
hl.window_rule({ match = { class = "^(the-line-settings)$" }, float = true, size = "1120 740" })
load_user("floating")   -- written by The Line: the apps you float, where you left them
load_user("workspaces") -- written by The Line from config.json: apps that open on their workspace
load_user("custom")
