pragma Singleton

import QtQuick
import Quickshell

// Which panel is open, and on which screen. Only one at a time.
Singleton {
    id: root

    property string openPanel: ""   // "" | "tl" | "tc" | "tr"
    property string openScreen: ""

    // The screens the clipboard history and the emoji picker are open on ("" for closed).
    property string clipScreen: ""
    property string emojiScreen: ""
    // The screen the viewer of every app (SUPER+SHIFT+A) is open on.
    property string appsScreen: ""
    // Coming back from the lock: the unlock curtain plays on every screen (modules/lock/UnlockCurtain.qml).
    property bool unlocking: false

    // The screen the wallpaper picker (SUPER+T) is open on.
    property string wallScreen: ""

    // The screen the power menu is open on ("" for closed), and the action it opens on.
    property string powerScreen: ""
    property int powerSelected: 0

    // An area screenshot is being selected: the screens show their frozen capture.
    property bool frozen: false

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
