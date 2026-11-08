pragma Singleton

import QtQuick
import Quickshell

// Every section and every setting of the app, declared once: the spine, the rows and the search are built from here.
// A setting: { section, group, key (in config.json), kind, label, sub, keywords, ... }
//   toggle   on / off
//   slider   min, max, step, unit
//   choice   choices: [{ value, label }]
//   color    choices: [{ value, label }] drawn as swatches
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

    readonly property var settings: [
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
        { section: "appearance", group: "Motion", key: "motionScale", kind: "choice", label: "Motion speed",
          sub: "How long every animation takes", keywords: "animation speed slow fast",
          choices: [{ value: 0.75, label: "Quick" }, { value: 1, label: "Normal" }, { value: 1.3, label: "Calm" }, { value: 1.6, label: "Slow" }] },

        { section: "workspaces", group: "Workspace ruler", key: "workspaceIcons", kind: "toggle", label: "App icons on the ruler",
          sub: "Each workspace shows its app's icon instead of its number", keywords: "icons numbers" },
        { section: "workspaces", group: "Workspace ruler", key: "workspaceScrollInverted", kind: "toggle", label: "Scroll down for the next workspace",
          sub: "SUPER + scroll", keywords: "scroll direction invert" },

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

    function section(id) {
        return sections.find(s => s.id === id) ?? null;
    }

    function settingsOf(id) {
        return settings.filter(s => s.section === id);
    }

    function value(setting) {
        return Config[setting.key];
    }

    // The value shown in a row or a search result.
    function valueText(setting) {
        const v = value(setting);
        if (setting.kind === "toggle")
            return v ? "on" : "off";
        if (setting.kind === "slider")
            return v + (setting.unit ? " " + setting.unit : "");
        const c = (setting.choices ?? []).find(c => same(c.value, v));
        return c ? c.label : String(v);
    }

    function same(a, b) {
        return typeof a === "number" ? Math.abs(a - Number(b)) < 0.001 : String(a).toLowerCase() === String(b).toLowerCase();
    }

    // Steps a setting: toggles flip, sliders and choices move by `dir` (-1 / 1, wrapping for choices).
    function step(setting, dir) {
        const v = value(setting);
        if (setting.kind === "toggle") {
            Config.set(setting.key, !v);
        } else if (setting.kind === "slider") {
            Config.set(setting.key, Math.max(setting.min, Math.min(setting.max, v + dir * setting.step)));
        } else {
            const list = setting.choices;
            const i = list.findIndex(c => same(c.value, v));
            Config.set(setting.key, list[((i < 0 ? 0 : i + dir) + list.length) % list.length].value);
        }
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
