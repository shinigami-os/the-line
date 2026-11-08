pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Settings > Shortcuts.
//   The Line's keys: read live from Hyprland (hyprctl binds -j); moving or turning one off is written to config.json
//   ("keys": original keys -> new ones, "" = off), which session/the-line-apply turns into hypr/keys.lua.
//   Your app keys: the one-line binds of ~/.config/the-line/hypr/apps.lua. Settings changes only those lines and
//   leaves any other line of the file as it is.
// A combo is written like Hyprland's own: "SUPER+CTRL+ALT+SHIFT+key", modifiers in that order.
// While a new shortcut is pressed, Hyprland sits in an empty submap (session/hyprland.lua) so no bind fires.
Singleton {
    id: root

    property var binds: []          // every live bind of the main submap: [{ combo, desc, group, text, mouse }]
    property var lineKeys: []       // The Line's own, that can be moved: [{ group, text, desc, combo, original, moved, off }]
    property var apps: []           // [{ line, combo, command, desc, name }] from apps.lua
    property bool capturing: false
    property var heldCaps: []        // the modifiers held so far while capturing
    property string error: ""

    readonly property string appsPath: Quickshell.env("HOME") + "/.config/the-line/hypr/apps.lua"

    // ------------------------------------------------------------------ names

    readonly property var mods: [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]]
    readonly property var modOrder: ["SUPER", "CTRL", "CONTROL", "ALT", "SHIFT"]

    // The same order and case as session/hyprland.lua's canon().
    function canon(combo) {
        const parts = combo.split("+").filter(p => p !== "");
        const key = parts.filter(p => modOrder.indexOf(p.toUpperCase()) < 0).pop() ?? "";
        const held = parts.map(p => p.toUpperCase()).filter(p => modOrder.indexOf(p) >= 0).map(p => p === "CONTROL" ? "CTRL" : p);
        return ["SUPER", "CTRL", "ALT", "SHIFT"].filter(m => held.indexOf(m) >= 0).concat([key]).join("+");
    }

    function comboOf(bind) {
        const key = (bind.key ?? "") === "" && bind.keycode ? "code:" + bind.keycode : (bind.key ?? "");
        return mods.filter(m => bind.modmask & m[0]).map(m => m[1]).concat([key]).join("+");
    }

    readonly property var keyNames: ({
        "Return": "Enter", "Escape": "Esc", "space": "Space", "semicolon": ";", "Left": "←", "Right": "→", "Up": "↑",
        "Down": "↓", "Super_L": "Super (tap)", "Prior": "Page up", "Next": "Page down", "BackSpace": "Backspace",
        "mouse_up": "Scroll up", "mouse_down": "Scroll down", "mouse:272": "Left drag", "mouse:273": "Right drag",
        "XF86AudioRaiseVolume": "Volume +", "XF86AudioLowerVolume": "Volume −", "XF86AudioMute": "Mute",
        "XF86AudioPlay": "Play", "XF86AudioPause": "Pause", "XF86AudioNext": "Next", "XF86AudioPrev": "Previous",
        "XF86MonBrightnessUp": "Brightness +", "XF86MonBrightnessDown": "Brightness −", "XF86PowerOff": "Power button",
        "XF86KbdBrightnessUp": "Backlight +", "XF86KbdBrightnessDown": "Backlight −"
    })
    // Keys bound by their place on the keyboard (code:N): the digit row, and the punctuation of a US layout.
    readonly property var codeNames: ({
        10: "1", 11: "2", 12: "3", 13: "4", 14: "5", 15: "6", 16: "7", 17: "8", 18: "9", 19: "0", 20: "-", 21: "=",
        34: "[", 35: "]", 47: ";", 48: "'", 49: "`", 51: "\\", 59: ",", 60: ".", 61: "/", 94: "<"
    })

    // "SUPER+SHIFT+code:10" -> ["Super", "Shift", "1"]
    function caps(combo) {
        if (combo === "")
            return [];
        const parts = combo.split("+");
        const key = parts.pop();
        const out = parts.map(m => m === "SUPER" ? "Super" : m === "CTRL" ? "Ctrl" : m === "ALT" ? "Alt" : "Shift")
            .filter(m => !(key === "Super_L" && m === "Super"));
        const code = key.match(/^code:(\d+)$/);
        out.push(code ? (codeNames[Number(code[1])] ?? "key " + code[1]) : keyNames[key] ?? (key.length === 1 ? key.toUpperCase() : key));
        return out;
    }

    // ------------------------------------------------------------------ pressing a new shortcut

    readonly property var qtNames: {
        const n = {};
        n[Qt.Key_Return] = "Return"; n[Qt.Key_Enter] = "Return"; n[Qt.Key_Space] = "space"; n[Qt.Key_Tab] = "Tab";
        n[Qt.Key_Backspace] = "BackSpace"; n[Qt.Key_Delete] = "Delete"; n[Qt.Key_Insert] = "Insert"; n[Qt.Key_Home] = "Home";
        n[Qt.Key_End] = "End"; n[Qt.Key_PageUp] = "Prior"; n[Qt.Key_PageDown] = "Next"; n[Qt.Key_Left] = "Left";
        n[Qt.Key_Right] = "Right"; n[Qt.Key_Up] = "Up"; n[Qt.Key_Down] = "Down"; n[Qt.Key_Print] = "Print"; n[Qt.Key_Pause] = "Pause";
        return n;
    }

    // Modifiers held, as caps ("Super", "Ctrl"...): what the capture shows while you hold them.
    function held(event) {
        const m = event.modifiers;
        return [[Qt.MetaModifier, "Super"], [Qt.ControlModifier, "Ctrl"], [Qt.AltModifier, "Alt"], [Qt.ShiftModifier, "Shift"]]
            .filter(x => m & x[0]).map(x => x[1]);
    }

    // The combo of a key press, or "" while only modifiers are held. Letters by their name (the layout's letter,
    // like the rest of the session), function keys and the named keys by name, everything else by its place
    // (code:N), as the workspace keys are.
    function comboFromEvent(event) {
        const k = event.key;
        if ([Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Control, Qt.Key_Alt, Qt.Key_AltGr, Qt.Key_Shift].indexOf(k) >= 0)
            return "";
        let key;
        if (k >= Qt.Key_A && k <= Qt.Key_Z)
            key = String.fromCharCode(k);
        else if (k >= Qt.Key_F1 && k <= Qt.Key_F24)
            key = "F" + (k - Qt.Key_F1 + 1);
        else if (qtNames[k] !== undefined)
            key = qtNames[k];
        else if (event.nativeScanCode > 0)
            key = "code:" + event.nativeScanCode;
        else
            return "";
        const m = event.modifiers;
        const parts = [];
        if (m & Qt.MetaModifier) parts.push("SUPER");
        if (m & Qt.ControlModifier) parts.push("CTRL");
        if (m & Qt.AltModifier) parts.push("ALT");
        if (m & Qt.ShiftModifier) parts.push("SHIFT");
        return parts.concat([key]).join("+");
    }

    // Why a combo can't be used, or "".
    function refuse(combo, except) {
        const parts = combo.split("+");
        const key = parts[parts.length - 1];
        const bare = parts.length === 1 || (parts.length === 2 && parts[0] === "SHIFT");
        if (bare && !/^(F\d+|Print|Pause|Insert)$/.test(key))
            return "Hold Super, Ctrl or Alt with it: alone, it would stop typing that key";
        if (/^(SUPER\+)?Super_L$/.test(combo))
            return "Super alone opens the launcher";
        const taken = whoHas(combo);
        if (taken !== "" && taken !== except)
            return caps(combo).join(" + ") + " already does: " + taken.replace(/^[^:]+:\s*/, "");
        return "";
    }

    // The desc of the bind that has this combo, or "".
    function whoHas(combo) {
        const c = canon(combo);
        const b = binds.find(b => b.combo === c);
        return b ? (b.desc || "something (no name)") : "";
    }

    // A key press while capturing: the combo once it can be used, "" while waiting (only modifiers held, or a combo
    // refused: `error` says why), null when Esc cancelled.
    function press(event, except) {
        if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
            stopCapture();
            return null;
        }
        const combo = comboFromEvent(event);
        if (combo === "") {
            heldCaps = held(event);
            return "";
        }
        const why = refuse(combo, except);
        heldCaps = [];
        if (why !== "") {
            error = why;
            return "";
        }
        stopCapture();
        return combo;
    }

    function startCapture() {
        error = "";
        heldCaps = [];
        capturing = true;
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap(\"the-line-keys\")"]);
        // Out of the submap in 15 s whatever happens to the app; then a bind works again.
        Quickshell.execDetached(["sh", "-c", "sleep 15; [ \"$(hyprctl submap)\" = the-line-keys ] && hyprctl dispatch 'hl.dsp.submap(\"reset\")'"]);
        captureLimit.restart();
    }

    function stopCapture() {
        if (!capturing)
            return;
        capturing = false;
        captureLimit.stop();
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap(\"reset\")"]);
    }

    Timer {
        id: captureLimit
        interval: 14000
        onTriggered: root.stopCapture()
    }

    // ------------------------------------------------------------------ The Line's keys

    // Moves one of The Line's keys (by its original combo); to "" turns it off, to the original puts it back.
    function move(original, to, desc) {
        const all = Object.assign({}, Config.keys ?? {});
        if (canon(to) === canon(original) && to !== "")
            delete all[original];
        else
            all[original] = { to: to === "" ? "" : canon(to), desc: desc };
        Config.set("keys", all);
        refreshSoon.restart();
    }

    function buildLine() {
        const moved = Config.keys ?? {};
        const back = {};   // live combo -> original
        for (const from in moved)
            if (moved[from].to !== "")
                back[moved[from].to] = from;
        const rows = [];
        for (const b of binds) {
            const m = b.desc.match(/^([^:]+):\s*(.*)$/);
            if (!m || b.mouse || /code:|mouse/.test(b.combo) || b.combo.endsWith("Super_L"))
                continue;
            const original = back[b.combo] ?? b.combo;
            rows.push({ group: m[1], text: m[2].charAt(0).toUpperCase() + m[2].slice(1), desc: b.desc, combo: b.combo, original: original, moved: original !== b.combo, off: false });
        }
        for (const from in moved) {
            if (moved[from].to !== "")
                continue;
            const m = (moved[from].desc ?? "").match(/^([^:]+):\s*(.*)$/);
            rows.push({ group: m ? m[1] : "The Line", text: m ? m[2].charAt(0).toUpperCase() + m[2].slice(1) : from, desc: moved[from].desc ?? "", combo: "", original: from, moved: true, off: true });
        }
        const order = ["The Line", "Session", "Windows", "Workspaces", "Volume and brightness", "Media", "Screenshots and tools"];
        rows.sort((a, b) => ((order.indexOf(a.group) + 1 || 99) - (order.indexOf(b.group) + 1 || 99)) || (a.original < b.original ? -1 : 1));
        // one row per original key, in the order of the groups
        lineKeys = rows.filter((r, i) => rows.findIndex(o => o.original === r.original) === i);
    }

    // ------------------------------------------------------------------ your app keys (apps.lua)

    readonly property var lineRe: /^hl\.bind\("([^"]+)",\s*hl\.dsp\.exec_cmd\("((?:[^"\\]|\\.)*)"\),\s*\{\s*desc\s*=\s*"((?:[^"\\]|\\.)*)"\s*\}\)\s*$/

    function luaString(s) {
        return "\"" + s.replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\"";
    }

    function unLua(s) {
        return s.replace(/\\(.)/g, "$1");
    }

    function appLine(combo, command, desc) {
        return "hl.bind(" + luaString(combo) + ", hl.dsp.exec_cmd(" + luaString(command) + "), { desc = " + luaString(desc) + " })";
    }

    function parseApps(text) {
        const lines = (text ?? appsFile.text()).split("\n");
        const out = [];
        lines.forEach((l, i) => {
            const m = l.match(lineRe);
            if (m)
                out.push({ line: i, combo: canon(m[1]), command: unLua(m[2]), desc: unLua(m[3]), name: unLua(m[3]).replace(/^Launch\s+/, "") });
        });
        apps = out;
    }

    // Rewrites apps.lua with line `i` replaced (text), removed (null), or a new line added (i = -1).
    function writeApps(i, text) {
        const lines = appsFile.text().replace(/\n$/, "").split("\n");
        if (i < 0)
            lines.push(text);
        else if (text === null)
            lines.splice(i, 1);
        else
            lines[i] = text;
        const content = lines.join("\n") + "\n";
        appsFile.setText(content);
        parseApps(content);
        hyprReload.restart();
    }

    function setAppKey(app, combo) {
        writeApps(app.line, appLine(canon(combo), app.command, app.desc));
    }

    function removeApp(app) {
        writeApps(app.line, null);
    }

    function addApp(name, command, combo) {
        if (appsFile.text() === "")
            appsFile.setText("-- Your app keys. This file is yours: The Line and its updates never overwrite it.\n");
        writeApps(-1, appLine(canon(combo), command, "Launch " + name));
    }

    FileView {
        id: appsFile
        path: root.appsPath
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseApps()
    }

    // Hyprland reads apps.lua when it loads its config.
    Timer {
        id: hyprReload
        interval: 300
        onTriggered: {
            Quickshell.execDetached(["hyprctl", "reload"]);
            refreshSoon.restart();
        }
    }

    // ------------------------------------------------------------------ reading Hyprland

    function refresh() {
        if (!bindsProc.running)
            bindsProc.running = true;
    }

    Timer {
        id: refreshSoon
        interval: 900   // after the-line-apply and Hyprland's reload
        onTriggered: root.refresh()
    }

    Connections {
        target: Config

        function onKeysChanged() {
            root.buildLine();
        }
    }

    Process {
        id: bindsProc
        running: true
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.binds = JSON.parse(text).filter(b => b.submap === "").map(b => ({
                        combo: root.comboOf(b), desc: b.description ?? "", mouse: b.mouse
                    }));
                    root.buildLine();
                } catch (e) {
                    console.warn("keys:", e);
                }
            }
        }
    }
}
