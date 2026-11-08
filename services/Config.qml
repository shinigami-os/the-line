pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// User settings, read from ~/.config/the-line/config.json (every key optional).
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

    // The clipboard recorders read their settings when they start: restart them when those change.
    onClipboardMaxChanged: if (loadedOnce) Quickshell.execDetached([Qt.resolvedUrl("../session/the-line-clipboard").toString().replace("file://", "")])
    onClipboardImagesChanged: if (loadedOnce) Quickshell.execDetached([Qt.resolvedUrl("../session/the-line-clipboard").toString().replace("file://", "")])
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
        }
    }
}
