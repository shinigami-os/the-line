pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The welcome story: Kira presenting The Line to a new user, on the real line and tiles (modules/welcome draws the
// narration, TheLine shows or hides its parts as the beats ask). Runs at the first login with every screen black, and
// again from the launcher ("welcome") or `qs ipc call line welcome`.
//   scope "all"  every screen goes black, the story is on the main screen (first login, replay)
//   scope "one"  only the focused screen (to try it without blacking the others: `line welcomeHere`)
// Each beat is a declarative state (the table below), so going back needs no undoing. The texts are in
// assets/story.txt (`beat.N = text`), read live. ← → Space Enter go on and back, Esc asks to skip, ↑↓ and a letter
// choose in an offer. The marker ~/.local/state/the-line/welcome-done says it was seen.
Singleton {
    id: root

    property bool active: false
    property bool checking: true        // until the marker is known, the wallpaper waits
    property string scope: "all"
    property string screen: ""
    property int beat: 0
    property bool finale: false         // the way out: wallpaper, every screen wakes
    property bool lineOn: false         // beat 1 waits a moment in the dark before the line draws itself
    property bool asking: false         // "skip the story?"
    property int demoStage: 1           // the fullscreen beat folds the shell away and back, for real
    property var texts: ({})

    readonly property string markerFile: Quickshell.env("HOME") + "/.local/state/the-line/welcome-done"
    // The wallpaper stays out until the finale (the first thing of the desktop they see is the end of the story).
    readonly property bool holdWallpaper: checking || (active && !finale)

    // What each beat shows. stage: 3 nothing, 2 the line alone, 1 the line and the tiles it is told to show.
    readonly property var beats: [
        { id: "hello", stage: 2, marker: false, left: false, center: false, right: false, offer: "calm" },
        { id: "line", stage: 1, marker: true, left: false, center: false, right: false, offer: "accent" },
        { id: "workspaces", stage: 1, marker: true, left: true, center: false, right: false },
        { id: "launcher", stage: 1, marker: true, left: true, center: false, right: false },
        { id: "clock", stage: 1, marker: true, left: true, center: true, right: false },
        { id: "status", stage: 1, marker: true, left: true, center: true, right: true },
        { id: "levels", stage: 1, marker: true, left: true, center: true, right: true },
        { id: "voice", stage: 1, marker: true, left: true, center: true, right: true, offer: "voice" },
        { id: "fullscreen", stage: 1, marker: true, left: true, center: true, right: true },
        { id: "keys", stage: 1, marker: true, left: true, center: true, right: true },
        { id: "eggs", stage: 1, marker: true, left: true, center: true, right: true },
        { id: "end", stage: 1, marker: true, left: true, center: true, right: true }
    ]
    readonly property var current: beats[beat]
    readonly property var shown: finale ? ({ marker: true, left: true, center: true, right: true }) : current
    // Where the stage machine of every story screen is heading.
    readonly property int stage: finale ? 0 : !lineOn ? 3 : current.id === "fullscreen" ? demoStage : current.stage

    // ------------------------------------------------------------------ texts

    function parse(text) {
        const out = {};
        for (const raw of text.split("\n")) {
            const line = raw.trim();
            if (line === "" || line.startsWith("#"))
                continue;
            const eq = line.indexOf("=");
            if (eq > 0)
                out[line.slice(0, eq).trim()] = line.slice(eq + 1).trim();
        }
        return out;
    }

    function t(key) {
        return Voice.render(texts[key] ?? "");
    }

    function paragraphs(id) {
        const out = [];
        for (let n = 1; texts[id + "." + n] !== undefined; n++)
            out.push(t(id + "." + n));
        return out;
    }

    readonly property var lines: paragraphs(current.id)

    FileView {
        path: Qt.resolvedUrl("../assets/story.txt").toString().replace("file://", "")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.texts = root.parse(text())
    }

    // ------------------------------------------------------------------ offers

    // Settings offered on the spot. Each option: key (a letter), label, color (a swatch), on() (is it the current one),
    // pick(). ↑↓ walk through the options, a letter picks one, a click picks one.
    function setAccent(value) {
        Config.set("accent", value);
        if (Config.accentFromWallpaper)
            Config.set("accentFromWallpaper", false);
    }

    function accentFromWallpaper() {
        Config.set("accentFromWallpaper", true);
        Accent.fromWallpaper(Config.wallpaperFor(Config.primaryScreen));
    }

    readonly property var offers: ({
        calm: [
            { key: "c", label: "calm: fewer animations", on: () => Config.reduceMotion, pick: () => Config.set("reduceMotion", true) },
            { key: "n", label: "as it is", on: () => !Config.reduceMotion, pick: () => Config.set("reduceMotion", false) }
        ],
        accent: Theme.accents.map(a => ({
            key: "", label: a.label, color: a.value,
            on: () => !Config.accentFromWallpaper && String(Config.accent).toLowerCase() === a.value.toLowerCase(),
            pick: () => root.setAccent(a.value)
        })).concat([{ key: "w", label: "from the wallpaper", on: () => Config.accentFromWallpaper, pick: () => root.accentFromWallpaper() }]),
        voice: [
            { key: "k", label: "keep her", on: () => Config.kiraVoice, pick: () => Config.set("kiraVoice", true) },
            { key: "s", label: "silence her", on: () => !Config.kiraVoice, pick: () => Config.set("kiraVoice", false) }
        ]
    })
    readonly property var offerOptions: current.offer ? offers[current.offer] : []

    function stepOffer(by) {
        const list = offerOptions;
        if (list.length === 0)
            return;
        const i = list.findIndex(o => o.on());
        list[((i < 0 ? 0 : i + by) + list.length) % list.length].pick();
    }

    // ------------------------------------------------------------------ the story

    function start(scopeName) {
        if (active)
            return;
        const names = Quickshell.screens.map(s => s.name);
        const wanted = scopeName === "all" ? Config.primaryScreen : (Hyprland.focusedMonitor?.name ?? "");
        scope = scopeName;
        screen = names.includes(wanted) ? wanted : (names[0] ?? "");
        beat = 0;
        finale = false;
        lineOn = false;
        asking = false;
        demoStage = 1;
        UiState.close();
        active = true;
        lineTimer.restart();
        enter();
    }

    function next() {
        asking = false;
        if (beat < beats.length - 1) {
            leave();
            beat++;
            enter();
        } else {
            finish();
        }
    }

    function prev() {
        asking = false;
        if (beat > 0) {
            leave();
            beat--;
            enter();
        }
    }

    // The way out: the wallpaper loads, every screen's cover lifts and its line draws itself in (TheLine).
    function finish() {
        if (!active || finale)
            return;
        asking = false;
        leave();
        finale = true;
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && date +%F > \"$1\"", "sh", markerFile]);
        closeTimer.restart();
    }

    // What the story does with the keyboard (TheLine hands it every key on the story screen).
    function key(event) {
        if (finale)
            return true;
        const k = event.key;
        if (asking) {
            if (k === Qt.Key_Return || k === Qt.Key_Enter)
                finish();
            else if (k === Qt.Key_Escape)
                asking = false;
            return true;
        }
        if (k === Qt.Key_Right || k === Qt.Key_Space || k === Qt.Key_Return || k === Qt.Key_Enter)
            next();
        else if (k === Qt.Key_Left || k === Qt.Key_Backspace)
            prev();
        else if (k === Qt.Key_Escape)
            asking = true;
        else if (k === Qt.Key_Up || k === Qt.Key_Down)
            stepOffer(k === Qt.Key_Up ? -1 : 1);
        else if (event.text !== "")
            offerOptions.find(o => o.key !== "" && o.key === event.text.toLowerCase())?.pick();
        return true;
    }

    Timer {
        id: lineTimer
        interval: 1300      // the dark, a point of nothing, then the line
        onTriggered: root.lineOn = true
    }
    Timer {
        id: closeTimer
        interval: 4200
        onTriggered: {
            root.active = false;
            root.beat = 0;
        }
    }

    // ------------------------------------------------------------------ demos, one per beat, stopped on leaving

    function enter() {
        const id = current.id;
        if (id === "launcher") {
            UiState.launcherQuery = "";
            typed = 0;
            typeTimer.interval = 1500;
            typeTimer.restart();
            UiState.openScreen = screen;
            UiState.openPanel = "tl";
        } else if (id === "clock") {
            notifyTimer.restart();
        } else if (id === "levels") {
            gaugeStep = 0;
            gaugeTimer.interval = 1200;
            gaugeTimer.restart();
        } else if (id === "voice") {
            voiceTimer.restart();
        } else if (id === "fullscreen") {
            demoStage = 1;
            demoTimer.restart();
        } else if (id === "eggs") {
            winkTimer.restart();
        }
    }

    function leave() {
        for (const timer of [typeTimer, notifyTimer, gaugeTimer, voiceTimer, demoTimer, winkTimer])
            timer.stop();
        if (UiState.openPanel === "tl")
            UiState.close();
        UiState.launcherQuery = "";
        demoStage = 1;
        Notifs.forget("welcome");
    }

    // beat 4: "fir" typed into the real launcher
    property int typed: 0
    Timer {
        id: typeTimer
        repeat: true
        onTriggered: {
            interval = 260;
            root.typed = Math.min(3, root.typed + 1);
            UiState.launcherQuery = "fir".slice(0, root.typed);
            if (root.typed >= 3)
                stop();
        }
    }

    // beat 5: a real notification, the pulse runs and the tile grows into its toast
    Timer {
        id: notifyTimer
        interval: 1600
        onTriggered: Notifs.push("The Line", root.t("clock.notify.title"), root.t("clock.notify.body"), 1, "welcome")
    }

    // beat 7: the gauge sweeps, as a volume key would
    property int gaugeStep: 0
    Timer {
        id: gaugeTimer
        repeat: true
        onTriggered: {
            interval = 1500;
            LineState.showGauge("vol", [0.3, 0.75, 0.5][root.gaugeStep % 3]);
            root.gaugeStep++;
        }
    }

    // beat 8: a line of hers, again and again while she is talked about
    Timer {
        id: voiceTimer
        interval: 1400
        repeat: true
        onTriggered: {
            interval = 7000;
            Voice.say(root.t("voice.line"), root.screen);
        }
    }

    // beat 9: the shell folds into the line and the line steps aside, then everything returns
    Timer {
        id: demoTimer
        interval: 3300
        repeat: true
        onTriggered: root.demoStage = root.demoStage === 1 ? 3 : 1
    }

    // beat 11: a wink on the line
    Timer {
        id: winkTimer
        interval: 1900
        onTriggered: LineState.pulse(false)
    }

    // ------------------------------------------------------------------ first login

    Process {
        running: true
        command: ["test", "-e", root.markerFile]
        onExited: code => {
            root.checking = false;
            if (code !== 0)
                root.start("all");
        }
    }
}
