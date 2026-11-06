import QtQuick
import qs.modules.common
import qs.services

// Top-centre tile: clock and date. Notifications arrive here (toast) and it grows into the notifications panel.
Tile {
    id: tile

    required property string screenName

    anchorSide: "center"
    restW: 176
    toastW: 400
    toastH: 128
    openW: 400
    openH: 492

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
                font.pixelSize: 20
                font.weight: Font.DemiBold
                font.features: { "lnum": 1, "tnum": 1 }
                color: Theme.text
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDate(Time.now, "ddd d MMM")
                font.family: Theme.fontUi
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Theme.muted
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
            width: tile.openW
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

        // Notifications panel.
        Column {
            id: panel
            width: tile.openW
            topPadding: 12
            leftPadding: 12
            spacing: 4

            readonly property real inner: width - 24

            PanelItem {
                order: 0
                shown: tile.open
                width: panel.inner
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
                    text: "clear"
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    color: clearHover.hovered ? Theme.accent : Theme.muted

                    HoverHandler { id: clearHover }
                    TapHandler { onTapped: Notifs.clear() }
                }
            }

            PanelItem {
                visible: Notifs.list.length === 0
                order: 1
                shown: tile.open
                width: panel.inner
                height: visible ? 36 : 0

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

            Repeater {
                model: Notifs.list.slice(0, 3)

                PanelItem {
                    id: card

                    required property var modelData
                    required property int index

                    order: 1 + index
                    shown: tile.open
                    width: panel.inner
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

            PanelItem {
                order: 5
                shown: tile.open
                width: panel.inner
                height: calendar.implicitHeight + 18

                Rectangle {
                    y: 8
                    width: parent.width
                    height: 1
                    color: Theme.border
                }
                Calendar {
                    id: calendar
                    x: 4
                    y: 18
                    width: parent.width - 8
                }
            }
        }
    ]
}
