pragma Singleton

import QtQuick
import TheLine.Ui
import Quickshell
import Quickshell.Hyprland

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
    readonly property int tileDelay: lead + Anim.pulse + Math.round(Anim.pulseWrap * wrapToCorner / wrapTotal)

    // The pulse timeline, shared by the dashes on every screen and by the clock tile that grows under them.
    // pulseMs is the elapsed time (linear). toTile: the dashes turn back and the tile's frame follows them,
    // otherwise they just meet at the centre.
    property bool pulseActive: false

    // Screens whose line is withdrawn (fullscreen). The pulse then starts a little late, so the line has
    // time to draw itself back before the dashes run on it.
    property var withdrawn: []
    readonly property int lead: withdrawn.length > 0 ? Anim.d(160) : 0

    function setWithdrawn(screen, on) {
        const rest = withdrawn.filter(s => s !== screen);
        withdrawn = on ? rest.concat(screen) : rest;
    }

    // The screen that was focused when the pulse started: with "pulseFocusedOnly", the only one that shows it.
    property string pulseScreen: ""

    function pulseOn(screen) {
        return !Config.pulseFocusedOnly || pulseScreen === "" || pulseScreen === screen;
    }

    property bool pulseAround: false
    property real pulseMs: 0

    function showGauge(kind, value) {
        gaugeKind = kind;
        gaugeValue = Math.max(0, Math.min(1, value));
        hold.restart();
    }

    // The flash: the whole line lit in one colour, a few times (a battery about to die, a script that wants attention).
    // Cut on and off, not faded: a fade is an animation and any animation redraws every window.
    property bool flashOn: false
    property color flashColor: Theme.error
    property int flashLeft: 0

    function flash(color, times) {
        flashColor = color ?? Theme.error;
        flashLeft = Math.max(1, times ?? 2);
        flashScreen = Hyprland.focusedMonitor?.name ?? "";
        flashOn = true;
        flashTimer.interval = Anim.d(200);
        flashTimer.restart();
    }

    property string flashScreen: ""

    Timer {
        id: flashTimer
        onTriggered: {
            if (root.flashOn) {
                root.flashOn = false;
                root.flashLeft--;
                if (root.flashLeft <= 0)
                    return;
                interval = Anim.d(150);
            } else {
                root.flashOn = true;
                interval = Anim.d(200);
            }
            restart();
        }
    }

    // The pulse's colour: the accent, or coral for something urgent (a battery about to die).
    property color pulseColor: Theme.accent

    function pulse(toTile, color) {
        pulseColor = color ?? Theme.accent;
        pulseAnim.stop();
        pulseAround = toTile;
        pulseScreen = Hyprland.focusedMonitor?.name ?? "";
        pulseAnim.from = -lead;
        pulseMs = -lead;
        pulseAnim.to = Anim.pulse + (toTile ? Anim.pulseWrap : 0);
        pulseActive = true;
        pulseAnim.restart();
    }

    NumberAnimation {
        id: pulseAnim
        target: root
        property: "pulseMs"
        duration: Math.max(1, to - from)
        easing.type: Easing.Linear
        onStopped: root.pulseActive = false
    }

    Timer {
        id: hold
        interval: Anim.gaugeHold
        onTriggered: root.gaugeKind = ""
    }
}
