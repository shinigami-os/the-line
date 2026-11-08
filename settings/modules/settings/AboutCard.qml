import QtQuick
import qs.services

// Settings > About: the name, drawn large over a line that runs out from it, and the version.
Item {
    id: card

    property var setting
    property bool active: false

    signal picked

    implicitHeight: 96

    function key(event) {
        return false;
    }

    Text {
        id: name
        x: 12
        y: 4
        text: "The Line"
        font.family: Theme.fontUi
        font.pixelSize: 40
        font.weight: Font.Light
        color: Theme.text
    }

    // The line: from the name's end to the card's edge, in the accent.
    Rectangle {
        x: name.x + name.implicitWidth + 16
        y: name.y + name.implicitHeight * 0.62
        width: parent.width - x - 12
        height: 1
        color: Theme.accent
    }

    Text {
        x: 14
        y: name.y + name.implicitHeight + 6
        text: (card.setting?.sub ?? "") + "      version " + Sys.line
        font.family: Theme.fontMono
        font.pixelSize: 11
        color: Theme.muted
    }
}
