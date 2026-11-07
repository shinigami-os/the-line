-- The Line: Hyprland configuration.
-- Square corners, 1px borders, one curve (quartic ease-out) shared with the shell's motion.
-- Your own settings go in ~/.config/the-line/hypr/: monitors.lua, apps.lua (your app keys), custom.lua (loaded last).

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
            active_border = "rgba(9a5cffff)",   -- the accent
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
-- (2 screens: 1 and 5; 3 screens: 1, 4 and 7). Set `primary_monitor = "DP-2"` in custom.lua to put a
-- given screen first.

local function spread_workspaces()
    local monitors = hl.get_monitors()
    table.sort(monitors, function(a, b)
        if a.name == primary_monitor then return true end
        if b.name == primary_monitor then return false end
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

hl.on("monitor.added", spread_workspaces)
hl.on("monitor.removed", spread_workspaces)

------------- Startup -------------

hl.on("hyprland.start", function()
    spread_workspaces()
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("hyprctl setcursor TheLine 24")
    hl.exec_cmd("QT_QPA_PLATFORM=wayland " .. QS)
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("hypridle -c " .. SHELL .. "/session/hypridle.conf")
end)

------------- Keys -------------
-- The list these come from, with what each one does: Kira-Linux/THE_LINE_SHORTCUTS.md (the owner's choices).
-- Every desc is "Group: what it does": the cheat sheet (SUPER+F1) reads them live from Hyprland and groups them.
-- A bind without a group lands in "Apps".
-- U / H / J / K mirror the arrows (up / left / down / right) wherever arrows are used.

local dirs = {
    { "Up", "U", "up", 0, -40 },
    { "Left", "H", "left", -40, 0 },
    { "Down", "J", "down", 0, 40 },
    { "Right", "K", "right", 40, 0 },
}

-- The Line
hl.bind("SUPER+Super_L", hl.dsp.global("the-line:launcherTap"), { release = true, desc = "The Line: launcher (tap Super)" })
hl.bind("SUPER+N", hl.dsp.global("the-line:notifications"), { desc = "The Line: notifications and calendar" })
hl.bind("SUPER+A", hl.dsp.global("the-line:quicksettings"), { desc = "The Line: quick settings" })
hl.bind("SUPER+P", hl.dsp.global("the-line:performance"), { desc = "The Line: performance" })
hl.bind("SUPER+End", hl.dsp.exec_cmd("pkill -f '^qs -p " .. SHELL .. "$'; " .. QS), { desc = "The Line: restart the shell" })
-- Coming with their features (the keys are reserved already):
hl.bind("SUPER+F1", hl.dsp.global("the-line:cheatsheet"), { desc = "The Line: every shortcut, in one sheet" })
hl.bind("SUPER+V", hl.dsp.global("the-line:clipboard"), { desc = "The Line: clipboard history" })
hl.bind("SUPER+T", hl.dsp.global("the-line:wallpapers"), { desc = "The Line: wallpaper picker" })
hl.bind("SUPER+semicolon", hl.dsp.global("the-line:emoji"), { desc = "The Line: emoji picker" })
hl.bind("SUPER+I", hl.dsp.global("the-line:settings"), { desc = "The Line: settings" })
hl.bind("CTRL+ALT+Delete", hl.dsp.global("the-line:power"), { desc = "The Line: power menu" })
hl.bind("XF86PowerOff", hl.dsp.global("the-line:power"), { locked = true, desc = "The Line: power menu (asks first)" })

-- Session
hl.bind("SUPER+L", hl.dsp.exec_cmd("hyprlock"), { desc = "Session: Lock" })

-- Volume and brightness: the line itself shows the level, no popup.
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, desc = "Volume and brightness: Mute" })
hl.bind("SUPER+XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, desc = "Volume and brightness: Mute the microphone" })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, desc = "Volume and brightness: Volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true, desc = "Volume and brightness: Volume down" })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -q set 5%+"), { locked = true, repeating = true, desc = "Volume and brightness: Brightness up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -q set 5%-"), { locked = true, repeating = true, desc = "Volume and brightness: Brightness down" })

-- Media
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, desc = "Media: Play / pause" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, desc = "Media: Play / pause" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, desc = "Media: Next track" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, desc = "Media: Previous track" })

