import QtQuick
import Quickshell.Hyprland
import qs.modules.common
import qs.services

// Top-left tile, at rest: ten workspace numerals hung under ticks on the line, and the window title under them.
Tile {
    id: tile

    required property int workspace   // active workspace of this screen

    anchorSide: "left"
    restW: 26 + 10 * Theme.wsCell

    readonly property var toplevel: Hyprland.activeToplevel

    function occupied(n) {
        const ws = Hyprland.workspaces.values.find(w => w.id === n);
        return !!ws && ws.toplevels.values.length > 0;
    }

    Item {
        anchors.fill: parent

        // Workspace ruler: 10 cells, ticks hanging from the line.
        Row {
            x: 13
            y: 1

            Repeater {
                model: 10

                Item {
                    id: cell

                    required property int index
                    readonly property int n: index + 1
                    readonly property bool active: n === tile.workspace
                    readonly property bool busy: tile.occupied(n)

                    width: Theme.wsCell
                    height: 20

                    Rectangle {
                        x: Theme.wsCell / 2 - 1
                        width: 1
                        height: cell.active ? 0 : (cell.busy ? 7 : 4)
                        color: cell.busy ? Theme.muted : Theme.borderStrong
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        text: cell.n % 10
                        font.family: Theme.fontUi
                        font.pixelSize: 12
                        font.weight: cell.active ? Font.Bold : Font.Medium
                        color: cell.active ? Theme.accent : (cell.busy ? Theme.text : (cellHover.hovered ? Theme.text : Theme.muted))
                    }

                    HoverHandler {
                        id: cellHover
                    }
                    TapHandler {
                        onTapped: Hyprland.dispatch("workspace " + cell.n)
                    }
                }
            }
        }

        // Window title under the numerals.
        Row {
            x: 13
            y: 22
            width: tile.restW - 26
            spacing: 8
            clip: true

            Text {
                text: tile.toplevel ? (tile.toplevel.title || "Untitled") : "Desktop"
                font.family: Theme.fontUi
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Theme.text
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 130)
            }
            Text {
                anchors.baseline: undefined
                text: tile.toplevel ? (tile.toplevel.lastIpcObject?.class ?? "") : "no windows"
                font.family: Theme.fontMono
                font.pixelSize: 10
                color: Theme.muted
            }
        }
    }
}
