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
    property var overviews: ({})        // screen name -> its open WorkspaceOverview (it registers itself)

    // Where a cell (win < 0) or a window of the workspace overview is, "x,y" in the screen's pixels; "" if it is not open.
    function overviewPoint(screen, n, win) {
        return overviews[screen]?.pointOf(n, win) ?? "";
    }

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
