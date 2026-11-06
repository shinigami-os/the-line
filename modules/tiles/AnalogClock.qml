import QtQuick
import qs.services

// Flat analog clock: twelve ticks and three hands, no face, no round edges.
// Angles come from a monotonic seconds count so the hands never spin backwards at midnight.
Item {
    id: clock

    property real size: 140

    readonly property real localSeconds: Time.now.getTime() / 1000 - Time.now.getTimezoneOffset() * 60
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
                NumberAnimation { duration: Anim.base; easing.type: Anim.easing }
            }
        }
    }

    Hand {
        width: 3
        length: clock.c * 0.5
        angle: clock.localSeconds / 120
        color: Theme.text
    }
    Hand {
        width: 2
        length: clock.c * 0.78
        angle: clock.localSeconds / 10
        color: Theme.text
    }
    Hand {
        width: 1
        length: clock.c * 0.86
        angle: clock.localSeconds * 6
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
