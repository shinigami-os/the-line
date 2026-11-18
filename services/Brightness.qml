pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import TheLine.Core

// Backlight level. Read from sysfs by TheLine.Core's BacklightReader (a thread of its own, no process per second, and
// not at all while the screen is locked), so changes made elsewhere (media keys) also show on the line. Setting goes
// through brightnessctl.
Singleton {
    id: root

    property real value: 0   // 0..1
    property bool armed: false

    function set(level) {
        const v = Math.max(0.01, Math.min(1, level));
        value = v;
        reader.expect(v);
        setter.command = ["brightnessctl", "-q", "set", Math.round(v * 100) + "%"];
        setter.running = true;
    }

    onValueChanged: if (armed) LineState.showGauge("bri", value)

    function step(direction) {
        set(value + direction * Config.levelStep / 100);
        LineState.showGauge("bri", value);
    }

    BacklightReader {
        id: reader
        active: !Lock.locked
        // what the hardware says while a set is still on its way is the old level
        onValueChanged: if (!setter.running) root.value = reader.value
    }

    Process {
        id: setter
    }

    // Ignore the first reading.
    Timer {
        running: true
        interval: 2500
        onTriggered: root.armed = true
    }
}
