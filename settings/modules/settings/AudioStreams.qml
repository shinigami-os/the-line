pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.services

// Settings > Sound > Apps playing: one line per app with its own volume, a line slider. ↑↓ apps, ←→ volume,
// Enter mutes it.
Item {
    id: streams

    property var setting
    property bool active: false
    property int cursor: 0

    signal picked

    readonly property var list: Sound.streams
    implicitHeight: Math.max(1, list.length) * 34

    onListChanged: cursor = Math.min(cursor, Math.max(0, list.length - 1))

    function change(node, delta) {
        if (node?.audio)
            node.audio.volume = Math.max(0, Math.min(1, node.audio.volume + delta));
    }

    function key(event) {
        const k = event.key;
        const node = list[cursor];
        if (k === Qt.Key_Up && cursor > 0) {
            cursor--;
            return true;
        }
        if (k === Qt.Key_Down && cursor < list.length - 1) {
            cursor++;
            return true;
        }
        if (node && (k === Qt.Key_Left || k === Qt.Key_Right)) {
            change(node, k === Qt.Key_Left ? -0.02 : 0.02);
            return true;
        }
        if (node?.audio && (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)) {
            node.audio.muted = !node.audio.muted;
            return true;
        }
        return false;
    }

    Text {
        visible: streams.list.length === 0
        x: 12
        y: 9
        text: "No app is playing"
        font.family: Theme.fontMono
        font.pixelSize: 11
        color: Theme.muted
    }

    Column {
        width: parent.width

        Repeater {
            model: streams.list

            ListLine {
                id: entry

                required property var modelData
                required property int index

                width: streams.width
                name: Sound.appName(modelData)
                detail: modelData.properties["media.name"] ?? ""
                under: streams.active && streams.cursor === index
                onEntered: if (streams.active) streams.cursor = index
                onClicked: {
                    streams.picked();
                    streams.cursor = index;
                }

                Row {
                    spacing: 12

                    LineSlider {
                        width: 200
                        anchors.verticalCenter: parent.verticalCenter
                        value: entry.modelData.audio?.muted ? 0 : (entry.modelData.audio?.volume ?? 0)
                        onMoved: v => {
                            streams.picked();
                            streams.cursor = entry.index;
                            if (entry.modelData.audio) {
                                entry.modelData.audio.muted = false;
                                entry.modelData.audio.volume = v;
                            }
                        }
                    }
                    Text {
                        width: 40
                        horizontalAlignment: Text.AlignRight
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.audio?.muted ? "muted" : Math.round((entry.modelData.audio?.volume ?? 0) * 100) + " %"
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        color: Theme.text
                    }
                }
            }
        }
    }
}
