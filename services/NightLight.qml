pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Night light through hyprsunset, if it is installed. Warmth and schedule from Settings > Night light: with the
// schedule on, it turns itself on at its start and off at its end; the button still works in between.
Singleton {
    id: root

    property bool on: false
    property bool available: true
    readonly property int temperature: Config.nightTemp
    readonly property bool scheduled: Config.nightScheduled && Config.within(Config.nightFrom, Config.nightTo, Time.now)

    readonly property string label: !available ? "not installed" : (on ? "on · " + temperature + " K" : "off")

    function toggle() {
        if (available)
            on = !on;
    }

    // Only when the schedule crosses one of its ends (or is turned on): a press of the button in between stays.
    onScheduledChanged: on = scheduled
    Component.onCompleted: if (scheduled) on = true

    // A new warmth while on: hyprsunset is started again with it.
    property bool restarting: false
    onTemperatureChanged: {
        if (on) {
            restarting = true;
            restart.restart();
        }
    }
    Timer {
        id: restart
        interval: 300
        onTriggered: root.restarting = false
    }

    Process {
        command: ["hyprsunset", "-t", String(root.temperature)]
        running: root.on && !root.restarting
        onExited: code => {
            if (code !== 0 && root.on && !root.restarting) {
                root.on = false;
                root.available = false;
            }
        }
    }
}
