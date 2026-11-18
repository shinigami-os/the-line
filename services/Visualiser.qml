pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import TheLine.Core

// The music visualiser on the line (SUPER+M, or the button in the music panel): cava's frequency bars, 0..1 each,
// lowest first. Off by default and off again at each login: the state lives in $XDG_RUNTIME_DIR (emptied at
// logout), so a shell restart keeps it. cava runs only while it is on, with its own config (raw output, ascii).
Singleton {
    id: root

    readonly property int count: 64
    property bool on: false
    readonly property var bars: cava.bars
    readonly property bool installed: which.found

    readonly property string stateDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/the-line"
    readonly property string stateFile: stateDir + "/visualiser"
    readonly property string confFile: stateDir + "/cava.conf"

    function toggle() {
        set(!on);
    }

    function set(value) {
        on = value && installed;
        Quickshell.execDetached(["sh", "-c", on ? "mkdir -p \"$1\" && : > \"$2\"" : "rm -f \"$2\"", "sh", stateDir, stateFile]);
    }

    // On again after a shell restart, if it was on in this session.
    Process {
        id: which
        property bool found: false
        running: true
        command: ["sh", "-c", "command -v cava >/dev/null && echo cava; [ -e \"$1\" ] && echo on", "sh", root.stateFile]
        stdout: StdioCollector {
            onStreamFinished: {
                which.found = text.includes("cava");
                root.on = which.found && text.includes("on");
            }
        }
    }

    // cava runs (and its lines are read) on TheLine.Core's thread, only while it is on and the screen is unlocked.
    CavaReader {
        id: cava
        count: root.count
        confFile: root.confFile
        running: root.on && !Lock.locked
    }
}
