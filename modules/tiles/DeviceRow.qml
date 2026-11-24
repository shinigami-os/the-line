import QtQuick
import TheLine.Ui

// One line of the status panel's Wi-Fi and Bluetooth views: a name, a muted detail, a status at the right. `lit` marks
// the one in use with the accent tick.
Item {
    id: line

    property string name
    property string detail
    property string status
    property color statusColor: Theme.muted
    property bool lit: false
    default property alias extra: slot.data   // replaces `status` (the signal bars)

    signal clicked

    height: 34

    Rectangle {
        anchors.fill: parent
        color: hover.hovered ? Theme.surface2 : "transparent"

        Behavior on color {
            ColorAnimation { duration: Anim.hover }
        }
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: 14
        color: Theme.accent
        visible: line.lit
    }
    Text {
        id: nameText
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, line.width * 0.5)
        elide: Text.ElideRight
        text: line.name
        font.family: Theme.fontUi
        font.pixelSize: 13
        font.weight: Font.Medium
        color: Theme.text
    }
    Text {
        anchors.left: nameText.right
        anchors.leftMargin: 10
        anchors.right: slot.children.length > 0 ? slot.left : statusText.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: line.detail
        font.family: Theme.fontMono
        font.pixelSize: 10
        color: Theme.muted
    }
    Text {
        id: statusText
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        visible: slot.children.length === 0
        text: line.status
        font.family: Theme.fontMono
        font.pixelSize: 10
        color: line.statusColor
    }
    Item {
        id: slot
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: line.clicked()
    }
}
