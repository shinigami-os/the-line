import QtQuick
import qs.services

// One half of the notification pulse. A 56px dash is pushed along a path by `s`, the distance travelled by its head:
//   along the line to the top corner of the toast frame, down the frame's side, then inward along its bottom edge.
// Drawn for the left half; the right half is the same item mirrored about the screen centre.
// With `around` off the dash just runs along the line to the centre (no tile to draw).
Item {
    id: dash

    property real centerX: width / 2
    property real toastW: LineState.toastW
    property real toastH: LineState.toastH
    property bool around: true
    property real s: 0

    readonly property real dashLen: 56
    readonly property real sideX: centerX - toastW / 2 + 0.5   // centre of the frame's side border
    readonly property real bottomY: 10 + toastH - 0.5          // centre of the frame's bottom border
    readonly property real len1: around ? sideX : centerX
    readonly property real len2: around ? bottomY - 10.5 : 0
    readonly property real len3: around ? centerX - sideX : 0
    readonly property real total: len1 + len2 + len3

    // The head stops here after the first stretch; the rest is the wrap around the tile.
    readonly property real corner: len1
    readonly property real end: around ? total + dashLen : total

    opacity: Math.min(1, s / Math.max(1, len1 * 0.15))

    function lo(a) { return Math.max(a, s - dashLen); }
    function hi(b) { return Math.min(b, s); }

    // Along the line.
    Rectangle {
        visible: dash.hi(dash.len1) > dash.lo(0)
        x: dash.lo(0)
        y: 9
        width: dash.hi(dash.len1) - dash.lo(0)
        height: 3
        color: Theme.accent
    }

    // Down the side.
    Rectangle {
        visible: dash.around && dash.hi(dash.len1 + dash.len2) > dash.lo(dash.len1)
        x: dash.sideX - 1.5
        y: 10.5 + (dash.lo(dash.len1) - dash.len1)
        width: 3
        height: dash.hi(dash.len1 + dash.len2) - dash.lo(dash.len1)
        color: Theme.accent
    }

    // Inward along the bottom.
    Rectangle {
        visible: dash.around && dash.hi(dash.total) > dash.lo(dash.len1 + dash.len2)
        x: dash.sideX + (dash.lo(dash.len1 + dash.len2) - dash.len1 - dash.len2)
        y: dash.bottomY - 1.5
        width: dash.hi(dash.total) - dash.lo(dash.len1 + dash.len2)
        height: 3
        color: Theme.accent
    }
}
