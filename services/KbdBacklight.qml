pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The keyboard backlight, if the laptop exposes one (a "*kbd_backlight*" LED for brightnessctl).
// Its keys (XF86KbdBrightnessUp/Down) step it and show it on the line; without one they do nothing.
Singleton {
    id: root

    property string device: ""
    property real value: 0   // 0..1
    property int max: 0

    readonly property bool available: device !== ""

    // One step = one level on keyboards with a few levels, else the level step from the config.
    function step(direction) {
        if (!available)
            return;
        const stepValue = max <= 10 ? 1 / max : Config.levelStep / 100;
        value = Math.max(0, Math.min(1, value + direction * stepValue));
        setter.command = ["brightnessctl", "-q", "-d", device, "set", Math.round(value * max).toString()];
        setter.running = true;
        LineState.showGauge("kbd", value);
    }

    Process {
        id: finder
        running: true
        command: ["brightnessctl", "-l", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                // device,class,current,percent,max
                const line = text.split("\n").find(l => /kbd_backlight/.test(l.split(",")[0] ?? ""));
                if (!line)
                    return;
                const f = line.split(",");
                root.device = f[0];
                root.max = Number(f[4]) || 0;
                root.value = root.max > 0 ? Number(f[2]) / root.max : 0;
            }
        }
    }

    Process {
        id: setter
    }
}
