import QtQuick
import qs.services

// A dialog grown from the line: the screen dims, a line draws itself across its middle from both edges, then a box
// opens on it, up and down at once (frame first, fill after), and its content arrives like a tile's panel.
// Closing keeps the same order: the content leaves, the line withdraws, then the box folds away.
// The power menu and the polkit agent use it.
Item {
    id: dialog

    property bool open: false
    property real boxWidth: 460
    property real boxHeight: 240
    default property alias content: body.data

    // A click outside the box: the sheet closes on it, the polkit dialog doesn't.
    signal outsideClicked

    // The content's own "shown", for PanelItems inside: true once the box has started to open.
    property bool contentShown: false

    readonly property int lineDraw: Math.round(Anim.panel * 1.6)
    readonly property real mid: Math.round(height / 2)

    visible: open || reach > 0 || box.height > 0

    property real reach: open ? 1 : 0
    Behavior on reach {
        SequentialAnimation {
            PauseAnimation { duration: dialog.open ? 0 : Anim.exitFade }
            NumberAnimation { duration: dialog.lineDraw; easing.type: Anim.easing }
        }
    }

    onOpenChanged: {
        if (open) {
            contentTimer.restart();
        } else {
            contentTimer.stop();
            contentShown = false;
        }
    }

    Timer {
        id: contentTimer
        interval: Math.round(dialog.lineDraw * 0.6)
        onTriggered: dialog.contentShown = true
    }

    // Dims the screen and keeps clicks away from the windows below.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: dialog.open ? 0.45 : 0

        Behavior on opacity {
            NumberAnimation { duration: Anim.panel }
        }

        MouseArea {
            anchors.fill: parent
            enabled: dialog.open
            onClicked: dialog.outsideClicked()
        }
    }

    // The line, one half from each edge of the screen.
    Rectangle {
        x: 0
        y: dialog.mid
        width: Math.ceil(dialog.width / 2 * dialog.reach)
        height: 1
        color: Theme.borderStrong
    }
    Rectangle {
        x: dialog.width - width
        y: dialog.mid
        width: Math.ceil(dialog.width / 2 * dialog.reach)
        height: 1
        color: Theme.borderStrong
    }

    // The box: grows up and down from the line, the outline leading the fill.
    Item {
        id: box

        x: (dialog.width - dialog.boxWidth) / 2
        width: dialog.boxWidth
        height: dialog.open ? dialog.boxHeight : 0
        y: dialog.mid - height / 2
        clip: true

        Behavior on height {
            SequentialAnimation {
                PauseAnimation { duration: dialog.open ? Math.round(dialog.lineDraw * 0.6) : Anim.exitFade + Math.round(dialog.lineDraw * 0.6) }
                NumberAnimation { duration: Anim.panel; easing.type: Anim.easing }
            }
        }

        Rectangle {
            id: fill
            width: parent.width
            height: dialog.open ? dialog.boxHeight : 0
            y: (box.height - height) / 2
            color: Theme.surface

            Behavior on height {
                SequentialAnimation {
                    PauseAnimation { duration: dialog.open ? Math.round(dialog.lineDraw * 0.6) + Anim.fillLag : Anim.exitFade + Math.round(dialog.lineDraw * 0.6) }
                    NumberAnimation { duration: Anim.panel; easing.type: Anim.easing }
                }
            }
        }

        // The content is laid out at the full size and revealed by the box.
        Item {
            id: body
            y: (box.height - dialog.boxHeight) / 2
            width: dialog.boxWidth
            height: dialog.boxHeight
            enabled: dialog.open
        }

        Rectangle { width: parent.width; height: 1; color: Theme.borderStrong }
        Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: Theme.borderStrong }
        Rectangle { width: 1; height: parent.height; color: Theme.borderStrong }
        Rectangle { x: parent.width - 1; width: 1; height: parent.height; color: Theme.borderStrong }
    }
}
