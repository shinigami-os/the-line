pragma Singleton

import QtQuick
import Quickshell

// Which panel is open, and on which screen. Only one at a time.
Singleton {
    id: root

    property string openPanel: ""   // "" | "tl" | "tc" | "tr"
    property string openScreen: ""

    // The screen the cheat sheet is open on ("" for closed).
    property string sheetScreen: ""
    property int sheetTab: 0   // the tab it opens on

    // Hyprland's resize mode (SUPER+R) is on.
    property bool resizing: false

    // The launcher's search text (one launcher is open at a time).
    property string launcherQuery: ""

    function isOpen(screenName, panel) {
        return openPanel === panel && openScreen === screenName;
    }

    function toggle(screenName, panel) {
        if (isOpen(screenName, panel)) {
            close();
        } else {
            openPanel = panel;
            openScreen = screenName;
        }
    }

    function close() {
        openPanel = "";
        openScreen = "";
    }
}
