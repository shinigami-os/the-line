pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// Settings > Sound > Plays on / Listens on: every output (or input), the default one lit. Enter picks it.
Item {
    id: devices

    property var setting
    property bool active: false
    property int cursor: 0

    signal picked

    readonly property bool output: setting?.key === "outputs"
    readonly property var list: output ? Sound.outputs : Sound.inputs
    readonly property var current: output ? Sound.sink : Sound.source
    implicitHeight: Math.max(1, list.length) * 34

    onListChanged: cursor = Math.min(cursor, Math.max(0, list.length - 1))

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
        if (list.length > 0 && (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)) {
            Sound.setDefault(list[cursor]);
            return true;
        }
        return false;
    }

    Text {
        visible: devices.list.length === 0
        x: 12
        y: 9
        text: devices.output ? "No output found" : "No microphone found"
        font.family: Theme.fontMono
        font.pixelSize: 11
        color: Theme.muted
    }

    Column {
        width: parent.width

        Repeater {
            model: devices.list

            ListLine {
                required property var modelData
                required property int index

                width: devices.width
                name: Sound.label(modelData)
                detail: modelData.name
                trailing: modelData === devices.current ? "in use" : ""
                trailingColor: Theme.accent
                lit: modelData === devices.current
                under: devices.active && devices.cursor === index
                onEntered: if (devices.active) devices.cursor = index
                onClicked: {
                    devices.picked();
                    devices.cursor = index;
                    Sound.setDefault(modelData);
                }
            }
        }
    }
}
