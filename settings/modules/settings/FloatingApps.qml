pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Settings > Workspaces > Remembered floating apps: what the shell keeps in ~/.local/state/the-line/floating.json.
// Forgetting one asks the shell (IPC), which owns that list and rewrites hypr/floating.lua.
// The Line's own floating windows (rules in session/hyprland.lua) come first: always floating, nothing to forget.
// Keyboard: ↑↓ lines · Delete / Enter forgets.
Item {
    id: floating

    property bool active: false
    property int cursor: 0
    property var memory: ({})
    readonly property var classes: Object.keys(memory).sort()

    signal picked

    readonly property var fixed: [{ name: "Settings", detail: "the-line-settings   1120 × 740, centred" }]

    implicitHeight: (fixed.length + Math.max(1, classes.length)) * 34

    function forget(cls) {
        const shell = Quickshell.shellDir.replace(/\/settings\/?$/, "");
        Quickshell.execDetached(["qs", "-p", shell, "ipc", "call", "line", "forgetFloat", cls]);
    }

    function key(event) {
        const k = event.key;
        if (k === Qt.Key_Up && cursor > 0) {
            cursor--;
            return true;
        }
        if (k === Qt.Key_Down && cursor < classes.length - 1) {
            cursor++;
            return true;
        }
        if (classes.length > 0 && (k === Qt.Key_Delete || k === Qt.Key_Backspace || k === Qt.Key_Return || k === Qt.Key_Enter)) {
            forget(classes[cursor]);
            return true;
        }
        return false;
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/the-line/floating.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                floating.memory = JSON.parse(text());
            } catch (e) {
                floating.memory = {};
            }
            floating.cursor = Math.min(floating.cursor, Math.max(0, floating.classes.length - 1));
        }
        onLoadFailed: floating.memory = {}
    }

    Column {
        width: parent.width

        Repeater {
            model: floating.fixed

            Item {
                id: fixedLine

                required property var modelData

                width: floating.width
                height: 34

                Text {
                    id: fixedName
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: fixedLine.modelData.name
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Theme.text
                }
                Text {
                    anchors.left: fixedName.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: fixedLine.modelData.detail
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    color: Theme.muted
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "always · The Line"
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    color: Theme.muted
                }
            }
        }
    }

    Text {
        visible: floating.classes.length === 0
        x: 10
        y: floating.fixed.length * 34 + 9
        text: "Yours: none yet. SUPER + ALT + Space floats a window, and its app is remembered"
        font.family: Theme.fontMono
        font.pixelSize: 11
        color: Theme.muted
    }

    Column {
        y: floating.fixed.length * 34
        width: parent.width

        Repeater {
            model: floating.classes

            Item {
                id: line

                required property string modelData
                required property int index
                readonly property var place: floating.memory[modelData]

                width: floating.width
                height: 34

                Rectangle {
                    anchors.fill: parent
                    color: floating.active && floating.cursor === line.index ? Theme.surface : "transparent"
                }
                Text {
                    id: appName
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: DesktopEntries.heuristicLookup(line.modelData)?.name ?? line.modelData
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Theme.text
                }
                Text {
                    anchors.left: appName.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: line.modelData + "   " + line.place.w + " × " + line.place.h + "  at  " + line.place.x + ", " + line.place.y
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    color: Theme.muted
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "forget"
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    color: forgetHover.hovered ? Theme.error : Theme.muted

                    HoverHandler {
                        id: forgetHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: floating.forget(line.modelData)
                    }
                }
                HoverHandler {
                    onHoveredChanged: if (hovered && floating.active && Registry.hoverPicks()) floating.cursor = line.index
                }
            }
        }
    }
}
