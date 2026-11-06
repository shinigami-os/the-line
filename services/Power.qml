pragma Singleton

import QtQuick
import Quickshell

// Session and power actions. They live only in the quick settings panel.
Singleton {
    function lock() {
        Quickshell.execDetached(["hyprlock"]);
    }

    function logout() {
        Quickshell.execDetached(["hyprctl", "dispatch", "exit"]);
    }

    function restart() {
        Quickshell.execDetached(["loginctl", "reboot"]);
    }

    function poweroff() {
        Quickshell.execDetached(["loginctl", "poweroff"]);
    }
}
