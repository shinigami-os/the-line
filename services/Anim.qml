pragma Singleton

import QtQuick
import Quickshell

// The whole motion system: one curve, a few durations, a few offsets.
Singleton {
    readonly property real scale: Config.motionScale
    readonly property bool reduce: Config.reduceMotion

    // Quartic ease-out. Used for everything that moves or resizes.
    readonly property int easing: Easing.OutQuart

    function d(ms) {
        return reduce ? 1 : Math.round(ms * scale);
    }

    readonly property int press: d(90)
    readonly property int hover: d(120)
    readonly property int base: d(180)
    readonly property int panel: d(260)
    readonly property int workspace: d(340)
    readonly property int pulse: d(700)
    readonly property int exitFade: d(90)

    readonly property int fillLag: d(55)
    readonly property int ruleDelay: d(80)
    readonly property int itemStart: d(110)
    readonly property int stagger: d(24)
    readonly property int closeLead: d(70)
    readonly property int toastDelay: d(730)
    readonly property int toastContent: d(120)
    readonly property int hintStagger: d(40)

    // Holds are not scaled.
    readonly property int gaugeHold: 1400
    readonly property int toastHold: 4200
}
