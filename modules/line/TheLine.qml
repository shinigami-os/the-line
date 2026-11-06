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
    // A fullscreen window on this screen's workspace: the tiles slide away, then the line withdraws into the
    // screen edges. Leaving fullscreen plays it backwards. The gauge and the pulse still show meanwhile.
    readonly property bool fullscreen: Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false
    readonly property int lineDraw: Math.round(Anim.panel * 1.6)

    onFullscreenChanged: if (fullscreen && UiState.openScreen === screenName) UiState.close()

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
        // Hyprland draws fullscreen windows over the top layer, so the line moves to the overlay layer meanwhile.
        WlrLayershell.layer: root.fullscreen ? WlrLayer.Overlay : WlrLayer.Top
        WlrLayershell.keyboardFocus: root.panelHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Input only where something is: the tiles, or the whole surface while a panel is open
        // (so a click outside closes it without reaching the window below).
        mask: root.panelHere ? fullMask : (root.fullscreen ? noMask : tilesMask)

        Region {
            id: fullMask
            item: content
        }
        Region {
            id: noMask
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

            // The three tiles move as one group in fullscreen: up and out, after (or before) the line.
            Item {
                id: tiles

                anchors.fill: parent
                enabled: !root.fullscreen
                opacity: root.fullscreen ? 0 : 1

                transform: Translate {
                    y: root.fullscreen ? -(Theme.tileHeight + 20) : 0

                    Behavior on y {
                        SequentialAnimation {
                            PauseAnimation { duration: root.fullscreen ? 0 : Math.round(root.lineDraw * 0.6) }
                            NumberAnimation { duration: Anim.panel; easing.type: Anim.easing }
                        }
                    }
                }

                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation { duration: root.fullscreen ? 0 : Math.round(root.lineDraw * 0.6) }
                        NumberAnimation { duration: Anim.base }
                    }
                }

                WorkspaceTile {
                    id: workspaceTile
                    screenName: root.screenName
                    workspace: root.workspace
                }

                ClockTile {
                    id: clockTile
                    screenName: root.screenName
                    fullscreen: root.fullscreen
                }

                StatusTile {
                    id: statusTile
                    screenName: root.screenName
                }
            }

            Line {
                anchors.fill: parent
                workspace: root.workspace
                fullscreen: root.fullscreen
                reach: root.fullscreen ? 0 : 1

                Behavior on reach {
                    SequentialAnimation {
                        PauseAnimation { duration: root.fullscreen ? Anim.panel : 0 }
                        NumberAnimation { duration: root.lineDraw; easing.type: Anim.easing }
                    }
                }
            }
        }
    }
}
