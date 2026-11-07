import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.modules.common
import qs.services

// Where everything is: the ten workspaces as small screens, two rows of five, each window drawn as a live
// thumbnail where it really sits. The active workspace has an accent frame; a click goes there.
// Windows can be dragged from one workspace to another (they move there, you stay); a click on a window focuses it.
Item {
    id: overview

    required property bool shown
    required property int active   // active workspace of this screen

    readonly property real cellW: 168
    readonly property real cellH: 95
    readonly property real gap: 10

    // Dragging a window: which one, from where, and where the pointer is (in this item).
    property var dragWin: null
    property int dragFrom: 0
    property point dragPoint: Qt.point(0, 0)
    property size dragSize: Qt.size(0, 0)
    readonly property int dropTarget: dragWin ? cellAt(dragPoint) : 0

    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight

    // The workspace number under a point of this item, 0 for none.
    function cellAt(p) {
        for (let i = 0; i < 10; i++) {
            const c = cells.itemAt(i);
            if (!c)
                continue;
            const q = c.mapFromItem(overview, p.x, p.y);
            if (q.x >= 0 && q.y >= 0 && q.x < cellW && q.y < cellH)
                return i + 1;
        }
        return 0;
    }

    function address(toplevel) {
        return "address:0x" + toplevel.address;
    }

    Grid {
        id: grid
        columns: 5
        columnSpacing: overview.gap
        rowSpacing: overview.gap

        Repeater {
            id: cells
            model: 10

            PanelItem {
                id: cell

                required property int index
                readonly property int n: index + 1
                readonly property var ws: Hyprland.workspaces.values.find(w => w.id === n) ?? null
                readonly property var windows: ws?.toplevels?.values ?? []
                readonly property var mon: ws?.monitor ?? null
                // Monitor size in layout pixels, and the scale that fits it in the cell.
                readonly property real monW: mon ? mon.width / (mon.scale || 1) : 1920
                readonly property real monH: mon ? mon.height / (mon.scale || 1) : 1080
                readonly property real k: Math.min(overview.cellW / monW, overview.cellH / monH)
                readonly property bool isActive: n === overview.active
                readonly property bool dropHere: overview.dragWin !== null && overview.dropTarget === n && n !== overview.dragFrom

                order: Math.floor(index / 5) * 2 + index % 5
                shown: overview.shown
                width: overview.cellW
                height: overview.cellH + 20

                Rectangle {
                    id: screen
                    width: overview.cellW
                    height: overview.cellH
                    color: Theme.bg
                    border.color: cell.isActive || cell.dropHere ? Theme.accent : (cellHover.hovered ? Theme.borderStrong : Theme.border)
                    border.width: cell.dropHere ? 2 : 1
                    clip: true

                    Behavior on border.color {
                        ColorAnimation { duration: Anim.hover }
                    }

                    // The screen area actually used by this monitor, centred in the cell.
                    Item {
                        x: (overview.cellW - cell.monW * cell.k) / 2
                        y: (overview.cellH - cell.monH * cell.k) / 2
                        width: cell.monW * cell.k
                        height: cell.monH * cell.k

                        Repeater {
                            model: cell.windows

                            Rectangle {
                                id: win

                                required property var modelData
                                readonly property var ipc: modelData.lastIpcObject ?? ({})

                                x: ((ipc.at?.[0] ?? 0) - (cell.mon?.x ?? 0)) * cell.k
                                y: ((ipc.at?.[1] ?? 0) - (cell.mon?.y ?? 0)) * cell.k
                                width: Math.max(4, (ipc.size?.[0] ?? 0) * cell.k)
                                height: Math.max(4, (ipc.size?.[1] ?? 0) * cell.k)
                                color: Theme.surface
                                border.width: 1
                                border.color: winArea.containsMouse && !overview.dragWin ? Theme.text : Theme.borderStrong
                                opacity: overview.dragWin === win.modelData ? 0.3 : 1

                                ScreencopyView {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    captureSource: overview.shown ? (win.modelData.wayland ?? null) : null
                                    live: false
                                }

                                // Press and move: drag the window to another workspace. Press and release: focus it.
                                MouseArea {
                                    id: winArea

                                    property point pressAt

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: overview.dragWin ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                                    onPressed: mouse => pressAt = Qt.point(mouse.x, mouse.y)
                                    onPositionChanged: mouse => {
                                        if (!pressed)
                                            return;
                                        if (!overview.dragWin && Math.hypot(mouse.x - pressAt.x, mouse.y - pressAt.y) > 4) {
                                            overview.dragWin = win.modelData;
                                            overview.dragFrom = cell.n;
                                            overview.dragSize = Qt.size(win.width, win.height);
                                        }
                                        if (overview.dragWin)
                                            overview.dragPoint = mapToItem(overview, mouse.x, mouse.y);
                                    }
                                    onReleased: {
                                        if (overview.dragWin) {
                                            const to = overview.dropTarget;
                                            if (to > 0 && to !== cell.n)
                                                Hyprland.dispatch("hl.dsp.window.move({ workspace = " + to + ", follow = false, window = \"" + overview.address(win.modelData) + "\" })");
                                            overview.dragWin = null;
                                        } else {
                                            Hyprland.dispatch("hl.dsp.focus({ window = \"" + overview.address(win.modelData) + "\" })");
                                            UiState.close();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    HoverHandler {
                        id: cellHover
                    }
                    TapHandler {
                        onTapped: {
                            Hyprland.dispatch("hl.dsp.focus({ workspace = " + cell.n + " })");
                            UiState.close();
                        }
                    }
                }

                // Numeral, and the first app's name.
                Row {
                    y: overview.cellH + 4
                    spacing: 6

                    Text {
                        text: cell.n % 10
                        font.family: Theme.fontUi
                        font.pixelSize: 12
                        font.weight: cell.isActive ? Font.Bold : Font.Medium
                        color: cell.isActive ? Theme.accent : (cell.windows.length > 0 ? Theme.text : Theme.muted)
                    }
                    Text {
                        readonly property string cls: cell.windows[0]?.lastIpcObject?.class ?? ""
                        width: overview.cellW - 20
                        text: cls === "" ? "" : (DesktopEntries.heuristicLookup(cls)?.name ?? cls) + (cell.windows.length > 1 ? "  +" + (cell.windows.length - 1) : "")
                        elide: Text.ElideRight
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        color: Theme.muted
                    }
                }
            }
        }
    }

    // The window being dragged, under the pointer.
    Rectangle {
        visible: overview.dragWin !== null
        x: overview.dragPoint.x - width / 2
        y: overview.dragPoint.y - height / 2
        width: Math.max(24, overview.dragSize.width)
        height: Math.max(16, overview.dragSize.height)
        color: Theme.surface
        border.width: 1
        border.color: Theme.accent
        z: 10

        ScreencopyView {
            anchors.fill: parent
            anchors.margins: 1
            captureSource: overview.dragWin?.wayland ?? null
            live: false
        }
    }
}
