pragma Singleton

import QtQuick
import Quickshell

// What the demo video's runner (scripts/video) puts on the screen: a caption, and the keys it presses. Nothing is
// shown unless it asks: `qs ipc call line caption "text" 3`, `... keys "SUPER+T"`, `... keycast off`.
Singleton {
    id: root

    property string caption: ""
    property var keys: []               // the caps of the last combo, e.g. ["SUPER", "T"]
    property bool keycast: true

    function say(text, seconds) {
        caption = text;
        captionTimer.interval = Math.max(0.5, seconds) * 1000;
        captionTimer.restart();
    }

    function press(combo) {
        if (!keycast || combo === "")
            return;
        keys = combo.split("+").filter(k => k !== "");
        keysTimer.restart();
    }

    Timer {
        id: captionTimer
        onTriggered: root.caption = ""
    }
    Timer {
        id: keysTimer
        interval: 1500
        onTriggered: root.keys = []
    }
}
