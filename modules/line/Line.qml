import QtQuick
import QtQuick.Shapes
import qs.services

// The line and everything that happens on it: workspace marker, level gauge, notification pulse.
// Lives in the same surface as the tiles but is stacked above them.
Item {
    id: line

    required property int workspace   // 1..10, the active workspace of this screen

    readonly property real lineWidth: width

    // The line itself: it comes out of both edges of the screen.
    Rectangle {
        x: 0
        y: 10
        width: line.lineWidth
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

    // Workspace marker: slides along the line, in step with the workspace switch.
    Rectangle {
        y: 9
        width: 14
        height: 3
        color: Theme.accent
        x: 33 + (Math.max(1, Math.min(10, line.workspace)) - 1) * 22

        Behavior on x {
            NumberAnimation { duration: Anim.workspace; easing.type: Anim.easing }
        }
    }

    // Notification pulse: two dashes run in along the line and meet at the centre, then turn back, run out to the
    // toast's top corners and draw its outline (down the sides, inward along the bottom) while the tile grows.
    PulseDash {
        id: pulseLeft
        anchors.fill: parent
        centerX: line.width / 2
        visible: false
    }
    PulseDash {
        id: pulseRight
        anchors.fill: parent
        centerX: line.width / 2
        visible: false
        transform: Scale {
            origin.x: line.width / 2
            xScale: -1
        }
    }

    SequentialAnimation {
        id: pulseAnim

        property bool around: true

        onStarted: {
            pulseLeft.visible = true;
            pulseRight.visible = true;
        }
        onStopped: {
            pulseLeft.visible = false;
            pulseRight.visible = false;
        }

        // Meet at the centre.
        NumberAnimation {
            targets: [pulseLeft, pulseRight]
            property: "s"
            from: 0
            to: pulseLeft.meetEnd
            duration: Anim.pulse
            easing.type: Easing.Linear
        }
        // Turn back and follow the tile's edges.
        ScriptAction {
            script: {
                if (pulseAnim.around) {
                    pulseLeft.r = 0;
                    pulseRight.r = 0;
                    pulseLeft.phase = 2;
                    pulseRight.phase = 2;
                }
            }
        }
        NumberAnimation {
            targets: [pulseLeft, pulseRight]
            property: "r"
            from: 0
            to: pulseLeft.wrapEnd
            duration: pulseAnim.around ? Anim.pulseWrap : 0
            easing.type: Easing.Linear
        }
    }

    Connections {
        target: LineState

        function onPulseRequested(toTile) {
            pulseAnim.stop();
            pulseLeft.phase = 1;
            pulseRight.phase = 1;
            pulseLeft.around = toTile;
            pulseRight.around = toTile;
            pulseAnim.around = toTile;
            pulseAnim.restart();
        }
    }
}
