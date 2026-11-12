import QtQuick
import TheLine.Ui
import qs.services

// Flat analog clock: twelve ticks and three hands, no face, no round edges.
// Angles stay within 0-360 (large angles lose precision in the transform and the hands freeze); the rotation
// always turns clockwise, so a hand passing 12 never spins backwards.
Item {
    id: clock

    property real size: 140
    // Ticks only while it can be seen: a hidden clock that still turned its hands every second redrew every window
    // of the shell, on every screen. Back on, it catches up with one turn.
    property bool live: true
    property date shown   // set, never bound: a binding to Time.now would tick whether shown or not
    Component.onCompleted: shown = Time.now
    Connections {
        target: Time
        enabled: clock.live
        function onNowChanged() {
            clock.shown = Time.now;
        }
    }
    onLiveChanged: if (live) shown = Time.now

    readonly property int h: shown.getHours() % 12
    readonly property int m: shown.getMinutes()
    readonly property int sec: shown.getSeconds()
    readonly property real c: size / 2

    width: size
    height: size

    Repeater {
        model: 12

        Rectangle {
            required property int index
            readonly property bool quarter: index % 3 === 0

            x: clock.c - 0.5
            y: 0
            width: 1
            height: quarter ? 10 : 5
            color: quarter ? Theme.muted : Theme.borderStrong

            transform: Rotation {
                origin.x: 0.5
                origin.y: clock.c
                angle: index * 30
            }
        }
    }

    component Hand: Rectangle {
        id: hand

        property real length: 40
        property real angle: 0

        x: clock.c - width / 2
        y: clock.c - length
        height: length

        transform: Rotation {
            origin.x: width / 2
            origin.y: length
            angle: hand.angle

            Behavior on angle {
                RotationAnimation {
                    direction: RotationAnimation.Clockwise
                    duration: Anim.base
                    easing.type: Anim.easing
                }
            }
        }
    }

    Hand {
        width: 3
        length: clock.c * 0.5
        angle: (clock.h * 3600 + clock.m * 60 + clock.sec) / 120
        color: Theme.text
    }
    Hand {
        width: 2
        length: clock.c * 0.78
        angle: (clock.m * 60 + clock.sec) / 10
        color: Theme.text
    }
    Hand {
        width: 1
        length: clock.c * 0.86
        angle: clock.sec * 6
        color: Theme.accent
    }

    Rectangle {
        x: clock.c - 3
        y: clock.c - 3
        width: 6
        height: 6
        color: Theme.accent
    }
}
