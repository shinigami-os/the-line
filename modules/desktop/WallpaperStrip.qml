pragma ComponentBehavior: Bound

import QtQuick
import TheLine.Ui
import Quickshell
import qs.services

// The wallpaper picker (SUPER+T). A line draws itself across the bottom of the screen from both edges, and the
// wallpapers hang under it on ticks, like the workspace numerals under the top line. The accent marker stays in the
// middle of the line and the strip slides under it: the wallpaper under the marker is the picked one, and the whole
// screen shows it behind the line and the tiles (WallpaperPreview) before anything is set.
// Two lines: the pictures on the first, the moving ones (GIFs, videos) on the second; each keeps its own place.
// ←→ pick · ↑↓ pictures / moving · Tab: which screen it goes to (every screen, or one) · Enter sets it · Esc leaves it
// as it was. The mouse: wheel to pick, click a wallpaper to pick it, click the picked one to set it, click above to leave.
Item {
    id: strip

    required property string screenName

    readonly property bool open: UiState.wallScreen === screenName
    property bool contentShown: false
    property string target: ""      // "" = every screen, or a screen's name
    readonly property var screens: [""].concat(Quickshell.screens.map(s => s.name))
    readonly property string inUse: target === "" ? Config.wallpaper : Config.wallpaperFor(target)

    // The two lines: pictures, then the moving ones. A line with nothing on it is not drawn.
    readonly property var lanes: [
        { name: "Pictures", files: Wallpapers.files.filter(f => Config.wallpaperKind(f) === "still") },
        { name: "GIFs and videos", files: Wallpapers.files.filter(f => Config.wallpaperKind(f) !== "still") }
    ].filter(l => l.files.length > 0)
    property int lane: 0
    property var cursors: [0, 0]
    readonly property var files: lanes[lane]?.files ?? []
    readonly property int cursor: cursors[lane] ?? 0
    readonly property string picked: files[cursor] ?? ""

    readonly property int thumbW: 208
    readonly property int thumbH: 117
    readonly property int gap: 18
    readonly property int hang: 16                      // tick between the line and a wallpaper
    readonly property int laneH: hang + thumbH + 34     // one line and its wallpapers, the next line's name above it
    readonly property real lineY: height - 64 - thumbH - hang - 26 - (lanes.length - 1) * laneH   // the first line
    readonly property int lineDraw: Math.round(Anim.panel * 1.6)

    visible: open || reach > 0

    // The lines: drawn in from both edges on open; on close they withdraw once the wallpapers have left.
    property real reach: open ? 1 : 0
    Behavior on reach {
        SequentialAnimation {
            PauseAnimation { duration: strip.open ? 0 : Anim.exitFade + Anim.d(60) }
            NumberAnimation { duration: strip.lineDraw; easing.type: Anim.easing }
        }
    }

    // Opens on the line and the place of the wallpaper in use.
    function placeOn(path) {
        const c = [0, 0];
        let l = 0;
        lanes.forEach((ln, i) => {
            const at = ln.files.indexOf(path);
            if (at >= 0) {
                c[i] = at;
                l = i;
            }
        });
        cursors = c;
        lane = l;
    }

    onOpenChanged: {
        if (open) {
            Wallpapers.refresh();
            const own = Config.wallpapers?.[screenName] !== undefined;
            target = own ? screenName : "";
            placeOn(inUse);
            contentTimer.restart();
        } else {
            contentTimer.stop();
            contentShown = false;
        }
    }
    onContentShownChanged: if (contentShown) keys.forceActiveFocus()
    // the list read again on open: keep the place on the same file
    onLanesChanged: if (open) placeOn(picked !== "" ? picked : inUse)

    Timer {
        id: contentTimer
        interval: Math.round(strip.lineDraw * 0.6)
        onTriggered: strip.contentShown = true
    }

    function close() {
        UiState.wallScreen = "";
    }

    function setCursor(i) {
        const c = cursors.slice();
        c[lane] = Math.max(0, Math.min(files.length - 1, i));
        cursors = c;
    }

    function move(by) {
        if (files.length > 0)
            setCursor(cursor + by);
    }

    function switchLane(by) {
        if (lanes.length > 1)
            lane = Math.max(0, Math.min(lanes.length - 1, lane + by));
    }

    function set() {
        if (picked !== "")
            Accent.setWallpaper(picked, target);
        close();
    }

    // The bottom of the screen darkens under the strip, so it reads on any wallpaper.
    Rectangle {
        anchors.fill: parent
        opacity: strip.open ? 1 : 0
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: Math.max(0, (strip.lineY - 90) / strip.height); color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.82) }
        }

        Behavior on opacity {
            NumberAnimation { duration: Anim.panel }
        }
    }

    // A click above the strip leaves it, as it was.
    MouseArea {
        anchors.fill: parent
        onClicked: strip.close()
        onWheel: wheel => strip.move(wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0 ? -1 : 1)
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            const k = event.key;
            if (k === Qt.Key_Left || k === Qt.Key_H)
                strip.move(-1);
            else if (k === Qt.Key_Right || k === Qt.Key_K)
                strip.move(1);
            else if (k === Qt.Key_Up || k === Qt.Key_U)
                strip.switchLane(-1);
            else if (k === Qt.Key_Down || k === Qt.Key_J)
                strip.switchLane(1);
            else if (k === Qt.Key_Home)
                strip.setCursor(0);
            else if (k === Qt.Key_End)
                strip.setCursor(strip.files.length - 1);
            else if ((k === Qt.Key_Tab || k === Qt.Key_Backtab) && strip.screens.length > 2) {
                const i = strip.screens.indexOf(strip.target);
                strip.target = strip.screens[(i + (k === Qt.Key_Backtab ? -1 : 1) + strip.screens.length) % strip.screens.length];
            } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)
                strip.set();
            else if (k === Qt.Key_Escape)
                strip.close();
            else
                return;
            event.accepted = true;
        }

        // Above the first line: what this is, where it goes, and the keys.
        Item {
            x: 32
            y: strip.lineY - 52
            width: strip.width - 64
            height: 20
            opacity: strip.contentShown ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: strip.contentShown ? Anim.base : Anim.exitFade }
            }

            Row {
                spacing: 18

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "WALLPAPER"
                    font.family: Theme.fontUi
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.9
                    color: Theme.muted
                }

                // Where it goes; a screen with its own wallpaper says so.
                Repeater {
                    model: strip.screens.length > 2 ? strip.screens : []

                    Item {
                        id: chip

                        required property string modelData
                        readonly property bool current: modelData === strip.target

                        width: chipText.implicitWidth
                        height: 20

                        Text {
                            id: chipText
                            anchors.verticalCenter: parent.verticalCenter
                            text: (chip.modelData === "" ? "Every screen" : chip.modelData)
                                + (chip.modelData === strip.screenName ? " · here" : "")
                                + (chip.modelData !== "" && Config.wallpapers?.[chip.modelData] !== undefined ? " · own" : "")
                            font.family: chip.modelData === "" ? Theme.fontUi : Theme.fontMono
                            font.pixelSize: 11
                            font.weight: chip.current ? Font.DemiBold : Font.Normal
                            color: chip.current ? Theme.text : Theme.muted
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: chip.current ? parent.width : 0
                            height: 2
                            color: Theme.accent

                            Behavior on width {
                                NumberAnimation { duration: Anim.base; easing.type: Anim.easing }
                            }
                        }
                        TapHandler {
                            onTapped: strip.target = chip.modelData
                        }
                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "←→ pick" + (strip.lanes.length > 1 ? "   ↑↓ pictures / moving" : "") + (strip.screens.length > 2 ? "   Tab screen" : "")
                    + "   ↵ set   Esc leave"
                font.family: Theme.fontMono
                font.pixelSize: 11
                color: Theme.muted
            }
        }

        // One line per kind: the active one bright with the marker, the other dimmed, each where it was left.
        Repeater {
            model: strip.lanes

            Item {
                id: laneItem

                required property var modelData
                required property int index
                readonly property bool active: index === strip.lane
                readonly property int laneCursor: strip.cursors[index] ?? 0
                readonly property real y0: strip.lineY + index * strip.laneH

                anchors.fill: parent
                opacity: active ? 1 : 0.38

                Behavior on opacity {
                    NumberAnimation { duration: Anim.base }
                }

                // its name, at the left end of its line
                Text {
                    x: 32
                    y: laneItem.y0 - 20
                    text: laneItem.modelData.name.toUpperCase() + "  ·  " + laneItem.modelData.files.length
                    font.family: Theme.fontUi
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.9
                    color: laneItem.active ? Theme.text : Theme.muted
                    opacity: strip.contentShown && strip.lanes.length > 1 ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: strip.contentShown ? Anim.base : Anim.exitFade }
                    }
                }

                // The line, from both edges.
                Rectangle {
                    y: laneItem.y0
                    width: Math.ceil(strip.width / 2 * strip.reach)
                    height: 1
                    color: Theme.borderStrong
                }
                Rectangle {
                    x: strip.width - width
                    y: laneItem.y0
                    width: Math.ceil(strip.width / 2 * strip.reach)
                    height: 1
                    color: Theme.borderStrong
                }

                // The wallpapers, sliding under the marker.
                Item {
                    x: strip.width / 2 - laneItem.laneCursor * (strip.thumbW + strip.gap) - strip.thumbW / 2
                    y: laneItem.y0

                    Behavior on x {
                        NumberAnimation { duration: Anim.panel; easing.type: Anim.easing }
                    }

                    Repeater {
                        model: laneItem.modelData.files

                        Item {
                            id: thumb

                            required property string modelData
                            required property int index
                            readonly property string kind: Config.wallpaperKind(modelData)
                            readonly property bool under: index === laneItem.laneCursor
                            readonly property bool used: modelData === strip.inUse
                            readonly property int far: Math.abs(index - laneItem.laneCursor)
                            // only the ones on screen (and a little past) load their picture
                            readonly property bool near: far * (strip.thumbW + strip.gap) < strip.width

                            x: index * (strip.thumbW + strip.gap)
                            width: strip.thumbW
                            height: strip.hang + strip.thumbH
                            visible: near

                            // Arrives like a panel's items, from the marker outwards; leaves at once.
                            opacity: strip.contentShown ? (under ? 1 : 0.55) : 0
                            transform: Translate {
                                y: strip.contentShown ? 0 : -6

                                Behavior on y {
                                    SequentialAnimation {
                                        PauseAnimation { duration: strip.contentShown ? Anim.itemStart + Math.min(8, thumb.far) * Anim.stagger : 0 }
                                        NumberAnimation {
                                            duration: strip.contentShown ? Anim.base : Anim.exitFade
                                            easing.type: strip.contentShown ? Anim.easing : Easing.Linear
                                        }
                                    }
                                }
                            }
                            Behavior on opacity {
                                SequentialAnimation {
                                    PauseAnimation { duration: strip.contentShown && thumb.opacity === 0 ? Anim.itemStart + Math.min(8, thumb.far) * Anim.stagger : 0 }
                                    NumberAnimation { duration: strip.contentShown ? Anim.base : Anim.exitFade }
                                }
                            }

                            // The tick it hangs from (the picked one hangs from the marker instead).
                            Rectangle {
                                visible: !(thumb.under && laneItem.active)
                                x: strip.thumbW / 2
                                width: 1
                                height: strip.hang
                                color: thumb.used ? Theme.accent : Theme.borderStrong
                            }

                            Rectangle {
                                y: strip.hang
                                width: strip.thumbW
                                height: strip.thumbH
                                color: Theme.surface
                                border.width: 1
                                border.color: thumb.under && laneItem.active ? Theme.accent : thumb.used ? Theme.muted : Theme.border

                                Behavior on border.color {
                                    ColorAnimation { duration: Anim.hover }
                                }

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    source: !thumb.near ? "" : thumb.kind !== "video" ? "file://" + thumb.modelData
                                        : Frames.have[thumb.modelData] ? "file://" + Frames.of(thumb.modelData) : ""
                                    sourceSize.width: strip.thumbW * 2
                                    sourceSize.height: strip.thumbH * 2
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    opacity: status === Image.Ready ? 1 : 0

                                    Behavior on opacity {
                                        NumberAnimation { duration: Anim.base }
                                    }
                                }

                                // Moving ones say so, in a corner.
                                KindBadge {
                                    kind: thumb.kind
                                    x: 7
                                    y: parent.height - height - 7
                                }
                            }

                            TapHandler {
                                onTapped: {
                                    if (thumb.under && laneItem.active) {
                                        strip.set();
                                    } else {
                                        strip.lane = laneItem.index;
                                        strip.setCursor(thumb.index);
                                    }
                                }
                            }
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }

                // The marker, in the middle of its line: the same 14 x 3 accent bar as the workspace marker.
                Rectangle {
                    x: strip.width / 2 - 7
                    y: laneItem.y0 - 1
                    width: 14
                    height: 3
                    color: laneItem.active ? Theme.accent : Theme.borderStrong
                    opacity: strip.contentShown ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: Anim.base }
                    }
                }
                Rectangle {
                    x: strip.width / 2
                    y: laneItem.y0 + 2
                    width: 1
                    height: strip.hang - 2
                    color: laneItem.active ? Theme.accent : Theme.borderStrong
                    opacity: strip.contentShown ? 1 : 0
                }
            }
        }

        // Under the last line: the picked one's name, and whether it is the one in use.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: strip.lineY + (strip.lanes.length - 1) * strip.laneH + strip.hang + strip.thumbH + 14
            width: Math.min(implicitWidth, strip.width - 64)
            elide: Text.ElideMiddle
            textFormat: Text.StyledText
            text: strip.lanes.length === 0 ? "No wallpaper found in ~/Pictures/Wallpapers"
                : strip.picked.split("/").pop() + (strip.picked === strip.inUse ? "<font color=\"" + Theme.muted + "\">  ·  in use</font>" : "")
                    + "<font color=\"" + Theme.muted + "\">  ·  " + (strip.cursor + 1) + " / " + strip.files.length + "</font>"
            font.family: Theme.fontMono
            font.pixelSize: 11
            color: Theme.text
            opacity: strip.contentShown ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: strip.contentShown ? Anim.base : Anim.exitFade }
            }
        }
    }
}
