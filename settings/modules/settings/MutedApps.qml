pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Settings > Notifications > Apps: every app that has sent a notification (the shell keeps their names in
// ~/.local/state/the-line/notif-apps.json). A muted app's notifications go to the list without a sound of the
// line: no pulse, no toast. Enter (or a click) mutes or unmutes the app under the cursor.
Item {
    id: apps

    property var setting
    property bool active: false
    property int cursor: 0

    signal picked

    property var list: []
    readonly property var muted: Config.notifMuted ?? []

    implicitHeight: Math.max(1, list.length) * 34
    readonly property real cursorY: cursor * 34

    function toggle(app) {
        Config.set("notifMuted", muted.indexOf(app) >= 0 ? muted.filter(a => a !== app) : muted.concat([app]));
    }

    function key(event) {
        const k = event.key;
        if (k === Qt.Key_Up && cursor > 0) {
            cursor--;
            return true;
        }
        if (k === Qt.Key_Down && cursor < list.length - 1) {
            cursor++;
            return true;
        }
        if ((k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) && list[cursor]) {
            toggle(list[cursor]);
            return true;
        }
        return false;
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/the-line/notif-apps.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                apps.list = JSON.parse(text() || "[]");
            } catch (e) {
                apps.list = [];
            }
        }
    }

    Text {
        visible: apps.list.length === 0
        x: 12
        y: 10
        text: "No app has sent a notification yet"
        font.family: Theme.fontMono
        font.pixelSize: 11
        color: Theme.muted
    }

    Column {
        width: parent.width

        Repeater {
            model: apps.list

            ListLine {
                required property string modelData
                required property int index
                readonly property bool isMuted: apps.muted.indexOf(modelData) >= 0

                width: apps.width
                name: modelData
                trailing: isMuted ? "muted" : "shows"
                trailingColor: isMuted ? Theme.accent : Theme.muted
                under: apps.active && apps.cursor === index
                onEntered: if (apps.active) apps.cursor = index
                onClicked: {
                    apps.picked();
                    apps.cursor = index;
                    apps.toggle(modelData);
                }
            }
        }
    }
}
