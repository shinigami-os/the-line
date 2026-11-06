import QtQuick
import QtQuick.Shapes
import qs.modules.common
import qs.services

// The performance dashboard: CPU graph and per-core load, memory, busiest processes.
Column {
    id: panel

    required property bool shown

    spacing: 8

    component Label: Text {
        font.family: Theme.fontUi
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 0.9
        color: Theme.muted
    }

    // Header.
    PanelItem {
        order: 0
        shown: panel.shown
        width: panel.width
        height: 24

        Label {
            x: 4
            y: 4
            text: "PERFORMANCE"
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 4
            y: 4
            text: "load " + SystemStats.load
            font.family: Theme.fontMono
            font.pixelSize: 11
            color: Theme.muted
        }
    }

    // CPU: graph over the last minute, then one bar per core.
    PanelItem {
        order: 1
        shown: panel.shown
        width: panel.width
        height: 16 + 4 + 56 + 6 + 24

        Label {
            x: 4
            text: "CPU"
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 4
            text: Math.round(SystemStats.cpu * 100) + "%"
            font.family: Theme.fontMono
            font.pixelSize: 12
            color: Theme.text
        }

        Rectangle {
            y: 20
            width: parent.width
            height: 56
            color: "transparent"
            border.width: 1
            border.color: Theme.border

            Shape {
                id: graph

                readonly property var points: SystemStats.cpuHistory.map((v, i) =>
                    Qt.point(1 + i * (width - 2) / (SystemStats.historyLength - 1), height - 2 - v * (height - 4)))

                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 1
                    strokeColor: Theme.accent
                    fillColor: "transparent"

                    PathPolyline {
                        path: graph.points
                    }
                }
            }
        }

        Row {
            y: 82
            width: parent.width
            spacing: 3

            Repeater {
                model: SystemStats.cores

                Item {
                    required property real modelData

                    width: (panel.width - (SystemStats.cores.length - 1) * 3) / Math.max(1, SystemStats.cores.length)
                    height: 24

                    Rectangle {
                        width: parent.width
                        height: 1
                        y: 23
                        color: Theme.borderStrong
                    }
                    Rectangle {
                        width: parent.width
                        height: Math.max(1, parent.modelData * 23)
                        y: 24 - height
                        color: parent.modelData > 0.8 ? Theme.accent : Theme.muted
                    }
                }
            }
        }
    }

    // Memory: RAM and swap, each a line gauge like the one on the screen's line.
    Repeater {
        model: [
            { label: "RAM", used: SystemStats.ramUsedKiB, total: SystemStats.ramTotalKiB },
            { label: "Swap", used: SystemStats.swapUsedKiB, total: SystemStats.swapTotalKiB }
        ]

        PanelItem {
            id: mem

            required property var modelData
            required property int index

            order: 2 + index
            shown: panel.shown
            width: panel.width
            height: 20

            Text {
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                text: mem.modelData.label
                font.family: Theme.fontUi
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Theme.text
            }
            Rectangle {
                x: 54
                y: 9
                width: parent.width - 54 - 130
                height: 1
                color: Theme.borderStrong

                Rectangle {
                    y: -1
                    width: mem.modelData.total > 0 ? parent.width * mem.modelData.used / mem.modelData.total : 0
                    height: 3
                    color: Theme.accent
                }
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: mem.modelData.total > 0 ? SystemStats.formatKiB(mem.modelData.used) + " / " + SystemStats.formatKiB(mem.modelData.total) : "none"
                font.family: Theme.fontMono
                font.pixelSize: 11
                color: Theme.muted
            }
        }
    }

    // Busiest processes.
    PanelItem {
        order: 4
        shown: panel.shown
        width: panel.width
        height: 16 + 5 * 22

        Label {
            x: 4
            text: "BUSIEST"
        }
        Column {
            y: 18
            width: parent.width

            Repeater {
                model: SystemStats.processes

                Item {
                    id: proc

                    required property var modelData

                    width: panel.width
                    height: 22

                    Text {
                        x: 4
                        width: parent.width - 150
                        anchors.verticalCenter: parent.verticalCenter
                        text: proc.modelData.name
                        elide: Text.ElideRight
                        font.family: Theme.fontUi
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Theme.text
                    }
                    Text {
                        x: parent.width - 140
                        width: 50
                        horizontalAlignment: Text.AlignRight
                        anchors.verticalCenter: parent.verticalCenter
                        text: proc.modelData.cpu.toFixed(1) + "%"
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        color: proc.modelData.cpu > 50 ? Theme.accent : Theme.text
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        width: 80
                        horizontalAlignment: Text.AlignRight
                        anchors.verticalCenter: parent.verticalCenter
                        text: SystemStats.formatKiB(proc.modelData.mem)
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        color: Theme.muted
                    }
                }
            }
        }
    }

    // Footer.
    PanelItem {
        order: 5
        shown: panel.shown
        width: panel.width
        height: 20

        Text {
            x: 4
            text: "up " + SystemStats.formatUptime(SystemStats.uptime)
            font.family: Theme.fontMono
            font.pixelSize: 11
            color: Theme.muted
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 4
            text: SystemStats.cores.length + " cores"
            font.family: Theme.fontMono
            font.pixelSize: 11
            color: Theme.muted
        }
    }
}
