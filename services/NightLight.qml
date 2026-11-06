pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Night light through hyprsunset, if it is installed.
Singleton {
    id: root

    property bool on: false
    property bool available: true
    readonly property int temperature: 4000

    readonly property string label: !available ? "not installed" : (on ? "on · " + temperature + " K" : "off")

    function toggle() {
        if (available)
            on = !on;
    }

    Process {
        command: ["hyprsunset", "-t", String(root.temperature)]
        running: root.on
        onExited: code => {
            if (code !== 0 && root.on) {
                root.on = false;
                root.available = false;
            }
        }
    }
}
