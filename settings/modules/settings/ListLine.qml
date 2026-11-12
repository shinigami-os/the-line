import QtQuick
import TheLine.Ui
import qs.services

// One line of a list inside a setting (networks, devices, apps): a name, a muted detail, something on the right;
// `lit` marks the one in use with the accent, `under` is the keyboard's cursor.
Item {
    id: line

    property string name
    property string detail
    property string trailing
    property color trailingColor: Theme.muted
    property bool lit: false
    property bool under: false
    default property alias extra: slot.data   // replaces `right` (a slider, a ruler...)

    signal clicked
    signal entered

    height: 34

    Rectangle {
        anchors.fill: parent
        color: line.under ? Theme.surface : "transparent"

        Behavior on color {
            ColorAnimation { duration: Anim.hover }
        }
    }
    Rectangle {
        x: 0
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
        width: Math.min(implicitWidth, line.width * 0.45)
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
        anchors.right: slot.children.length > 0 ? slot.left : rightText.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: line.detail
        font.family: Theme.fontMono
        font.pixelSize: 10
        color: Theme.muted
    }
    Text {
        id: rightText
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        visible: slot.children.length === 0
        text: line.trailing
        font.family: Theme.fontMono
        font.pixelSize: 10
        color: line.trailingColor
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
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: if (hovered && Registry.hoverPicks()) line.entered()
    }
    TapHandler {
        onTapped: line.clicked()
    }
}
