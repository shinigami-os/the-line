import QtQuick
import qs.services

// Kira's voice: a line of text and, under it, a second line of the desktop drawn to the same length.
// Appearing mirrors leaving: leaving, the text and the line go together and the line takes longer; appearing,
// the line starts first and the text rises in after it, both landing together (650 ms).
Item {
    id: voice

    property string text
    property bool shown: false

    width: col.implicitWidth
    height: col.implicitHeight

    Column {
        id: col
        spacing: 10

        Text {
            id: quote
            text: voice.text
            font.family: Theme.fontUi
            font.pixelSize: 22
            font.italic: true
            font.weight: Font.Normal
            color: Theme.text
            opacity: voice.shown ? 1 : 0

            transform: Translate {
                y: voice.shown ? 0 : 8

                Behavior on y {
                    SequentialAnimation {
                        PauseAnimation { duration: voice.shown ? Anim.d(230) : 0 }
                        NumberAnimation { duration: voice.shown ? Anim.d(420) : Anim.panel; easing.type: Anim.easing }
                    }
                }
            }

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: voice.shown ? Anim.d(230) : 0 }
                    NumberAnimation { duration: voice.shown ? Anim.d(420) : Anim.panel; easing.type: Anim.easing }
                }
            }
        }

        Rectangle {
            width: quote.implicitWidth
            height: 1
            color: Theme.borderStrong

            transform: Scale {
                xScale: voice.shown ? 1 : 0

                Behavior on xScale {
                    SequentialAnimation {
                        PauseAnimation { duration: 0 }
                        NumberAnimation { duration: voice.shown ? Anim.d(650) : Math.round(Anim.panel * 1.6); easing.type: Anim.easing }
                    }
                }
            }
        }
    }
}
