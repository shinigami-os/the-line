import QtQuick
import qs.services

// Binary-coded decimal clock: one column per digit (HH MM SS), bits 8 4 2 1 from top to bottom.
// Bits a digit can never use are not drawn.
Item {
    id: clock

    property real size: 140

    readonly property string digits: Qt.formatTime(Time.now, "HHmmss")
    readonly property var bitsUsed: [2, 4, 3, 4, 3, 4]
    readonly property real cell: 14
    readonly property real gap: 6
    readonly property real pairGap: 18

    width: size
    height: size

    Row {
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: 6

            Item {
                id: column

                required property int index
                readonly property int digit: Number(clock.digits[index])

                width: clock.cell + (index === 5 ? 0 : (index % 2 === 0 ? clock.gap : clock.pairGap))
                height: 4 * clock.cell + 3 * clock.gap + 22

                Repeater {
                    model: 4

                    Rectangle {
                        required property int index
                        readonly property int bit: 8 >> index
                        readonly property bool on: (column.digit & bit) !== 0

                        visible: 4 - index <= clock.bitsUsed[column.index]
                        y: index * (clock.cell + clock.gap)
                        width: clock.cell
                        height: clock.cell
                        color: on ? Theme.accent : "transparent"
                        border.width: 1
                        border.color: on ? Theme.accent : Theme.borderStrong

                        Behavior on color {
                            ColorAnimation { duration: Anim.base }
                        }
                        Behavior on border.color {
                            ColorAnimation { duration: Anim.base }
                        }
                    }
                }

                Text {
                    y: 4 * (clock.cell + clock.gap) + 2
                    width: clock.cell
                    horizontalAlignment: Text.AlignHCenter
                    text: column.digit
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    color: Theme.muted
                }
            }
        }
    }
}
