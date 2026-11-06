import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.tiles
import qs.services

// One screen: the strut that keeps windows below the tiles, and the surface that holds the line and the tiles.
Scope {
    id: root

    required property ShellScreen modelData

    readonly property string screenName: modelData.name
    readonly property bool panelHere: UiState.openScreen === screenName && UiState.openPanel !== ""
    readonly property int workspace: {
        const ws = Hyprland.monitorFor(modelData)?.activeWorkspace?.id ?? 1;
        return ws;
    }

    // Reserves the top of the screen (line at 10 + tile height) so tiled windows start under the tiles.
    PanelWindow {
        screen: root.modelData
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 1
        exclusiveZone: 10 + Theme.tileHeight
        color: "transparent"
        mask: Region {}
        WlrLayershell.namespace: "the-line-strut"
    }

    PanelWindow {
        id: win

        screen: root.modelData
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "the-line"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: root.panelHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Input only where something is: the tiles, or the whole surface while a panel is open
        // (so a click outside closes it without reaching the window below).
        mask: root.panelHere ? fullMask : tilesMask

        Region {
            id: fullMask
            item: content
        }
        Region {
            id: tilesMask
            regions: [
                Region { item: workspaceTile },
                Region { item: clockTile },
                Region { item: statusTile }
            ]
        }

        Item {
            id: content
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: UiState.close()

            MouseArea {
                anchors.fill: parent
                enabled: root.panelHere
                onClicked: UiState.close()
            }

            WorkspaceTile {
                id: workspaceTile
                workspace: root.workspace
            }

            ClockTile {
                id: clockTile
                screenName: root.screenName
            }

            StatusTile {
                id: statusTile
                screenName: root.screenName
            }

            Line {
                anchors.fill: parent
                workspace: root.workspace
            }
        }
    }
}
