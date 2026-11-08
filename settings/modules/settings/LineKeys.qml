pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// Settings > Shortcuts > The Line's keys: every key of the session that can move (the workspace numbers, the mouse
// and the scroll stay), by group. Enter (or a click) listens for the new keys; Delete turns it off; R puts back
// The Line's own key. A key already used elsewhere is refused, saying by what.
Item {
    id: list

    property var setting
    property bool active: false
    property int cursor: 0
    property string listening: ""      // the original combo being given new keys

    signal picked

    readonly property var rows: Binds.lineKeys
    readonly property var current: rows[cursor] ?? null

    implicitHeight: column.implicitHeight
    // where the cursor's line is, for the view to keep it shown
    readonly property real cursorY: {
        const item = repeater.itemAt(cursor);
        return item ? item.y + item.height - 34 : -1;
    }

    onRowsChanged: cursor = Math.min(cursor, Math.max(0, rows.length - 1))
    onActiveChanged: if (!active) stop()

    function listen(row) {
        listening = row.original;
        Binds.startCapture();
    }

    function stop() {
        if (listening !== "") {
            listening = "";
            Binds.stopCapture();
        }
    }

    function key(event) {
        const k = event.key;
        if (listening !== "") {
            const row = rows.find(r => r.original === listening);
            const combo = Binds.press(event, row?.desc ?? "");
            if (combo === null)
                listening = "";
            else if (combo !== "") {
                Binds.move(row.original, combo, row.desc);
                listening = "";
            }
            return true;
        }
        if (k === Qt.Key_Up && cursor > 0) {
            cursor--;
            return true;
        }
        if (k === Qt.Key_Down && cursor < rows.length - 1) {
            cursor++;
            return true;
        }
        if (!current)
            return false;
        if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            listen(current);
            return true;
        }
        if (k === Qt.Key_Delete && !current.off) {
            Binds.move(current.original, "", current.desc);
            return true;
        }
        if (k === Qt.Key_R && current.moved) {
            Binds.move(current.original, current.original, current.desc);
            return true;
        }
        return false;
    }

    Column {
        id: column
        width: parent.width

        Repeater {
            id: repeater
            model: list.rows

            Column {
                id: entry

                required property var modelData
                required property int index
                readonly property bool firstOfGroup: index === 0 || list.rows[index - 1].group !== modelData.group
                readonly property bool under: list.active && list.cursor === index
                readonly property bool listeningHere: list.listening === modelData.original

                width: list.width

                Text {
                    visible: entry.firstOfGroup
                    height: visible ? 28 : 0
                    x: 12
                    verticalAlignment: Text.AlignBottom
                    bottomPadding: 6
                    text: entry.modelData.group.toUpperCase()
                    font.family: Theme.fontUi
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                    color: Theme.muted
                }

                ListLine {
                    width: list.width
                    name: entry.modelData.text
                    detail: entry.listeningHere ? "" : entry.modelData.off ? "off" : entry.modelData.moved ? "was " + Binds.caps(entry.modelData.original).join(" + ") : ""
                    under: entry.under
                    lit: entry.modelData.moved
                    onEntered: if (list.active && list.listening === "") list.cursor = entry.index
                    onClicked: {
                        list.picked();
                        list.cursor = entry.index;
                        list.listen(entry.modelData);
                    }

                    Row {
                        spacing: 12

                        // Listening: what is held so far, or why the last keys were refused.
                        Text {
                            visible: entry.listeningHere
                            anchors.verticalCenter: parent.verticalCenter
                            text: Binds.error !== "" ? Binds.error : "press the new keys · Esc cancels"
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            color: Binds.error !== "" ? Theme.error : Theme.accent
                        }
                        KeyCaps {
                            visible: entry.listeningHere && Binds.heldCaps.length > 0
                            anchors.verticalCenter: parent.verticalCenter
                            names: Binds.heldCaps
                            tint: Theme.accent
                        }

                        // Under the cursor: what else can be done, clickable too.
                        Text {
                            visible: entry.under && !entry.listeningHere && entry.modelData.moved
                            anchors.verticalCenter: parent.verticalCenter
                            text: "R back"
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            color: Theme.muted

                            TapHandler {
                                onTapped: Binds.move(entry.modelData.original, entry.modelData.original, entry.modelData.desc)
                            }
                        }
                        Text {
                            visible: entry.under && !entry.listeningHere && !entry.modelData.off
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Del off"
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            color: Theme.muted

                            TapHandler {
                                onTapped: Binds.move(entry.modelData.original, "", entry.modelData.desc)
                            }
                        }
                        KeyCaps {
                            visible: !entry.listeningHere && !entry.modelData.off
                            anchors.verticalCenter: parent.verticalCenter
                            combo: entry.modelData.combo
                        }
                    }
                }
            }
        }
    }
}
