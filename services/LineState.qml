pragma Singleton

import QtQuick
import Quickshell

// Events that play out on the line: the level gauge and the notification pulse.
Singleton {
    id: root

    property string gaugeKind: ""   // "" | "vol" | "bri"
    property real gaugeValue: 0     // 0..1, kept after the gauge hides so it fades out in place

    signal pulseRequested

    function showGauge(kind, value) {
        gaugeKind = kind;
        gaugeValue = Math.max(0, Math.min(1, value));
        hold.restart();
    }

    function pulse() {
        pulseRequested();
    }

    Timer {
        id: hold
        interval: Anim.gaugeHold
        onTriggered: root.gaugeKind = ""
    }
}
