pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The music visualiser on the line (SUPER+M, or the button in the music panel): cava's frequency bars, 0..1 each,
// lowest first. Off by default and off again at each login: the state lives in $XDG_RUNTIME_DIR (emptied at
// logout), so a shell restart keeps it. cava runs only while it is on, with its own config (raw output, ascii).
Singleton {
    id: root

    readonly property int count: 64
    property bool on: false
    property var bars: []
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
        if (!on)
            bars = [];
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

    Process {
        id: cava
        running: root.on
        command: ["sh", "-c", "mkdir -p \"$1\" && cat > \"$2\" <<EOF\n"
            + "[general]\nbars = " + root.count + "\nframerate = 60\nautosens = 1\nlower_cutoff_freq = 40\nhigher_cutoff_freq = 12000\n"
            + "[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 1000\nbar_delimiter = 59\nframe_delimiter = 10\n"
            + "[smoothing]\nnoise_reduction = 0.7\nmonstercat = 1\n"
            + "EOF\nexec cava -p \"$2\"", "sh", root.stateDir, root.confFile]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";");
                const out = new Array(root.count);
                for (let i = 0; i < root.count; i++)
                    out[i] = Math.min(1, (Number(parts[i]) || 0) / 1000);
                root.bars = out;
            }
        }
        onExited: root.bars = []
    }
}
