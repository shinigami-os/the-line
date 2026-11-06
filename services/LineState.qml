pragma Singleton

import QtQuick
import Quickshell

// Events that play out on the line: the level gauge and the notification pulse.
Singleton {
    id: root

    property string gaugeKind: ""   // "" | "vol" | "bri"
    property real gaugeValue: 0     // 0..1, kept after the gauge hides so it fades out in place

    // Size of the toast the pulse draws around; the clock tile uses the same numbers.
    readonly property int toastW: 400
    readonly property int toastH: 128

    // toTile: the pulse ends by opening the clock tile (a toast follows), otherwise it just meets at the centre.
    signal pulseRequested(bool toTile)

    function showGauge(kind, value) {
        gaugeKind = kind;
        gaugeValue = Math.max(0, Math.min(1, value));
        hold.restart();
    }

    function pulse(toTile) {
        pulseRequested(toTile);
    }

    Timer {
        id: hold
        interval: Anim.gaugeHold
        onTriggered: root.gaugeKind = ""
    }
}
