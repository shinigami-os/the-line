pragma Singleton

import QtQuick
import TheLine.Ui
import Quickshell
import Quickshell.Io

// The greeter's settings: the accent and the motion of the last user who signed in, read from their
// ~/.config/the-line/config.json (readable by greetd's user); Kira violet and the default motion otherwise.
// Theme.qml and Anim.qml (shared with the shell) read these.
Singleton {
    id: root

    property string accent: "#9A5CFF"
    property bool reduceMotion: false
    property real motionScale: 1.0

    // The last user's home: Login knows who it was.
    property string home: ""

    FileView {
        path: root.home !== "" ? root.home + "/.config/the-line/config.json" : ""
        printErrors: false
        onLoaded: {
            try {
                const c = JSON.parse(text());
                if (/^#[0-9a-f]{6}$/i.test(c.accent ?? ""))
                    root.accent = c.accent;
                root.reduceMotion = c.reduceMotion === true;
                if (typeof c.motionScale === "number" && c.motionScale > 0)
                    root.motionScale = c.motionScale;
            } catch (e) {}
        }
    }
}
