import QtQuick
import qs.services

// Hold Super: key hints hang from the tiles on 1 px threads. In one after the other (left, centre, right),
// out all at once on release.
Item {
    id: hints

    property bool shown: false
    required property Item leftTile
    required property Item centerTile
    required property Item rightTile

    // A hint tag: key caps and a label, on a thread from the tile's bottom edge.
    component Hint: Column {
        id: hint

        property int order: 0
        property var keys: []   // [["Super", "Space"], "launcher"] pairs, one row each
        property bool alignRight: false

        spacing: 6
        opacity: hints.shown ? 1 : 0

        transform: Translate {
            y: hints.shown ? 0 : -6

            Behavior on y {
                SequentialAnimation {
                    PauseAnimation { duration: hints.shown ? hint.order * Anim.hintStagger : 0 }
                    NumberAnimation { duration: Anim.base; easing.type: Anim.easing }
                }
            }
        }

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: hints.shown ? hint.order * Anim.hintStagger : 0 }
                NumberAnimation { duration: Anim.base; easing.type: Anim.easing }
            }
        }

        Rectangle {
            x: hint.alignRight ? hint.width - 16 - 1 : 16
            width: 1
            height: 12
            color: Theme.borderStrong
        }

        Repeater {
            model: hint.keys

            Rectangle {
                id: tag

                required property var modelData

                x: hint.alignRight ? hint.width - width : 0
                width: tagRow.implicitWidth + 20
                height: tagRow.implicitHeight + 12
                color: Theme.surface
                border.width: 1
                border.color: Theme.borderStrong

                Row {
                    id: tagRow
                    anchors.centerIn: parent
                    spacing: 8

                    Repeater {
                        model: tag.modelData[0]

                        Rectangle {
                            required property string modelData

                            anchors.verticalCenter: parent.verticalCenter
                            width: capText.implicitWidth + 12
                            height: 18
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.borderStrong

                            Text {
                                id: capText
                                anchors.centerIn: parent
                                text: parent.modelData
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                                color: Theme.text
                            }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tag.modelData[1]
                        font.family: Theme.fontUi
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Theme.text
                    }
                }
            }
        }
    }

    Hint {
        order: 0
        x: hints.leftTile.x
        y: 10 + Theme.tileHeight
        keys: [[["Super", "Space"], "launcher"], [["Super", "1 – 0"], "workspace"]]
    }
    Hint {
        order: 1
        x: hints.centerTile.x + hints.centerTile.width / 2 - 16
        y: 10 + Theme.tileHeight
        keys: [[["Super", "N"], "notifications"]]
    }
    Hint {
        order: 2
        alignRight: true
        width: 260
        x: hints.rightTile.x + hints.rightTile.width - width
        y: 10 + Theme.tileHeight
        keys: [[["Super", "A"], "quick settings"], [["Super", "P"], "performance"]]
    }
}
