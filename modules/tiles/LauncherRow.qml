import QtQuick
import Quickshell
import TheLine.Ui
import Quickshell.Widgets
import qs.services

// One launcher row: the app's icon (or, without one, a mono glyph in a box), name, muted description, and a key cap
// or a state pill on the right.
Rectangle {
    id: row

    property string glyph
    property string icon   // an icon path from Quickshell.iconPath, "" for none
    property string name
    property string description
    property bool monoName: false
    property string keycap
    property string pill
    property bool pillOn: false
    property bool selected: false

    signal activated
    signal hovered

    height: 32
    color: selected ? Theme.surface2 : "transparent"

    Behavior on color {
        ColorAnimation { duration: Anim.hover }
    }

    IconImage {
        visible: row.icon !== ""
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: 20
        source: row.icon
    }

    Rectangle {
        visible: row.icon === ""
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24
        color: "transparent"
        border.width: 1
        border.color: row.selected ? Theme.accent : Theme.borderStrong

        Text {
            anchors.centerIn: parent
            text: row.glyph
            font.family: Theme.fontMono
            font.pixelSize: 11
            color: row.selected ? Theme.accent : Theme.text
        }
    }

    Text {
        id: nameText
        x: 44
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, row.width * 0.45)
        text: row.name
        elide: Text.ElideRight
        font.family: row.monoName ? Theme.fontMono : Theme.fontUi
        font.pixelSize: row.monoName ? 12 : 13
        font.weight: Font.Medium
        color: Theme.text
    }

    Text {
        x: Math.max(44 + 120, nameText.x + nameText.width + 12)
        anchors.verticalCenter: parent.verticalCenter
        width: right.x - x - 12
        text: row.description
        elide: Text.ElideRight
        font.family: Theme.fontUi
        font.pixelSize: 12
        font.weight: Font.Medium
        color: Theme.muted
    }

    Rectangle {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        visible: row.keycap !== "" || row.pill !== ""
        width: rightText.implicitWidth + (row.pill !== "" ? 16 : 12)
        height: 18
        color: "transparent"
        border.width: 1
        border.color: row.pillOn ? Theme.accent : Theme.borderStrong

        Text {
            id: rightText
            anchors.centerIn: parent
            text: row.pill !== "" ? row.pill : row.keycap
            font.family: Theme.fontMono
            font.pixelSize: 11
            color: row.pillOn ? Theme.accent : Theme.muted
        }
    }

    HoverHandler {
        onHoveredChanged: if (hovered) row.hovered()
    }
    TapHandler {
        onTapped: row.activated()
    }
}
