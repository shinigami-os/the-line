pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Session and power actions: the quick settings power row and the power menu (CTRL+ALT+Delete, the power button).
Singleton {
    function lock() {
        Quickshell.execDetached(["hyprlock"]);
    }

    function logout() {
        Hyprland.dispatch("hl.dsp.exit()");   // Hyprland 0.55 Lua dispatcher
    }

    function suspend() {
        Quickshell.execDetached(["loginctl", "suspend"]);
    }

    function restart() {
        Quickshell.execDetached(["loginctl", "reboot"]);
    }

    function poweroff() {
        Quickshell.execDetached(["loginctl", "poweroff"]);
    }
}
