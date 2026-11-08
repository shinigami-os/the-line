pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// Settings > Sign-in > Your face: the faces howdy knows for you (read from /etc/howdy/models/<you>.dat), and
// "+ add a face" last: it records one through the camera (the helper runs howdy, after the password).
// Keyboard: ↑↓ lines · Enter on "+ add a face" records · Delete removes the face under the cursor.
Item {
    id: faces

    property var setting
    property bool active: false
    property int cursor: 0

    signal picked

    readonly property var list: Sys.faces
    implicitHeight: (list.length + 1) * 34

    onListChanged: cursor = Math.min(cursor, list.length)

    function add() {
        Sys.run(["face", "add"], "Look at the camera…");
    }

    function remove(face) {
        Sys.run(["face", "remove", String(face.id)], "Removing…");
    }

    function key(event) {
        const k = event.key;
        if (k === Qt.Key_Up && cursor > 0) {
            cursor--;
            return true;
        }
        if (k === Qt.Key_Down && cursor < list.length) {
            cursor++;
            return true;
        }
        if (cursor === list.length && (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)) {
            add();
            return true;
        }
        if (cursor < list.length && (k === Qt.Key_Delete || k === Qt.Key_Backspace)) {
            remove(list[cursor]);
            return true;
        }
        return false;
    }

    Column {
        width: parent.width

        Repeater {
            model: faces.list

            ListLine {
                required property var modelData
                required property int index

                width: faces.width
                name: modelData.label
                detail: "recorded " + new Date(modelData.time * 1000).toLocaleDateString(Qt.locale(), "d MMMM yyyy")
                trailing: faces.active && faces.cursor === index ? "Delete removes it" : ""
                under: faces.active && faces.cursor === index
                onEntered: if (faces.active) faces.cursor = index
                onClicked: {
                    faces.picked();
                    faces.cursor = index;
                }
            }
        }

        ListLine {
            width: faces.width
            name: faces.list.length === 0 ? "+ add your face" : "+ add a face"
            detail: faces.list.length === 0 ? "none yet: it looks at you through the camera for a few seconds" : "in other light, with or without glasses"
            under: faces.active && faces.cursor === faces.list.length
            onEntered: if (faces.active) faces.cursor = faces.list.length
            onClicked: {
                faces.picked();
                faces.cursor = faces.list.length;
                faces.add();
            }
        }
    }
}
