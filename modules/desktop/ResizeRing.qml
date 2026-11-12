import QtQuick
import Quickshell
import TheLine.Ui
import QtQuick.Shapes
import Quickshell.Hyprland
import qs.services

// Resize mode (SUPER+R): a loading ring around the focused window. Four accent segments, each an eighth of the
// border, one per quarter, running around it. Drawn by the screen the window is on, and follows the resize.
Item {
    id: ring

    required property var screen   // this surface's ShellScreen

    readonly property var focused: Hyprland.activeToplevel ?? Hyprland.toplevels.values.find(t => t.activated) ?? null
    readonly property var ipc: UiState.resizing ? (focused?.lastIpcObject ?? null) : null
    readonly property bool here: ipc !== null && ipc.at !== undefined
        && ipc.at[0] >= screen.x && ipc.at[0] < screen.x + screen.width
        && ipc.at[1] >= screen.y && ipc.at[1] < screen.y + screen.height

    // The window's rectangle on this screen, just outside it (on its border).
    readonly property real rx: here ? ipc.at[0] - screen.x - 1 : 0
    readonly property real ry: here ? ipc.at[1] - screen.y - 1 : 0
    readonly property real rw: here ? ipc.size[0] + 2 : 0
    readonly property real rh: here ? ipc.size[1] + 2 : 0
    readonly property real perimeter: 2 * (rw + rh)

    property real phase: 0   // 0..1, one quarter turn per cycle

    visible: here
    opacity: here ? 1 : 0

    Behavior on opacity {
        NumberAnimation { duration: Anim.base }
    }

    NumberAnimation on phase {
        running: ring.here
        loops: Animation.Infinite
        from: 0
        to: 1
        duration: 900
    }

    // A point at distance d along the rectangle's border, clockwise from the top-left corner.
    function at(d) {
        d = ((d % perimeter) + perimeter) % perimeter;
        if (d < rw)
            return Qt.point(rx + d, ry);
        d -= rw;
        if (d < rh)
            return Qt.point(rx + rw, ry + d);
        d -= rh;
        if (d < rw)
            return Qt.point(rx + rw - d, ry + rh);
        d -= rw;
        return Qt.point(rx, ry + rh - d);
    }

    // The points of a segment from d to d + len, corners included.
    function segment(d, len) {
        const pts = [at(d)];
        const corners = [0, rw, rw + rh, 2 * rw + rh];
        for (let k = 0; k < 2; k++) {
            for (const c of corners) {
                const cc = c + k * perimeter;
                if (cc > d && cc < d + len)
                    pts.push(at(cc));
            }
        }
        pts.push(at(d + len));
        return pts;
    }

    Repeater {
        model: 4

        Shape {
            required property int index

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 2
                strokeColor: Theme.accent
                fillColor: "transparent"
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.MiterJoin

                PathPolyline {
                    path: ring.here ? ring.segment((index + ring.phase) * ring.perimeter / 4, ring.perimeter / 8) : []
                }
            }
        }
    }

    // Window classes and sizes come from Hyprland's IPC: read them often while resizing.
    Timer {
        running: UiState.resizing
        repeat: true
        interval: 50
        onTriggered: Hyprland.refreshToplevels()
    }
}
