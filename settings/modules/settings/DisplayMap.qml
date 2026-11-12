pragma ComponentBehavior: Bound

import QtQuick
import TheLine.Ui
import qs.services

// Settings > Displays > Arrangement: the screens as planned, drawn small with room around them. The selected one is
// framed in the accent; the rows below change it. ←→ pick a screen · Shift+arrows move it against the next screen
// that way · with the mouse: click to pick, drag to move. A dragged screen snaps from spot to spot against the
// others (an outline shows where it lands). Nothing reaches the screens before Apply. Screens turned off wait under the map.
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
    readonly property real bigW: rects.length ? Math.max(...rects.map(r => r.w)) : 1
    readonly property real bigH: rects.length ? Math.max(...rects.map(r => r.h)) : 1
    readonly property real mapH: 210
    // room for one more screen on every side, so a screen can be dragged above, below or beyond the others
    readonly property real f: Math.min((width - 40) / (spanW + 2 * bigW), mapH / (spanH + 2 * bigH))
    readonly property real ox: (width - spanW * f) / 2
    readonly property real oy: (mapH - spanH * f) / 2

    implicitHeight: mapH + 12 + (off.length > 0 ? 30 : 0)

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

    // The map's frame: a dotted grid would be noise; a faint border says where the room ends.
    Rectangle {
        width: parent.width
        height: map.mapH
        color: "transparent"
        border.width: 1
        border.color: Theme.border
    }

    Repeater {
        model: map.on

        Item {
            id: screen

            required property var modelData
            readonly property var r: Displays.rect(modelData)
            readonly property bool chosen: modelData.name === Displays.selected
            readonly property bool main: modelData.name === Displays.main
            // while dragged: the spot it would land on, in Hyprland's pixels
            property var spot: null

            function spotAt(tx, ty) {
                return Displays.snap(modelData.name, r.x + tx / map.f, r.y + ty / map.f);
            }

            x: map.ox + ((spot ? spot.x : r.x) - map.minX) * map.f
            y: map.oy + ((spot ? spot.y : r.y) - map.minY) * map.f
            z: drag.active ? 2 : chosen ? 1 : 0
            width: r.w * map.f
            height: r.h * map.f

            Behavior on x {
                NumberAnimation { duration: Anim.hover; easing.type: Anim.easing }
            }
            Behavior on y {
                NumberAnimation { duration: Anim.hover; easing.type: Anim.easing }
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
                    spacing: 1

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: screen.modelData.name
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        color: Theme.text
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: screen.modelData.w + "×" + screen.modelData.h + (screen.modelData.scale !== 1 ? " " + Math.round(screen.modelData.scale * 100) + "%" : "")
                        font.family: Theme.fontMono
                        font.pixelSize: 8
                        color: Theme.muted
                    }
                }

                // The main screen: a short accent line along its top, like the workspace marker.
                Rectangle {
                    visible: screen.main
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 4
                    width: 14
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
                        screen.spot = screen.spotAt(0, 0);
                    } else {
                        // moved first, then let go of the spot: no slide back to the old place on the way
                        const s = screen.spot;
                        if (s && (s.x !== screen.r.x || s.y !== screen.r.y))
                            Displays.moveTo(screen.modelData.name, s.x, s.y, "");
                        screen.spot = null;
                    }
                }
                onActiveTranslationChanged: if (active) screen.spot = screen.spotAt(activeTranslation.x, activeTranslation.y)
            }

            // Under the hand while dragging: where the pointer is, faint, so the jump to the spot reads as a snap.
            Rectangle {
                visible: drag.active
                x: drag.activeTranslation.x - (parent.x - map.ox - (screen.r.x - map.minX) * map.f)
                y: drag.activeTranslation.y - (parent.y - map.oy - (screen.r.y - map.minY) * map.f)
                width: parent.width
                height: parent.height
                color: "transparent"
                border.width: 1
                border.color: Theme.muted
                opacity: 0.5
            }
        }
    }

    // Screens turned off.
    Row {
        visible: map.off.length > 0
        y: map.mapH + 12
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
