import QtQuick
import QtQuick.Shapes
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs.modules.common
import qs.services

// Top-right tile: a performance summary and the system status, both as labelled readings.
// The summary grows into the performance dashboard, the status into quick settings (the only place for power actions). Grows into quick settings,
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

    // Which panel is open on this screen: "tr" quick settings, "tp" performance.
    readonly property string kind: UiState.isOpen(screenName, "tr") ? "tr" : (UiState.isOpen(screenName, "tp") ? "tp" : "")

    anchorSide: "right"
    // Rest width from the compact readings, so it doesn't follow the expansion while closing.
    restW: 12 + 36 + 10 + cpuR.compactWidth + 10 + swapR.compactWidth + 10 + ramR.compactWidth
        + 12 + 1 + 12 + netR.compactWidth + 10 + volR.compactWidth + 10 + batR.compactWidth + 12
    openW: kind === "tp" ? 460 : 400
    openH: Theme.tileHeight + (kind === "tp" ? 12 + performance.implicitHeight + 12 : 348)
    mode: kind !== "" ? "open" : "rest"

    Binding {
        target: SystemStats
        property: "watching"
        value: tile.kind === "tp"
    }

    // Top row: two groups of readings. The summary opens the performance dashboard, the status group opens
    // quick settings. While a panel is open, its group writes its readings out in full.
    Item {
        anchors.fill: parent

        MouseArea {
            id: perfArea
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: row.x + sep.x + sep.width / 2
            onClicked: UiState.toggle(tile.screenName, "tp")

            Rectangle {
                anchors.fill: parent
                z: -1
                color: perfArea.pressed ? Theme.surface2 : "transparent"

                Behavior on color {
                    ColorAnimation { duration: Anim.press }
                }
            }
        }
        MouseArea {
            id: statusArea
            anchors.left: perfArea.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            onClicked: UiState.toggle(tile.screenName, "tr")

            Rectangle {
                anchors.fill: parent
                z: -1
                color: statusArea.pressed ? Theme.surface2 : "transparent"

                Behavior on color {
                    ColorAnimation { duration: Anim.press }
                }
            }

            // Scrolling over the status group changes the volume.
            WheelHandler {
                onWheel: event => Audio.step((event.angleDelta.y > 0 ? 1 : -1) * Config.levelStep / 100)
            }
        }

        Row {
            id: row
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            // Performance: CPU graph, then CPU, swap and RAM.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Shape {
                    id: cpuGraph

                    readonly property int samples: tile.kind === "tp" ? 48 : 24
                    readonly property var points: SystemStats.cpuHistory.slice(-samples).map((v, i) =>
                        Qt.point(i * width / (samples - 1), height - 1 - v * (height - 2)))

                    anchors.verticalCenter: parent.verticalCenter
                    width: tile.kind === "tp" ? 80 : 36
                    height: 14
                    preferredRendererType: Shape.CurveRenderer

                    Behavior on width {
                        NumberAnimation { duration: Anim.panel; easing.type: Anim.easing }
                    }

                    ShapePath {
                        strokeWidth: 1
                        strokeColor: Theme.accent
                        fillColor: "transparent"

                        PathPolyline {
                            path: cpuGraph.points
                        }
                    }
                }

                Reading {
                    id: cpuR
                    anchors.verticalCenter: parent.verticalCenter
                    label: "CPU"
                    value: Math.round(SystemStats.cpu * 100) + "%"
                }
                Reading {
                    id: swapR
                    anchors.verticalCenter: parent.verticalCenter
                    label: "SWAP"
                    value: Math.round(SystemStats.swap * 100) + "%"
                    wide: SystemStats.formatKiB(SystemStats.swapUsedKiB)
                    expanded: tile.kind === "tp"
                }
                Reading {
                    id: ramR
                    anchors.verticalCenter: parent.verticalCenter
                    label: "RAM"
                    value: Math.round(SystemStats.ram * 100) + "%"
                    wide: SystemStats.formatKiB(SystemStats.ramUsedKiB) + " / " + SystemStats.formatKiB(SystemStats.ramTotalKiB)
                    expanded: tile.kind === "tp"
                }
            }

            Rectangle {
                id: sep
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 22
                color: Theme.border
            }

            // Status: network (signal drawn as ruler ticks), volume, battery.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Reading {
                    id: netR
                    anchors.verticalCenter: parent.verticalCenter
                    label: "NET"
                    value: Network.wifiEnabled ? (Network.connected ? "" : "--") : "off"
                    wide: Network.label
                    expanded: tile.kind === "tr"
                    valueColor: Network.connected ? Theme.text : Theme.muted

                    Row {
                        spacing: 2

                        Repeater {
                            model: 4

                            // Bars the signal doesn't reach stay drawn, in the empty tone.
                            Rectangle {
                                required property int index

                                y: 10 - height
                                width: 2
                                height: 3 + index * 2
                                color: Network.connected && Network.signal > index * 25 ? Theme.text : Theme.borderStrong
                            }
                        }
                    }
                }
                Reading {
                    id: volR
                    anchors.verticalCenter: parent.verticalCenter
                    label: "VOL"
                    value: Audio.muted ? "mute" : tile.volumePct + "%"
                    valueColor: tile.volumeHot ? Theme.accent : (Audio.muted ? Theme.muted : Theme.text)
                }
                Reading {
                    id: batR
                    anchors.verticalCenter: parent.verticalCenter
                    label: "BAT"
                    value: tile.batteryPct + "%"
                    wide: tile.batteryPct + "%" + (tile.charging ? " · charging" : (tile.timeLeft() !== "" ? " · " + tile.timeLeft() : ""))
                    expanded: tile.kind === "tr"
                    valueColor: tile.charging ? Theme.accent : (tile.batteryPct <= 15 ? Theme.error : Theme.text)
                }
            }
        }
    }

    bodyData: [
        PerformancePanel {
            id: performance

            x: 13
            y: 12
            width: 434
            enabled: tile.kind === "tp"
            shown: tile.open && tile.kind === "tp"
        },

        Column {
            id: panel

            x: 13
            y: 12
            width: 374
            enabled: tile.kind === "tr"
            spacing: 8

            PanelItem {
                order: 0
                shown: tile.open && tile.kind === "tr"
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
                        label: "Keep awake"
                        sub: Power.keepAwake ? "on · never sleeps" : "off"
                        on: Power.keepAwake
                        onClicked: Power.keepAwake = !Power.keepAwake
                    }
                }
            }

            PanelItem {
                order: 2
                shown: tile.open && tile.kind === "tr"
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
                shown: tile.open && tile.kind === "tr"
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
                shown: tile.open && tile.kind === "tr"
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
                shown: tile.open && tile.kind === "tr"
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
                shown: tile.open && tile.kind === "tr"
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
