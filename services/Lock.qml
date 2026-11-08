pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// The lock screen's state (modules/lock). lock(): every screen is captured first (uncompressed, ~70 ms), so the lock
// can start from what was on it, then the session lock is taken. PAM runs as soon as it is up: with face sign-in on, howdy tries
// first and says so; then it asks for the password, typed on the line.
//   phase  ""  →  "locking" (the line glides down)  →  "locked"  →  "unlocking" (accent fills the line)  →  ""
// While locked, $XDG_RUNTIME_DIR/the-line/locked exists: a shell that starts again after a crash locks again at once
// (Hyprland keeps the session locked meanwhile: misc:allow_session_lock_restore).
Singleton {
    id: root

    property bool locked: false
    property string phase: ""
    property string buffer: ""
    property string message: ""       // from PAM (howdy: "Identifying you…"), or after a failure
    property bool messageIsError: false
    property int failures: 0
    property bool waiting: false      // the password is out, PAM hasn't answered yet
    // Bumped at each wrong password, for the surfaces to drain their ticks and shake the line.
    property int refused: 0
    // Seconds before a test lock opens by itself (lockTest); 0 = a real lock.
    property int testSeconds: 0

    readonly property string stateDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/the-line"
    readonly property string marker: stateDir + "/locked"
    readonly property string captureDir: stateDir + "/lock-capture"

    // The capture of a screen taken just before locking ("" when there is none).
    property var captured: ({})

    function captureOf(screen) {
        return captured[screen] ? "file://" + captureDir + "/" + screen + ".ppm" : "";
    }

    function lock() {
        if (locked || capture.running)
            return;
        testSeconds = 0;
        capture.screens = Quickshell.screens.map(s => s.name);
        capture.running = true;
        captureTimeout.restart();
    }

    function lockTest(seconds) {
        lock();
        testSeconds = Math.max(5, seconds);
    }

    // After the capture (or without it, if it is slow: before a suspend there is no time to wait).
    function engage() {
        if (locked)
            return;
        captureTimeout.stop();
        buffer = "";
        message = "";
        messageIsError = false;
        failures = 0;
        waiting = false;
        phase = "locking";
        locked = true;
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && : > \"$2\"", "sh", stateDir, marker]);
        startPam.restart();
        if (testSeconds > 0)
            testTimer.restart();
    }

    function type(text) {
        if (phase === "unlocking" || waiting)
            return;
        buffer += text;
        if (messageIsError) {
            message = "";
            messageIsError = false;
        }
    }

    function erase(all) {
        if (phase === "unlocking" || waiting)
            return;
        buffer = all ? "" : buffer.slice(0, -1);
    }

    function submit() {
        if (phase === "unlocking" || waiting || buffer === "")
            return;
        if (pam.responseRequired) {
            waiting = true;
            pam.respond(buffer);
        } else {
            // howdy still looking: the password waits for PAM's question (pamMessage below)
            waiting = true;
        }
    }

    // The way out (PAM said yes): the surfaces fill the line, then the curtain takes over (UnlockCurtain).
    function succeed() {
        waiting = false;
        phase = "unlocking";
        testTimer.stop();
        release.restart();
    }

    // The lock is let go once the shell's own surface draws the same frame under it (UnlockCurtain).
    Timer {
        id: release
        interval: Anim.d(420)
        onTriggered: {
            UiState.unlocking = true;
            releaseLate.restart();
        }
    }
    Timer {
        id: releaseLate
        interval: 60
        onTriggered: {
            root.locked = false;
            root.phase = "";
            root.buffer = "";
            Quickshell.execDetached(["rm", "-f", root.marker]);
        }
    }

    Timer {
        id: testTimer
        interval: root.testSeconds * 1000
        onTriggered: {
            if (pam.active)
                pam.abort();
            root.succeed();
        }
    }

    Timer {
        id: startPam
        interval: 50
        onTriggered: if (root.locked && !pam.active) pam.start()
    }

    Timer {
        id: settle
        interval: Anim.d(900)
        running: root.phase === "locking"
        onTriggered: if (root.phase === "locking") root.phase = "locked"
    }

    PamContext {
        id: pam

        // /etc/pam.d/hyprlock for now: the face toggle in Settings > Sign-in edits that one
        config: "hyprlock"

        onPamMessage: {
            if (responseRequired) {
                // a password typed while howdy was still looking goes out now
                if (root.waiting && root.buffer !== "")
                    respond(root.buffer);
                return;
            }
            root.message = message;
            root.messageIsError = messageIsError;
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.succeed();
                return;
            }
            root.waiting = false;
            root.failures++;
            root.buffer = "";
            root.message = "not this one";
            root.messageIsError = true;
            root.refused++;
            if (root.locked)
                startPam.restart();
        }
        onError: err => {
            root.waiting = false;
            root.message = "something went wrong, try again";
            root.messageIsError = true;
            if (root.locked)
                startPam.restart();
        }
    }

    Process {
        id: capture

        property var screens: []

        command: ["sh", "-c", "mkdir -p \"$1\" && rm -f \"$1\"/*; d=$1; shift; for o; do grim -t ppm -o \"$o\" \"$d/$o.ppm\" & done; wait",
            "sh", root.captureDir].concat(screens)
        onExited: {
            const c = {};
            for (const s of capture.screens)
                c[s] = true;
            root.captured = c;
            root.engage();
        }
    }
    Timer {
        id: captureTimeout
        interval: 250
        onTriggered: {
            root.captured = {};
            root.engage();
        }
    }

    // Locked when the shell went down: lock again at once (no capture: the screens show the old lock's frame).
    Process {
        running: true
        command: ["test", "-e", root.marker]
        onExited: code => {
            if (code === 0) {
                root.captured = {};
                root.engage();
            }
        }
    }
}
