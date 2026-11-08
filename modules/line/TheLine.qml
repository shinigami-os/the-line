import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs.modules.desktop
import qs.modules.tiles
import qs.services

// One screen: the strut that keeps windows below the tiles, and the surface that holds the line and the tiles.
Scope {
    id: root

    required property ShellScreen modelData

    readonly property string screenName: modelData.name
    readonly property bool panelHere: UiState.openScreen === screenName && UiState.openPanel !== ""
    // A panel open on any screen: a click on this one closes it too.
    readonly property bool panelAnywhere: UiState.openPanel !== ""
    // A dialog from the line (polkit) is open on this screen: it takes the keyboard and every click.
    readonly property bool dialogHere: (Polkit.active && Polkit.screen === screenName) || UiState.sheetScreen === screenName
        || UiState.powerScreen === screenName || UiState.clipScreen === screenName || UiState.emojiScreen === screenName
        || UiState.wallScreen === screenName
    // This screen's surface wants the keyboard (a panel or a dialog open here); keysTaken follows it a moment later.
    readonly property bool keysHere: panelHere || dialogHere
    property bool keysTaken: false

    onKeysHereChanged: {
        // one screen: no other surface to wait for
        keysTaken = keysHere && Quickshell.screens.length === 1;
        if (keysHere && !keysTaken)
            takeKeys.restart();
    }

    Timer {
        id: takeKeys
        interval: 60
        onTriggered: root.keysTaken = true
    }

    // A fullscreen window on this screen's workspace. Going fullscreen runs in stages, one after the other:
    //   1. the music part leaves the workspace tile,  2. the three tiles fold up into the line,
    //   3. the line withdraws into the screen edges.
    // Leaving fullscreen runs them backwards. `stage` is where the screen is now (0 = everything shown).
    // The shell also starts hidden (stage 3) and plays the way back in as its intro, once the wallpaper is up.
    // Only a real fullscreen (mode 2): Hyprland also counts a maximized window (mode 1) as "fullscreen", and Electron
    // apps leave F11 maximized; a maximized window fits under the line, so the line stays.
    readonly property bool fullscreen: {
        const ws = Hyprland.monitorFor(modelData)?.activeWorkspace;
        if (!ws?.hasFullscreen)
            return false;
        return ws.toplevels.values.some(t => (t.lastIpcObject?.fullscreen ?? 2) === 2);
    }
    readonly property int lineDraw: Math.round(Anim.panel * 1.6)
    property int stage: 3
    property bool introDone: false
    // Where the stages head: 3 (withdrawn) in fullscreen and before the intro, 2 (the tiles folded into the line) while
    // the music visualiser plays on it, 0 otherwise. Two ways to get the tiles back meanwhile:
    //   edgePeek  fullscreen: the pointer pushed against the top edge for 400 ms, until it leaves the tiles' band
    //             (read from Pointer: over a fullscreen window the surface gets clicks but no pointer motion)
    //   reveal    visualiser: the pointer over the tiles' band
    property bool edgePeek: false
    property bool reveal: false
    readonly property int target: !introDone || (fullscreen && !edgePeek) ? 3
        : Visualiser.on && !edgePeek && !reveal && !panelHere ? 2 : 0

    // React to `target` itself: a handler on what it reads can run before it has caught up.
    onTargetChanged: scheduleStage()


    // Intro: a moment after this screen's wallpaper is shown (or right away without one).
    Timer {
        id: introTimer
        interval: 700
        running: !root.introDone && (Config.wallpaperFor(root.screenName) === "" || (wallpaper.item?.ready ?? false))
        onTriggered: root.introDone = true
    }

    // While the line is withdrawn, a notification or a level change draws it back for the event (peek).
    readonly property bool lineEvent: (LineState.pulseActive && LineState.pulseOn(screenName)) || LineState.gaugeKind !== ""
    readonly property bool peek: stage >= 3 && (lineEvent || peekLinger.running)

    // How long the current stage's animation needs before the next one starts.
    function stageDelay() {
        if (stage < target)
            return [0, Media.active ? Anim.closeLead + Anim.panel : 0, Anim.closeLead + Anim.panel][stage];
        return [0, Anim.panel + Anim.fillLag, root.lineDraw, 0][stage];
    }

    function scheduleStage() {
        if (stage !== target) {
            stageTimer.interval = Math.max(1, stageDelay());
            stageTimer.restart();
        } else {
            stageTimer.stop();
        }
    }

    onFullscreenChanged: {
        if (fullscreen && UiState.openScreen === screenName)
            UiState.close();
        edgePeek = false;
    }

    readonly property bool pointerHere: Pointer.x >= modelData.x && Pointer.x < modelData.x + modelData.width
        && Pointer.y >= modelData.y && Pointer.y < modelData.y + modelData.height
    readonly property bool pointerAtEdge: pointerHere && Pointer.y - modelData.y < 2
    readonly property bool pointerInBand: pointerHere && Pointer.y - modelData.y < 10 + Theme.tileHeight + 16

    Timer {
        id: edgeHold
        interval: 400
        running: root.fullscreen && !root.edgePeek && root.pointerAtEdge
        onTriggered: root.edgePeek = true
    }
    // The pointer is in the tiles' band. A click in it takes the hover away until the pointer moves again (Qt), so
    // the band also counts as held for a moment after a press: clicking play and keeping still doesn't fold the tiles.
    readonly property bool inBand: bandHover.hovered || bandPress.active || clickHold.running

    // The peek ends once the pointer has left the band a moment (not while a panel opened from it is open).
    Timer {
        interval: 500
        running: root.edgePeek && !root.inBand && !root.pointerInBand && !root.panelHere
        onTriggered: root.edgePeek = false
    }
    Timer {
        interval: root.reveal ? 500 : 120
        running: Visualiser.on && root.reveal !== root.inBand
        onTriggered: root.reveal = root.inBand
    }
    Timer {
        id: clickHold
        interval: 3000
    }
    onStageChanged: {
        scheduleStage();
        LineState.setWithdrawn(screenName, stage >= 3);
    }
    onLineEventChanged: if (!lineEvent && stage >= 3) peekLinger.restart()

    Timer {
        id: stageTimer
        onTriggered: root.stage += root.stage < root.target ? 1 : -1
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

    Loader {
        id: wallpaper
        active: Config.wallpaperFor(root.screenName) !== ""
        sourceComponent: Wallpaper {
            screen: root.modelData
            paused: root.fullscreen || (Config.wallpaperStillOnBattery && UPower.onBattery)
        }
    }

    Freeze {
        screen: root.modelData
    }

    // Kira's voice on an empty workspace, behind the windows. It steps aside while a one-off line plays here.
    DesktopVoice {
        screen: root.modelData
        active: Config.kiraVoice && root.desktopEmpty && root.stage < 3 && !root.fullscreen && !(Voice.eventActive && Voice.eventScreen === root.screenName)
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
        // While a surface holds the keyboard (exclusive), Hyprland sends clicks to such surfaces only: with a panel open,
        // every screen's surface takes the keyboard, so a click on another screen still reaches its close area. The
        // panel's own screen takes it a moment later (keysTaken), as Hyprland gives the keys to the last one.
        WlrLayershell.keyboardFocus: (root.keysHere && root.keysTaken) || (root.panelAnywhere && !root.keysHere)
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        IdleInhibitor {
            window: win
            enabled: Power.keepAwake
        }

        // Input only where something is: the tiles, or the whole surface while a panel is open on any screen
        // (so a click outside closes it without reaching the window below). While peeking or visualising, the
        // tiles' whole band (to know when the pointer leaves it).
        mask: root.panelAnywhere || root.dialogHere ? fullMask
            : root.edgePeek || (Visualiser.on && !root.fullscreen) ? bandMask
            : root.stage > 0 ? noMask : tilesMask
        // A new input region reaches Hyprland with the next frame: on a still screen there may be none for a long
        // while, so one is drawn.
        onMaskChanged: nudge.opacity = nudge.opacity > 0 ? 0 : 0.01

        Region {
            id: fullMask
            item: content
        }
        Region {
            id: noMask
        }
        Region {
            id: bandMask
            item: band
        }
        Region {
            id: tilesMask
            regions: [
                Region { item: workspaceTile },
                Region { item: clockTile },
                Region { item: statusTile }
            ]
        }

        Rectangle {
            id: nudge
            width: 1
            height: 1
            color: "black"
            opacity: 0
        }

        Item {
            id: content
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: UiState.close()
            // Keys typed while the launcher's screen is still taking the keyboard land here: they go on to it.
            Keys.onPressed: event => {
                if (!root.panelHere && UiState.openPanel === "tl" && event.text !== "" && event.text.charCodeAt(0) >= 32)
                    UiState.launcherQuery += event.text;
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.panelAnywhere
                onClicked: UiState.close()
            }

            // The wallpaper picker's preview: behind the line and the tiles.
            WallpaperPreview {
                anchors.fill: parent
                open: wallStrip.open
                path: wallStrip.picked
            }

            // Kira's voice on top of the windows, for one-off lines (power plugged / unplugged).
            KiraVoice {
                x: 16
                y: parent.height - 22 - height
                text: Voice.eventText
                decode: Voice.eventDecode
                shown: Voice.eventActive && Voice.eventScreen === root.screenName && root.stage < 3 && !root.fullscreen
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

            ResizeRing {
                anchors.fill: parent
                screen: root.modelData
            }

            Line {
                anchors.fill: parent
                screenName: root.screenName
                quietDesktop: root.desktopEmpty
                workspace: root.workspace
                musicShown: root.stage < 1
                markerShown: root.stage < 2
                tileShown: root.stage < 2
                spectrumShown: root.stage === 2
                reach: root.stage >= 3 && !root.peek ? 0 : 1

                Behavior on reach {
                    NumberAnimation { duration: root.lineDraw; easing.type: Anim.easing }
                }
            }


            CheatSheet {
                anchors.fill: parent
                screenName: root.screenName
            }

            PowerMenu {
                anchors.fill: parent
                screenName: root.screenName
            }

            ClipboardDialog {
                anchors.fill: parent
                screenName: root.screenName
            }

            EmojiDialog {
                anchors.fill: parent
                screenName: root.screenName
            }

            // The tiles' band (the strut's height; a little more while peeking over a fullscreen window, so the
            // pointer can wander under the tiles). Over everything, so nothing appearing under a still pointer takes
            // its hover.
            Item {
                id: band
                width: parent.width
                height: 10 + Theme.tileHeight + (root.edgePeek ? 16 : 0)

                HoverHandler {
                    id: bandHover
                }
                // sees presses on the tiles too (a passive grab), without taking them
                PointHandler {
                    id: bandPress
                    acceptedButtons: Qt.AllButtons
                    onActiveChanged: if (!active) clickHold.restart()
                }
            }

            WallpaperStrip {
                id: wallStrip
                anchors.fill: parent
                screenName: root.screenName
            }

            PolkitDialog {
                anchors.fill: parent
                screenName: root.screenName
            }
        }
    }
}
