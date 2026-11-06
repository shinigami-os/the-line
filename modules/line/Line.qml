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

    // Notification pulse: two dashes travel in and meet at the clock.
    Rectangle {
        id: pulseLeft
        y: 9
        width: 56
        height: 3
        x: 0
        color: Theme.accent
        visible: false
    }
    Rectangle {
        id: pulseRight
        y: 9
        width: 56
        height: 3
        x: line.width - 56
        color: Theme.accent
        visible: false
    }

    ParallelAnimation {
        id: pulseAnim

        onStarted: {
            pulseLeft.visible = true;
            pulseRight.visible = true;
        }
        onStopped: {
            pulseLeft.visible = false;
            pulseRight.visible = false;
        }

        NumberAnimation {
            target: pulseLeft
            property: "x"
            from: 0
            to: line.width / 2 - 56
            duration: Anim.pulse
            easing.type: Anim.easing
        }
        NumberAnimation {
            target: pulseRight
            property: "x"
            from: line.width - 56
            to: line.width / 2
            duration: Anim.pulse
            easing.type: Anim.easing
        }
        NumberAnimation {
            targets: [pulseLeft, pulseRight]
            property: "opacity"
            from: 0
            to: 1
            duration: Anim.pulse * 0.15
        }
    }

    Connections {
        target: LineState

        function onPulseRequested() {
            pulseAnim.restart();
        }
    }
}
