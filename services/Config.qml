pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// User settings, read from ~/.config/the-line/config.json (every key optional). That file is yours: written by the
// shell and the settings app, never by an update. ~/.config/the-line/README.md lists every file and who writes it.
// THE_LINE_SCREENS="HDMI-A-1,DP-2" overrides `screens` for a single run.
Singleton {
    id: root

    readonly property string accent: adapter.accent
    readonly property bool reduceMotion: adapter.reduceMotion
    readonly property real motionScale: adapter.motionScale
    readonly property string terminal: adapter.terminal
    readonly property string wallpaper: adapter.wallpaper
    readonly property var wallpapers: adapter.wallpapers
    readonly property bool wallpaperStillOnBattery: adapter.wallpaperStillOnBattery
    // The screen the accent comes from (its wallpaper): the one set in Settings > Displays, or the first.
    readonly property string primaryScreen: adapter.primaryScreen !== "" ? adapter.primaryScreen : (Quickshell.screens[0]?.name ?? "")
    readonly property bool workspaceIcons: adapter.workspaceIcons
    readonly property bool kiraVoice: adapter.kiraVoice
    readonly property real levelStep: adapter.levelStep
    readonly property int clipboardMax: adapter.clipboardMax
    readonly property bool clipboardImages: adapter.clipboardImages
    readonly property bool clipboardWipeOnLogin: adapter.clipboardWipeOnLogin
    readonly property bool accentFromWallpaper: adapter.accentFromWallpaper
    readonly property int idleDim: adapter.idleDim
    readonly property int idleLock: adapter.idleLock
    readonly property int idleSuspend: adapter.idleSuspend
    readonly property string powerButton: adapter.powerButton
    readonly property var workspaceApps: adapter.workspaceApps
    readonly property var keys: adapter.keys
    readonly property string kbLayout: adapter.kbLayout
    readonly property string kbVariant: adapter.kbVariant
    readonly property string kbOptions: adapter.kbOptions
    readonly property int repeatDelay: adapter.repeatDelay
    readonly property int repeatRate: adapter.repeatRate
    readonly property bool numlock: adapter.numlock
    readonly property real pointerSpeed: adapter.pointerSpeed
    readonly property string pointerAccel: adapter.pointerAccel
    readonly property bool naturalScroll: adapter.naturalScroll
    readonly property bool tapToClick: adapter.tapToClick
    readonly property bool disableWhileTyping: adapter.disableWhileTyping
    readonly property real touchpadScroll: adapter.touchpadScroll
    readonly property real touchpadSpeed: adapter.touchpadSpeed
    readonly property var notifMuted: adapter.notifMuted
    readonly property bool dndScheduled: adapter.dndScheduled
    readonly property string dndFrom: adapter.dndFrom
    readonly property string dndTo: adapter.dndTo
    readonly property bool dndUrgent: adapter.dndUrgent
    readonly property int nightTemp: adapter.nightTemp
    readonly property bool nightScheduled: adapter.nightScheduled
    readonly property string nightFrom: adapter.nightFrom
    readonly property string nightTo: adapter.nightTo

    // "22:00" to "08:00" holds `now` (a Date), across midnight too.
    function within(from, to, now) {
        const m = t => {
            const p = String(t).split(":");
            return Number(p[0]) * 60 + Number(p[1] ?? 0);
        };
        const n = now.getHours() * 60 + now.getMinutes();
        const a = m(from);
        const b = m(to);
        return a <= b ? n >= a && n < b : n >= a || n < b;
    }
    readonly property var inputKeys: ["kbLayout", "kbVariant", "kbOptions", "repeatDelay", "repeatRate", "numlock", "pointerSpeed",
        "pointerAccel", "naturalScroll", "tapToClick", "disableWhileTyping", "touchpadScroll", "touchpadSpeed"]

    // A script of session/: the shell runs from the repo root, the settings app from its settings/ folder.
    function session(script) {
        return Quickshell.shellDir.replace(/\/settings\/?$/, "") + "/session/" + script;
    }

    // The clipboard recorders read their settings when they start: restart them when those change.
    onClipboardMaxChanged: if (loadedOnce && inShell) Quickshell.execDetached([session("the-line-clipboard")])
    onClipboardImagesChanged: if (loadedOnce && inShell) Quickshell.execDetached([session("the-line-clipboard")])
    // hypridle and Hyprland's workspace rules are generated from this file (session/the-line-apply), by whoever
    // changes those settings, right after writing it (see set()).
    Timer {
        id: applyIdle
        interval: 600   // a dragged slider: one hypridle restart at the end
        onTriggered: Quickshell.execDetached([root.session("the-line-apply"), "idle"])
    }
    Timer {
        id: applyAccent
        interval: 700   // swatches stepped through: one cursor build for the last one
        onTriggered: Quickshell.execDetached([root.session("the-line-apply"), "accent"])
    }
    Timer {
        id: applyKeys
        interval: 300
        onTriggered: Quickshell.execDetached([root.session("the-line-apply"), "keys"])
    }
    Timer {
        id: applyInput
        interval: 700   // a dragged slider: one Hyprland reload at the end
        onTriggered: Quickshell.execDetached([root.session("the-line-apply"), "input"])
    }
    Timer {
        id: applyWorkspaces
        interval: 800   // ←→ held on a workspace: one Hyprland reload at the end
        onTriggered: Quickshell.execDetached([root.session("the-line-apply"), "workspaces"])
    }
    readonly property bool workspaceScrollInverted: adapter.workspaceScrollInverted

    // Hyprland reads workspaceScrollInverted from this file itself: reload it when the setting changes.
    // The settings app shares this file; only the shell reloads, or Hyprland would reload twice.
    property bool loadedOnce: false
    readonly property bool inShell: Quickshell.appId !== "the-line-settings"
    onWorkspaceScrollInvertedChanged: if (loadedOnce && inShell) Quickshell.execDetached(["hyprctl", "reload"])
    readonly property var screenFilter: {
        const env = Quickshell.env("THE_LINE_SCREENS");
        return env ? env.split(",") : adapter.screens;
    }

    // A screen's wallpaper: its own, or the one of every screen.
    function wallpaperFor(screen) {
        return wallpapers?.[screen] ?? wallpaper;
    }

    // "still", "gif" (animated), or "video".
    function wallpaperKind(path) {
        if (/\.(mp4|webm|mkv|mov)$/i.test(path))
            return "video";
        if (/\.gif$/i.test(path))
            return "gif";
        return "still";
    }

    function setReduceMotion(value) {
        set("reduceMotion", value);
    }

    // Any key of the file (the settings app writes through this).
    function set(key, value) {
        adapter[key] = value;
        file.writeAdapter();
        if (key === "idleDim" || key === "idleLock" || key === "idleSuspend")
            applyIdle.restart();
        else if (key === "workspaceApps")
            applyWorkspaces.restart();
        else if (key === "accent")
            applyAccent.restart();
        else if (key === "keys")
            applyKeys.restart();
        else if (inputKeys.indexOf(key) >= 0)
            applyInput.restart();
    }

    // FileView does not create the directory.
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.config/the-line"])

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/the-line/config.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.loadedOnce = true

        adapter: JsonAdapter {
            id: adapter
            property string accent: "#9A5CFF"
            property bool reduceMotion: false
            property real motionScale: 1.0
            property string terminal: "foot"
            property bool workspaceIcons: false            // app icons on the workspace ruler
            property int clipboardMax: 200                 // clipboard history size
            property bool clipboardImages: true            // keep copied images too
            property bool clipboardWipeOnLogin: false      // empty the history at each login
            property real levelStep: 2                     // % per press for volume, brightness, keyboard backlight
            property bool kiraVoice: true                  // Kira's quotes on an empty workspace, and her one-off lines
            property bool workspaceScrollInverted: false   // SUPER+scroll: scroll down for the next workspace
            property string wallpaper: "/usr/share/kira/wallpapers/default.png"   // "" = leave it to another tool
            property var wallpapers: ({})                   // { "DP-2": path }: a screen's own, over `wallpaper`
            property bool wallpaperStillOnBattery: true      // animated wallpapers stop on battery
            property string primaryScreen: ""               // "" = the first screen
            property list<string> screens: []
            property bool accentFromWallpaper: false        // the settings app picks the accent when the wallpaper changes
            property int idleDim: 10                        // minutes, 0 = never (all three)
            property int idleLock: 30
            property int idleSuspend: 60
            property string powerButton: "menu"            // menu, suspend, lock, nothing
            property var workspaceApps: []                  // [{ class, name, workspace }]: the app always opens there
            property var keys: ({})                         // The Line's keys moved: { "SUPER+P": { to: "SUPER+ALT+P" ("" = off), desc } }
            // Settings > Input (hypr/input.lua): the session's defaults; "" layout = the console's (/etc/vconsole.conf)
            property string kbLayout: ""
            property string kbVariant: ""
            property string kbOptions: ""
            property int repeatDelay: 250                   // ms before a held key repeats
            property int repeatRate: 35                     // repeats per second
            property bool numlock: true
            property real pointerSpeed: 0                   // -1 .. 1
            property string pointerAccel: ""                // "", "flat", "adaptive"
            property bool naturalScroll: false
            property bool tapToClick: true
            property bool disableWhileTyping: true
            property real touchpadScroll: 0.5
            property real touchpadSpeed: 0                  // -1 .. 1, set on each touchpad (hl.device), apart from the mouse
            property var notifMuted: []                     // app names: their notifications go to the list, silently
            property bool dndScheduled: false               // do not disturb from dndFrom to dndTo, every day
            property string dndFrom: "22:00"
            property string dndTo: "08:00"
            property bool dndUrgent: true                   // urgent notifications still show during do not disturb
            property int nightTemp: 4000                    // night light warmth, in kelvin (lower is warmer)
            property bool nightScheduled: false             // night light on from nightFrom to nightTo
            property string nightFrom: "21:00"
            property string nightTo: "07:00"
        }
    }
}
