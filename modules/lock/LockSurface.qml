pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// One screen of the lock (LockScreen). The line across the middle, the time above it, who and the date below; the
// password is typed as accent ticks hanging from the line, from the marker outwards.
//   locking    it starts from what was on the screen (Lock's capture) with its own line over the real one at the
//              top; the capture melts into the blurred wallpaper while the line glides down to the middle, then
//              the time rises in.
//   refused    the ticks turn to the error colour and drain into the marker; the line shakes once.
//   unlocking  the accent runs out along the line from the marker to both edges, everything else leaves; the
//              shell's own UnlockCurtain takes over from this exact frame.
Item {
    id: surface

    required property string screenName

    readonly property real midY: Math.round(height / 2)
    // 0 at the top (where the real line is), 1 in the middle
    property real glide: 0
    readonly property real lineY: Math.round(10 + (midY - 10) * glide)
    readonly property bool settled: glide === 1
    readonly property bool unlocking: Lock.phase === "unlocking"

    property real shake: 0
    property bool draining: false
    property bool drainGo: false
    property real fill: 0       // the accent run on unlocking, 0..1 of each half

    Component.onCompleted: glideIn.start()

    NumberAnimation {
        id: glideIn
        target: surface
        property: "glide"
        from: 0
        to: 1
        duration: Anim.d(700)
        easing.type: Anim.easing
    }

    Connections {
        target: Lock

        function onRefusedChanged() {
            surface.draining = true;
            drainEnd.restart();
            shakeAnim.restart();
        }
        function onPhaseChanged() {
            if (Lock.phase === "unlocking")
                fillAnim.restart();
        }
    }
    Timer {
        id: drainEnd
        interval: Anim.d(520)
        onTriggered: {
            surface.draining = false;
            surface.drainGo = false;
        }
    }
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: surface; property: "shake"; to: 9; duration: Anim.d(60); easing.type: Easing.OutQuad }
        NumberAnimation { target: surface; property: "shake"; to: -7; duration: Anim.d(90); easing.type: Easing.InOutQuad }
        NumberAnimation { target: surface; property: "shake"; to: 4; duration: Anim.d(80); easing.type: Easing.InOutQuad }
        NumberAnimation { target: surface; property: "shake"; to: 0; duration: Anim.d(110); easing.type: Anim.easing }
    }
    NumberAnimation {
        id: fillAnim
        target: surface
        property: "fill"
        from: 0
        to: 1
        duration: Anim.d(380)
        easing.type: Anim.easing
    }

    LockBackdrop {
        anchors.fill: parent
        screenName: surface.screenName
    }

    // What was on the screen when it locked: the line pulls the night down over it, and what is left below the line
    // melts away on the way.
    Item {
        y: surface.lineY
        width: surface.width
        height: surface.height - surface.lineY
        clip: true
        opacity: Math.max(0, 1 - surface.glide * 1.3)
        visible: opacity > 0

        Image {
            y: -surface.lineY
            width: surface.width
            height: surface.height
            source: Lock.captureOf(surface.screenName)
            asynchronous: false
            cache: false
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                Lock.submit();
            else if (event.key === Qt.Key_Backspace)
                Lock.erase(event.modifiers & Qt.ControlModifier);
            else if (event.key === Qt.Key_Escape)
                Lock.erase(true);
            else if (event.text !== "" && event.text.charCodeAt(0) >= 32)
                Lock.type(event.text);
            event.accepted = true;
        }
    }

    // The line.
    Item {
        x: surface.shake
        y: surface.lineY
        width: surface.width
        height: 1

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.borderStrong
        }

        // Unlocking: the accent runs out from the marker to both edges.
        Rectangle {
            x: surface.width / 2 - width
            y: -1
            width: surface.width / 2 * surface.fill
            height: 3
            color: Theme.accent
        }
        Rectangle {
            x: surface.width / 2
            y: -1
            width: surface.width / 2 * surface.fill
            height: 3
            color: Theme.accent
        }

        // The marker.
        Rectangle {
            x: surface.width / 2 - 7
            y: -1
            width: 14
            height: 3
            color: Theme.accent
        }

        // The password: one tick per character, centred on the marker, growing both ways.
        Repeater {
            model: surface.draining ? 0 : Lock.buffer.length

            Rectangle {
                required property int index
                readonly property int count: Lock.buffer.length
                readonly property real gap: 12

                x: surface.width / 2 + (index - (count - 1) / 2) * gap - 1
                y: 3
                width: 2
                height: 0
                color: Lock.waiting ? Theme.muted : Theme.accent
                opacity: surface.unlocking ? 0 : 1

                Component.onCompleted: height = 12

                Behavior on x {
                    NumberAnimation { duration: Anim.base; easing.type: Anim.easing }
                }
                Behavior on height {
                    NumberAnimation { duration: Anim.base; easing.type: Anim.easing }
                }
                Behavior on opacity {
                    NumberAnimation { duration: Anim.exitFade }
                }
            }
        }

        // Refused: the ticks that were there, in the error colour, drawn into the marker.
        Repeater {
            model: surface.draining ? drained.count : 0

            Rectangle {
                required property int index

                x: surface.drainGo ? surface.width / 2 - 1 : surface.width / 2 + (index - (drained.count - 1) / 2) * 12 - 1
                y: 3
                width: 2
                height: surface.drainGo ? 0 : 12
                color: Theme.error

                Behavior on x {
                    NumberAnimation { duration: Anim.d(420); easing.type: Anim.easing }
                }
                Behavior on height {
                    NumberAnimation { duration: Anim.d(420); easing.type: Anim.easing }
                }
            }
        }
    }

    // How many ticks were there when the password was refused (the buffer is empty by then).
    QtObject {
        id: drained
        property int count: 0
    }
    Connections {
        target: Lock
        function onBufferChanged() {
            if (Lock.buffer !== "")
                drained.count = Lock.buffer.length;
        }
    }
    // drawn where they were first, then sent into the marker
    Timer {
        interval: 20
        running: surface.draining && !surface.drainGo
        onTriggered: surface.drainGo = true
    }

    // The time, standing on the line.
    Text {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        y: surface.lineY - height - 22 + (shown ? 0 : 10)
        readonly property bool shown: surface.settled && !surface.unlocking
        text: Qt.formatTime(Time.now, "HH:mm")
        font.family: Theme.fontUi
        font.pixelSize: 112
        font.weight: Font.Light
        color: Theme.text
        opacity: shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: clock.shown ? Anim.d(420) : Anim.exitFade; easing.type: Anim.easing }
        }
        Behavior on y {
            enabled: surface.settled
            NumberAnimation { duration: Anim.d(420); easing.type: Anim.easing }
        }
    }

    // Who, the date, and what PAM says (howdy looking, a refused password).
    Column {
        id: below
        anchors.horizontalCenter: parent.horizontalCenter
        y: surface.lineY + 34
        spacing: 10
        readonly property bool shown: surface.settled && !surface.unlocking
        opacity: shown ? 1 : 0

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: below.shown ? Anim.d(160) : 0 }
                NumberAnimation { duration: below.shown ? Anim.d(420) : Anim.exitFade }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Session.user + "  ·  " + Qt.formatDate(Time.now, "dddd d MMMM").toLowerCase()
            font.family: Theme.fontMono
            font.pixelSize: 12
            color: Theme.muted
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Lock.testSeconds > 0 ? "test lock · opens by itself" : Lock.message.toLowerCase()
            font.family: Theme.fontMono
            font.pixelSize: 11
            color: Lock.messageIsError ? Theme.error : Theme.muted
            opacity: text !== "" ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: Anim.base }
            }
        }
    }
}
