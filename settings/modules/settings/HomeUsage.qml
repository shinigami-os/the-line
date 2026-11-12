pragma ComponentBehavior: Bound

import QtQuick
import TheLine.Ui
import Quickshell
import qs.services

// Settings > Storage > Your home: what fills it, one folder down, biggest first, each with its share as a line.
// Measured on demand (it reads every file): Enter measures, Enter on a folder opens it.
Item {
    id: usage

    property var setting
    property bool active: false
    property int cursor: 0

    signal picked

    readonly property var list: Disks.home
    implicitHeight: 34 + list.length * 34
    readonly property real cursorY: cursor * 34

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
        if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            if (cursor === 0)
                Disks.measure();
            else
                Qt.openUrlExternally("file://" + list[cursor - 1].path);
            return true;
        }
        return false;
    }

    Column {
        width: parent.width

        ListLine {
            width: usage.width
            name: Disks.measuring ? "Measuring…" : Disks.measured ? "Measure again" : "Measure your home"
            detail: Disks.measured ? Disks.size(Disks.homeSize) + " in all" : "reads every file once: a few seconds"
            under: usage.active && usage.cursor === 0
            onEntered: if (usage.active) usage.cursor = 0
            onClicked: {
                usage.picked();
                usage.cursor = 0;
                Disks.measure();
            }
        }

        Repeater {
            model: usage.list

            ListLine {
                id: folder

                required property var modelData
                required property int index

                width: usage.width
                name: modelData.name
                trailing: Disks.size(modelData.size)
                under: usage.active && usage.cursor === index + 1
                onEntered: if (usage.active) usage.cursor = index + 1
                onClicked: {
                    usage.picked();
                    usage.cursor = index + 1;
                    Qt.openUrlExternally("file://" + modelData.path);
                }

                // its share of the home, under the name
                Rectangle {
                    parent: folder
                    x: 12
                    y: folder.height - 5
                    width: (folder.width - 24) * folder.modelData.size / Math.max(1, Disks.homeSize)
                    height: 1
                    color: Theme.accent
                    opacity: 0.7
                }
            }
        }
    }
}
