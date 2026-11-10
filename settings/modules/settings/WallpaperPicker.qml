import QtQuick
import Quickshell
import qs.modules.common
import qs.services

// Settings > Appearance > Wallpaper: thumbnails of The Line's wallpapers (assets/wallpapers), Kira's, and yours
// (~/Pictures/Wallpapers, ~/.local/share/wallpapers): pictures, animated GIFs and videos (mp4, webm, mkv, mov).
// With several screens, a line on top picks where it goes: every screen, or one (its own wallpaper).
// ←→ (and ↑↓ inside the grid) move the cursor, Enter sets it, Tab / Shift+Tab change the screen; a click sets it at once.
Item {
    id: picker

    property bool active: false
    property int cursor: 0
    readonly property var files: Wallpapers.files
    property string screen: ""     // "" = every screen
    readonly property var screens: [""].concat(Quickshell.screens.map(s => s.name))
    readonly property string shownPath: screen === "" ? Config.wallpaper : Config.wallpaperFor(screen)
    readonly property int columns: Math.max(1, Math.floor((width + gap) / (thumbW + gap)))
    readonly property int thumbW: 168
    readonly property int thumbH: 95
    readonly property int gap: 12
    readonly property int gridY: screens.length > 2 ? 34 : 0

    signal picked

    implicitHeight: gridY + grid.implicitHeight + 26
    // for the view to keep the cursor's line of thumbnails shown
    readonly property real cursorY: gridY + Math.floor(cursor / columns) * (thumbH + gap)
    readonly property real cursorH: thumbH + 24

    onShownPathChanged: cursor = Math.max(0, files.indexOf(shownPath))

    function set(path) {
        Accent.setWallpaper(path, screen);
    }

    function key(event) {
        const k = event.key;
        const n = files.length;
        if ((k === Qt.Key_Tab || k === Qt.Key_Backtab) && screens.length > 2) {
            const i = screens.indexOf(screen);
            screen = screens[(i + (k === Qt.Key_Backtab ? -1 : 1) + screens.length) % screens.length];
            return true;
        }
        if (n === 0)
            return false;
        if (k === Qt.Key_Left || k === Qt.Key_Right) {
            cursor = (cursor + (k === Qt.Key_Left ? -1 : 1) + n) % n;
            return true;
        }
        // ↑↓ move a line inside the grid; past its first or last line they leave the row
        if (k === Qt.Key_Up && cursor - columns >= 0) {
            cursor -= columns;
            return true;
        }
        if (k === Qt.Key_Down && cursor + columns < n) {
            cursor += columns;
            return true;
        }
        if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            set(files[cursor]);
            return true;
        }
        return false;
    }

    Component.onCompleted: Wallpapers.refresh()

    Connections {
        target: Wallpapers

        function onFilesChanged() {
            picker.cursor = Math.max(0, picker.files.indexOf(picker.shownPath));
        }
    }

    // Where it goes: every screen, or one of them. A screen with its own wallpaper is marked.
    Row {
        visible: picker.screens.length > 2
        spacing: 18

        Repeater {
            model: picker.screens

            Item {
                id: chip

                required property string modelData
                readonly property bool current: modelData === picker.screen
                readonly property bool own: modelData !== "" && (Config.wallpapers ?? {})[modelData] !== undefined

                width: label.implicitWidth
                height: 24

                Text {
                    id: label
                    anchors.verticalCenter: parent.verticalCenter
                    text: (chip.modelData === "" ? "Every screen" : chip.modelData)
                        + (chip.modelData !== "" && chip.modelData === Config.primaryScreen ? " · primary" : "")
                        + (chip.own ? " ·  own" : "")
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

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: {
                        picker.picked();
                        picker.screen = chip.modelData;
                    }
                }
            }
        }
    }

    Flow {
        id: grid

        y: picker.gridY
        width: parent.width
        spacing: picker.gap

        Repeater {
            model: picker.files

            Item {
                id: thumb

                required property string modelData
                required property int index
                readonly property string kind: Config.wallpaperKind(modelData)
                readonly property bool current: modelData === picker.shownPath
                readonly property bool under: picker.active && index === picker.cursor

                width: picker.thumbW
                height: picker.thumbH

                // A video shows its still frame (Frames), once made; a GIF its first frame.
                Image {
                    anchors.fill: parent
                    anchors.margins: 3
                    source: thumb.kind !== "video" ? "file://" + thumb.modelData
                        : Frames.have[thumb.modelData] ? "file://" + Frames.of(thumb.modelData) : ""
                    sourceSize.width: picker.thumbW * 2
                    sourceSize.height: picker.thumbH * 2
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
                    x: 8
                    y: parent.height - height - 8
                }

                // The cursor: a white frame; the wallpaper in use: an accent frame and a tick under it.
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 1
                    border.color: thumb.current ? Theme.accent : thumb.under ? Theme.text : Theme.border

                    Behavior on border.color {
                        ColorAnimation { duration: Anim.hover }
                    }
                }
                Rectangle {
                    visible: thumb.current
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height + 4
                    width: 18
                    height: 2
                    color: Theme.accent
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: if (hovered && Registry.hoverPicks()) picker.cursor = thumb.index
                }
                TapHandler {
                    onTapped: {
                        picker.picked();
                        picker.cursor = thumb.index;
                        picker.set(thumb.modelData);
                    }
                }
            }
        }
    }

    // The file under the cursor.
    Text {
        y: picker.gridY + grid.implicitHeight + 10
        text: picker.files.length === 0 ? "No wallpaper found" : picker.files[picker.cursor].replace(Quickshell.env("HOME"), "~")
        font.family: Theme.fontMono
        font.pixelSize: 10
        color: Theme.muted
    }
}