-- Screenshots and tools
hl.bind("Print", hl.dsp.exec_cmd("grim - | wl-copy"), { locked = true, desc = "Screenshots and tools: Screenshot to the clipboard" })
hl.bind("SUPER+SHIFT+S", hl.dsp.exec_cmd(SHELL .. "/session/the-line-shot"), { desc = "Screenshots and tools: Screenshot an area, any screen (frozen while selecting)" })
hl.bind("CTRL+Print", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | tesseract - - | wl-copy"), { desc = "Screenshots and tools: Text from an area (OCR) to the clipboard" })
hl.bind("ALT+Print", hl.dsp.exec_cmd("hyprpicker -a"), { desc = "Screenshots and tools: Colour picker to the clipboard" })
hl.bind("SUPER+ALT+R", hl.dsp.exec_cmd("pkill -INT -x wf-recorder || { mkdir -p ~/Videos/Recordings && wf-recorder -g \"$(slurp)\" -f ~/Videos/Recordings/$(date +%Y-%m-%d_%H.%M.%S).mp4; }"), { desc = "Screenshots and tools: Record an area (again to stop)" })

-- Windows
hl.bind("SUPER+Q", hl.dsp.window.close(), { desc = "Windows: Close the window" })
hl.bind("SUPER+SHIFT+Q", hl.dsp.exec_cmd("hyprctl kill"), { desc = "Windows: Kill a window (pick it)" })
hl.bind("SUPER+F", hl.dsp.window.fullscreen(), { desc = "Windows: Fullscreen" })
hl.bind("SUPER+ALT+Space", hl.dsp.window.float(), { desc = "Windows: Float / tile" })
hl.bind("SUPER+SHIFT+Space", hl.dsp.window.center(), { desc = "Windows: Centre a floating window" })
hl.bind("SUPER+Y", hl.dsp.layout("togglesplit"), { desc = "Windows: Toggle split" })
for _, d in ipairs(dirs) do
    local arrow, letter, dir = d[1], d[2], d[3]
    for _, key in ipairs({ arrow, letter }) do
        hl.bind("SUPER+" .. key, hl.dsp.focus({ direction = dir }), { desc = "Windows: Focus " .. dir })
        -- Moving past the edge of a screen sends the window to the next screen.
        hl.bind("SUPER+SHIFT+" .. key, hl.dsp.window.move({ direction = dir }), { desc = "Windows: Move the window " .. dir })
    end
end
hl.bind("SUPER+mouse:272", hl.dsp.window.drag(), { mouse = true, desc = "Windows: Move with the mouse" })
hl.bind("SUPER+mouse:273", hl.dsp.window.resize(), { mouse = true, desc = "Windows: Resize with the mouse" })

-- Resize mode: SUPER+R, then arrows (or U/H/J/K) resize, Esc / Enter / SUPER+R leave.
-- While it is on, The Line draws a loading ring around the focused window (modules/desktop/ResizeRing.qml).
hl.bind("SUPER+R", hl.dsp.submap("resize"), { desc = "Windows: Resize mode" })
hl.define_submap("resize", function()
    for _, d in ipairs(dirs) do
        for _, key in ipairs({ d[1], d[2] }) do
            hl.bind(key, hl.dsp.window.resize({ x = d[4], y = d[5], relative = true }), { repeating = true, desc = "Resize mode: Resize " .. d[3] })
        end
    end
    hl.bind("Escape", hl.dsp.submap("reset"), { desc = "Resize mode: Leave" })
    hl.bind("Return", hl.dsp.submap("reset"), { desc = "Resize mode: Leave" })
    hl.bind("SUPER+R", hl.dsp.submap("reset"), { desc = "Resize mode: Leave" })
end)

-- Workspaces 1-10 (keys 1 to 0): Super to go, Super+Ctrl to send the window there, Super+Shift to send and follow.
for i = 1, 10 do
    local code = (i % 10) + 9
    hl.bind("SUPER+code:" .. code, hl.dsp.focus({ workspace = i }), { desc = "Workspaces: Go to workspace " .. i })
    hl.bind("SUPER+CTRL+code:" .. code, hl.dsp.window.move({ workspace = i, follow = false }), { desc = "Workspaces: Send the window to workspace " .. i })
    hl.bind("SUPER+SHIFT+code:" .. code, hl.dsp.window.move({ workspace = i, follow = true }), { desc = "Workspaces: Send the window to workspace " .. i .. " and follow" })
end
-- Next / previous workspace: one step per scroll notch or key press. Scroll up goes to the next one, unless the
-- "workspaceScrollInverted" setting is on.
local scroll_inverted = the_line_setting("workspaceScrollInverted") == true
hl.bind(scroll_inverted and "SUPER+mouse_down" or "SUPER+mouse_up", hl.dsp.focus({ workspace = "r+1" }), { desc = "Workspaces: Next workspace" })
hl.bind(scroll_inverted and "SUPER+mouse_up" or "SUPER+mouse_down", hl.dsp.focus({ workspace = "r-1" }), { desc = "Workspaces: Previous workspace" })
for _, key in ipairs({ "Right", "K" }) do
    hl.bind("SUPER+ALT+" .. key, hl.dsp.focus({ workspace = "r+1" }), { desc = "Workspaces: Next workspace" })
end
for _, key in ipairs({ "Left", "H" }) do
    hl.bind("SUPER+ALT+" .. key, hl.dsp.focus({ workspace = "r-1" }), { desc = "Workspaces: Previous workspace" })
end

-- Touchpad: 4 fingers sideways for workspaces, up or down for fullscreen.
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "vertical", action = "fullscreen" })

------------- Yours -------------

load_user("monitors")
load_user("apps")
load_user("custom")
