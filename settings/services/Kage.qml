pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Settings > Displays > Decoy screen: kagemusha (`kage`), which makes every app see a bigger screen than the real one
// and scales it down onto the panel. Off unless the user turns it on; it is not saved: `kage up` is a session thing.
Singleton {
    id: root

    property bool installed: false
    property string size: "off"       // "off", or the decoy's size as kage reports it: "2560x1440@60"
    property bool busy: false

    readonly property var sizes: ["2560x1440@60", "3840x2160@60", "5120x2880@60"]

    function refresh() {
        status.running = true;
    }

    // Registry rows: "size". `kage up` wants a real output to mirror: the screen picked in the Displays section.
    function set(key, v) {
        if (busy)
            return;
        if (!installed) {
            Displays.error = "kagemusha is not installed: flux install kira-kagemusha";
            return;
        }
        busy = true;
        run.command = v === "off" ? ["kage", "down"] : ["kage", "up", String(v), "--on", Displays.current?.name ?? Displays.main];
        run.running = true;
    }

    Component.onCompleted: which.running = true

    Process {
        id: which
        command: ["sh", "-c", "command -v kage"]
        onExited: code => {
            root.installed = code === 0;
            if (root.installed)
                root.refresh();
        }
    }

    Process {
        id: status
        command: ["kage", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/^up: (\S+)/);
                root.size = m ? m[1] : "off";
            }
        }
    }

    Process {
        id: run
        stderr: StdioCollector {
            onStreamFinished: Displays.error = text.trim() !== "" ? text.trim().split("\n").pop() : ""
        }
        onExited: {
            root.busy = false;
            root.refresh();
        }
    }
}
