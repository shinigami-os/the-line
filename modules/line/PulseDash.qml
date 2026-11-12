import QtQuick
import TheLine.Ui
import qs.services

// One half of the notification pulse, a 56px dash drawn for the left half (the right half is the same item mirrored).
//   phase 1: the dash runs along the line from the screen edge to the centre, where the two halves meet (s = head position).
//   phase 2: it turns back, runs along the line to the top corner of the toast frame, down the frame's side, then
//            inward along its bottom edge (r = distance its leading end has travelled from the meeting point).
// With `around` off only phase 1 plays. Positions come from LineState.pulseMs (constant speed).
Item {
    id: dash

    property real centerX: width / 2
    property real toastW: LineState.toastW
    property real toastH: LineState.toastH
    property bool tileShown: true   // false in fullscreen: no tile to draw, the dashes just meet
    readonly property bool around: LineState.pulseAround && tileShown
    readonly property real ms: LineState.pulseMs
    readonly property int phase: around && ms >= Anim.pulse ? 2 : 1
    readonly property real s: Math.max(0, Math.min(centerX, ms / Anim.pulse * centerX))
    readonly property real r: Math.max(0, ms - Anim.pulse) / Anim.pulseWrap * wrapEnd

    readonly property real dashLen: 56

    // Phase 2 path, as a distance d along it (d < 0 is the tail still behind the start, on the line near the centre).
    readonly property real x0: centerX - dashLen                // leading end when the dash turns back
    readonly property real sideX: centerX - toastW / 2 + 0.5     // centre of the frame's side border
    readonly property real bottomY: 10 + toastH - 0.5            // centre of the frame's bottom border
    readonly property real len1: x0 - sideX
    readonly property real len2: bottomY - 10.5
    readonly property real len3: centerX - sideX
    readonly property real total: len1 + len2 + len3

    readonly property real wrapEnd: total + dashLen              // phase 2 target

    // Fades in over the first stretch; gone once they meet if there is no tile to draw on this screen.
    opacity: ms < 0 || (!around && ms >= Anim.pulse) ? 0 : (phase === 1 ? Math.min(1, s / Math.max(1, centerX * 0.15)) : 1)

    function lo(a) { return Math.max(a, r - dashLen); }
    function hi(b) { return Math.min(b, r); }

    // Phase 1: along the line towards the centre.
    Rectangle {
        visible: dash.phase === 1
        x: Math.max(0, dash.s - dash.dashLen)
        y: 9
        width: dash.s - x
        height: 3
        color: Theme.accent
    }

    // Phase 2, along the line, going back out.
    Rectangle {
        visible: dash.phase === 2 && dash.hi(dash.len1) > dash.lo(-dash.dashLen)
        x: dash.x0 - dash.hi(dash.len1)
        y: 9
        width: dash.hi(dash.len1) - dash.lo(-dash.dashLen)
        height: 3
        color: Theme.accent
    }

    // Down the side.
    Rectangle {
        visible: dash.phase === 2 && dash.hi(dash.len1 + dash.len2) > dash.lo(dash.len1)
        x: dash.sideX - 1.5
        y: 10.5 + (dash.lo(dash.len1) - dash.len1)
        width: 3
        height: dash.hi(dash.len1 + dash.len2) - dash.lo(dash.len1)
        color: Theme.accent
    }

    // Inward along the bottom.
    Rectangle {
        visible: dash.phase === 2 && dash.hi(dash.total) > dash.lo(dash.len1 + dash.len2)
        x: dash.sideX + (dash.lo(dash.len1 + dash.len2) - dash.len1 - dash.len2)
        y: dash.bottomY - 1.5
        width: dash.hi(dash.total) - dash.lo(dash.len1 + dash.len2)
        height: 3
        color: Theme.accent
    }
}
