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
            property list<string> screens: []
            property bool accentFromWallpaper: false        // the settings app picks the accent when the wallpaper changes
            property int idleDim: 10                        // minutes, 0 = never (all three)
            property int idleLock: 30
            property int idleSuspend: 60
            property string powerButton: "menu"            // menu, suspend, lock, nothing
            property var workspaceApps: []                  // [{ class, name, workspace }]: the app always opens there
        }
    }
}
