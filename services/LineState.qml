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
    readonly property int toastH: Theme.tileHeight + 76

    // The pulse's second leg, in px: back out along the line, down the frame's side, inward along its bottom, tail.
    readonly property real wrapToCorner: toastW / 2 - 56.5 + toastH - 1
    readonly property real wrapTotal: wrapToCorner + toastW / 2 - 0.5 + 56

    // When the toast content takes over: the dashes have drawn the frame down to its bottom corners.
    readonly property int tileDelay: Anim.pulse + Math.round(Anim.pulseWrap * wrapToCorner / wrapTotal)

    // The pulse timeline, shared by the dashes on every screen and by the clock tile that grows under them.
    // pulseMs is the elapsed time (linear). toTile: the dashes turn back and the tile's frame follows them,
    // otherwise they just meet at the centre.
    property bool pulseActive: false
    property bool pulseAround: false
    property real pulseMs: 0

    function showGauge(kind, value) {
        gaugeKind = kind;
        gaugeValue = Math.max(0, Math.min(1, value));
        hold.restart();
    }

    function pulse(toTile) {
        pulseAnim.stop();
        pulseAround = toTile;
        pulseMs = 0;
        pulseAnim.to = Anim.pulse + (toTile ? Anim.pulseWrap : 0);
        pulseActive = true;
        pulseAnim.restart();
    }

    NumberAnimation {
        id: pulseAnim
        target: root
        property: "pulseMs"
        from: 0
        duration: Math.max(1, to)
        easing.type: Easing.Linear
        onStopped: root.pulseActive = false
    }

    Timer {
        id: hold
        interval: Anim.gaugeHold
        onTriggered: root.gaugeKind = ""
    }
}
