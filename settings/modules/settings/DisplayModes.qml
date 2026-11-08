pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// Settings > Displays > Resolution: the selected screen's modes, sharpest and fastest first; the one in use is lit.
// ↑↓ lines · Enter (or a click) switches to it, then asks to keep it.
Item {
    id: modes

    property var setting
    property bool active: false
    property int cursor: 0

    signal picked

    readonly property var list: Displays.options("mode")
    readonly property string inUse: Displays.valueOf("mode")

    implicitHeight: Math.max(1, list.length) * 34
    readonly property real cursorY: cursor * 34

    onListChanged: cursor = Math.max(0, list.findIndex(m => m.value === inUse))

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
            Displays.setOption("mode", list[cursor].value);
            return true;
        }
        return false;
    }

    Column {
        width: parent.width

        Repeater {
            model: modes.list

            ListLine {
                required property var modelData
                required property int index

                width: modes.width
                name: modelData.label.split("  ")[0]
                detail: modelData.label.split("  ")[1] ?? ""
                lit: modelData.value === modes.inUse
                trailing: lit ? "in use" : ""
                under: modes.active && modes.cursor === index
                onEntered: if (modes.active) modes.cursor = index
                onClicked: {
                    modes.picked();
                    modes.cursor = index;
                    Displays.setOption("mode", modelData.value);
                }
            }
        }
    }
}
