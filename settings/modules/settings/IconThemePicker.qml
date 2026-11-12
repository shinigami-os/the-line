import QtQuick
import TheLine.Ui
import qs.services

// Settings > Appearance > Icon theme: the theme in use, ← → to step through the installed ones (IconThemes).
// "automatic" is The Line's pick: Papirus-Dark, else Papirus, Breeze Dark, Adwaita (session/the-line-app-theme).
Item {
    id: picker

    property var setting
    property bool active: false

    signal picked

    readonly property var list: IconThemes.choices
    readonly property int index: Math.max(0, list.findIndex(c => c.value === Config.iconTheme))

    implicitHeight: 32

    function step(by) {
        Config.set("iconTheme", list[(index + by + list.length) % list.length].value);
    }

    function key(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            step(event.key === Qt.Key_Left ? -1 : 1);
            return true;
        }
        return false;
    }

    Row {
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Text {
            text: "‹"
            font.family: Theme.fontMono
            font.pixelSize: 13
            color: picker.active ? Theme.text : Theme.muted

            TapHandler {
                onTapped: {
                    picker.picked();
                    picker.step(-1);
                }
            }
        }
        Text {
            text: (picker.list[picker.index]?.label ?? "automatic") + "  " + (picker.index + 1) + "/" + picker.list.length
            font.family: Theme.fontMono
            font.pixelSize: 11
            color: Theme.text
        }
        Text {
            text: "›"
            font.family: Theme.fontMono
            font.pixelSize: 13
            color: picker.active ? Theme.text : Theme.muted

            TapHandler {
                onTapped: {
                    picker.picked();
                    picker.step(1);
                }
            }
        }
    }
}
