import QtQuick
import QtQuick.Shapes
import qs.modules.common
import qs.services

// The music panel. The track is drawn as a ruler, like the workspace ruler: a tick every 15 s, a longer labelled
// tick every minute, the elapsed part in accent and the marker sliding along it. Click or drag on it to seek.
Column {
    id: panel

    required property bool shown

    spacing: 0

    component Button: Rectangle {
        id: button

        property string label
        property bool on: false
        property bool enabledState: true
        default property alias glyph: glyphBox.data
        signal clicked

        width: label !== "" ? labelText.implicitWidth + 20 : 40
        height: 30
        color: on ? Theme.accentTint : (hover.hovered ? Theme.surface2 : "transparent")
        border.width: 1
        border.color: on ? Theme.accent : (hover.hovered ? Theme.borderStrong : Theme.border)
        opacity: enabledState ? 1 : 0.4

        Behavior on color {
            ColorAnimation { duration: Anim.hover }
        }
        Behavior on border.color {
            ColorAnimation { duration: Anim.hover }
        }

        Item {
            id: glyphBox
            anchors.centerIn: parent
            width: childrenRect.width
            height: childrenRect.height
        }
        Text {
            id: labelText
            visible: button.label !== ""
            anchors.centerIn: parent
            text: button.label
            font.family: Theme.fontMono
            font.pixelSize: 11
            color: button.on ? Theme.text : Theme.muted
        }

        HoverHandler {
            id: hover
        }
        TapHandler {
            onTapped: if (button.enabledState) button.clicked()
        }
    }

    // Skip glyph: a triangle against a bar, pointing forward or back.
    component SkipGlyph: Item {
        id: skip

        property bool forward: true

        width: 11
        height: 10

        Rectangle {
            x: skip.forward ? 9 : 0
            width: 2
            height: 10
            color: Theme.text
        }
        Shape {
            x: skip.forward ? 0 : 3
            width: 8
            height: 10
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: Theme.text
                startX: skip.forward ? 0 : 8
                startY: 0
                PathLine { x: skip.forward ? 8 : 0; y: 5 }
                PathLine { x: skip.forward ? 0 : 8; y: 10 }
                PathLine { x: skip.forward ? 0 : 8; y: 0 }
            }
        }
    }

    // Cover and track.
    PanelItem {
        order: 0
        shown: panel.shown
        width: panel.width
        height: 88 + 14

        Rectangle {
            id: cover
            width: 88
            height: 88
            color: Theme.bg
            border.width: 1
            border.color: Theme.border

            Image {
                anchors.fill: parent
                anchors.margins: 1
                source: Media.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                visible: Media.art === ""
                text: "--"
                font.family: Theme.fontMono
                font.pixelSize: 12
                color: Theme.borderStrong
            }
        }

        Column {
            anchors.left: cover.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            y: 4
            spacing: 3

            Text {
                width: parent.width
                text: Media.title
                elide: Text.ElideRight
                font.family: Theme.fontUi
                font.pixelSize: 15
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: Media.artist
                elide: Text.ElideRight
                font.family: Theme.fontUi
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Theme.text
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: Media.album
                elide: Text.ElideRight
                font.family: Theme.fontUi
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Theme.muted
            }
        }

        // Elapsed / total, at the foot of the track info.
        Text {
            anchors.left: cover.right
            anchors.leftMargin: 14
            y: 88 - height
            textFormat: Text.StyledText
            text: "<font color=\"" + Theme.accent + "\">" + Media.format(Media.position) + "</font> / " + Media.format(Media.length)
            font.family: Theme.fontMono
            font.pixelSize: 11
            color: Theme.text
        }
    }

    // The track ruler.
    PanelItem {
        id: rulerItem

        order: 1
        shown: panel.shown
        width: panel.width
        height: 46

        readonly property real secs: Math.max(1, Media.length)
        readonly property real rulerW: width - 44            // room at the end for the total time
        readonly property real px: rulerW / secs              // pixels per second

        Rectangle {
            y: 6
            width: rulerItem.rulerW
            height: 1
            color: Theme.borderStrong
        }
        Rectangle {
            y: 6
            width: Media.progress * rulerItem.rulerW
            height: 1
            color: Theme.accent

            Behavior on width {
                NumberAnimation { duration: 1000 }
            }
        }

        Repeater {
            model: Math.floor(rulerItem.secs / 15) + 1

            Item {
                id: tick

                required property int index
                readonly property bool minute: index % 4 === 0

                x: index * 15 * rulerItem.px
                y: 7
                width: 1
                height: 30

                Rectangle {
                    width: 1
                    height: tick.minute ? 8 : 4
                    color: tick.minute ? Theme.muted : Theme.borderStrong
                }
                Text {
                    visible: tick.minute && tick.x + implicitWidth < rulerItem.rulerW - 4
                    y: 10
                    text: (tick.index / 4) + ":00"
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    color: Theme.muted
                }
            }
        }

        // Marker: the same 14 x 3 accent bar as the workspace marker.
        Rectangle {
            x: Math.max(0, Math.min(rulerItem.rulerW - width, Media.progress * rulerItem.rulerW - width / 2))
            y: 5
            width: 14
            height: 3
            color: Theme.accent

            Behavior on x {
                NumberAnimation { duration: 1000 }
            }
        }

        // End of the ruler: a closing tick and the total time.
        Rectangle {
            x: rulerItem.rulerW
            y: 6
            width: 1
            height: 9
            color: Theme.muted
        }
        Text {
            x: rulerItem.rulerW + 8
            y: 0
            text: Media.format(Media.length)
            font.family: Theme.fontMono
            font.pixelSize: 10
            color: Theme.muted
        }

        MouseArea {
            width: rulerItem.rulerW
            height: 24
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => Media.seek(mouse.x / width)
            onPositionChanged: mouse => {
                if (pressed)
                    Media.seek(mouse.x / width);
            }
        }
    }

    // Controls.
    PanelItem {
        order: 2
        shown: panel.shown
        width: panel.width
        height: 30 + 12

        Row {
            spacing: 6

            Button {
                enabledState: Media.player?.canGoPrevious ?? false
                onClicked: Media.previous()

                SkipGlyph {
                    forward: false
                }
            }
            Button {
                width: 52
                onClicked: Media.toggle()

                Row {
                    visible: Media.playing
                    spacing: 3
                    Rectangle { width: 2.5; height: 10; color: Theme.text }
                    Rectangle { width: 2.5; height: 10; color: Theme.text }
                }
                Shape {
                    visible: !Media.playing
                    width: 9
                    height: 10
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: 0
                        strokeColor: "transparent"
                        fillColor: Theme.text
                        startX: 0
                        startY: 0
                        PathLine { x: 9; y: 5 }
                        PathLine { x: 0; y: 10 }
                        PathLine { x: 0; y: 0 }
                    }
                }
            }
            Button {
                enabledState: Media.player?.canGoNext ?? false
                onClicked: Media.next()

                SkipGlyph {
                    forward: true
                }
            }
        }

        Row {
            anchors.right: parent.right
            spacing: 6

            // The frequencies on the line, while the tiles fold away (SUPER+M).
            Button {
                visible: Visualiser.installed
                label: "visualiser"
                on: Visualiser.on
                onClicked: Visualiser.toggle()
            }
            Button {
                visible: Media.player?.shuffleSupported ?? false
                label: "shuffle"
                on: Media.player?.shuffle ?? false
                onClicked: Media.toggleShuffle()
            }
            Button {
                visible: Media.loopLabel !== ""
                label: Media.loopLabel
                on: Media.loopLabel !== "" && Media.loopLabel !== "loop · off"
                onClicked: Media.cycleLoop()
            }
        }
    }

    // Players: pick which one the shell follows.
    PanelItem {
        order: 3
        shown: panel.shown
        width: panel.width
        height: 26

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }
        Row {
            x: 4
            y: 9
            spacing: 14

            Repeater {
                model: Media.players

                Text {
                    id: playerTab

                    required property var modelData

                    textFormat: Text.StyledText
                    text: (modelData.identity ?? "player").toLowerCase()
                        + "<font color=\"" + Theme.muted + "\"> · " + (modelData.isPlaying ? "playing" : "paused") + "</font>"
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    color: modelData === Media.player ? Theme.accent : (tabHover.hovered ? Theme.text : Theme.muted)

                    HoverHandler {
                        id: tabHover
                    }
                    TapHandler {
                        onTapped: Media.pinned = playerTab.modelData
                    }
                }
            }
        }
    }
}
