pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Floating windows (SUPER+ALT+Space goes through here).
//   Floating one: it shrinks to 75% of its tiled size, centred where it was tiled, instead of filling the screen;
//   or, for an app floated before, it goes back to that app's last size and place.
//   The apps you float are remembered with their size and position (on their screen) as Hyprland window rules in
//   ~/.config/the-line/hypr/floating.lua: their next window opens floating, in place. Tiling one again forgets it.
Singleton {
    id: root

    property var memory: ({})   // class -> { w, h, x, y } (x, y on the window's screen)
    property bool dirty: false
    // The Line's own windows with a fixed floating rule (session/hyprland.lua): never remembered over it.
    readonly property var fixed: ["the-line-settings"]
    readonly property string rulesPath: Quickshell.env("HOME") + "/.config/the-line/hypr/floating.lua"

    function toggle() {
        if (!active.running)
            active.running = true;
    }

    // Settings > Workspaces: forget an app, its next window opens tiled.
    function forget(cls) {
        // This singleton starts on first use: called before its file has loaded, read the file now.
        let mem = memory;
        if (mem[cls] === undefined) {
            try {
                mem = JSON.parse(state.text() || "{}");
            } catch (e) {
                mem = {};
            }
        }
        if (mem[cls] === undefined)
            return;
        const m = Object.assign({}, mem);
        delete m[cls];
        memory = m;
        save(true);
        maybeReload(cls);
    }

    function monitorOf(id) {
        return Hyprland.monitors.values.find(m => m.id === id) ?? null;
    }

    function apply(win) {
        const cls = win.class ?? "";
        const target = "window = \"address:" + win.address + "\"";
        if (win.floating) {
            Hyprland.dispatch("hl.dsp.window.float({ action = \"disable\", " + target + " })");
            if (memory[cls] !== undefined) {
                const m = Object.assign({}, memory);
                delete m[cls];
                memory = m;
                save(true);
            }
            return;
        }
        const mon = monitorOf(win.monitor);
        const mx = mon?.x ?? 0, my = mon?.y ?? 0;
        const known = memory[cls];
        const w = known ? known.w : Math.round(win.size[0] * 0.75);
        const h = known ? known.h : Math.round(win.size[1] * 0.75);
        const x = known ? mx + known.x : Math.round(win.at[0] + (win.size[0] - w) / 2);
        const y = known ? my + known.y : Math.round(win.at[1] + (win.size[1] - h) / 2);
        Hyprland.dispatch("hl.dsp.window.float({ action = \"enable\", " + target + " })");
        Hyprland.dispatch("hl.dsp.window.resize({ x = " + w + ", y = " + h + ", " + target + " })");
        Hyprland.dispatch("hl.dsp.window.move({ x = " + x + ", y = " + y + ", " + target + " })");
        if (cls !== "" && fixed.indexOf(cls) < 0) {
            const m = Object.assign({}, memory);
            m[cls] = { w: w, h: h, x: x - mx, y: y - my };
            memory = m;
            save(true);
        }
    }

    // Lua string escaping for a class used in a regex.
    function pattern(cls) {
        return "^(" + cls.replace(/[.*+?^${}()|[\]\\]/g, "\\\\$&").replace(/"/g, "\\\"") + ")$";
    }

    function save(now) {
        const lines = ["-- Written by The Line: the apps you set floating, with their last size and place on their screen.",
            "-- Tile an app again (SUPER+ALT+Space) and it leaves this list. Edits here are replaced: forget an app in Settings > Workspaces."];
        for (const cls in memory) {
            const g = memory[cls];
            // "W H" and "X Y", space-separated (with a comma Hyprland ignores them); move is on the window's screen.
            lines.push("hl.window_rule({ match = { class = \"" + pattern(cls) + "\" }, float = true, size = \""
                + g.w + " " + g.h + "\", move = \"" + g.x + " " + g.y + "\" })");
        }
        rules.setText(lines.join("\n") + "\n");
        state.setText(JSON.stringify(memory));
        dirty = true;
    }

    // Hyprland reads the rules when it loads its config: reload it when an app it should now remember closes.
    function maybeReload(cls) {
        if (dirty) {
            dirty = false;
            Quickshell.execDetached(["hyprctl", "reload"]);
        }
    }

    // The focused window, fresh from Hyprland.
    Process {
        id: active
        command: ["hyprctl", "-j", "activewindow"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const win = JSON.parse(text);
                    if (win && win.address)
                        root.apply(win);
                } catch (e) {}
            }
        }
    }

    // Keep the remembered apps' size and place up to date while they float (moved or resized by hand).
    Process {
        id: clients
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                let changed = false;
                const m = Object.assign({}, root.memory);
                try {
                    for (const c of JSON.parse(text)) {
                        if (!c.floating || m[c.class] === undefined || c.fullscreen)
                            continue;
                        const mon = root.monitorOf(c.monitor);
                        const g = { w: c.size[0], h: c.size[1], x: c.at[0] - (mon?.x ?? 0), y: c.at[1] - (mon?.y ?? 0) };
                        const o = m[c.class];
                        if (o.w !== g.w || o.h !== g.h || o.x !== g.x || o.y !== g.y) {
                            m[c.class] = g;
                            changed = true;
                        }
                    }
                } catch (e) {}
                if (changed) {
                    root.memory = m;
                    root.save(false);
                }
            }
        }
    }
    Timer {
        running: Object.keys(root.memory).length > 0
        repeat: true
        interval: 3000
        onTriggered: if (!clients.running) clients.running = true
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "closewindow")
                root.maybeReload();
        }
    }

    FileView {
        id: state
        path: Quickshell.env("HOME") + "/.local/state/the-line/floating.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                root.memory = JSON.parse(text());
            } catch (e) {
                root.memory = {};
            }
        }
    }
    FileView {
        id: rules
        path: root.rulesPath
        printErrors: false
    }
}
