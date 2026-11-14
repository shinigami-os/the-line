pragma ComponentBehavior: Bound

import QtQuick
import TheLine.Ui
import Quickshell
import Quickshell.Io
import qs.services

// Settings > Sound > Test the speakers / Test the microphone. Speakers: a tone on the left, then on the right, on
// the output in use. Microphone: five seconds recorded from the input in use, then played back on the output in use.
// Enter (or a click) starts it, and stops it again.
Item {
    id: test

    property var setting
    property bool active: false

    signal picked

    readonly property bool speakers: setting?.key === "speakerTest"
    // "" idle, then "left" / "right" (speakers), "record" / "play" (microphone)
    property string step: ""
    readonly property string recording: Quickshell.env("XDG_RUNTIME_DIR") + "/the-line-mic-test.wav"
    property int remaining: 0

    implicitHeight: 34

    readonly property string text: {
        if (step === "left")
            return "Playing on the left…";
        if (step === "right")
            return "Playing on the right…";
        if (step === "record")
            return "Recording, say something… " + remaining + " s";
        if (step === "play")
            return "Playing back what was recorded…";
        if (!speakers && Sound.inputMuted)
            return "The microphone is muted: unmute it first";
        return speakers ? "Play a sound on each side" : "Record 5 seconds and play them back";
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
            step = "record";
            remaining = 5;
            record.running = true;
            tick.restart();
        }
    }

    function stop() {
        step = "";
        tick.stop();
        left.running = false;
        right.running = false;
        record.running = false;
        playback.running = false;
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
    // parecord writes a proper file when it is interrupted (SIGINT)
    Process {
        id: record
        command: ["timeout", "-s", "INT", "5", "parecord", "--channels=1", "--file-format=wav", test.recording]
        onExited: {
            tick.stop();
            if (test.step === "record") {
                test.step = "play";
                playback.running = true;
            }
        }
    }
    Process {
        id: playback
        command: ["paplay", test.recording]
        onExited: {
            if (test.step === "play")
                test.step = "";
            Quickshell.execDetached(["rm", "-f", test.recording]);
        }
    }
    Timer {
        id: tick
        interval: 1000
        repeat: true
        onTriggered: test.remaining = Math.max(0, test.remaining - 1)
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
    }
}
