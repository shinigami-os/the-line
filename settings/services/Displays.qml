pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Settings > Displays: the screens as Hyprland has them (hyprctl monitors all -j), changed by writing their lines in
// ~/.config/the-line/hypr/monitors.lua (one hl.monitor line per screen; other lines of the file stay) and reloading.
// Every change asks to be kept: without Enter within 15 s it goes back. A detached watchdog goes back too
// (after 20 s), even if this app is closed or can't be seen any more.
// Positions are Hyprland's: logical pixels (the mode divided by the scale, turned when rotated).
Singleton {
    id: root

    property var screens: []          // [{ name, desc, w, h, hz, x, y, scale, transform, disabled, modes: [{ w, h, hz }] }]
    property string selected: ""
    property bool pending: false       // a change waits to be kept
    property int countdown: 0
    property string error: ""

    readonly property string path: Quickshell.env("HOME") + "/.config/the-line/hypr/monitors.lua"
    readonly property string state: Quickshell.env("HOME") + "/.local/state/the-line"
    readonly property var current: screens.find(s => s.name === selected) ?? null

    // Rows of the section (source "displays") read these.
    readonly property bool primary: current !== null && current.name === Config.primaryScreen
    readonly property bool enabled: current !== null && !current.disabled
    readonly property real scale: current?.scale ?? 1
    readonly property int transform: current?.transform ?? 0


    // ------------------------------------------------------------------ geometry

    function logical(s) {
        const turned = s.transform % 2 === 1;
        return { w: Math.round((turned ? s.h : s.w) / s.scale), h: Math.round((turned ? s.w : s.h) / s.scale) };
    }

    function rect(s) {
        const l = logical(s);
        return { x: s.x, y: s.y, w: l.w, h: l.h };
    }

    function overlaps(a, b) {
        return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
    }

    // Places where `s` can sit against the other screens: each side of each, aligned at the start, centre or end.
    function spots(plan, s) {
        const me = rect(s);
        const out = [];
        for (const o of plan.filter(o => o.name !== s.name && !o.disabled)) {
            const r = rect(o);
            const ys = [r.y, r.y + Math.round((r.h - me.h) / 2), r.y + r.h - me.h];
            const xs = [r.x, r.x + Math.round((r.w - me.w) / 2), r.x + r.w - me.w];
            for (const y of ys) {
                out.push({ x: r.x - me.w, y: y });
                out.push({ x: r.x + r.w, y: y });
            }
            for (const x of xs) {
                out.push({ x: x, y: r.y - me.h });
                out.push({ x: x, y: r.y + r.h });
            }
        }
        return out.filter(p => !plan.some(o => o.name !== s.name && !o.disabled && overlaps({ x: p.x, y: p.y, w: me.w, h: me.h }, rect(o))));
    }

    // The top-left screen at 0,0.
    function normalize(plan) {
        const on = plan.filter(s => !s.disabled);
        if (on.length === 0)
            return plan;
        const minX = Math.min(...on.map(s => s.x));
        const minY = Math.min(...on.map(s => s.y));
        return plan.map(s => s.disabled ? s : Object.assign({}, s, { x: s.x - minX, y: s.y - minY }));
    }

    // After a size change: screens pushed out of each other's way (to the right, then down), gaps closed.
    function settle(plan) {
        const on = plan.filter(s => !s.disabled).sort((a, b) => a.x - b.x || a.y - b.y);
        for (let i = 0; i < on.length; i++) {
            for (let j = 0; j < i; j++) {
                const a = rect(on[j]);
                const b = rect(on[i]);
                if (overlaps(a, b))
                    on[i] = Object.assign({}, on[i], { x: a.x + a.w });
            }
        }
        // close a horizontal gap left of a screen when another screen shares its height band
        for (let i = 0; i < on.length; i++) {
            const b = rect(on[i]);
            const left = on.filter((o, j) => j !== i).map(rect).filter(r => r.x + r.w <= b.x && r.y < b.y + b.h && b.y < r.y + r.h);
            if (left.length > 0)
                on[i] = Object.assign({}, on[i], { x: Math.max(...left.map(r => r.x + r.w)) });
        }
        return normalize(plan.map(s => on.find(o => o.name === s.name) ?? s));
    }

    // ------------------------------------------------------------------ changes

    function changed(name, changes) {
        return screens.map(s => s.name === name ? Object.assign({}, s, changes) : s);
    }

    // A screen dropped (map) or pushed (Shift+arrows) towards x, y: the nearest free spot against the others.
    function moveTo(name, x, y, dir) {
        const s = screens.find(s => s.name === name);
        if (!s)
            return;
        let candidates = spots(screens, s);
        if (dir === "left") candidates = candidates.filter(p => p.x < s.x);
        if (dir === "right") candidates = candidates.filter(p => p.x > s.x);
        if (dir === "up") candidates = candidates.filter(p => p.y < s.y);
        if (dir === "down") candidates = candidates.filter(p => p.y > s.y);
        if (candidates.length === 0)
            return;
        const weight = p => dir === "left" || dir === "right" ? Math.abs(p.x - x) + 2 * Math.abs(p.y - y)
            : dir ? 2 * Math.abs(p.x - x) + Math.abs(p.y - y) : Math.hypot(p.x - x, p.y - y);
        const best = candidates.reduce((a, b) => weight(b) < weight(a) ? b : a);
        if (best.x === s.x && best.y === s.y)
            return;
        apply(normalize(changed(name, { x: best.x, y: best.y })));
    }

    function options(what) {
        const s = current;
        if (!s)
            return [];
        if (what === "mode")
            return s.modes.map(m => ({ value: m.w + "x" + m.h + "@" + m.hz, label: m.w + " × " + m.h + "  " + Math.round(Number(m.hz)) + " Hz" }));
        return [];
    }

    function valueOf(what) {
        const s = current;
        if (!s)
            return "";
        if (what === "mode")
            return s.w + "x" + s.h + "@" + Number(s.hz).toFixed(2);
        if (what === "scale")
            return s.scale;
        return s.transform;
    }

    function setOption(what, v) {
        const s = current;
        if (!s)
            return;
        if (what === "mode") {
            const m = String(v).match(/^(\d+)x(\d+)@([\d.]+)$/);
            if (m)
                apply(settle(changed(s.name, { w: Number(m[1]), h: Number(m[2]), hz: m[3] })));
        } else if (what === "scale") {
            apply(settle(changed(s.name, { scale: Number(v) })));
        } else {
            apply(settle(changed(s.name, { transform: Number(v) })));
        }
    }

    // Registry rows: "scale", "transform", "primary" (the main screen) and "enabled".
    function set(key, v) {
        const s = current;
        if (!s)
            return;
        if (key === "scale" || key === "transform")
            setOption(key, v);
        else if (key === "primary" && v) {
            Config.set("primaryScreen", s.name);
            // workspaces shared out again, the main screen first (session/hyprland.lua)
            Quickshell.execDetached(["hyprctl", "dispatch", "function() the_line_spread_workspaces() end"]);
        } else if (key === "enabled") {
            if (!v && screens.filter(o => !o.disabled).length <= 1) {
                error = "The last screen on stays on";
                return;
            }
            // back on: its first mode if Hyprland lost it, to the right of the others
            const right = Math.max(0, ...screens.filter(o => !o.disabled).map(o => rect(o).x + rect(o).w));
            const mode = s.w > 0 ? {} : { w: s.modes[0]?.w ?? 1920, h: s.modes[0]?.h ?? 1080, hz: s.modes[0]?.hz ?? "60.00" };
            apply(settle(changed(s.name, Object.assign({ disabled: !v }, v ? Object.assign({ x: right, y: 0, scale: s.scale || 1 }, mode) : {}))));
        }
    }

    // ------------------------------------------------------------------ writing, keeping, going back

    function monitorLine(s) {
        if (s.disabled)
            return "hl.monitor({ output = \"" + s.name + "\", disabled = true })";
        return "hl.monitor({ output = \"" + s.name + "\", mode = \"" + s.w + "x" + s.h + "@" + Number(s.hz).toFixed(2) + "\", position = \""
            + s.x + "x" + s.y + "\", scale = " + Number(s.scale.toFixed(6)) + (s.transform ? ", transform = " + s.transform : "") + " })";
    }

    function compose(plan) {
        const header = "-- Your screens: Settings > Displays writes a screen's line when you change it there; other lines are yours.";
        let lines = file.text().replace(/\n$/, "").split("\n").filter(l => l !== "");
        if (lines.length > 0 && lines[0].startsWith("--") && /Settings > Displays/.test(lines[0]))
            lines[0] = header;
        else
            lines.unshift(header);
        for (const s of plan) {
            const i = lines.findIndex(l => l.indexOf("output = \"" + s.name + "\"") >= 0);
            if (i >= 0)
                lines[i] = monitorLine(s);
            else
                lines.push(monitorLine(s));
        }
        return lines.join("\n") + "\n";
    }

    function apply(plan) {
        error = "";
        if (plan.every(s => s.disabled)) {
            error = "The last screen on stays on";
            return;
        }
        const on = plan.filter(s => !s.disabled).map(rect);
        if (on.some((a, i) => on.some((b, j) => j > i && overlaps(a, b)))) {
            error = "Those screens would overlap";
            return;
        }
        const token = String(Date.now());
        Quickshell.execDetached(["sh", "-c",
            "st=$1; target=$2; token=$3; first=$4; mkdir -p \"$st\"; "
            + "[ \"$first\" = 1 ] && { cp \"$target\" \"$st/monitors.lua.bak\" 2>/dev/null || : > \"$st/monitors.lua.bak\"; }; "
            + "printf '%s' \"$5\" > \"$target.new\" && mv \"$target.new\" \"$target\"; "
            + "printf '%s' \"$token\" > \"$st/monitors.pending\"; hyprctl reload >/dev/null 2>&1; "
            + "( sleep 20; [ \"$(cat \"$st/monitors.pending\" 2>/dev/null)\" = \"$token\" ] || exit 0; "
            + "cp \"$st/monitors.lua.bak\" \"$target\"; rm -f \"$st/monitors.pending\"; hyprctl reload ) >/dev/null 2>&1 &",
            "sh", state, path, token, pending ? "0" : "1", compose(plan)]);
        screens = plan;
        pending = true;
        countdown = 15;
        tick.restart();
        refreshSoon.restart();
    }

    function keep() {
        if (!pending)
            return;
        pending = false;
        tick.stop();
        Quickshell.execDetached(["rm", "-f", state + "/monitors.pending"]);
        refreshSoon.restart();
    }

    function revert() {
        if (!pending)
            return;
        pending = false;
        tick.stop();
        Quickshell.execDetached(["sh", "-c", "cp \"$1/monitors.lua.bak\" \"$2\"; rm -f \"$1/monitors.pending\"; hyprctl reload >/dev/null 2>&1",
            "sh", state, path]);
        refreshSoon.restart();
    }

    // A refusal stays a few seconds.
    onErrorChanged: if (error !== "") errorClear.restart()
    Timer {
        id: errorClear
        interval: 6000
        onTriggered: root.error = ""
    }

    Timer {
        id: tick
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown--;
            if (root.countdown <= 0)
                root.revert();
        }
    }

    FileView {
        id: file
        path: root.path
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }

    // ------------------------------------------------------------------ reading Hyprland

    function refresh() {
        if (!reader.running)
            reader.running = true;
    }

    Timer {
        id: refreshSoon
        interval: 1200   // once Hyprland has reloaded
        onTriggered: root.refresh()
    }

    Process {
        id: reader
        running: true
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text).map(m => ({
                        name: m.name, desc: (m.make + " " + m.model).trim() || m.description,
                        w: m.width, h: m.height, hz: Number(m.refreshRate).toFixed(2), x: m.x, y: m.y, scale: m.scale,
                        transform: m.transform, disabled: m.disabled,
                        // sharpest first, then fastest; each mode once
                        modes: (m.availableModes ?? []).map(t => t.match(/^(\d+)x(\d+)@([\d.]+)Hz$/)).filter(x => x)
                            .map(x => ({ w: Number(x[1]), h: Number(x[2]), hz: Number(x[3]).toFixed(2) }))
                            .filter((x, i, all) => all.findIndex(o => o.w === x.w && o.h === x.h && o.hz === x.hz) === i)
                            .sort((a, b) => b.w * b.h - a.w * a.h || Number(b.hz) - Number(a.hz))
                    })).sort((a, b) => a.disabled - b.disabled || a.x - b.x || a.y - b.y);
                    // while a change waits, the plan stays what was asked (Hyprland may still be reloading)
                    if (!root.pending)
                        root.screens = list;
                    if (!list.some(s => s.name === root.selected))
                        root.selected = list.find(s => s.name === Config.primaryScreen)?.name ?? list[0]?.name ?? "";
                } catch (e) {
                    console.warn("displays:", e);
                }
            }
        }
    }

    // A screen plugged in or out.
    Timer {
        running: true
        repeat: true
        interval: 5000
        onTriggered: if (!root.pending) root.refresh()
    }
}
