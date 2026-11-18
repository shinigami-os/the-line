pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Where the pointer is, in Hyprland's layout pixels, asked over Hyprland's socket every 100 ms, and only while a
// workspace shows a fullscreen window. Over a fullscreen window Hyprland sends the shell's surface clicks but no
// pointer motion, so the fullscreen peek (TheLine) can't rely on hovering; it reads this instead.
Singleton {
    id: root

    property real x: -1
    property real y: -1
    // Only a workspace on show with a real fullscreen window (mode 2: a maximized one, mode 1, counts as "fullscreen" too).
    readonly property bool watching: Hyprland.monitors.values.some(m => {
        const ws = m.activeWorkspace;
        return (ws?.hasFullscreen ?? false) && ws.toplevels.values.some(t => (t.lastIpcObject?.fullscreen ?? 2) === 2);
    })

    property string reply: ""

    Timer {
        running: root.watching
        repeat: true
        interval: 100
        onTriggered: {
            if (!sock.connected)
                sock.connected = true;
        }
    }

    Socket {
        id: sock

        path: Quickshell.env("XDG_RUNTIME_DIR") + "/hypr/" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "/.socket.sock"
        onConnectedChanged: {
            if (connected) {
                root.reply = "";
                write("j/cursorpos");
                flush();
            }
        }
        // the whole answer in: read it and hang up first (Hyprland hanging up is reported as an error)
        parser: SplitParser {
            onRead: data => {
                root.reply += data;
                if (!root.reply.includes("}"))
                    return;
                try {
                    const p = JSON.parse(root.reply);
                    root.x = p.x;
                    root.y = p.y;
                } catch (e) {}
                sock.connected = false;
            }
        }
    }
}
