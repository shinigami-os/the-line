pragma Singleton

import QtQuick
import Quickshell

// The settings app's sections, in the spine's order: read by the app (settings/services/Registry.qml) and by the
// launcher, which offers "Settings › Network" when you type "wifi". A section's words are searched too.
Singleton {
    id: root

    readonly property var list: [
        { id: "network", name: "Network", keywords: "wifi wi-fi wireless ethernet internet connection", plan: "Wi-Fi networks, connect, forget, Ethernet" },
        { id: "bluetooth", name: "Bluetooth", keywords: "devices pair headphones", plan: "Scan, pair, connect, forget devices" },
        { id: "sound", name: "Sound", keywords: "audio volume speakers microphone output input", plan: "Output and input devices, per-app volume" },
        { id: "displays", name: "Displays", keywords: "monitor screen resolution scale refresh primary", plan: "Resolution, scale, position, primary screen" },
        { id: "input", name: "Input", keywords: "keyboard layout touchpad mouse tap natural scroll", plan: "Keyboard layout, touchpad speed, tap, natural scroll" },
        { id: "appearance", name: "Appearance", keywords: "theme look colour color accent wallpaper motion animation icons", plan: "Wallpaper, accent, icon theme, motion" },
        { id: "workspaces", name: "Workspaces", keywords: "workspace app rule floating", plan: "Bind an app to a workspace, remembered floating apps" },
        { id: "shortcuts", name: "Shortcuts", keywords: "keys keybinds bindings hotkeys", plan: "Every shortcut, edit app keys, rebind The Line's keys" },
        { id: "power", name: "Power & idle", keywords: "idle dim lock suspend sleep battery charge power button", plan: "Dim, lock and suspend times, power button, battery charge limit" },
        { id: "notifications", name: "Notifications", keywords: "dnd do not disturb toast", plan: "Do not disturb schedule, muted apps" },
        { id: "nightlight", name: "Night light", keywords: "blue light warm temperature evening", plan: "Temperature and schedule" },
        { id: "storage", name: "Storage", keywords: "disk drive space partition usage", plan: "Disks, partitions, what fills your home" },
        { id: "apps", name: "Default apps", keywords: "browser file manager terminal open with mime", plan: "Browser, file manager, terminal, viewers" },
        { id: "signin", name: "Sign-in", keywords: "howdy face fingerprint login password", plan: "Howdy face models, fingerprints" },
        { id: "system", name: "System", keywords: "hostname name date time timezone clock specifications hardware kernel", plan: "Computer name, date and time, time zone, specifications" },
        { id: "line", name: "The Line", keywords: "shell bar line levels clipboard voice", plan: "Level steps, clipboard history, Kira's voice" },
        { id: "about", name: "About", keywords: "version credits author creator links github website", plan: "Version, what it runs on, who made it" }
    ]

    // Sections whose name or one of whose words starts with every word typed ("wifi", "key", "night li").
    function search(query) {
        const words = query.trim().toLowerCase().split(/\s+/).filter(w => w !== "");
        if (words.length === 0 || query.trim().length < 3)
            return [];
        return list.filter(s => {
            const all = (s.name + " " + s.keywords).toLowerCase().split(/[\s\-]+/);
            return words.every(w => all.some(a => a.startsWith(w)));
        });
    }

    // The launcher's "/" prefix: from the first letter, every section when nothing is typed (nine at most).
    function find(query) {
        const words = query.trim().toLowerCase().split(/\s+/).filter(w => w !== "");
        return list.filter(s => {
            const all = (s.name + " " + s.keywords).toLowerCase().split(/[\s\-]+/);
            return words.every(w => all.some(a => a.startsWith(w)));
        }).slice(0, 9);
    }
}
