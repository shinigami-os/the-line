pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Session and power actions. They live only in the quick settings panel.
Singleton {
    function lock() {
        Quickshell.execDetached(["hyprlock"]);
    }

    function logout() {
        Hyprland.dispatch("hl.dsp.exit()");   // Hyprland 0.55 Lua dispatcher
    }

    function restart() {
        Quickshell.execDetached(["loginctl", "reboot"]);
    }

    function poweroff() {
        Quickshell.execDetached(["loginctl", "poweroff"]);
    }
}
