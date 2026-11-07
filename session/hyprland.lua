-- The Line: Hyprland configuration.
-- Square corners, 1px borders, one curve (quartic ease-out) shared with the shell's motion.
-- Your own settings go in ~/.config/the-line/hypr/: monitors.lua, apps.lua, custom.lua (loaded last).

local HOME = os.getenv("HOME")
local SHELL = os.getenv("THE_LINE_DIR") or "/usr/share/the-line"
local QS = "qs -p " .. SHELL

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

------------- Look -------------

hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 4,
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
            natural_scroll = true,
            disable_while_typing = true,
            clickfinger_behavior = true,
            scroll_factor = 0.5,
        },
    },
    binds = {
        scroll_event_delay = 0,
    },
    xwayland = {
        force_zero_scaling = true,
    },
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
})

hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })

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

------------- Startup -------------

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("QT_QPA_PLATFORM=wayland " .. QS)
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("hypridle -c " .. SHELL .. "/session/hypridle.conf")
end)

------------- Keys -------------

-- The Line
hl.bind("SUPER+Space", hl.dsp.global("the-line:launcher"), { desc = "The Line: launcher" })
hl.bind("SUPER+N", hl.dsp.global("the-line:notifications"), { desc = "The Line: notifications and calendar" })
hl.bind("SUPER+A", hl.dsp.global("the-line:quicksettings"), { desc = "The Line: quick settings" })
hl.bind("SUPER+P", hl.dsp.global("the-line:performance"), { desc = "The Line: performance" })
hl.bind("SUPER_L", hl.dsp.global("the-line:hints"), { ignore_mods = true, transparent = true })
hl.bind("SUPER_L", hl.dsp.global("the-line:hints"), { ignore_mods = true, transparent = true, release = true })
hl.bind("SUPER+End", hl.dsp.exec_cmd("pkill -f '^qs -p " .. SHELL .. "$'; " .. QS), { desc = "The Line: restart the shell" })

-- Session
hl.bind("SUPER+L", hl.dsp.exec_cmd("hyprlock"), { desc = "Session: lock" })
hl.bind("SUPER+Return", hl.dsp.exec_cmd("foot"), { desc = "Terminal" })

-- Volume and brightness: the line itself shows the level, no popup.
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -q set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -q set 5%-"), { locked = true, repeating = true })

-- Media
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Screenshots
hl.bind("Print", hl.dsp.exec_cmd("grim - | wl-copy"), { locked = true, desc = "Screenshot to the clipboard" })
hl.bind("SUPER+SHIFT+S", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"), { desc = "Screenshot an area to the clipboard" })
hl.bind("CTRL+Print", hl.dsp.exec_cmd("mkdir -p ~/Pictures/Screenshots && grim ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H.%M.%S).png"), { locked = true, desc = "Screenshot to ~/Pictures/Screenshots" })

-- Windows
hl.bind("SUPER+Q", hl.dsp.window.close(), { desc = "Close the window" })
hl.bind("SUPER+F", hl.dsp.window.fullscreen(), { desc = "Fullscreen" })
hl.bind("SUPER+ALT+Space", hl.dsp.window.float(), { desc = "Float" })
hl.bind("SUPER+J", hl.dsp.layout("togglesplit"), { desc = "Toggle split" })
hl.bind("SUPER+Left", hl.dsp.window.move({ direction = "left" }))
hl.bind("SUPER+Right", hl.dsp.window.move({ direction = "right" }))
hl.bind("SUPER+Up", hl.dsp.window.move({ direction = "up" }))
hl.bind("SUPER+Down", hl.dsp.window.move({ direction = "down" }))
hl.bind("SUPER+mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER+mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Workspaces 1-10 (keys 1 to 0): Super to go, Super+Ctrl to send the window.
for i = 1, 10 do
    local code = (i % 10) + 9
    hl.bind("SUPER+code:" .. code, hl.dsp.focus({ workspace = i }), { desc = "Workspace " .. i })
    hl.bind("SUPER+CTRL+code:" .. code, hl.dsp.window.move({ workspace = i, follow = false }), { desc = "Send to workspace " .. i })
end
hl.bind("SUPER+mouse_up", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER+mouse_down", hl.dsp.focus({ direction = "left" }))

------------- Yours -------------

load_user("monitors")
load_user("apps")
load_user("custom")
