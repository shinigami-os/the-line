import QtQuick
import QtQuick.Shapes
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs.modules.common
import qs.services

// Top-right tile: a performance summary, then Wi-Fi, volume and battery. Selecting it opens quick settings. Grows into quick settings,
// the only place for power actions.
Tile {
    id: tile

    required property string screenName

    readonly property var battery: UPower.displayDevice
    readonly property int batteryPct: Math.round((battery?.percentage ?? 0) * 100)
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging
    readonly property int volumePct: Math.round((Audio.muted ? 0 : Audio.volume) * 100)
    readonly property bool volumeHot: LineState.gaugeKind === "vol"
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property int btConnected: btAdapter ? btAdapter.devices.values.filter(d => d.connected).length : 0

    function timeLeft() {
        const secs = charging ? (battery?.timeToFull ?? 0) : (battery?.timeToEmpty ?? 0);
        if (secs <= 0)
            return "";
        const h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60);
        return (h > 0 ? h + " h " : "") + m + " min";
    }

    anchorSide: "right"
    restW: 340
    openW: 360
    openH: 400
    mode: UiState.isOpen(screenName, "tr") ? "open" : "rest"

    // Top row: the whole row is the trigger. Scrolling on it changes the volume.
    Rectangle {
        anchors.fill: parent
        color: press.pressed ? Theme.surface2 : "transparent"

        Behavior on color {
            ColorAnimation { duration: Anim.press }
        }

        MouseArea {
            id: press
            anchors.fill: parent
            onClicked: UiState.toggle(tile.screenName, "tr")
        }
        WheelHandler {
            onWheel: event => Audio.step(event.angleDelta.y > 0 ? 0.02 : -0.02)
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            // Performance summary: CPU graph and CPU, swap and RAM load.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Shape {
                    id: cpuGraph

                    readonly property var points: SystemStats.cpuHistory.map((v, i) =>
                        Qt.point(i * width / (SystemStats.historyLength - 1), height - 1 - v * (height - 2)))

                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 16
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: 1
                        strokeColor: Theme.accent
                        fillColor: "transparent"

                        PathPolyline {
                            path: cpuGraph.points
                        }
                    }
                }

                Repeater {
                    model: [
                        { label: "CPU", value: SystemStats.cpu },
                        { label: "SWAP", value: SystemStats.swap },
                        { label: "RAM", value: SystemStats.ram }
                    ]

                    Column {
                        required property var modelData

                        anchors.verticalCenter: parent.verticalCenter
                        width: 30

                        Text {
                            text: parent.modelData.label
                            font.family: Theme.fontUi
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.6
                            color: Theme.muted
                        }
                        Text {
                            text: Math.round(parent.modelData.value * 100) + "%"
                            font.family: Theme.fontMono
                            font.pixelSize: 12
                            color: Theme.text
                        }
                    }
                }
            }

            // Separator between the summary and the status icons.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 22
                color: Theme.border
            }

            // Wi-Fi
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 12
                path: "M1 4.2a10 10 0 0 1 14 0M3.4 6.8a6.6 6.6 0 0 1 9.2 0M5.8 9.3a3.2 3.2 0 0 1 4.4 0"
                color: Network.connected ? Theme.text : Theme.muted

                Rectangle {
                    x: 7.3
                    y: 10.6
                    width: 1.4
                    height: 1.4
                    color: parent.color
                }
            }

            // Volume
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 12
                    path: Audio.muted ? "M1 4h3l4-3v10L4 8H1z" : "M1 4h3l4-3v10L4 8H1zM10.5 3.5a3.5 3.5 0 0 1 0 5"
                    color: Audio.muted ? Theme.muted : Theme.text
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tile.volumePct
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                    color: tile.volumeHot ? Theme.accent : (Audio.muted ? Theme.muted : Theme.text)

                    Behavior on color {
                        ColorAnimation { duration: Anim.base }
                    }
                }
            }

            // Battery
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 11

                    Rectangle {
                        width: 18
                        height: 11
                        color: "transparent"
                        border.width: 1
                        border.color: tile.charging ? Theme.accent : Theme.text
                    }
                    Rectangle {
                        x: 18
                        y: 3.5
                        width: 1.5
                        height: 4
                        color: tile.charging ? Theme.accent : Theme.text
                    }
                    Rectangle {
                        x: 2
                        y: 2
                        width: 14 * Math.max(0, Math.min(1, tile.batteryPct / 100))
                        height: 7
                        color: tile.batteryPct <= 15 && !tile.charging ? Theme.error : (tile.charging ? Theme.accent : Theme.text)
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tile.batteryPct
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                    color: Theme.text
                }
            }
        }
    }

    bodyData: [
        Column {
            id: panel

            x: 13
            y: 12
            width: tile.openW - 26
            spacing: 8

            PanelItem {
                order: 0
                shown: tile.open
                width: panel.width
                height: 104

                Grid {
                    columns: 2
                    spacing: 8

                    Toggle {
                        width: (panel.width - 8) / 2
                        label: "Wi-Fi"
                        sub: Network.label
                        on: Network.wifiEnabled
                        onClicked: Network.setWifi(!Network.wifiEnabled)
                    }
                    Toggle {
                        width: (panel.width - 8) / 2
                        label: "Bluetooth"
                        sub: !tile.btAdapter ? "no adapter" : (tile.btAdapter.enabled ? (tile.btConnected > 0 ? "on · " + tile.btConnected + (tile.btConnected === 1 ? " device" : " devices") : "on · no device") : "off")
                        on: tile.btAdapter?.enabled ?? false
                        onClicked: if (tile.btAdapter) tile.btAdapter.enabled = !tile.btAdapter.enabled
                    }
                    Toggle {
                        width: (panel.width - 8) / 2
                        label: "Night light"
                        sub: NightLight.label
                        on: NightLight.on
                        onClicked: NightLight.toggle()
                    }
                    Toggle {
                        width: (panel.width - 8) / 2
                        label: "Do not disturb"
                        sub: Notifs.dnd ? "on · line only" : "off"
                        on: Notifs.dnd
                        onClicked: Notifs.dnd = !Notifs.dnd
                    }
                }
            }

            PanelItem {
                order: 2
                shown: tile.open
                width: panel.width
                height: 36

                Text {
                    x: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Volume"
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Theme.text
                }
                LineSlider {
                    x: 94
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 94 - 44
                    value: Audio.muted ? 0 : Audio.volume
                    onMoved: v => Audio.setVolume(v)
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: tile.volumePct
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                    color: Theme.text
                }
            }

            PanelItem {
                order: 3
                shown: tile.open
                width: panel.width
                height: 36

                Text {
                    x: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Brightness"
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Theme.text
                }
                LineSlider {
                    x: 94
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 94 - 44
                    value: Brightness.value
                    onMoved: v => Brightness.set(v)
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(Brightness.value * 100)
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                    color: Theme.text
                }
            }

            PanelItem {
                order: 4
                shown: tile.open
                width: panel.width
                height: 44

                Toggle {
                    width: parent.width
                    compact: true
                    label: "Reduce motion"
                    sub: Config.reduceMotion ? "on" : "off"
                    on: Config.reduceMotion
                    onClicked: Config.setReduceMotion(!Config.reduceMotion)
                }
            }

            // Power lives here and nowhere else.
            PanelItem {
                order: 5
                shown: tile.open
                width: panel.width
                height: 40

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.border

                    Row {
                        anchors.fill: parent

                        Repeater {
                            model: [
                                { label: "Lock", danger: false },
                                { label: "Log out", danger: false },
                                { label: "Restart", danger: false },
                                { label: "Power off", danger: true }
                            ]

                            Rectangle {
                                id: cell

                                required property var modelData
                                required property int index

                                width: parent.width / 4
                                height: parent.height
                                color: cellHover.hovered ? Theme.surface2 : "transparent"

                                Behavior on color {
                                    ColorAnimation { duration: Anim.hover }
                                }

                                Rectangle {
                                    visible: cell.index > 0
                                    width: 1
                                    height: parent.height
                                    color: Theme.border
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: cell.modelData.label
                                    font.family: Theme.fontUi
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: cell.modelData.danger ? Theme.error : Theme.text
                                }
                                HoverHandler {
                                    id: cellHover
                                }
                                TapHandler {
                                    onTapped: [Power.lock, Power.logout, Power.restart, Power.poweroff][cell.index]()
                                }
                            }
                        }
                    }
                }
            }

            PanelItem {
                order: 6
                shown: tile.open
                width: panel.width
                height: 20

                Text {
                    x: 4
                    text: "battery " + tile.batteryPct + "%" + (tile.timeLeft() !== "" ? " · " + tile.timeLeft() + (tile.charging ? " to full" : " left") : (tile.charging ? " · charging" : ""))
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    color: Theme.muted
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    text: "Super A"
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    color: Theme.muted
                }
            }
        }
    ]
}
