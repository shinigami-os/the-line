pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import TheLine.Ui
import qs.services

// The login screen. Black; two dials of ticks (minutes, seconds) come out of the left edge and turn with the time,
// read where they cross The Line, which runs across the whole screen at mid-height (an accent marker at each reading
// point). The hour stands on the line inside the dials, like clockwork's; the day and the date past them, the line
// running between the two. On the right: who, and the password typed as accent ticks hanging from the line. Top right:
// the keyboard layout, the session, Reboot, Power off.
//   checking  the dials start to spin while PAM answers
//   refused   they slow down again, the typed ticks drain into their marker in the error colour, the line shakes
//   granted   "shedding": the dials accelerate, and every tick that passes the reading point peels off onto the line
//             and races to the right edge as an accent dash. When the dials are empty the line is accent from edge to
//             edge; it holds a beat, withdraws into both edges, and the session starts (The Line's intro draws it in).
Item {
    id: greeter

    readonly property real s: height / 768
    readonly property real cx: 40 * s
    readonly property real cy: Math.round(height / 2)
    readonly property real minR: 320 * s
    readonly property real secR: 480 * s
    readonly property real rightX: width - 80 * s     // the password's marker

    // The time, smooth, and the dials' extra spin (degrees) from the wind-up.
    property real localMs: 0
    property real spinMin: 0
    property real spinSec: 0
    property real windup: 0          // 0..1
    readonly property real minAngle: -((localMs % 3600000) / 3600000) * 360 - spinMin
    readonly property real secAngle: -((localMs % 60000) / 60000) * 360 - spinSec

    property string buffer: ""
    property real shake: 0
    property bool draining: false
    property bool drainGo: false
    property int drained: 0

    // Shedding: how far each dial has turned since it began, and each tick's distance to the reading point then.
    property bool shedding: false
    property real shedFromMin: 0
    property real shedFromSec: 0
    property var shedAtMin: []
    property var shedAtSec: []
    readonly property real shedMin: shedding ? spinMin - shedFromMin : -1
    readonly property real shedSec: shedding ? spinSec - shedFromSec : -1
    property var dashes: []          // [{ x, v, len }] racing along the line
    property int shedCount: 0
    property real fillRight: 0       // how far the accent has reached to the right (px)
    property real fillLeft: 0        // 0..1 of the way to the left edge, once the dials are empty
    property real reach: 1           // the line, 1 edge to edge, 0 withdrawn
    property real fade: 0            // 0 → 1: everything appears
    property bool done: false

    Component.onCompleted: appear.start()

    NumberAnimation {
        id: appear
        target: greeter
        property: "fade"
        from: 0
        to: 1
        duration: Anim.d(700)
        easing.type: Anim.easing
    }

    function ringAngleAt(i, angle) {
        let a = (i * 6 + angle) % 360;
        if (a < 0)
            a += 360;
        return a;
    }

    function startShedding() {
        const am = [];
        const as = [];
        for (let i = 0; i < 60; i++) {
            am.push(ringAngleAt(i, minAngle));
            as.push(ringAngleAt(i, secAngle));
        }
        shedAtMin = am;
        shedAtSec = as;
        shedFromMin = spinMin;
        shedFromSec = spinSec;
        shedCount = 0;
        fillRight = 0;
        dashes = [];
        shedding = true;
        windAnim.stop();
        windAnim.to = 1;
        windAnim.duration = Anim.d(1500);
        windAnim.easing.type = Easing.InQuad;
        windAnim.start();
    }

    NumberAnimation {
        id: windAnim
        target: greeter
        property: "windup"
    }

    function windTo(value, ms) {
        windAnim.stop();
        windAnim.to = value;
        windAnim.duration = Anim.d(ms);
        windAnim.easing.type = Anim.easing;
        windAnim.start();
    }

    Connections {
        target: Login

        function onPhaseChanged() {
            if (Login.phase === "checking")
                greeter.windTo(0.3, 600);
            else if (Login.phase === "granted")
                greeter.startShedding();
        }
        function onRefusedChanged() {
            greeter.windTo(0, 700);
            greeter.drained = greeter.buffer.length;
            greeter.buffer = "";
            greeter.draining = true;
            drainEnd.restart();
            shakeAnim.restart();
        }
    }

    // Every frame: the time, the spin, the shed ticks and their dashes.
    FrameAnimation {
        running: true
        onTriggered: {
            const d = new Date();
            greeter.localMs = ((d.getHours() * 60 + d.getMinutes()) * 60 + d.getSeconds()) * 1000 + d.getMilliseconds();
            const dt = Math.min(0.05, frameTime);
            const w3 = Math.pow(greeter.windup, 3);
            greeter.spinSec += 2600 * w3 * dt;
            greeter.spinMin += 1500 * w3 * dt;
            if (greeter.shedding)
                greeter.stepShedding(dt);
        }
    }

    function stepShedding(dt) {
        let n = 0;
        for (let i = 0; i < 60; i++) {
            if (shedMin >= shedAtMin[i])
                n++;
            if (shedSec >= shedAtSec[i])
                n++;
        }
        const list = dashes.slice();
        // new dashes, at the reading points: a minute tick leaves from the inner dial, a second tick from the outer
        for (let k = shedCount; k < n; k++) {
            list.push({ x: k % 2 === 0 ? cx + secR : cx + minR, v: 1600 + 2800 * windup + Math.random() * 600,
                len: 18 + 70 * windup });
        }
        shedCount = n;
        const out = [];
        for (const dash of list) {
            dash.x += dash.v * dt;
            if (dash.x - dash.len < width) {
                out.push(dash);
                fillRight = Math.max(fillRight, Math.min(width, dash.x) - (cx + minR));
            } else {
                fillRight = width - (cx + minR);
            }
        }
        dashes = out;
        stream.requestPaint();
        if (n >= 120 && out.length === 0 && !done) {
            done = true;
            fillRight = width;
            finale.start();
        }
    }

    SequentialAnimation {
        id: finale
        NumberAnimation { target: greeter; property: "fillLeft"; from: 0; to: 1; duration: Anim.d(260); easing.type: Anim.easing }
        PauseAnimation { duration: Anim.d(240) }
        NumberAnimation { target: greeter; property: "reach"; from: 1; to: 0; duration: Anim.d(520); easing.type: Easing.InOutQuart }
        PauseAnimation { duration: Anim.d(160) }
        ScriptAction { script: Login.launch() }
    }

    Timer {
        id: drainEnd
        interval: Anim.d(520)
        onTriggered: {
            greeter.draining = false;
            greeter.drainGo = false;
        }
    }
    Timer {
        interval: 20
        running: greeter.draining && !greeter.drainGo
        onTriggered: greeter.drainGo = true
    }
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: greeter; property: "shake"; to: 10; duration: Anim.d(60); easing.type: Easing.OutQuad }
        NumberAnimation { target: greeter; property: "shake"; to: -8; duration: Anim.d(90); easing.type: Easing.InOutQuad }
        NumberAnimation { target: greeter; property: "shake"; to: 4; duration: Anim.d(80); easing.type: Easing.InOutQuad }
        NumberAnimation { target: greeter; property: "shake"; to: 0; duration: Anim.d(110); easing.type: Anim.easing }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    // ------------------------------------------------------------------ keys

    Item {
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (Login.phase !== "") {
                event.accepted = true;
                return;
            }
            const k = event.key;
            const pad = Keypad.digit(event);   // the numpad with NumLock off (cage can't set it) still types digits
            if (pad !== "") {
                greeter.buffer += pad;
            } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                if (greeter.buffer !== "")
                    Login.signIn(greeter.buffer);
            } else if (k === Qt.Key_Backspace) {
                greeter.buffer = event.modifiers & Qt.ControlModifier ? "" : greeter.buffer.slice(0, -1);
            } else if (k === Qt.Key_Escape) {
                if (greeter.buffer === "")
                    Login.leave();   // test mode only
                greeter.buffer = "";
            } else if (k === Qt.Key_Tab || k === Qt.Key_Backtab) {
                Login.nextUser(k === Qt.Key_Backtab ? -1 : 1);
            } else if (k === Qt.Key_F2) {
                Login.nextSession();
            } else if (event.text !== "" && event.text.charCodeAt(0) >= 32) {
                greeter.buffer += event.text;
                if (Login.messageIsError)
                    Login.message = "";
            }
            event.accepted = true;
        }
    }

    // ------------------------------------------------------------------ the dials

    component Dial: Item {
        id: dial

        property real radius
        property real angle
        property real shed: -1           // degrees turned since shedding began (-1: not shedding)
        property var shedAt: []
        property real majorLen
        property real minorLen
        property real labelSize
        property real labelInset

        anchors.fill: parent

        Repeater {
            model: 60

            Item {
                id: tick

                required property int index
                readonly property real deg: dial.angle + index * 6
                readonly property real rad: deg * Math.PI / 180
                readonly property real rel: {
                    let a = deg % 360;
                    if (a > 180)
                        a -= 360;
                    if (a < -180)
                        a += 360;
                    return a;
                }
                readonly property real spot: Math.max(0, 1 - Math.abs(rel) / 4)
                readonly property bool major: index % 5 === 0
                readonly property bool gone: dial.shed >= 0 && dial.shed >= (dial.shedAt[index] ?? 999)
                readonly property real tx: greeter.cx + dial.radius * Math.cos(rad)
                readonly property real ty: greeter.cy + dial.radius * Math.sin(rad)

                visible: tx > -100 && tx < greeter.width + 100 && !gone

                Rectangle {
                    x: tick.tx - width / 2
                    y: tick.ty - height / 2
                    width: tick.major ? 2 : 1
                    height: (tick.major ? dial.majorLen : dial.minorLen) * greeter.s
                    rotation: tick.deg + 90
                    antialiasing: true
                    color: tick.spot > 0 ? Theme.accent : tick.major ? Theme.muted : Theme.borderStrong
                    opacity: tick.spot > 0 ? 1 : tick.major ? 0.7 : 0.8
                }
                Text {
                    visible: tick.major
                    readonly property real r: dial.radius - dial.labelInset * greeter.s
                    x: greeter.cx + r * Math.cos(tick.rad) - width / 2
                    y: greeter.cy + r * Math.sin(tick.rad) - height / 2
                    text: String(tick.index).padStart(2, "0")
                    rotation: tick.deg
                    antialiasing: true
                    font.family: Theme.fontMono
                    font.pixelSize: dial.labelSize * greeter.s
                    font.weight: tick.spot > 0.5 ? Font.DemiBold : Font.Normal
                    color: tick.spot > 0 ? Theme.text : Theme.muted
                    opacity: tick.spot > 0 ? 0.5 + tick.spot * 0.5 : 0.45
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: greeter.fade * (greeter.done ? 0 : 1)

        Behavior on opacity {
            enabled: greeter.done
            NumberAnimation { duration: Anim.d(200) }
        }

        Dial {
            radius: greeter.minR
            angle: greeter.minAngle
            shed: greeter.shedMin
            shedAt: greeter.shedAtMin
            majorLen: 18
            minorLen: 10
            labelSize: 20
            labelInset: 35
        }
        Dial {
            radius: greeter.secR
            angle: greeter.secAngle
            shed: greeter.shedSec
            shedAt: greeter.shedAtSec
            majorLen: 13
            minorLen: 8
            labelSize: 14
            labelInset: 30
        }
    }

    // ------------------------------------------------------------------ the line

    Item {
        id: line
        x: greeter.shake
        y: greeter.cy
        width: greeter.width
        height: 1
        opacity: Math.min(1, greeter.fade * 1.5)

        // drawn from both edges; withdrawn into them at the very end
        Rectangle {
            width: Math.ceil(greeter.width / 2 * greeter.reach)
            height: 1
            color: Theme.borderStrong
        }
        Rectangle {
            x: greeter.width - width
            width: Math.ceil(greeter.width / 2 * greeter.reach)
            height: 1
            color: Theme.borderStrong
        }

        // the accent the dials shed: from the inner reading point to the right, then back to the left edge
        Rectangle {
            visible: greeter.shedding
            x: greeter.cx + greeter.minR
            y: -1
            width: Math.max(0, Math.min(greeter.fillRight, greeter.width / 2 * greeter.reach + greeter.width / 2 - x))
            height: 3
            color: Theme.accent
            opacity: 0.85
        }
        Rectangle {
            visible: greeter.fillLeft > 0
            x: Math.max(greeter.width / 2 * (1 - greeter.reach), (greeter.cx + greeter.minR) * (1 - greeter.fillLeft))
            y: -1
            width: Math.max(0, greeter.cx + greeter.minR - x)
            height: 3
            color: Theme.accent
            opacity: 0.85
        }

        // the reading points, and the password's marker
        Repeater {
            model: [greeter.cx + greeter.minR, greeter.cx + greeter.secR, greeter.rightX]

            Rectangle {
                required property real modelData
                x: modelData - 7
                y: -1
                width: 14
                height: 3
                color: Theme.accent
                opacity: greeter.shedding ? 0 : 1
            }
        }

        // the password: ticks hanging from the line, growing leftwards from the marker
        Repeater {
            model: greeter.draining ? 0 : greeter.buffer.length

            Rectangle {
                required property int index
                x: greeter.rightX + 6 - (greeter.buffer.length - index) * 12
                y: 3
                width: 2
                height: 0
                color: Login.phase === "checking" ? Theme.muted : Theme.accent
                opacity: greeter.shedding ? 0 : 1
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
        Repeater {
            model: greeter.draining ? greeter.drained : 0

            Rectangle {
                required property int index
                x: greeter.drainGo ? greeter.rightX - 1 : greeter.rightX + 6 - (greeter.drained - index) * 12
                y: 3
                width: 2
                height: greeter.drainGo ? 0 : 12
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

    // The dashes racing along the line.
    Canvas {
        id: stream
        y: greeter.cy - 2
        width: greeter.width
        height: 5
        visible: greeter.shedding && !greeter.done

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = Theme.accent;
            for (const dash of greeter.dashes)
                ctx.fillRect(dash.x - dash.len, 1, dash.len, 3);
        }
    }

    // ------------------------------------------------------------------ text

    Item {
        anchors.fill: parent
        opacity: greeter.fade * (greeter.shedding ? 0 : 1)

        Behavior on opacity {
            enabled: greeter.shedding
            NumberAnimation { duration: Anim.d(260) }
        }

        // the hour, standing on the line inside the dials, centred between the screen's edge and the minute dial (the
        // minutes and the seconds are the dials themselves)
        Text {
            id: hour
            x: (greeter.cx + greeter.minR) / 2 - width / 2
            y: greeter.cy - height + 10 * greeter.s
            text: Qt.formatTime(Time.now, "HH")
            font.family: Theme.fontUi
            font.pixelSize: 112 * greeter.s
            font.weight: Font.Light
            color: Theme.text
        }

        // the day and the date past the dials, the line running between them
        Text {
            id: dayName
            x: greeter.cx + greeter.secR + 72 * greeter.s
            y: greeter.cy - height - 10 * greeter.s
            text: Qt.formatDate(Time.now, "dddd").toUpperCase()
            font.family: Theme.fontUi
            font.pixelSize: 20 * greeter.s
            font.weight: Font.DemiBold
            font.letterSpacing: 8 * greeter.s
            color: Theme.text
        }
        Text {
            x: dayName.x
            y: greeter.cy + 12 * greeter.s
            text: Qt.formatDate(Time.now, "dd MMM yyyy").toLowerCase()
            font.family: Theme.fontMono
            font.pixelSize: 12 * greeter.s
            font.letterSpacing: 3 * greeter.s
            color: Theme.muted
        }

        // who: above the line, right-aligned on the password's marker
        Text {
            id: who
            anchors.right: parent.right
            anchors.rightMargin: greeter.width - greeter.rightX - 7 - greeter.shake
            y: greeter.cy - height - 12 * greeter.s
            text: (Login.user?.realName ?? "").toUpperCase()
            font.family: Theme.fontUi
            font.pixelSize: 17 * greeter.s
            font.weight: Font.DemiBold
            font.letterSpacing: 7 * greeter.s
            color: whoHover.hovered ? Theme.accent : Theme.text

            HoverHandler {
                id: whoHover
                cursorShape: Login.users.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
            TapHandler {
                onTapped: Login.nextUser(1)
            }
        }

        // under the ticks: what PAM says, or how to go on
        Text {
            anchors.right: parent.right
            anchors.rightMargin: greeter.width - greeter.rightX - 7
            y: greeter.cy + 30 * greeter.s
            text: Login.message !== "" ? Login.message.toLowerCase()
                : Login.phase === "checking" ? "checking…"
                : greeter.buffer === "" ? (Login.testing ? "test mode: the password is test, esc leaves"
                    : "type your password" + (Login.users.length > 1 ? "   tab: who" : ""))
                : "↵ sign in"
            font.family: Theme.fontMono
            font.pixelSize: 11 * greeter.s
            font.letterSpacing: 1
            color: Login.messageIsError ? Theme.error : Theme.muted
        }

        // top right: the session, and the power
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 80 * greeter.s
            y: 50 * greeter.s
            spacing: 26 * greeter.s

            component Action: Text {
                id: action
                signal clicked
                font.family: Theme.fontMono
                font.pixelSize: 11 * greeter.s
                font.letterSpacing: 2
                color: actionHover.hovered ? Theme.text : Theme.muted

                HoverHandler {
                    id: actionHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: action.clicked()
                }
            }

            // the keyboard the password is typed on (cage takes it from the console's keymap, or the last user's
            // Settings > Input: greeter-env)
            Text {
                visible: text !== ""
                readonly property string layout: Quickshell.env("XKB_DEFAULT_LAYOUT") ?? ""
                text: layout === "" ? "" : layout + (Quickshell.env("XKB_DEFAULT_VARIANT") ? " · " + Quickshell.env("XKB_DEFAULT_VARIANT") : "")
                font.family: Theme.fontMono
                font.pixelSize: 11 * greeter.s
                font.letterSpacing: 2
                color: Theme.borderStrong
            }
            Action {
                visible: Login.sessions.length > 0
                text: (Login.session?.name ?? "").toLowerCase() + (Login.sessions.length > 1 ? "  ·  f2" : "")
                onClicked: Login.nextSession()
            }
            Action {
                text: "reboot"
                onClicked: Login.reboot()
            }
            Action {
                text: "power off"
                onClicked: Login.powerOff()
            }
        }
    }
}
