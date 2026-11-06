import QtQuick
import QtQuick.Shapes
import qs.services

// The line and everything that happens on it: music progress, workspace marker, level gauge, notification pulse.
// Lives in the same surface as the tiles but is stacked above them.
Item {
    id: line

    required property int workspace   // 1..10, the active workspace of this screen
    property bool fullscreen: false
    property real reach: 1             // 1 = edge to edge, 0 = withdrawn into both screen edges

    readonly property real lineWidth: width

    // The line itself: it comes out of both edges of the screen, one half from each side.
    Rectangle {
        x: 0
        y: 10
        width: Math.ceil(line.lineWidth / 2 * line.reach)
        height: 1
        color: Theme.borderStrong
    }
    Rectangle {
        x: line.lineWidth - width
        y: 10
        width: Math.ceil(line.lineWidth / 2 * line.reach)
        height: 1
        color: Theme.borderStrong
    }

    // Level gauge: the whole line becomes the bar. No popup.
    Rectangle {
        y: 9
        x: 0
        height: 3
        width: LineState.gaugeValue * line.lineWidth
        color: Theme.accent
        opacity: LineState.gaugeKind !== "" ? 1 : 0

        Behavior on width {
            NumberAnimation { duration: Anim.base; easing.type: Anim.easing }
        }
        Behavior on opacity {
            NumberAnimation { duration: Anim.base }
        }
    }

    // Music progress: on the line, exactly above the music part of the top-left tile. Creeps forward each second.
    Rectangle {
        x: 16 + Theme.wsBlockW
        y: 10
        width: Media.progress * Theme.musicW
        height: 1
        color: Theme.accent
        opacity: Media.active && !line.fullscreen ? 0.85 : 0

        Behavior on width {
            NumberAnimation { duration: 1000 }
        }
        Behavior on opacity {
            NumberAnimation { duration: Anim.base }
        }
    }

        // Workspace marker: slides along the line, in step with the workspace switch.
    Rectangle {
        y: 9
        width: 14
        height: 3
        color: Theme.accent
        opacity: line.fullscreen ? 0 : 1

        Behavior on opacity {
            NumberAnimation { duration: Anim.base }
        }

        // Centred over the active cell of the workspace ruler (tile at 16, ruler 13 px in).
        x: 16 + 13 + Theme.wsCell / 2 - 7 + (Math.max(1, Math.min(10, line.workspace)) - 1) * Theme.wsCell

        Behavior on x {
            NumberAnimation { duration: Anim.workspace; easing.type: Anim.easing }
        }
    }

    // Notification pulse: two dashes run in along the line and meet at the centre, then turn back, run out to the
    // toast's top corners and down its sides while the clock tile's frame grows with them (see ClockTile).
    PulseDash {
        anchors.fill: parent
        centerX: line.width / 2
        tileShown: !line.fullscreen
        visible: LineState.pulseActive
    }
    PulseDash {
        anchors.fill: parent
        centerX: line.width / 2
        tileShown: !line.fullscreen
        visible: LineState.pulseActive
        transform: Scale {
            origin.x: line.width / 2
            xScale: -1
        }
    }
}
