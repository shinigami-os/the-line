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
    readonly property var screenFilter: {
        const env = Quickshell.env("THE_LINE_SCREENS");
        return env ? env.split(",") : adapter.screens;
    }

    function setReduceMotion(value) {
        adapter.reduceMotion = value;
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

        adapter: JsonAdapter {
            id: adapter
            property string accent: "#9A5CFF"
            property bool reduceMotion: false
            property real motionScale: 1.0
            property string terminal: "foot"
            property bool workspaceIcons: false   // app icons on the workspace ruler
            property string wallpaper: "/usr/share/kira/wallpapers/default.png"   // "" = leave it to another tool
            property list<string> screens: []
        }
    }
}
