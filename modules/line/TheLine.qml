import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.desktop
import qs.modules.tiles
import qs.services

// One screen: the strut that keeps windows below the tiles, and the surface that holds the line and the tiles.
Scope {
    id: root

    required property ShellScreen modelData

    readonly property string screenName: modelData.name
    readonly property bool panelHere: UiState.openScreen === screenName && UiState.openPanel !== ""
    // A fullscreen window on this screen's workspace. Going fullscreen runs in stages, one after the other:
    //   1. the music part leaves the workspace tile,  2. the three tiles fold up into the line,
    //   3. the line withdraws into the screen edges.
    // Leaving fullscreen runs them backwards. `stage` is where the screen is now (0 = everything shown).
    readonly property bool fullscreen: Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false
    readonly property int lineDraw: Math.round(Anim.panel * 1.6)
    property int stage: 0

    // While the line is withdrawn, a notification or a level change draws it back for the event (peek).
    readonly property bool lineEvent: LineState.pulseActive || LineState.gaugeKind !== ""
    readonly property bool peek: stage >= 3 && (lineEvent || peekLinger.running)

    // How long the current stage's animation needs before the next one starts.
    function stageDelay() {
        if (fullscreen)
            return [0, Media.active ? Anim.closeLead + Anim.panel : 0, Anim.closeLead + Anim.panel][stage];
        return [0, Anim.panel + Anim.fillLag, root.lineDraw, 0][stage];
    }

    function scheduleStage() {
        if ((fullscreen && stage < 3) || (!fullscreen && stage > 0)) {
            stageTimer.interval = Math.max(1, stageDelay());
            stageTimer.restart();
        } else {
            stageTimer.stop();
        }
    }

    onFullscreenChanged: {
        if (fullscreen && UiState.openScreen === screenName)
            UiState.close();
        scheduleStage();
    }
    onStageChanged: {
        scheduleStage();
        LineState.setWithdrawn(screenName, stage >= 3);
    }
    onLineEventChanged: if (!lineEvent && stage >= 3) peekLinger.restart()

    Timer {
        id: stageTimer
        onTriggered: root.stage += root.fullscreen ? 1 : -1
    }

    // Keeps the line out a moment after the event, so the gauge fades before the line withdraws.
    Timer {
        id: peekLinger
        interval: Anim.base
    }

    // No window on this screen's workspace: Kira's voice shows.
    readonly property bool desktopEmpty: (Hyprland.monitorFor(modelData)?.activeWorkspace?.toplevels?.values?.length ?? 1) === 0

    readonly property int workspace: {
        const ws = Hyprland.monitorFor(modelData)?.activeWorkspace?.id ?? 1;
        return ws;
    }

    // Kira's voice on an empty workspace, behind the windows. It steps aside while a one-off line plays here.
    DesktopVoice {
        screen: root.modelData
        active: root.desktopEmpty && root.stage === 0 && !(Voice.eventActive && Voice.eventScreen === root.screenName)
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
        WlrLayershell.layer: root.fullscreen || root.stage > 0 ? WlrLayer.Overlay : WlrLayer.Top
        WlrLayershell.keyboardFocus: root.panelHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Input only where something is: the tiles, or the whole surface while a panel is open
        // (so a click outside closes it without reaching the window below).
        mask: root.panelHere ? fullMask : (root.fullscreen || root.stage > 0 ? noMask : tilesMask)

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

            // Kira's voice on top of the windows, for one-off lines (power plugged / unplugged).
            KiraVoice {
                x: 16
                y: parent.height - 22 - height
                text: Voice.eventText
                shown: Voice.eventActive && Voice.eventScreen === root.screenName && root.stage === 0
            }

            // The three tiles. In fullscreen they fold up into the line (stage 2).
            Item {
                id: tiles

                anchors.fill: parent
                enabled: root.stage === 0

                WorkspaceTile {
                    id: workspaceTile
                    screenName: root.screenName
                    workspace: root.workspace
                    musicHidden: root.stage >= 1
                    collapsed: root.stage >= 2
                }

                ClockTile {
                    id: clockTile
                    screenName: root.screenName
                    fullscreen: root.fullscreen
                    collapsed: root.stage >= 2
                }

                StatusTile {
                    id: statusTile
                    screenName: root.screenName
                    collapsed: root.stage >= 2
                }
            }

            Line {
                anchors.fill: parent
                workspace: root.workspace
                musicShown: root.stage < 1
                markerShown: root.stage < 2
                tileShown: root.stage < 2
                reach: root.stage >= 3 && !root.peek ? 0 : 1

                Behavior on reach {
                    NumberAnimation { duration: root.lineDraw; easing.type: Anim.easing }
                }
            }

            Hints {
                anchors.fill: parent
                leftTile: workspaceTile
                centerTile: clockTile
                rightTile: statusTile
                shown: UiState.hints && Config.superHints && root.stage === 0 && !root.panelHere
            }
        }
    }
}
