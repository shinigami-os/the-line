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
    readonly property bool watching: Hyprland.workspaces.values.some(w => w.hasFullscreen)

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
