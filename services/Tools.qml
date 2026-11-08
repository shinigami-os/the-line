pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The launcher's shortcuts: the shell's own tools, with the keys they are on (read from Hyprland by their bind's
// description, so a key moved in Settings > Shortcuts shows where it is now). Some are switches and show on / off.
// Each one's `run(screen)` gets the screen the launcher was open on.
Singleton {
    id: root

    property var keyOf: ({})   // bind description -> "Super+V"

    function dialog(key, screen) {
        UiState[key] = screen;
    }

    function exec(command) {
        // after the launcher has folded, so a screenshot doesn't catch it
        Quickshell.execDetached(["sh", "-c", "sleep 0.35; " + command]);
    }

    readonly property var list: [
        { id: "wallpapers", name: "Wallpapers", about: "pick one, seen on the whole screen first", bind: "The Line: wallpaper picker",
          keywords: "background picture image", run: s => root.dialog("wallScreen", s) },
        { id: "clipboard", name: "Clipboard history", about: "what you copied", bind: "The Line: clipboard history",
          keywords: "copy paste", run: s => root.dialog("clipScreen", s) },
        { id: "emoji", name: "Emoji", about: "pick one, it is copied", bind: "The Line: emoji picker",
          keywords: "smiley symbol", run: s => root.dialog("emojiScreen", s) },
        { id: "visualiser", name: "Music visualiser", about: "the frequencies on the line", bind: "The Line: music visualiser on the line (again to stop)",
          keywords: "music spectrum cava audio", toggle: () => Visualiser.on, run: s => Visualiser.toggle() },
        { id: "shortcuts", name: "Every shortcut", about: "the cheat sheet", bind: "The Line: every shortcut, in one sheet",
          keywords: "keys keyboard help cheat sheet binds", run: s => root.dialog("sheetScreen", s) },
        { id: "overview", name: "Workspace overview", about: "every workspace at a glance", tap: "Super Super",
          keywords: "windows expose", run: s => UiState.toggle(s, "tw") },
        { id: "notifications", name: "Notifications", about: "and the calendar", bind: "The Line: notifications and calendar",
          keywords: "calendar clock", run: s => UiState.toggle(s, "tc") },
        { id: "quick", name: "Quick settings", about: "Wi-Fi, Bluetooth, sound, brightness", bind: "The Line: quick settings",
          keywords: "wifi bluetooth volume", run: s => UiState.toggle(s, "tr") },
        { id: "performance", name: "Performance", about: "processor, memory, disks, network", bind: "The Line: performance",
          keywords: "cpu ram usage monitor", run: s => UiState.toggle(s, "tp") },
        { id: "dnd", name: "Do not disturb", about: "notifications wait in the list", keywords: "quiet silence focus",
          toggle: () => Notifs.dnd, run: s => Notifs.dnd = !Notifs.dnd },
        { id: "awake", name: "Keep awake", about: "no dimming, no lock, no sleep", keywords: "caffeine idle inhibit",
          toggle: () => Power.keepAwake, run: s => Power.keepAwake = !Power.keepAwake },
        { id: "night", name: "Night light", about: "warmer colours", keywords: "blue light warm hyprsunset",
          toggle: () => NightLight.on, run: s => NightLight.toggle() },
        { id: "shot", name: "Screenshot", about: "an area, on this screen", bind: "Screenshots and tools: Screenshot (Flameshot, on this screen)",
          keywords: "capture print", run: s => root.exec(Config.session("the-line-shot")) },
        { id: "picker", name: "Colour picker", about: "the colour under the pointer, copied", bind: "Screenshots and tools: Colour picker to the clipboard",
          keywords: "color hex eyedropper", run: s => root.exec("hyprpicker -a") },
        { id: "ocr", name: "Text from an area", about: "read from the screen, copied", bind: "Screenshots and tools: Text from an area (OCR) to the clipboard",
          keywords: "ocr tesseract read", run: s => root.exec("grim -g \"$(slurp)\" - | tesseract - - | wl-copy") },
        { id: "record", name: "Record an area", about: "to ~/Videos/Recordings, again to stop", bind: "Screenshots and tools: Record an area (again to stop)",
          keywords: "video screencast wf-recorder", run: s => root.exec("pkill -INT -x wf-recorder || { mkdir -p ~/Videos/Recordings && wf-recorder -g \"$(slurp)\" -f ~/Videos/Recordings/$(date +%Y-%m-%d_%H.%M.%S).mp4; }") },
        { id: "lock", name: "Lock", about: "the screens", bind: "Session: Lock", keywords: "screen password", run: s => root.exec("hyprlock") },
        { id: "power", name: "Power menu", about: "log out, suspend, restart, power off", bind: "The Line: power menu",
          keywords: "shutdown reboot logout suspend", run: s => { UiState.powerSelected = 0; root.dialog("powerScreen", s); } },
        { id: "restart", name: "Restart the shell", about: "The Line starts again", bind: "The Line: restart the shell",
          keywords: "reload quickshell", run: s => root.exec("pkill -f '^qs -p " + Config.shellRoot + "$'; pgrep -f '^/bin/sh .*/session/the-line-shell$' >/dev/null || " + Config.session("the-line-shell")) }
    ]

    // The key a tool is on, as written on a key cap.
    function keys(tool) {
        return tool.tap ?? keyOf[tool.bind] ?? "";
    }

    // The empty launcher shows these.
    readonly property var first: ["wallpapers", "clipboard", "visualiser", "shortcuts"]

    // Every word typed starts a word of the name, the description or the keywords.
    function search(query, limit) {
        const q = query.trim().toLowerCase();
        if (q === "")
            return list.filter(t => first.includes(t.id)).slice(0, limit);
        const words = q.split(/\s+/);
        const scored = [];
        for (const t of list) {
            const name = t.name.toLowerCase();
            const all = (name + " " + t.about + " " + t.keywords).toLowerCase().split(/[\s,()/]+/);
            if (!words.every(w => all.some(a => a.startsWith(w))))
                continue;
            scored.push({ t: t, s: name.startsWith(q) ? 3 : name.split(/\s+/).some(w => w.startsWith(words[0])) ? 2 : 1 });
        }
        return scored.sort((a, b) => b.s - a.s).slice(0, limit).map(x => x.t);
    }

    // The keys are read again each time the launcher opens (they can move in Settings > Shortcuts).
    function refresh() {
        if (!binds.running)
            binds.running = true;
    }

    Process {
        id: binds
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const map = {};
                    for (const b of JSON.parse(text)) {
                        const d = b.description ?? "";
                        if (d !== "" && map[d] === undefined)
                            map[d] = Cheatsheet.capsOf(b).join("+");
                    }
                    root.keyOf = map;
                } catch (e) {}
            }
        }
    }
}
