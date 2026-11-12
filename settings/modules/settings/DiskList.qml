pragma ComponentBehavior: Bound

import QtQuick
import TheLine.Ui
import qs.services

// Settings > Storage > Disks: each disk, then its partitions; a mounted one shows how full it is as a line (the
// line's own 1 px track, filled in the accent; red past 90 %). Only to read.
Item {
    id: list

    property var setting
    property bool active: false

    signal picked

    implicitHeight: column.implicitHeight

    function key(event) {
        return false;
    }

    Column {
        id: column
        width: parent.width
        spacing: 4

        Repeater {
            model: Disks.disks

            Column {
                id: disk

                required property var modelData

                width: list.width

                Item {
                    width: parent.width
                    height: 30

                    Text {
                        x: 12
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        text: (disk.modelData.model || disk.modelData.name) + (disk.modelData.removable ? "   removable" : "")
                        font.family: Theme.fontUi
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: Theme.text
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        text: disk.modelData.name + "   " + Disks.size(disk.modelData.size)
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        color: Theme.muted
                    }
                }

                Repeater {
                    model: disk.modelData.parts

                    Item {
                        id: part

                        required property var modelData
                        readonly property real fill: modelData.used >= 0 ? modelData.used / Math.max(1, modelData.size) : 0

                        width: list.width
                        height: 30

                        // its name (and label), then where it is mounted
                        Text {
                            id: partName
                            x: 24
                            y: 4
                            text: part.modelData.name + (part.modelData.label ? "  " + part.modelData.label : "")
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            color: part.modelData.mount !== "" ? Theme.text : Theme.muted
                        }
                        Text {
                            visible: part.modelData.mount !== ""
                            anchors.left: partName.right
                            anchors.leftMargin: 14
                            y: 4
                            text: part.modelData.mount === "[SWAP]" ? "swap" : "on " + part.modelData.mount
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            color: Theme.accent
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            y: 4
                            text: (part.modelData.used >= 0 ? Disks.size(part.modelData.used) + " of " : "")
                                + Disks.size(part.modelData.size) + (part.modelData.mount === "" ? "   not mounted" : "")
                                + (part.modelData.fstype ? "   " + part.modelData.fstype : "")
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            color: Theme.muted
                        }
                        Rectangle {
                            visible: part.modelData.used >= 0
                            x: 24
                            y: 22
                            width: parent.width - 34
                            height: 1
                            color: Theme.borderStrong

                            Rectangle {
                                width: parent.width * part.fill
                                height: 1
                                color: part.fill > 0.9 ? Theme.error : Theme.accent
                            }
                        }
                    }
                }
            }
        }
    }
}
