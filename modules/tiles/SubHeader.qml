import QtQuick
import TheLine.Ui

// Top of the status panel's Wi-Fi and Bluetooth views: back to quick settings on the left, the radio's switch at the right.
Item {
    id: head

    property string title
    property bool on: false
    property bool available: true

    signal back
    signal switched

    height: 32

    Item {
        width: backRow.width + 8
        height: parent.height

        Row {
            id: backRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                text: "‹"
                font.family: Theme.fontMono
                font.pixelSize: 16
                color: backHover.hovered ? Theme.accent : Theme.muted
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: head.title
                font.family: Theme.fontUi
                font.pixelSize: 14
                font.weight: Font.Medium
                color: Theme.text
            }
        }
        HoverHandler {
            id: backHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: head.back()
        }
    }

    Rectangle {
        visible: head.available
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 56
        height: 26
        color: head.on ? Theme.accentTint : (switchHover.hovered ? Theme.surface2 : "transparent")
        border.width: 1
        border.color: head.on ? Theme.accent : (switchHover.hovered ? Theme.borderStrong : Theme.border)

        Behavior on color {
            ColorAnimation { duration: Anim.hover }
        }
        Behavior on border.color {
            ColorAnimation { duration: Anim.hover }
        }

        Text {
            anchors.centerIn: parent
            text: head.on ? "on" : "off"
            font.family: Theme.fontMono
            font.pixelSize: 11
            color: head.on ? Theme.text : Theme.muted
        }
        HoverHandler {
            id: switchHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: head.switched()
        }
    }
}
