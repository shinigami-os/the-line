pragma Singleton

import QtQuick
import TheLine.Ui
import Quickshell

// Every section and every setting of the app, declared once: the spine, the rows and the search are built from here.
// A setting: { section, group, key (in config.json), kind, label, sub, keywords, ... }
//   toggle   on / off
//   slider   min, max, step, unit
//   choice   choices: [{ value, label }]
//   color    choices: [{ value, label }] drawn as swatches
//   stops    stops: [{ value, label }] on a line slider (idle times)
//   speed    motionScale shown as a speed, 0.5× to 2× (a slider, 1× in the middle, log scale)
//   info     a value to read, nothing to change
//   wallpaper, workspaceApps, ...: rows with their own component (`customs`), which takes the keyboard while selected
// A setting with a `source` ("net", "bt", "sound") reads and writes that backend instead of config.json.
// A section's `plan` says what it holds (the launcher shows it next to "Settings › <section>").
Singleton {
    id: root

    // The sections (spine order): services/SettingsSections.qml, shared with the shell's launcher.
    readonly property var sections: SettingsSections.list

    // Row kinds drawn by their own component (in modules/settings).
    readonly property var customs: ({
        wallpaper: "WallpaperPicker.qml", workspaceApps: "WorkspaceRules.qml", floatingApps: "FloatingApps.qml",
        wifiNetworks: "WifiNetworks.qml", btDevices: "BtDevices.qml", audioDevices: "AudioDevices.qml", audioStreams: "AudioStreams.qml",
        text: "TextSetting.qml", timezone: "ZonePicker.qml", datetime: "DateTimeSetting.qml", faces: "FaceModels.qml",
        chargeLimit: "ChargeLimit.qml", appKeys: "AppKeys.qml", lineKeys: "LineKeys.qml", displayMap: "DisplayMap.qml",
        displayModes: "DisplayModes.qml", kbLayout: "LayoutPicker.qml", aboutCard: "AboutCard.qml",
        disks: "DiskList.qml", homeUsage: "HomeUsage.qml", defaultApp: "DefaultApp.qml", mutedApps: "MutedApps.qml",
        iconTheme: "IconThemePicker.qml"
    })

    function isCustom(setting) {
        return customs[setting.kind] !== undefined;
    }

    function backend(setting) {
        return setting.source === "net" ? Net : setting.source === "bt" ? Bt : setting.source === "sound" ? Sound
            : setting.source === "sys" ? Sys : setting.source === "displays" ? Displays : null;
    }

    // Times of day every half hour, for the schedules: { value: "21:30", label: "21:30" }.
    readonly property var halfHours: {
        const out = [];
        for (let i = 0; i < 48; i++) {
            const t = String(Math.floor(i / 2)).padStart(2, "0") + ":" + (i % 2 ? "30" : "00");
            out.push({ value: t, label: t });
        }
        return out;
    }

    readonly property var settings: [
        { section: "storage", group: "Disks", key: "disks", kind: "disks", label: "Disks",
          sub: "How full each mounted partition is", keywords: "disk drive partition space free usage ssd nvme usb" },
        { section: "storage", group: "Your home", key: "homeUsage", kind: "homeUsage", label: "What fills your home",
          sub: "Enter measures · Enter on a folder opens it", keywords: "home folder size du space big files" },

        { section: "apps", group: "Links and files", key: "browser", app: "browser", kind: "defaultApp", label: "Web browser",
          sub: "Opens links", keywords: "browser web internet http links firefox chromium" },
        { section: "apps", group: "Links and files", key: "files", app: "files", kind: "defaultApp", label: "File manager",
          sub: "Opens folders", keywords: "files folders file manager explorer dolphin nautilus thunar" },
        { section: "apps", group: "Links and files", key: "mail", app: "mail", kind: "defaultApp", label: "Mail",
          sub: "Opens mailto: links", keywords: "mail email mailto thunderbird" },
        { section: "apps", group: "Links and files", key: "terminal", app: "terminal", kind: "defaultApp", label: "Terminal",
          sub: "The Line's terminal (launcher, apps that run in one)", keywords: "terminal console shell foot kitty alacritty" },
        { section: "apps", group: "Media and documents", key: "images", app: "images", kind: "defaultApp", label: "Images",
          sub: "PNG, JPEG, GIF, WebP…", keywords: "image picture photo viewer png jpg" },
        { section: "apps", group: "Media and documents", key: "video", app: "video", kind: "defaultApp", label: "Videos",
          sub: "MP4, MKV, WebM…", keywords: "video movie player mpv vlc mp4" },
        { section: "apps", group: "Media and documents", key: "music", app: "music", kind: "defaultApp", label: "Music",
          sub: "MP3, FLAC, Ogg…", keywords: "music audio player mp3 flac" },
        { section: "apps", group: "Media and documents", key: "text", app: "text", kind: "defaultApp", label: "Text",
          sub: "Plain text files", keywords: "text editor txt notes" },
        { section: "apps", group: "Media and documents", key: "pdf", app: "pdf", kind: "defaultApp", label: "PDF",
          sub: "Documents", keywords: "pdf document reader viewer" },

        { section: "notifications", group: "Where they show", key: "pulseFocusedOnly", kind: "toggle", label: "On the focused screen only",
          sub: "The pulse and the toast skip the other screens", keywords: "pulse toast screen monitor multi focused" },
        { section: "notifications", group: "Do not disturb", key: "dndScheduled", kind: "toggle", label: "Every day, on a schedule",
          sub: "No toast and no pulse in those hours (the button works too)", keywords: "dnd do not disturb quiet night schedule silence" },
        { section: "notifications", group: "Do not disturb", key: "dndFrom", kind: "stops", label: "From",
          sub: "When it starts", keywords: "dnd start quiet hours", stops: root.halfHours },
        { section: "notifications", group: "Do not disturb", key: "dndTo", kind: "stops", label: "Until",
          sub: "When it ends, the next morning if earlier", keywords: "dnd end quiet hours", stops: root.halfHours },
        { section: "notifications", group: "Do not disturb", key: "dndUrgent", kind: "toggle", label: "Urgent ones still show",
          sub: "Critical notifications (battery, calls) get through", keywords: "urgent critical dnd" },
        { section: "notifications", group: "Apps", key: "mutedApps", kind: "mutedApps", label: "Apps",
          sub: "Enter mutes or unmutes · a muted app goes to the list silently", keywords: "mute app silence notifications" },

        { section: "nightlight", group: "Warmth", key: "nightTemp", kind: "slider", min: 2500, max: 6000, step: 100, unit: "K",
          label: "Warmth", sub: "Lower is warmer and easier on the eyes at night", keywords: "temperature kelvin warm color colour blue light" },
        { section: "nightlight", group: "Schedule", key: "nightScheduled", kind: "toggle", label: "Every evening, on a schedule",
          sub: "On at the start, off at the end (the button works too)", keywords: "schedule automatic evening night" },
        { section: "nightlight", group: "Schedule", key: "nightFrom", kind: "stops", label: "From",
          sub: "When it turns on", keywords: "night light start evening", stops: root.halfHours },
        { section: "nightlight", group: "Schedule", key: "nightTo", kind: "stops", label: "Until",
          sub: "When it turns off, the next morning", keywords: "night light end morning", stops: root.halfHours },
        { section: "nightlight", group: "Schedule", source: "sys", key: "hyprsunset", kind: "info", label: "hyprsunset",
          sub: "What tints the screens", keywords: "hyprsunset install" },

        { section: "displays", group: "Your screens", key: "displayMap", kind: "displayMap", label: "Arrangement",
          sub: "← → pick a screen · Shift+arrows move it · or drag it", keywords: "position arrange layout left right above monitor" },
        { section: "displays", group: "The picked screen", source: "displays", key: "mode", kind: "displayModes", label: "Resolution and refresh rate",
          sub: "Enter switches to it · you then have 15 s to keep it", keywords: "resolution refresh rate hz mode pixels" },
        { section: "displays", group: "The picked screen", source: "displays", key: "scale", kind: "choice", label: "Scale",
          sub: "Bigger text and windows on a sharp screen", keywords: "scale zoom size hidpi dpi",
          choices: [{ value: 1, label: "100%" }, { value: 1.25, label: "125%" }, { value: 1.5, label: "150%" }, { value: 1.75, label: "175%" }, { value: 2, label: "200%" }] },
        { section: "displays", group: "The picked screen", source: "displays", key: "transform", kind: "choice", label: "Rotation",
          sub: "For a screen turned on its side", keywords: "rotate portrait vertical turn transform",
          choices: [{ value: 0, label: "none" }, { value: 1, label: "90°" }, { value: 2, label: "180°" }, { value: 3, label: "270°" }] },
        { section: "displays", group: "The picked screen", source: "displays", key: "primary", kind: "toggle", label: "Main screen",
          sub: "Gets workspace 1, and gives the accent its wallpaper", keywords: "primary main first default" },
        { section: "displays", group: "The picked screen", source: "displays", key: "enabled", kind: "toggle", label: "Use this screen",
          sub: "Off: nothing is shown on it", keywords: "disable turn off enable" },

        { section: "input", group: "Keyboard", key: "kbLayout", kind: "kbLayout", label: "Layout",
          sub: "Enter, then type a language", keywords: "keyboard layout azerty qwerty language bepo dvorak xkb" },
        { section: "input", group: "Keyboard", key: "kbOptions", kind: "choice", label: "Caps Lock key",
          sub: "What the key does", keywords: "caps lock escape ctrl capslock",
          choices: [{ value: "", label: "Caps Lock" }, { value: "caps:escape", label: "Esc" }, { value: "ctrl:nocaps", label: "Ctrl" }, { value: "caps:none", label: "nothing" }] },
        { section: "input", group: "Keyboard", key: "repeatDelay", kind: "slider", min: 150, max: 800, step: 25, unit: "ms",
          label: "Repeat after", sub: "How long a key is held before it repeats", keywords: "repeat delay hold" },
        { section: "input", group: "Keyboard", key: "repeatRate", kind: "slider", min: 10, max: 60, step: 1, unit: "/ s",
          label: "Repeat speed", sub: "Letters per second, once it repeats", keywords: "repeat rate speed" },
        { section: "input", group: "Keyboard", key: "numlock", kind: "toggle", label: "Num Lock on at login",
          sub: "The number pad types numbers", keywords: "numlock numpad numbers" },
        { section: "input", group: "Mouse", key: "pointerSpeed", kind: "slider", min: -1, max: 1, step: 0.05, decimals: 2, unit: "",
          label: "Speed", sub: "0 is the mouse's own speed", keywords: "mouse speed sensitivity cursor pointer" },
        { section: "input", group: "Mouse", key: "pointerAccel", kind: "choice", label: "Acceleration",
          sub: "Flat: the pointer moves as far as your hand", keywords: "mouse acceleration accel flat adaptive gaming",
          choices: [{ value: "", label: "device's" }, { value: "adaptive", label: "adaptive" }, { value: "flat", label: "flat" }] },
        { section: "input", group: "Touchpad", key: "touchpadSpeed", kind: "slider", min: -1, max: 1, step: 0.05, decimals: 2, unit: "",
          label: "Speed", sub: "The touchpad's own, apart from the mouse", keywords: "touchpad trackpad speed sensitivity cursor pointer" },
        { section: "input", group: "Touchpad", key: "tapToClick", kind: "toggle", label: "Tap to click",
          sub: "A tap on the touchpad clicks", keywords: "touchpad tap click trackpad" },
        { section: "input", group: "Touchpad", key: "naturalScroll", kind: "toggle", label: "Natural scrolling",
          sub: "On the touchpad, the page follows your fingers", keywords: "touchpad scroll reverse natural direction trackpad" },
        { section: "input", group: "Touchpad", key: "touchpadScroll", kind: "slider", min: 0.1, max: 2, step: 0.05, decimals: 2, unit: "×",
          label: "Touchpad scroll speed", sub: "How far two fingers scroll", keywords: "touchpad scroll speed factor trackpad" },
        { section: "input", group: "Touchpad", key: "disableWhileTyping", kind: "toggle", label: "Touchpad off while typing",
          sub: "No stray clicks from your palms", keywords: "touchpad typing palm disable trackpad" },

        { section: "shortcuts", group: "Your apps", key: "appKeys", kind: "appKeys", label: "Your app keys",
          sub: "Enter gives new keys · Delete removes one · kept in hypr/apps.lua", keywords: "app launch keys bind hotkey terminal browser" },
        { section: "shortcuts", group: "The Line's", key: "lineKeys", kind: "lineKeys", label: "The Line's keys",
          sub: "Enter gives new keys · Delete turns one off · R puts it back", keywords: "rebind keys bind hotkey shortcut launcher lock screenshot window workspace" },
        { section: "shortcuts", group: "The Line's", key: "workspaceKeys", kind: "info", label: "Workspaces 1 to 10",
          sub: "Go: Super · send the window: Super+Ctrl · send and follow: Super+Shift", keywords: "workspace number digit send move",
          value: "the 1 … 0 keys" },
        { section: "shortcuts", group: "The Line's", key: "cheatsheet", kind: "info", label: "Every shortcut at once",
          sub: "The cheat sheet, anywhere", keywords: "cheat sheet help list", value: "Super + F1" },

        { section: "system", group: "This computer", source: "sys", key: "hostname", kind: "text", label: "Name of this computer",
          sub: "How other devices on the network see it", keywords: "hostname name computer network",
          placeholder: "letters, digits and dashes", validate: "^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$" },
        { section: "system", group: "Date and time", source: "sys", key: "ntp", kind: "toggle", label: "Set the time automatically",
          sub: "From the internet (chrony)", keywords: "ntp chrony sync clock automatic" },
        { section: "system", group: "Date and time", source: "sys", key: "timezone", kind: "timezone", label: "Time zone",
          sub: "Enter, then type a city", keywords: "timezone zone city region clock" },
        { section: "system", group: "Date and time", source: "sys", key: "time", kind: "datetime", label: "Date and time",
          sub: "Turn off the automatic time to set it by hand", keywords: "date time clock set" },
        { section: "system", group: "Specifications", source: "sys", key: "model", kind: "info", label: "Computer", sub: "", keywords: "model vendor laptop hardware" },
        { section: "system", group: "Specifications", source: "sys", key: "cpu", kind: "info", label: "Processor", sub: "", keywords: "cpu processor" },
        { section: "system", group: "Specifications", source: "sys", key: "gpu", kind: "info", label: "Graphics", sub: "", keywords: "gpu graphics card nvidia intel amd video" },
        { section: "system", group: "Specifications", source: "sys", key: "memory", kind: "info", label: "Memory", sub: "", keywords: "ram memory" },
        { section: "system", group: "Specifications", source: "sys", key: "kernel", kind: "info", label: "Kernel", sub: "", keywords: "kernel linux version shinigami" },
        { section: "system", group: "Specifications", source: "sys", key: "uptime", kind: "info", label: "Running for", sub: "Since the last start", keywords: "uptime" },

        { section: "about", group: "The Line", key: "aboutCard", kind: "aboutCard", label: "The Line", bare: true,
          sub: "A desktop shell for Hyprland, made with Quickshell", keywords: "version shell" },
        { section: "about", group: "The Line", source: "sys", key: "os", kind: "info", label: "Running on", sub: "The system under it", keywords: "os distribution kira linux release" },
        { section: "about", group: "The Line", source: "sys", key: "hyprland", kind: "info", label: "Hyprland", sub: "The compositor: windows, workspaces, keys", keywords: "compositor wayland version" },
        { section: "about", group: "The Line", source: "sys", key: "quickshell", kind: "info", label: "Quickshell", sub: "What the shell is built with (QML)", keywords: "qml qt version" },
        { section: "about", group: "Made by", key: "creator", kind: "info", label: "OxoGhost", sub: "Who made The Line", keywords: "creator author credits", value: "creator" },
        { section: "about", group: "Made by", key: "website", kind: "link", label: "Website", sub: "Enter opens it", keywords: "site web link", value: "oxoghost.dev", url: "https://oxoghost.dev" },
        { section: "about", group: "Made by", key: "github", kind: "link", label: "GitHub", sub: "Enter opens it", keywords: "github code link", value: "github.com/OxoGhost01", url: "https://github.com/OxoGhost01" },
        { section: "about", group: "Made by", key: "source", kind: "link", label: "The Line's code", sub: "Enter opens it", keywords: "source repository git link", value: "github.com/shinigami-os/the-line", url: "https://github.com/shinigami-os/the-line" },

        { section: "signin", group: "Your face", source: "sys", key: "faces", kind: "faces", label: "Faces",
          sub: "Recorded with howdy · Delete removes one", keywords: "howdy face camera record ir" },
        { section: "signin", group: "Your face", key: "unlockBiometrics", kind: "toggle", label: "Unlock the screen with your face or fingerprint",
          sub: "Three tries, then only the password · also a button on the lock screen", keywords: "howdy lock unlock face fingerprint biometrics tries" },
        { section: "signin", group: "Your face", source: "sys", key: "faceGreetd", kind: "toggle", label: "Log in with your face",
          sub: "On the login screen, before the password", keywords: "howdy login greeter face" },
        { section: "signin", group: "Fingerprint", source: "sys", key: "fingerprint", kind: "info", label: "Fingerprint reader",
          sub: "Through fprintd", keywords: "fingerprint fprintd reader" },

        { section: "network", group: "Wi-Fi", source: "net", key: "wifiEnabled", kind: "toggle", label: "Wi-Fi",
          sub: "Wireless networking", keywords: "wireless radio airplane" },
        { section: "network", group: "Wi-Fi", source: "net", key: "networks", kind: "wifiNetworks", label: "Networks around",
          sub: "Enter connects or disconnects · Delete forgets a saved one", keywords: "ssid connect password join forget scan" },
        { section: "network", group: "Wired", source: "net", key: "wired", kind: "info", label: "Ethernet",
          sub: "A network cable", keywords: "cable lan wired" },
        { section: "network", group: "This computer", source: "net", key: "address", kind: "info", label: "IP address",
          sub: "On the local network", keywords: "ip address local lan" },
        { section: "network", group: "This computer", source: "net", key: "publicAddress", kind: "info", label: "Public IP address",
          sub: "As the internet sees you · asked to api.ipify.org while this page is open", keywords: "ip address public external wan internet outside" },

        { section: "bluetooth", group: "Bluetooth", source: "bt", key: "enabled", kind: "toggle", label: "Bluetooth",
          sub: "The adapter's power", keywords: "on off radio" },
        { section: "bluetooth", group: "Bluetooth", source: "bt", key: "discovering", kind: "toggle", label: "Look for devices",
          sub: "Devices nearby appear in the list while on", keywords: "scan search discover new pair" },
        { section: "bluetooth", group: "Bluetooth", source: "bt", key: "discoverable", kind: "toggle", label: "Visible to other devices",
          sub: "Lets a phone or another computer find this one", keywords: "discoverable visible" },
        { section: "bluetooth", group: "Devices", source: "bt", key: "devices", kind: "btDevices", label: "Devices",
          sub: "Enter connects or disconnects (pairs a new one first) · Delete forgets", keywords: "headphones mouse keyboard controller pair connect forget" },

        { section: "sound", group: "Output", source: "sound", key: "outputs", kind: "audioDevices", label: "Plays on",
          sub: "Enter picks the output", keywords: "speakers headphones hdmi output device" },
        { section: "sound", group: "Output", source: "sound", key: "outputVolume", kind: "slider", min: 0, max: 100, step: 2, unit: "%",
          label: "Volume", sub: "The output's own volume", keywords: "loud sound level" },
        { section: "sound", group: "Output", source: "sound", key: "outputMuted", kind: "toggle", label: "Mute",
          sub: "Silences the output", keywords: "silence quiet" },
        { section: "sound", group: "Input", source: "sound", key: "inputs", kind: "audioDevices", label: "Listens on",
          sub: "Enter picks the microphone", keywords: "microphone mic input device record" },
        { section: "sound", group: "Input", source: "sound", key: "inputVolume", kind: "slider", min: 0, max: 100, step: 2, unit: "%",
          label: "Input level", sub: "How loud the microphone is", keywords: "microphone gain level" },
        { section: "sound", group: "Input", source: "sound", key: "inputMuted", kind: "toggle", label: "Mute the microphone",
          sub: "Nothing is recorded", keywords: "microphone silence privacy" },
        { section: "sound", group: "Apps", source: "sound", key: "streams", kind: "audioStreams", label: "Apps playing",
          sub: "Each app's own volume · ← → changes it", keywords: "app application volume mixer per-app" },

        { section: "appearance", group: "Wallpaper", key: "wallpaper", kind: "wallpaper", label: "Wallpaper",
          sub: "← → to look, Enter to set it · Tab: which screen", keywords: "background image picture screen monitor animated video gif live" },
        { section: "appearance", group: "Wallpaper", key: "wallpaperStillOnBattery", kind: "toggle", label: "Still on battery",
          sub: "Animated wallpapers stop moving off the charger", keywords: "animated video gif power battery" },
        { section: "appearance", group: "Accent", key: "accentFromWallpaper", kind: "toggle", label: "Accent from the wallpaper",
          sub: "Picks it in the primary screen's wallpaper each time it changes", keywords: "color colour matugen auto" },
        { section: "appearance", group: "Accent", key: "accent", kind: "color", label: "Accent colour",
          sub: "The workspace marker, toggles, selections", keywords: "color colour highlight",
          choices: Theme.accents },
        { section: "appearance", group: "Other apps", key: "iconTheme", kind: "iconTheme", label: "Icon theme",
          sub: "Apps' icons, and the launcher's · ← → · Qt apps need qt6ct · apps change when they start again",
          keywords: "icons papirus gtk qt qt6ct theme apps" },
        { section: "appearance", group: "Motion", key: "reduceMotion", kind: "toggle", label: "Reduce motion",
          sub: "Everything appears at once", keywords: "animation accessibility" },
        { section: "appearance", group: "Motion", key: "motionScale", kind: "speed", label: "Motion speed",
          sub: "Every animation, faster or slower", keywords: "animation speed slow fast" },

        { section: "workspaces", group: "Workspace ruler", key: "workspaceIcons", kind: "toggle", label: "App icons on the ruler",
          sub: "Each workspace shows its app's icon instead of its number", keywords: "icons numbers" },
        { section: "workspaces", group: "Workspace ruler", key: "workspaceScrollInverted", kind: "choice", label: "SUPER + scroll up goes to",
          sub: "Scrolling down goes the other way", keywords: "scroll direction invert wheel",
          choices: [{ value: false, label: "the next one (3 → 4)" }, { value: true, label: "the previous one (4 → 3)" }] },
        { section: "workspaces", group: "Apps on their workspace", key: "workspaceApps", kind: "workspaceApps", label: "Apps on their workspace",
          sub: "An app listed here always opens on its workspace", keywords: "rule bind assign app open" },
        { section: "workspaces", group: "Floating apps", key: "floating", kind: "floatingApps", label: "Remembered floating apps",
          sub: "Set floating with SUPER + ALT + Space: they open floating, where you left them", keywords: "float window size place remember forget" },

        { section: "power", group: "When idle", key: "idleDim", kind: "stops", label: "Dim the screens after",
          sub: "Any key or move brings the brightness back", keywords: "idle dim brightness timeout", stops: root.minutes },
        { section: "power", group: "When idle", key: "idleLock", kind: "stops", label: "Lock after",
          sub: "The screens stay on once locked", keywords: "idle lock timeout password", stops: root.minutes },
        { section: "power", group: "When idle", key: "idleSuspend", kind: "stops", label: "Suspend after",
          sub: "The session is locked first", keywords: "idle suspend sleep timeout", stops: root.minutes },
        { section: "power", group: "Battery", source: "sys", key: "chargeLimit", kind: "chargeLimit", label: "Stop charging at",
          sub: "A battery that stays plugged in lasts longer below 100 % · ← →", keywords: "battery charge limit threshold health 80" },
        { section: "power", group: "Buttons and lid", key: "powerButton", kind: "choice", label: "Pressing the power button",
          sub: "A long press still turns the computer off", keywords: "power button acpi",
          choices: [{ value: "menu", label: "power menu" }, { value: "suspend", label: "suspend" }, { value: "lock", label: "lock" }, { value: "nothing", label: "nothing" }] },
        { section: "power", group: "Buttons and lid", source: "sys", key: "lidAction", kind: "choice", label: "Closing the lid",
          sub: "Plugged in or not; a lid closed with a screen plugged in does nothing", keywords: "lid close laptop sleep suspend lock",
          choices: [{ value: "sleep", label: "lock and sleep" }, { value: "lock", label: "lock" }, { value: "nothing", label: "nothing" }] },
        { section: "power", group: "Buttons and lid", source: "sys", key: "sleepKey", kind: "choice", label: "Pressing the sleep key",
          sub: "The keyboard's sleep or moon key", keywords: "sleep key suspend button moon fn",
          choices: [{ value: "sleep", label: "lock and suspend" }, { value: "lock", label: "lock" }, { value: "nothing", label: "nothing" }] },

        { section: "line", group: "Levels", key: "levelStep", kind: "slider", min: 1, max: 10, step: 1, unit: "%",
          label: "Volume and brightness step", sub: "How much one key press changes", keywords: "volume brightness keyboard backlight keys" },
        { section: "line", group: "Kira", key: "kiraVoice", kind: "toggle", label: "Kira's voice",
          sub: "Her quotes on an empty workspace, and her one-off lines", keywords: "quotes voice text desktop" },
        { section: "line", group: "Clipboard", key: "clipboardMax", kind: "choice", label: "History size",
          sub: "Entries kept in SUPER + V", keywords: "clipboard history",
          choices: [{ value: 50, label: "50" }, { value: 100, label: "100" }, { value: 200, label: "200" }, { value: 500, label: "500" }, { value: 1000, label: "1000" }] },
        { section: "line", group: "Clipboard", key: "clipboardImages", kind: "toggle", label: "Keep images",
          sub: "Copied images go in the history too", keywords: "clipboard pictures screenshots" },
        { section: "line", group: "Clipboard", key: "clipboardWipeOnLogin", kind: "toggle", label: "Empty it at each login",
          sub: "Nothing copied survives a logout", keywords: "clipboard privacy clear" }
    ]

    // Idle times, in minutes (0 = never).
    readonly property var minutes: [1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 0].map(m => ({
        value: m, label: m === 0 ? "never" : m < 60 ? m + " min" : (m / 60) + " h"
    }))

    // Hovering selects a row, but not right after a key: a list scrolled by the keyboard slides rows under a still
    // pointer, and they would take the selection back.
    property real keyAt: 0

    function hoverPicks() {
        return Date.now() - keyAt > Math.max(500, Anim.base + 400);   // longer than the list's scroll, at any speed
    }

    function section(id) {
        return sections.find(s => s.id === id) ?? null;
    }

    function settingsOf(id) {
        return settings.filter(s => s.section === id);
    }

    function value(setting) {
        if (setting.value !== undefined)
            return setting.value;   // a fixed fact (an info row)
        const b = backend(setting);
        return b ? b[setting.key] : Config[setting.key];
    }

    // The value shown in a row or a search result.
    function valueText(setting) {
        const v = value(setting);
        if (setting.kind === "toggle")
            return v ? "on" : "off";
        if (setting.kind === "slider")
            return (setting.decimals ? Number(v).toFixed(setting.decimals) : v) + (setting.unit ? " " + setting.unit : "");
        if (setting.kind === "speed")
            return speed(v).toFixed(2) + "×";
        if (setting.kind === "wallpaper")
            return String(v).split("/").pop();
        if (setting.kind === "workspaceApps")
            return (v ?? []).length + " apps";
        if (setting.kind === "info" || setting.kind === "link")
            return String(v);
        if (setting.kind === "text" || setting.kind === "timezone")
            return String(v);
        if (setting.kind === "iconTheme")
            return IconThemes.choices.find(c => c.value === v)?.label ?? (v || "automatic");
        if (setting.kind === "chargeLimit")
            return Sys.chargeSupported ? v + " %" : "not offered";
        if (isCustom(setting))
            return "›";
        const c = (setting.choices ?? setting.stops ?? []).find(c => same(c.value, v));
        return c ? c.label : String(v);
    }

    function same(a, b) {
        return typeof a === "number" ? Math.abs(a - Number(b)) < 0.001 : String(a).toLowerCase() === String(b).toLowerCase();
    }

    // Sets a setting. Picking an accent by hand stops taking it from the wallpaper.
    function set(setting, v) {
        const b = backend(setting);
        if (b) {
            b.set(setting.key, v);
            return;
        }
        Config.set(setting.key, v);
        if (setting.key === "accent" && Config.accentFromWallpaper)
            Config.set("accentFromWallpaper", false);
    }

    // Steps a setting: toggles flip, sliders and choices move by `dir` (-1 / 1, wrapping for choices).
    function step(setting, dir) {
        const v = value(setting);
        if (setting.kind === "link") {
            Qt.openUrlExternally(setting.url);
        } else if (setting.kind === "toggle") {
            set(setting, !v);
        } else if (setting.kind === "slider") {
            set(setting, snap(setting, v + dir * setting.step));
        } else if (setting.kind === "speed") {
            setSpeed(Math.round((speed(v) + dir * 0.05) * 100) / 100);
        } else if (setting.kind === "stops") {
            const i = setting.stops.findIndex(c => same(c.value, v));
            set(setting, setting.stops[Math.max(0, Math.min(setting.stops.length - 1, (i < 0 ? 0 : i) + dir))].value);
        } else if (setting.choices) {
            const list = setting.choices;
            const i = list.findIndex(c => same(c.value, v));
            set(setting, list[((i < 0 ? 0 : i + dir) + list.length) % list.length].value);
        }
    }

    // A slider's value on its steps and within its ends, without float dust (0.1 + 0.2).
    function snap(setting, v) {
        const n = Math.round((v - setting.min) / setting.step) * setting.step + setting.min;
        return Number(Math.max(setting.min, Math.min(setting.max, n)).toFixed(4));
    }

    // Motion speed: config.json keeps motionScale, a duration factor (speed 2× = durations × 0.5).
    function speed(scale) {
        return 1 / Math.max(0.01, scale);
    }

    function setSpeed(value) {
        Config.set("motionScale", 1 / Math.max(0.5, Math.min(2, value)));
    }

    // `text` with every word of the search lit in the accent (StyledText).
    function highlight(text, query) {
        const esc = t => t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        const words = query.trim().toLowerCase().split(/\s+/).filter(w => w !== "");
        if (words.length === 0)
            return esc(text);
        const lit = new Array(text.length).fill(false);
        const lower = text.toLowerCase();
        for (const w of words) {
            let i = lower.indexOf(w);
            while (i >= 0) {
                for (let k = i; k < i + w.length; k++)
                    lit[k] = true;
                i = lower.indexOf(w, i + w.length);
            }
        }
        let out = "";
        let open = false;
        for (let k = 0; k < text.length; k++) {
            if (lit[k] !== open) {
                out += lit[k] ? "<font color=\"" + Theme.accent + "\">" : "</font>";
                open = lit[k];
            }
            out += esc(text[k]);
        }
        return out + (open ? "</font>" : "");
    }

    // The search: every setting and every section, by label, sub, keywords and section name.
    function search(query) {
        const q = query.trim().toLowerCase();
        if (q === "")
            return [];
        const words = q.split(/\s+/);
        const score = (text, extra) => {
            const t = text.toLowerCase();
            const all = (t + " " + extra).toLowerCase();
            if (!words.every(w => all.includes(w)))
                return 0;
            return t.startsWith(q) ? 100 : t.split(/\s+/).some(w => w.startsWith(words[0])) ? 80 : 50;
        };
        const out = [];
        for (const s of sections) {
            const sc = score(s.name, s.keywords + " " + s.plan);
            if (sc > 0)
                out.push({ kind: "section", section: s.id, label: s.name, where: "section", score: sc + 5 });
        }
        for (const st of settings) {
            const sec = section(st.section);
            const sc = score(st.label, st.sub + " " + st.keywords + " " + st.group + " " + sec.name);
            if (sc > 0)
                out.push({ kind: "setting", section: st.section, setting: st, label: st.label, where: sec.name, score: sc });
        }
        return out.sort((a, b) => b.score - a.score || a.label.localeCompare(b.label)).slice(0, 9);
    }
}
