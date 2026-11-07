import QtQuick
import qs.services

// Flat analog clock: twelve ticks and three hands, no face, no round edges.
// Angles stay within 0-360 (large angles lose precision in the transform and the hands freeze); the rotation
// always turns clockwise, so a hand passing 12 never spins backwards.
Item {
    id: clock

    property real size: 140

    readonly property int h: Time.now.getHours() % 12
    readonly property int m: Time.now.getMinutes()
    readonly property int sec: Time.now.getSeconds()
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
