pragma Singleton

import QtQuick
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
// A section without settings yet shows what is planned for it (`plan`).
Singleton {
    id: root

    readonly property var sections: [
        { id: "network", name: "Network", keywords: "wifi wi-fi wireless ethernet internet connection", plan: "Wi-Fi networks, connect, forget, Ethernet" },
        { id: "bluetooth", name: "Bluetooth", keywords: "devices pair headphones", plan: "Scan, pair, connect, forget devices" },
        { id: "sound", name: "Sound", keywords: "audio volume speakers microphone output input", plan: "Output and input devices, per-app volume" },
        { id: "displays", name: "Displays", keywords: "monitor screen resolution scale refresh primary", plan: "Resolution, scale, position, primary screen" },
        { id: "input", name: "Input", keywords: "keyboard layout touchpad mouse tap natural scroll", plan: "Keyboard layout, touchpad speed, tap, natural scroll" },
        { id: "appearance", name: "Appearance", keywords: "theme look colour color accent wallpaper motion animation", plan: "Wallpaper picker, accent from the wallpaper" },
        { id: "workspaces", name: "Workspaces", keywords: "workspace app rule floating", plan: "Bind an app to a workspace, remembered floating apps" },
        { id: "shortcuts", name: "Shortcuts", keywords: "keys keybinds bindings hotkeys", plan: "Every shortcut, edit app keys, rebind The Line's keys" },
        { id: "power", name: "Power & idle", keywords: "idle dim lock suspend sleep battery charge power button", plan: "Dim, lock and suspend times, power button, battery charge limit" },
        { id: "notifications", name: "Notifications", keywords: "dnd do not disturb toast", plan: "Do not disturb schedule, muted apps" },
        { id: "nightlight", name: "Night light", keywords: "blue light warm temperature evening", plan: "Temperature and schedule" },
        { id: "storage", name: "Storage", keywords: "disk drive space partition usage", plan: "Disks, partitions, what fills your home" },
        { id: "apps", name: "Default apps", keywords: "browser file manager terminal open with mime", plan: "Browser, file manager, terminal, viewers" },
        { id: "signin", name: "Sign-in", keywords: "howdy face fingerprint login password", plan: "Howdy face models, fingerprints" },
        { id: "system", name: "System", keywords: "hostname name date time timezone clock about version kernel", plan: "Hostname, date and time, time zone, about this computer" },
        { id: "line", name: "The Line", keywords: "shell bar line", plan: "" }
    ]

    // Row kinds drawn by their own component (in modules/settings).
    readonly property var customs: ({
        wallpaper: "WallpaperPicker.qml", workspaceApps: "WorkspaceRules.qml", floatingApps: "FloatingApps.qml",
        wifiNetworks: "WifiNetworks.qml", btDevices: "BtDevices.qml", audioDevices: "AudioDevices.qml", audioStreams: "AudioStreams.qml"
    })

    function isCustom(setting) {
        return customs[setting.kind] !== undefined;
    }

    function backend(setting) {
        return setting.source === "net" ? Net : setting.source === "bt" ? Bt : setting.source === "sound" ? Sound : null;
    }

    readonly property var settings: [
        { section: "network", group: "Wi-Fi", source: "net", key: "wifiEnabled", kind: "toggle", label: "Wi-Fi",
          sub: "Wireless networking", keywords: "wireless radio airplane" },
        { section: "network", group: "Wi-Fi", source: "net", key: "networks", kind: "wifiNetworks", label: "Networks around",
          sub: "Enter connects or disconnects · Delete forgets a saved one", keywords: "ssid connect password join forget scan" },
        { section: "network", group: "Wired", source: "net", key: "wired", kind: "info", label: "Ethernet",
          sub: "A network cable", keywords: "cable lan wired" },
        { section: "network", group: "This computer", source: "net", key: "address", kind: "info", label: "IP address",
          sub: "On the local network", keywords: "ip address local lan" },

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
          sub: "← → to look, Enter to set it", keywords: "background image picture" },
        { section: "appearance", group: "Accent", key: "accentFromWallpaper", kind: "toggle", label: "Accent from the wallpaper",
          sub: "Picks the accent in the wallpaper each time you change it", keywords: "color colour matugen auto" },
        { section: "appearance", group: "Accent", key: "accent", kind: "color", label: "Accent colour",
          sub: "The workspace marker, toggles, selections", keywords: "color colour highlight",
          choices: [
              { value: "#9A5CFF", label: "Kira violet" }, { value: "#5C8DFF", label: "Blue" },
              { value: "#4FC3B5", label: "Teal" }, { value: "#6CC495", label: "Green" },
              { value: "#E8B04B", label: "Amber" }, { value: "#EF7A5E", label: "Coral" },
              { value: "#E86FA5", label: "Pink" }, { value: "#ECE8E1", label: "Bone" }
          ] },
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
          sub: "The screens stay on once locked", keywords: "idle lock hyprlock timeout password", stops: root.minutes },
        { section: "power", group: "When idle", key: "idleSuspend", kind: "stops", label: "Suspend after",
          sub: "The session is locked first", keywords: "idle suspend sleep timeout", stops: root.minutes },
        { section: "power", group: "Power button", key: "powerButton", kind: "choice", label: "Pressing the power button",
          sub: "A long press still turns the computer off", keywords: "power button acpi",
          choices: [{ value: "menu", label: "power menu" }, { value: "suspend", label: "suspend" }, { value: "lock", label: "lock" }, { value: "nothing", label: "nothing" }] },

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
        const b = backend(setting);
        return b ? b[setting.key] : Config[setting.key];
    }

    // The value shown in a row or a search result.
    function valueText(setting) {
        const v = value(setting);
        if (setting.kind === "toggle")
            return v ? "on" : "off";
        if (setting.kind === "slider")
            return v + (setting.unit ? " " + setting.unit : "");
        if (setting.kind === "speed")
            return speed(v).toFixed(2) + "×";
        if (setting.kind === "wallpaper")
            return String(v).split("/").pop();
        if (setting.kind === "workspaceApps")
            return (v ?? []).length + " apps";
        if (setting.kind === "info")
            return String(v);
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
        if (setting.kind === "toggle") {
            set(setting, !v);
        } else if (setting.kind === "slider") {
            set(setting, Math.max(setting.min, Math.min(setting.max, v + dir * setting.step)));
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
