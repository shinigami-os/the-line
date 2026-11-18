pragma ComponentBehavior: Bound

import QtQuick
import TheLine.Ui
import Quickshell
import qs.services

// Settings > Shortcuts > Your app keys: the apps of ~/.config/the-line/hypr/apps.lua and their keys, then
// "+ add an app key": type an app's name, Enter, then press its keys.
// Keyboard: ↑↓ lines · Enter gives new keys · Delete or Backspace removes the key (the app stays installed).
Item {
    id: apps

    property var setting
    property bool active: false
    property int cursor: 0
    property int listening: -1          // the line being given keys; list.length = the app being added
    property bool searching: false
    property string query: ""
    property int pick: 0
    property var adding: null           // { name, command } picked, waiting for its keys

    signal picked
    signal refocus

    readonly property var list: Binds.apps
    readonly property var matches: {
        const q = query.trim().toLowerCase();
        if (q === "")
            return [];
        return DesktopEntries.applications.values.filter(e => !e.noDisplay && e.name.toLowerCase().includes(q))
            .sort((a, b) => a.name.toLowerCase().indexOf(q) - b.name.toLowerCase().indexOf(q)).slice(0, 6);
    }

    implicitHeight: (list.length + 1) * 34 + (searching ? 44 + matches.length * 34 : 0)
    readonly property real cursorY: cursor * 34

    onListChanged: cursor = Math.min(cursor, list.length)
    onActiveChanged: if (!active) stop()

    function listen(i) {
        listening = i;
        Binds.startCapture();
    }

    function stop() {
        if (listening >= 0) {
            listening = -1;
            adding = null;
            Binds.stopCapture();
        }
    }

    function search() {
        searching = true;
        query = "";
        pick = 0;
        field.text = "";
        field.focusInput();
    }

    // The desktop entry's command, without its %u / %F placeholders.
    function choose(entry) {
        searching = false;
        refocus();
        adding = { name: entry.name, command: entry.execString.replace(/\s*%[a-zA-Z]/g, "").trim() };
        cursor = list.length;
        listen(list.length);
    }

    function key(event) {
        const k = event.key;
        if (listening >= 0) {
            const app = list[listening];
            const combo = Binds.press(event, app ? app.desc : "");
            if (combo === null) {
                listening = -1;
                adding = null;
            } else if (combo !== "") {
                if (adding)
                    Binds.addApp(adding.name, adding.command, combo);
                else
                    Binds.setAppKey(app, combo);
                listening = -1;
                adding = null;
            }
            return true;
        }
        if (k === Qt.Key_Up && cursor > 0) {
            cursor--;
            return true;
        }
        if (k === Qt.Key_Down && cursor < list.length) {
            cursor++;
            return true;
        }
        if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            if (cursor === list.length)
                search();
            else
                listen(cursor);
            return true;
        }
        if ((k === Qt.Key_Delete || k === Qt.Key_Backspace) && cursor < list.length) {
            Binds.removeApp(list[cursor]);
            return true;
        }
        return false;
    }

    // What a line shows on its right while it listens.
    component Listening: Row {
        spacing: 10

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Binds.error !== "" ? Binds.error : "press its keys · Esc cancels"
            font.family: Theme.fontMono
            font.pixelSize: 10
            color: Binds.error !== "" ? Theme.error : Theme.accent
        }
        KeyCaps {
            visible: Binds.heldCaps.length > 0
            anchors.verticalCenter: parent.verticalCenter
            names: Binds.heldCaps
            tint: Theme.accent
        }
    }

    Column {
        width: parent.width

        Repeater {
            model: apps.list

            ListLine {
                id: line

                required property var modelData
                required property int index
                readonly property bool listeningHere: apps.listening === index

                width: apps.width
                name: modelData.name
                detail: modelData.command
                under: apps.active && apps.cursor === index
                onEntered: if (apps.active && apps.listening < 0) apps.cursor = index
                onClicked: {
                    apps.picked();
                    apps.cursor = index;
                    apps.listen(index);
                }

                Row {
                    spacing: 12

                    Listening {
                        visible: line.listeningHere
                    }
                    Text {
                        id: removeText

                        visible: line.under && !line.listeningHere
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Del remove"
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        color: removeHover.hovered ? Theme.error : Theme.muted

                        HoverHandler {
                            id: removeHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        // a hit area wider than the words, so it is easy to click (the line itself gives new keys)
                        TapHandler {
                            margin: 8
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: Binds.removeApp(line.modelData)
                        }
                    }
                    KeyCaps {
                        visible: !line.listeningHere
                        anchors.verticalCenter: parent.verticalCenter
                        combo: line.modelData.combo
                    }
                }
            }
        }

        ListLine {
            id: addLine

            readonly property bool listeningHere: apps.listening === apps.list.length

            width: apps.width
            name: apps.adding ? apps.adding.name : "+ add an app key"
            detail: apps.adding ? apps.adding.command : "type its name, then press its keys"
            under: apps.active && apps.cursor === apps.list.length
            onEntered: if (apps.active && apps.listening < 0) apps.cursor = apps.list.length
            onClicked: {
                apps.picked();
                apps.cursor = apps.list.length;
                apps.search();
            }

            Listening {
                visible: addLine.listeningHere
            }
        }

        // The app to add: its name, then the matches.
        Column {
            visible: apps.searching
            width: apps.width

            Item {
                width: parent.width
                height: 44

                SearchField {
                    id: field

                    y: 4
                    width: parent.width
                    placeholder: "An app's name"
                    onTextChanged: {
                        apps.query = text;
                        apps.pick = 0;
                    }
                    onMoved: (dx, dy) => {
                        if (dy !== 0 && apps.matches.length > 0)
                            apps.pick = (apps.pick + dy + apps.matches.length) % apps.matches.length;
                    }
                    onAccepted: if (apps.matches.length > 0) apps.choose(apps.matches[apps.pick])
                    onCancelled: {
                        apps.searching = false;
                        apps.refocus();
                    }
                }
            }

            Repeater {
                model: apps.searching ? apps.matches : []

                ListLine {
                    required property var modelData
                    required property int index

                    width: apps.width
                    name: modelData.name
                    detail: modelData.execString
                    under: index === apps.pick
                    onEntered: apps.pick = index
                    onClicked: apps.choose(modelData)
                }
            }
        }
    }
}
