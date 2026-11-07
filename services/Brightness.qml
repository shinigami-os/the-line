pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Backlight level through brightnessctl. Polled, so changes made elsewhere (media keys) also show on the line.
Singleton {
    id: root

    property real value: 0   // 0..1
    property bool armed: false

    function set(level) {
        const v = Math.max(0.01, Math.min(1, level));
        value = v;
        setter.command = ["brightnessctl", "-q", "set", Math.round(v * 100) + "%"];
        setter.running = true;
    }

    onValueChanged: if (armed) LineState.showGauge("bri", value)

    function step(direction) {
        set(value + direction * Config.levelStep / 100);
        LineState.showGauge("bri", value);
    }

    Process {
        id: getter
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                // device,class,current,percent,max
                const f = text.trim().split(",");
                if (f.length >= 5 && Number(f[4]) > 0) {
                    const v = Number(f[2]) / Number(f[4]);
                    if (Math.abs(v - root.value) > 0.004)
                        root.value = v;
                }
            }
        }
    }

    Process {
        id: setter
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 1000
        onTriggered: if (!getter.running) getter.running = true
    }

    // Ignore the first reading.
    Timer {
        running: true
        interval: 2500
        onTriggered: root.armed = true
    }
}
