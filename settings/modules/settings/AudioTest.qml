pragma ComponentBehavior: Bound

import QtQuick
import TheLine.Ui
import Quickshell
import Quickshell.Io
import qs.services

// Settings > Sound > Test the speakers / Test the microphone. Speakers: a tone on the left, then on the right, on
// the output in use. Microphone: a live level bar of the input in use (as in chat apps).
// Enter (or a click) starts it, and stops it again.
Item {
    id: test

    property var setting
    property bool active: false

    signal picked

    readonly property bool speakers: setting?.key === "speakerTest"
    // "" idle, then "left" / "right" (speakers) or "listen" (microphone)
    property string step: ""
    // the microphone's level, 0..1, as it is heard now, and the loudest of the last moments
    property real level: 0
    property real peak: 0

    implicitHeight: 34

    readonly property string text: {
        if (step === "left")
            return "Playing on the left…";
        if (step === "right")
            return "Playing on the right…";
        if (step === "listen")
            return "Say something…";
        if (!speakers && Sound.inputMuted)
            return "The microphone is muted: unmute it first";
        return speakers ? "Play a sound on each side" : "Show what the microphone hears";
    }

    function tone(side) {
        // a 440 Hz tone on one side only, moderate
        return "av://lavfi:sine=frequency=440:duration=1.2,volume=0.35,pan=stereo|c0=" + (side === "left" ? "c0|c1=0*c0" : "0*c0|c1=c0");
    }

    function start() {
        if (step !== "")
            return stop();
        if (speakers) {
            step = "left";
            left.running = true;
        } else if (!Sound.inputMuted) {
            step = "listen";
            meter.running = true;
        }
    }

    function stop() {
        step = "";
        level = 0;
        peak = 0;
        left.running = false;
        right.running = false;
        meter.running = false;
    }

    function key(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            start();
            return true;
        }
        return false;
    }

    Process {
        id: left
        command: ["mpv", "--no-config", "--no-video", "--really-quiet", test.tone("left")]
        onExited: {
            if (test.step === "left") {
                test.step = "right";
                right.running = true;
            }
        }
    }
    Process {
        id: right
        command: ["mpv", "--no-config", "--no-video", "--really-quiet", test.tone("right")]
        onExited: if (test.step === "right")
            test.step = ""
    }

    // The input in use, 8 kHz mono, in blocks of 40 ms; one line per block: its level, 0 to 100, above the room's own
    // noise (the quietest of the last moments, which rises slowly), up to -8 dB.
    Process {
        id: meter
        command: ["sh", "-c", "parec --raw --format=s16le --rate=8000 --channels=1 --latency-msec=40 | python3 -u -c '"
            + "import sys,array,math\n"
            + "f=None\n"
            + "while True:\n"
            + " b=sys.stdin.buffer.read(640)\n"
            + " if len(b)<640: break\n"
            + " a=array.array(\"h\",b)\n"
            + " m=sum(a)/len(a)\n"
            + " r=math.sqrt(sum((x-m)**2 for x in a)/len(a))/32768\n"
            + " d=20*math.log10(r) if r>0 else -90\n"
            + " f=d if f is None else min(f+0.02,d)\n"
            + " print(int(max(0,min(100,(d-f)/max(10,-8-f)*100))))\n"
            + "'"]
        stdout: SplitParser {
            onRead: line => {
                const v = parseInt(line) / 100;
                // quick to rise, slow to fall
                test.level = v > test.level ? v : test.level * 0.7 + v * 0.3;
                test.peak = Math.max(v, test.peak - 0.01);
            }
        }
        onExited: if (test.step === "listen")
            test.stop()
    }

    ListLine {
        width: test.width
        name: test.text
        trailing: test.step === "" ? "Enter" : "Enter stops"
        trailingColor: test.step === "" ? Theme.muted : Theme.accent
        lit: test.step !== ""
        under: test.active
        onClicked: {
            test.picked();
            test.start();
        }

        // the level bar: the sound as it is now, a tick on the loudest of the last moments
        Item {
            visible: test.step === "listen"
            width: 260
            height: 10

            Rectangle {
                anchors.fill: parent
                color: Theme.surface
                border.width: 1
                border.color: Theme.border
            }
            Rectangle {
                x: 1
                y: 1
                width: Math.max(0, (parent.width - 2) * test.level)
                height: parent.height - 2
                color: test.level > 0.92 ? Theme.error : Theme.accent
            }
            Rectangle {
                x: 1 + (parent.width - 3) * test.peak
                y: 1
                width: 2
                height: parent.height - 2
                color: Theme.text
                visible: test.peak > 0.02
            }
        }
    }
}
