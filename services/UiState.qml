pragma Singleton

import QtQuick
import Quickshell

// Which panel is open, and on which screen. Only one at a time.
Singleton {
    id: root

    property string openPanel: ""   // "" | "tl" | "tc" | "tr"
    property string openScreen: ""

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
