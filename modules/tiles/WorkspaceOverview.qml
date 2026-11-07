import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.modules.common
import qs.services

// Where everything is: the ten workspaces as small screens, two rows of five, each window drawn as a live
// thumbnail where it really sits. The active workspace has an accent frame; a click goes there.
Column {
    id: overview

    required property bool shown
    required property int active   // active workspace of this screen

    readonly property real cellW: 168
    readonly property real cellH: 95
    readonly property real gap: 10

    spacing: 0

    Grid {
        columns: 5
        columnSpacing: overview.gap
        rowSpacing: overview.gap

        Repeater {
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

                order: Math.floor(index / 5) * 2 + index % 5
                shown: overview.shown
                width: overview.cellW
                height: overview.cellH + 20

                Rectangle {
                    id: screen
                    width: overview.cellW
                    height: overview.cellH
                    color: Theme.bg
                    border.width: 1
                    border.color: cell.isActive ? Theme.accent : (cellHover.hovered ? Theme.borderStrong : Theme.border)
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
                                border.color: Theme.borderStrong

                                ScreencopyView {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    captureSource: overview.shown ? (win.modelData.wayland ?? null) : null
                                    live: false
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
}
