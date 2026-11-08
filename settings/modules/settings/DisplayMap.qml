pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// Settings > Displays > Arrangement: the screens as they sit, drawn to scale. The selected one is framed in the
// accent; the rows below change it. ←→ pick a screen · Shift+arrows move it against the next screen that way ·
// with the mouse: click to pick, drag to move (it snaps against the others). Screens turned off wait under the map.
Item {
    id: map

    property var setting
    property bool active: false

    signal picked

    readonly property var on: Displays.screens.filter(s => !s.disabled)
    readonly property var off: Displays.screens.filter(s => s.disabled)
    readonly property var rects: on.map(s => Object.assign({ name: s.name }, Displays.rect(s)))
    readonly property real minX: rects.length ? Math.min(...rects.map(r => r.x)) : 0
    readonly property real minY: rects.length ? Math.min(...rects.map(r => r.y)) : 0
    readonly property real spanW: rects.length ? Math.max(...rects.map(r => r.x + r.w)) - minX : 1
    readonly property real spanH: rects.length ? Math.max(...rects.map(r => r.y + r.h)) - minY : 1
    readonly property real mapH: 170
    readonly property real f: Math.min((width - 40) / spanW, mapH / spanH)
    readonly property real ox: (width - spanW * f) / 2

    implicitHeight: mapH + 20 + (off.length > 0 ? 34 : 0)

    function key(event) {
        const k = event.key;
        const shift = event.modifiers & Qt.ShiftModifier;
        const all = Displays.screens;
        if (all.length === 0)
            return false;
        if (shift && Displays.current && !Displays.current.disabled) {
            const dir = k === Qt.Key_Left ? "left" : k === Qt.Key_Right ? "right" : k === Qt.Key_Up ? "up" : k === Qt.Key_Down ? "down" : "";
            if (dir !== "") {
                Displays.moveTo(Displays.selected, Displays.current.x, Displays.current.y, dir);
                return true;
            }
        }
        if (k === Qt.Key_Left || k === Qt.Key_Right) {
            const i = all.findIndex(s => s.name === Displays.selected);
            Displays.selected = all[(i + (k === Qt.Key_Left ? -1 : 1) + all.length) % all.length].name;
            return true;
        }
        return false;
    }

    Repeater {
        model: map.on

        Item {
            id: screen

            required property var modelData
            readonly property var r: Displays.rect(modelData)
            readonly property bool chosen: modelData.name === Displays.selected
            readonly property bool main: modelData.name === Config.primaryScreen

            x: map.ox + (r.x - map.minX) * map.f + (drag.active ? drag.activeTranslation.x : 0)
            y: 6 + (r.y - map.minY) * map.f + (drag.active ? drag.activeTranslation.y : 0)
            z: drag.active ? 2 : chosen ? 1 : 0
            width: r.w * map.f
            height: r.h * map.f

            Behavior on x {
                enabled: !drag.active
                NumberAnimation { duration: Anim.base; easing.type: Anim.easing }
            }
            Behavior on y {
                enabled: !drag.active
                NumberAnimation { duration: Anim.base; easing.type: Anim.easing }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                color: screen.chosen ? Theme.surface2 : Theme.surface
                border.width: 1
                border.color: screen.chosen ? Theme.accent : Theme.borderStrong

                Behavior on border.color {
                    ColorAnimation { duration: Anim.hover }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: screen.modelData.name
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        color: Theme.text
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: screen.modelData.w + "×" + screen.modelData.h + (screen.modelData.scale !== 1 ? "  " + Math.round(screen.modelData.scale * 100) + "%" : "")
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                        color: Theme.muted
                    }
                }

                // The main screen: a short accent line along its top, like the workspace marker.
                Rectangle {
                    visible: screen.main
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 5
                    width: 18
                    height: 2
                    color: Theme.accent
                }
            }

            HoverHandler {
                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            }
            TapHandler {
                onTapped: {
                    map.picked();
                    Displays.selected = screen.modelData.name;
                }
            }
            DragHandler {
                id: drag
                target: null
                onActiveChanged: {
                    if (active) {
                        map.picked();
                        Displays.selected = screen.modelData.name;
                    } else {
                        // dropped: the nearest free spot against the others, in Hyprland's pixels
                        Displays.moveTo(screen.modelData.name, Math.round(screen.r.x + activeTranslation.x / map.f),
                            Math.round(screen.r.y + activeTranslation.y / map.f), "");
                    }
                }
            }
        }
    }

    // Screens turned off.
    Row {
        visible: map.off.length > 0
        y: map.mapH + 20
        spacing: 16

        Repeater {
            model: map.off

            Text {
                required property var modelData
                readonly property bool chosen: modelData.name === Displays.selected

                text: modelData.name + "  off"
                font.family: Theme.fontMono
                font.pixelSize: 11
                color: chosen ? Theme.accent : Theme.muted

                TapHandler {
                    onTapped: {
                        map.picked();
                        Displays.selected = parent.modelData.name;
                    }
                }
            }
        }
    }
}
