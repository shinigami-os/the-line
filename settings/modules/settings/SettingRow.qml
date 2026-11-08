import QtQuick
import qs.modules.common
import qs.services

// One setting: label and what it does on the left, its control on the right, drawn with the line's own parts
// (1px tracks, a bar for a knob). The selected row (keyboard or hover) gets the launcher's selection colour.
// Wallpaper, app rules and floating apps are taller rows: their own component sits under the label, and takes
// the keyboard first while the row is selected (key() returns true when it used the key).
Rectangle {
    id: row

    required property var setting
    property bool selected: false
    readonly property var value: Registry.value(setting)
    readonly property bool custom: ["wallpaper", "workspaceApps", "floatingApps"].indexOf(setting.kind) >= 0

    signal picked      // clicked or hovered: becomes the selected row
    signal refocus     // a custom row is done with its own text field: the keyboard goes back to the view

    function key(event) {
        return custom && body.item ? body.item.key(event) : false;
    }

    height: custom ? 52 + (body.item ? body.item.implicitHeight : 0) + 16 : 52
    color: selected ? Theme.surface2 : "transparent"

    Behavior on color {
        ColorAnimation { duration: Anim.hover }
    }

    // The accent tick at the left edge of the selected row.
    Rectangle {
        width: 2
        height: parent.height
        color: Theme.accent
        opacity: row.selected ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Anim.hover }
        }
    }

    HoverHandler {
        onHoveredChanged: if (hovered && !row.custom) row.picked()
    }
    TapHandler {
        onTapped: row.picked()
    }

    Column {
        x: 18
        y: 26 - height / 2
        width: parent.width - control.width - 54
        spacing: 3

        Text {
            width: parent.width
            text: row.setting.label
            elide: Text.ElideRight
            font.family: Theme.fontUi
            font.pixelSize: 13
            font.weight: Font.Medium
            color: Theme.text
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: row.setting.sub ?? ""
            elide: Text.ElideRight
            font.family: Theme.fontUi
            font.pixelSize: 11
            font.weight: Font.Medium
            color: Theme.muted
        }
    }

    Loader {
        id: body

        x: 18
        y: 52
        width: row.width - 36
        active: row.custom
        source: row.setting.kind === "wallpaper" ? "WallpaperPicker.qml"
            : row.setting.kind === "workspaceApps" ? "WorkspaceRules.qml"
            : row.setting.kind === "floatingApps" ? "FloatingApps.qml" : ""
        onLoaded: {
            item.active = Qt.binding(() => row.selected);
            if (item.refocus)
                item.refocus.connect(row.refocus);
            if (item.picked)
                item.picked.connect(row.picked);
        }
    }

    Item {
        id: control

        anchors.right: parent.right
        anchors.rightMargin: 18
        y: 26 - height / 2
        visible: !row.custom
        width: row.setting.kind === "slider" || row.setting.kind === "stops" || row.setting.kind === "speed" ? 300
            : row.setting.kind === "toggle" ? 70 : choices.width
        height: row.setting.kind === "speed" ? 34 : 20

        // Toggle: a short line with the knob at its end, "on" lit in the accent.
        Item {
            visible: row.setting.kind === "toggle"
            anchors.fill: parent

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: row.value ? "on" : "off"
                font.family: Theme.fontMono
                font.pixelSize: 11
                color: row.value ? Theme.accent : Theme.muted
            }
            Rectangle {
                id: track
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 1
                color: row.value ? Theme.accent : Theme.borderStrong
            }
            Rectangle {
                x: track.x + (row.value ? track.width - width : 0)
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 14
                color: row.value ? Theme.accent : Theme.text

                Behavior on x {
                    NumberAnimation { duration: Anim.base; easing.type: Anim.easing }
                }
            }
            TapHandler {
                onTapped: {
                    row.picked();
                    Registry.step(row.setting, 1);
                }
            }
        }

        // Sliders: a number (slider), fixed stops (stops) or the motion speed (speed, log scale, 1× in the middle).
        Item {
            visible: row.setting.kind === "slider" || row.setting.kind === "stops" || row.setting.kind === "speed"
            anchors.fill: parent

            readonly property var stops: row.setting.stops ?? []

            LineSlider {
                id: slider
                y: 1
                width: parent.width - 64
                value: {
                    const s = row.setting;
                    if (s.kind === "slider")
                        return (row.value - s.min) / (s.max - s.min);
                    if (s.kind === "stops")
                        return Math.max(0, parent.stops.findIndex(c => Registry.same(c.value, row.value))) / Math.max(1, parent.stops.length - 1);
                    if (s.kind === "speed")
                        return (Math.log2(Registry.speed(row.value)) + 1) / 2;
                    return 0;
                }
                onMoved: v => {
                    const s = row.setting;
                    row.picked();
                    if (s.kind === "slider") {
                        Config.set(s.key, Math.round((s.min + v * (s.max - s.min)) / s.step) * s.step);
                    } else if (s.kind === "stops") {
                        Config.set(s.key, parent.stops[Math.round(v * (parent.stops.length - 1))].value);
                    } else {
                        // precise to 0.01×, with a little pull towards 1×
                        let speed = Math.round(Math.pow(2, 2 * v - 1) * 100) / 100;
                        if (Math.abs(speed - 1) < 0.03)
                            speed = 1;
                        Registry.setSpeed(speed);
                    }
                }
            }
            Text {
                anchors.right: parent.right
                y: slider.y + slider.height / 2 - height / 2
                text: Registry.valueText(row.setting)
                font.family: Theme.fontMono
                font.pixelSize: 11
                color: Theme.text
            }

            // Speed marks under the track: 0.5×, 1×, 2×.
            Repeater {
                model: row.setting.kind === "speed" ? [{ at: 0, label: "0.5×" }, { at: 0.5, label: "1×" }, { at: 1, label: "2×" }] : []

                Item {
                    required property var modelData

                    x: 4 + modelData.at * (slider.width - 8)
                    y: slider.y + 18

                    Rectangle {
                        x: 0
                        y: -3
                        width: 1
                        height: 4
                        color: Theme.borderStrong
                    }
                    Text {
                        x: -width / 2
                        y: 3
                        text: parent.modelData.label
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                        color: Theme.muted
                    }
                }
            }
        }

        // Choice: the options in a row, the current one underlined in the accent; colour: swatches (plus the
        // current colour when it is none of them: picked from the wallpaper).
        Row {
            id: choices

            visible: row.setting.kind === "choice" || row.setting.kind === "color"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: row.setting.kind === "color" ? 10 : 16

            Repeater {
                model: {
                    if (!choices.visible)
                        return [];
                    const list = row.setting.choices;
                    if (row.setting.kind === "color" && !list.some(c => Registry.same(c.value, row.value)))
                        return list.concat([{ value: String(row.value), label: "from the wallpaper" }]);
                    return list;
                }

                Item {
                    id: option

                    required property var modelData
                    readonly property bool current: Registry.same(modelData.value, row.value)

                    width: row.setting.kind === "color" ? 18 : label.implicitWidth
                    height: 20

                    Text {
                        id: label
                        visible: row.setting.kind === "choice"
                        anchors.verticalCenter: parent.verticalCenter
                        text: option.modelData.label
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        color: option.current ? Theme.text : Theme.muted
                    }
                    Rectangle {
                        visible: row.setting.kind === "choice"
                        y: parent.height - 1
                        width: parent.width
                        height: 1
                        color: Theme.accent
                        opacity: option.current ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: Anim.hover }
                        }
                    }

                    Rectangle {
                        visible: row.setting.kind === "color"
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        color: "transparent"
                        border.width: 1
                        border.color: option.current ? Theme.text : "transparent"

                        Rectangle {
                            anchors.centerIn: parent
                            width: 12
                            height: 12
                            color: option.modelData.value
                        }
                    }

                    TapHandler {
                        onTapped: {
                            row.picked();
                            Registry.set(row.setting, option.modelData.value);
                        }
                    }
                }
            }
        }
    }
}
