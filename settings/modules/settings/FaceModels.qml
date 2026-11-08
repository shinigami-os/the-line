pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.services

// Settings > Sign-in > Your face: the faces howdy knows for you (read from /etc/howdy/models/<you>.dat), and
// "+ add a face" last: it asks a name for it, then records it through the camera (the helper runs howdy, after the
// password). Keyboard: ↑↓ lines · Enter on "+ add a face" names it, Enter again records · Delete removes one.
Item {
    id: faces

    property var setting
    property bool active: false
    property int cursor: 0
    property bool naming: false

    signal picked
    signal refocus

    readonly property var list: Sys.faces
    implicitHeight: (list.length + 1) * 34 + (naming ? 44 : 0)

    onListChanged: cursor = Math.min(cursor, list.length)

    // The name howdy keeps for it (24 characters, no comma): where or how, "Desk lamp", "With glasses".
    function name() {
        naming = true;
        nameField.text = list.length === 0 ? "Me" : "";
        nameField.focusInput();
    }

    function add(label) {
        naming = false;
        refocus();
        Sys.run(["face", "add", label.replace(/,/g, "").trim().slice(0, 24) || "Face " + (list.length + 1)], "Look at the camera…");
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
            name();
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
                faces.name();
            }
        }

        // Its name, before the camera.
        Item {
            width: faces.width
            height: 44
            visible: faces.naming

            SearchField {
                id: nameField
                y: 4
                width: parent.width
                placeholder: "A name for this face: where, or how (\"desk lamp\", \"glasses\")   ↵ record"
                onAccepted: faces.add(text)
                onCancelled: {
                    faces.naming = false;
                    faces.refocus();
                }
            }
        }
    }
}
