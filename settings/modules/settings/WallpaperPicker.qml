import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Settings > Appearance > Wallpaper: thumbnails of Kira's wallpapers and yours (~/Pictures/Wallpapers,
// ~/.local/share/wallpapers). ←→ (and ↑↓ inside the grid) move the cursor, Enter sets it; a click sets it at once.
Item {
    id: picker

    property bool active: false
    property int cursor: 0
    property var files: []
    readonly property int columns: Math.max(1, Math.floor((width + gap) / (thumbW + gap)))
    readonly property int thumbW: 168
    readonly property int thumbH: 95
    readonly property int gap: 12

    signal picked

    implicitHeight: grid.implicitHeight + 26

    function key(event) {
        const k = event.key;
        const n = files.length;
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
            Accent.setWallpaper(files[cursor]);
            return true;
        }
        return false;
    }

    Process {
        running: true
        command: ["sh", "-c", "for d in /usr/share/kira/wallpapers \"$HOME/Pictures/Wallpapers\" \"$HOME/.local/share/wallpapers\"; do "
            + "find \"$d\" -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) 2>/dev/null | sort; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                picker.files = text.split("\n").filter(f => f !== "");
                const i = picker.files.indexOf(Config.wallpaper);
                picker.cursor = Math.max(0, i);
            }
        }
    }

    Flow {
        id: grid

        width: parent.width
        spacing: picker.gap

        Repeater {
            model: picker.files

            Item {
                id: thumb

                required property string modelData
                required property int index
                readonly property bool current: modelData === Config.wallpaper
                readonly property bool under: picker.active && index === picker.cursor

                width: picker.thumbW
                height: picker.thumbH

                Image {
                    anchors.fill: parent
                    anchors.margins: 3
                    source: "file://" + thumb.modelData
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
                    onHoveredChanged: if (hovered) picker.cursor = thumb.index
                }
                TapHandler {
                    onTapped: {
                        picker.picked();
                        picker.cursor = thumb.index;
                        Accent.setWallpaper(thumb.modelData);
                    }
                }
            }
        }
    }

    // The file under the cursor.
    Text {
        y: grid.implicitHeight + 10
        text: picker.files.length === 0 ? "No wallpaper found" : picker.files[picker.cursor].replace(Quickshell.env("HOME"), "~")
        font.family: Theme.fontMono
        font.pixelSize: 10
        color: Theme.muted
    }
}
