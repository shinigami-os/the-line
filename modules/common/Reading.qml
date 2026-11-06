import QtQuick
import qs.services

// A labelled reading for a tile's top row: a small uppercase label over a mono value, with an optional
// line-drawn decoration before the value (default children). While `expanded` (the tile is open) the longer
// `wide` value cross-fades in and the width follows with the panel timing.
Item {
    id: reading

    property string label
    property string value
    property string wide: value
    property bool expanded: false
    property color valueColor: Theme.text
    property real minWidth: 30

    default property alias decoration: deco.data

    readonly property real _decoW: deco.childrenRect.width > 0 ? deco.childrenRect.width + 5 : 0

    // Width at rest, whatever the current state: lets a tile size itself without following the expansion.
    readonly property real compactWidth: Math.max(minWidth, labelText.implicitWidth, _decoW + valueText.implicitWidth)

    width: expanded ? Math.max(minWidth, labelText.implicitWidth, _decoW + wideText.implicitWidth) : compactWidth
    height: 27
    clip: true

    Behavior on width {
        NumberAnimation { duration: Anim.panel; easing.type: Anim.easing }
    }

    Text {
        id: labelText
        text: reading.label
        font.family: Theme.fontUi
        font.pixelSize: 9
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
        color: Theme.muted
    }

    Item {
        id: deco
        y: 14
        width: childrenRect.width
        height: 10
    }

    Text {
        id: valueText
        x: reading._decoW
        y: 11
        text: reading.value
        font.family: Theme.fontMono
        font.pixelSize: 12
        color: reading.valueColor
        opacity: reading.expanded ? 0 : 1

        Behavior on opacity {
            NumberAnimation { duration: Anim.base }
        }
        Behavior on color {
            ColorAnimation { duration: Anim.base }
        }
    }

    Text {
        id: wideText
        x: reading._decoW
        y: 11
        text: reading.wide
        font.family: Theme.fontMono
        font.pixelSize: 12
        color: reading.valueColor
        opacity: reading.expanded ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Anim.base }
        }
        Behavior on color {
            ColorAnimation { duration: Anim.base }
        }
    }
}
