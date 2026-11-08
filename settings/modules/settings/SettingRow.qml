import QtQuick
import qs.modules.common
import qs.services

// One setting: label and what it does on the left, its control on the right, drawn with the line's own parts
// (1px tracks, a bar for a knob). The selected row (keyboard or hover) gets the launcher's selection colour.
Rectangle {
    id: row

    required property var setting
    property bool selected: false
    readonly property var value: Registry.value(setting)

    signal picked   // clicked or hovered: becomes the selected row

    height: 52
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
        onHoveredChanged: if (hovered) row.picked()
    }

    Column {
        x: 18
        anchors.verticalCenter: parent.verticalCenter
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

    Item {
        id: control

        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        width: row.setting.kind === "slider" ? 260 : row.setting.kind === "toggle" ? 70 : choices.width
        height: 20

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
                onTapped: Registry.step(row.setting, 1)
            }
        }

        // Slider: the line slider and the value.
        Item {
            visible: row.setting.kind === "slider"
            anchors.fill: parent

            LineSlider {
                id: slider
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 52
                value: row.setting.kind === "slider" ? (row.value - row.setting.min) / (row.setting.max - row.setting.min) : 0
                onMoved: v => {
                    const s = row.setting;
                    const raw = s.min + v * (s.max - s.min);
                    Config.set(s.key, Math.round(raw / s.step) * s.step);
                }
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: row.setting.kind === "slider" ? Registry.valueText(row.setting) : ""
                font.family: Theme.fontMono
                font.pixelSize: 11
                color: Theme.text
            }
        }

        // Choice: the options in a row, the current one underlined in the accent; colour: swatches.
        Row {
            id: choices

            visible: row.setting.kind === "choice" || row.setting.kind === "color"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: row.setting.kind === "color" ? 10 : 16

            Repeater {
                model: visible ? row.setting.choices : []

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
                        onTapped: Config.set(row.setting.key, option.modelData.value)
                    }
                }
            }
        }
    }

    TapHandler {
        onTapped: row.picked()
    }
}
