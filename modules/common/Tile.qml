import QtQuick
import qs.services

// A tile that grows into a panel. Four layers:
//   fill    surface-coloured rectangle with its own size, so it can lag behind the frame
//   topRow  the always-visible tile content (default children go here)
//   rule    1px divider under the top row, drawn from the anchor side
//   body    the panel content, fixed at the open width and revealed by the frame (bodyData)
// The frame is this item: it clips, has no top border (the line is the top edge) and leads the fill.
Item {
    id: tile

    property string anchorSide: "left"   // left | center | right
    property string mode: "rest"         // rest | toast | open
    property real margin: 16

    property real restW: 176
    property real restH: 52
    property real toastW: restW
    property real toastH: restH
    property real openW: restW
    property real openH: restH

    // When driven, the frame and the fill take these sizes directly (no animation of their own).
    property bool driven: false
    property real drivenW: restW
    property real drivenH: restH
    property real drivenFillW: restW
    property real drivenFillH: restH

    readonly property bool open: mode === "open"
    readonly property real targetW: mode === "open" ? openW : (mode === "toast" ? toastW : restW)
    readonly property real targetH: mode === "open" ? openH : (mode === "toast" ? toastH : restH)

    default property alias topData: topRow.data
    property alias bodyData: body.data

    property bool bodyVisible: false
    property color borderColor: hover.hovered ? Theme.borderStrong : Theme.border

    function _sideX(w) {
        return anchorSide === "left" ? 0 : (anchorSide === "right" ? tile.width - w : (tile.width - w) / 2);
    }

    y: 10
    x: anchorSide === "left" ? margin : (anchorSide === "right" ? parent.width - margin - width : (parent.width - width) / 2)
    width: driven ? drivenW : targetW
    height: driven ? drivenH : targetH
    clip: true

    // Frame: no pause when opening, a short lead when closing so the content leaves first.
    Behavior on width {
        enabled: !tile.driven
        SequentialAnimation {
            PauseAnimation { duration: tile.mode === "rest" ? Anim.closeLead : 0 }
            NumberAnimation { duration: Anim.panel; easing.type: Anim.easing }
        }
    }
    Behavior on height {
        enabled: !tile.driven
        SequentialAnimation {
            PauseAnimation { duration: tile.mode === "rest" ? Anim.closeLead : 0 }
            NumberAnimation { duration: Anim.panel; easing.type: Anim.easing }
        }
    }
    Behavior on borderColor {
        ColorAnimation { duration: Anim.hover }
    }

    onModeChanged: {
        if (mode !== "rest") {
            hideTimer.stop();
            bodyVisible = true;
        } else {
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: Anim.panel
        onTriggered: tile.bodyVisible = false
    }

    HoverHandler {
        id: hover
    }

    Rectangle {
        id: fill
        color: Theme.surface
        width: tile.driven ? tile.drivenFillW : tile.targetW
        height: tile.driven ? tile.drivenFillH : tile.targetH
        x: tile._sideX(width)

        Behavior on width {
            enabled: !tile.driven
            SequentialAnimation {
                PauseAnimation { duration: tile.mode === "rest" ? Anim.closeLead : Anim.fillLag }
                NumberAnimation { duration: Anim.panel; easing.type: Anim.easing }
            }
        }
        Behavior on height {
            enabled: !tile.driven
            SequentialAnimation {
                PauseAnimation { duration: tile.mode === "rest" ? Anim.closeLead : Anim.fillLag }
                NumberAnimation { duration: Anim.panel; easing.type: Anim.easing }
            }
        }
    }

    Item {
        id: topRow
        width: tile.restW
        height: 51
        x: tile._sideX(width)
    }

    Rectangle {
        id: rule
        y: 51
        width: tile.width
        height: 1
        color: Theme.border

        transform: Scale {
            origin.x: tile.anchorSide === "left" ? 0 : (tile.anchorSide === "right" ? rule.width : rule.width / 2)
            xScale: tile.mode === "rest" ? 0 : 1

            Behavior on xScale {
                SequentialAnimation {
                    PauseAnimation { duration: tile.mode === "rest" ? 0 : Anim.ruleDelay }
                    NumberAnimation { duration: Anim.panel; easing.type: Anim.easing }
                }
            }
        }
    }

    Item {
        id: body
        y: 52
        width: tile.openW
        height: tile.openH - 52
        x: tile._sideX(width)
        visible: tile.bodyVisible
        enabled: tile.mode !== "rest"
    }

    // Borders: left, right and bottom, on top of everything.
    Rectangle { x: 0; width: 1; height: parent.height; color: tile.borderColor }
    Rectangle { x: parent.width - 1; width: 1; height: parent.height; color: tile.borderColor }
    Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: tile.borderColor }
}
