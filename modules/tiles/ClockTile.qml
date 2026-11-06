import QtQuick
import qs.modules.common
import qs.services

// Top-centre tile: clock and date. Notifications arrive here (toast) and it grows into the notifications panel.
Tile {
    id: tile

    required property string screenName

    anchorSide: "center"
    restW: 152
    toastW: LineState.toastW
    toastH: LineState.toastH
    openW: 720
    openH: Theme.tileHeight + 380

    // While the pulse draws this tile, the frame is exactly where the dashes are: the width grows as they run out
    // along the line, the height as they run down the sides. The fill follows fillLag behind.
    function frameW(ms) {
        const r = Math.max(0, ms - Anim.pulse) / Anim.pulseWrap * LineState.wrapTotal;
        return 2 * Math.min(toastW / 2, Math.max(restW / 2, 56 + r));
    }

    function frameH(ms) {
        const r = Math.max(0, ms - Anim.pulse) / Anim.pulseWrap * LineState.wrapTotal;
        return Math.min(toastH, Math.max(restH, r - (toastW / 2 - 56.5) + 1));
    }

    driven: LineState.pulseActive && LineState.pulseAround && mode !== "open"
    drivenW: frameW(LineState.pulseMs)
    drivenH: frameH(LineState.pulseMs)
    drivenFillW: frameW(LineState.pulseMs - Anim.fillLag)
    drivenFillH: frameH(LineState.pulseMs - Anim.fillLag)

    mode: UiState.isOpen(screenName, "tc") ? "open" : (Notifs.toast ? "toast" : "rest")

    // Top row: the clock is a button.
    Rectangle {
        anchors.fill: parent
        color: press.pressed ? Theme.surface2 : "transparent"

        Behavior on color {
            ColorAnimation { duration: Anim.press }
        }

        MouseArea {
            id: press
            anchors.fill: parent
            onClicked: UiState.toggle(tile.screenName, "tc")
        }

        Row {
            anchors.centerIn: parent
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatTime(Time.now, "HH:mm:ss")
                font.family: Theme.fontUi
                font.pixelSize: 17
                font.weight: Font.DemiBold
                color: Theme.text
            }
            // Short date at rest; written out in full while the panel is open.
            Item {
                id: dateBox

                anchors.verticalCenter: parent.verticalCenter
                width: tile.open ? longDate.implicitWidth : shortDate.implicitWidth
                height: shortDate.implicitHeight
                clip: true

                Behavior on width {
                    NumberAnimation { duration: Anim.panel; easing.type: Anim.easing }
                }

                Text {
                    id: shortDate
                    text: Qt.formatDate(Time.now, "ddd d MMM")
                    font.family: Theme.fontUi
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Theme.muted
                    opacity: tile.open ? 0 : 1

                    Behavior on opacity {
                        NumberAnimation { duration: Anim.base }
                    }
                }
                Text {
                    id: longDate
                    text: Qt.formatDate(Time.now, "dddd d MMMM yyyy")
                    font.family: Theme.fontUi
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Theme.muted
                    opacity: tile.open ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: Anim.base }
                    }
                }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: Notifs.unread > 0 && !tile.open
                width: Math.max(16, badgeText.implicitWidth + 8)
                height: 16
                color: Theme.accent

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: Notifs.unread
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    color: Theme.accentText
                }
            }
        }
    }

    bodyData: [
        // Toast: one block, fades in after the tile starts dropping.
        Item {
            id: toastBlock
            x: (tile.openW - tile.toastW) / 2
            width: tile.toastW
            opacity: tile.mode === "toast" ? 1 : 0

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: tile.mode === "toast" ? Anim.toastContent : 0 }
                    NumberAnimation {
                        duration: tile.mode === "toast" ? Anim.base : Anim.exitFade
                        easing.type: tile.mode === "toast" ? Anim.easing : Easing.Linear
                    }
                }
            }

            Column {
                x: 16
                y: 12
                width: parent.width - 32
                spacing: 3

                Item {
                    width: parent.width
                    height: 14

                    Text {
                        text: Notifs.lastToast?.app ?? ""
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        color: Theme.muted
                    }
                    Text {
                        anchors.right: parent.right
                        text: Notifs.lastToast?.time ?? ""
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        color: Theme.muted
                    }
                }
                Text {
                    width: parent.width
                    text: Notifs.lastToast?.title ?? ""
                    font.family: Theme.fontUi
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Theme.text
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: Notifs.lastToast?.body ?? ""
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.muted
                    elide: Text.ElideRight
                }
            }
        },

        // Left half: analog clock, calendar under it.
        Item {
            id: leftHalf
            width: 300
            height: parent.height

            PanelItem {
                order: 0
                shown: tile.open
                x: (leftHalf.width - width) / 2
                y: 12
                width: 140
                height: 140

                AnalogClock {
                    size: 140
                }
            }

            PanelItem {
                order: 2
                shown: tile.open
                x: 12
                y: 164
                width: leftHalf.width - 24
                height: calendar.implicitHeight + 18

                Rectangle {
                    y: 0
                    width: parent.width
                    height: 1
                    color: Theme.border
                }
                Calendar {
                    id: calendar
                    x: 4
                    y: 10
                    width: parent.width - 8
                }
            }
        },

        // The cut: a vertical divider between the two halves.
        PanelItem {
            order: 1
            shown: tile.open
            x: 300
            width: 1
            height: parent.height

            Rectangle {
                anchors.fill: parent
                color: Theme.border
            }
        },

        // Right half: notification centre, controls at the bottom.
        Item {
            id: rightHalf
            x: 301
            width: tile.openW - 301
            height: parent.height

            readonly property real inner: width - 24

            PanelItem {
                order: 1
                shown: tile.open
                x: 12
                y: 12
                width: rightHalf.inner
                height: 28

                Text {
                    y: 4
                    x: 4
                    text: "NOTIFICATIONS"
                    font.family: Theme.fontUi
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.9
                    color: Theme.muted
                }
                Text {
                    y: 4
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    text: Notifs.list.length + (Notifs.list.length === 1 ? " item" : " items")
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    color: Theme.muted
                }
            }

            PanelItem {
                visible: Notifs.list.length === 0
                order: 2
                shown: tile.open
                x: 12
                y: 44
                width: rightHalf.inner
                height: 36

                Text {
                    x: 4
                    y: 10
                    text: "Nothing new."
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.muted
                }
            }

            Column {
                x: 12
                y: 44
                width: rightHalf.inner
                spacing: 4

                Repeater {
                    model: Notifs.list.slice(0, 4)

                    PanelItem {
                        id: card

                        required property var modelData
                        required property int index

                        order: 2 + index
                        shown: tile.open
                        width: rightHalf.inner
                        height: cardCol.implicitHeight + 18

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: 1
                            border.color: card.modelData.read ? Theme.border : Theme.borderStrong
                        }

                        Column {
                            id: cardCol
                            x: 10
                            y: 9
                            width: parent.width - 20
                            spacing: 2

                            Item {
                                width: parent.width
                                height: 14

                                Text {
                                    text: card.modelData.app
                                    font.family: Theme.fontMono
                                    font.pixelSize: 11
                                    color: Theme.muted
                                }
                                Text {
                                    anchors.right: parent.right
                                    text: card.modelData.time
                                    font.family: Theme.fontMono
                                    font.pixelSize: 11
                                    color: Theme.muted
                                }
                            }
                            Text {
                                width: parent.width
                                text: card.modelData.title
                                font.family: Theme.fontUi
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: Theme.text
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: card.modelData.body
                                font.family: Theme.fontUi
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: Theme.muted
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            // Controls: do not disturb, clear all.
            PanelItem {
                order: 6
                shown: tile.open
                x: 12
                y: rightHalf.height - 12 - 36
                width: rightHalf.inner
                height: 36

                Row {
                    spacing: 8

                    Rectangle {
                        width: (rightHalf.inner - 8) / 2
                        height: 36
                        border.width: 1
                        border.color: Notifs.dnd ? Theme.accent : (dndHover.hovered ? Theme.borderStrong : Theme.border)
                        color: Notifs.dnd ? Theme.accentTint : "transparent"

                        Behavior on border.color {
                            ColorAnimation { duration: Anim.base }
                        }
                        Behavior on color {
                            ColorAnimation { duration: Anim.base }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Notifs.dnd ? "Do not disturb · on" : "Do not disturb"
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Theme.text
                        }
                        HoverHandler { id: dndHover }
                        TapHandler { onTapped: Notifs.dnd = !Notifs.dnd }
                    }

                    Rectangle {
                        width: (rightHalf.inner - 8) / 2
                        height: 36
                        border.width: 1
                        border.color: clearHover.hovered ? Theme.borderStrong : Theme.border
                        color: "transparent"

                        Behavior on border.color {
                            ColorAnimation { duration: Anim.hover }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Clear all"
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: clearHover.hovered ? Theme.accent : Theme.text
                        }
                        HoverHandler { id: clearHover }
                        TapHandler { onTapped: Notifs.clear() }
                    }
                }
            }
        }
    ]
}
