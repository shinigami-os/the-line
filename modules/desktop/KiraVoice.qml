import QtQuick
import qs.services

// Kira's voice, bottom-left, only on an empty workspace: the quote, a short second line echoing the top one,
// and who/where/how long. A new quote is picked each time it appears, and every few minutes while it stays.
Item {
    id: voice

    property bool active: false   // the workspace is empty
    property bool resting: false  // briefly hidden to swap the quote

    readonly property bool shown: active && !resting

    x: 16
    y: parent.height - 22 - height
    width: col.implicitWidth
    height: col.implicitHeight

    onActiveChanged: if (active) Voice.next()

    // Every five minutes on the same empty workspace: fade out, swap, fade back in.
    Timer {
        running: voice.active
        repeat: true
        interval: 5 * 60 * 1000
        onTriggered: {
            voice.resting = true;
            swap.restart();
        }
    }
    Timer {
        id: swap
        interval: Anim.panel + 100
        onTriggered: {
            Voice.next();
            voice.resting = false;
        }
    }

    Column {
        id: col
        spacing: 10

        // Quote: fades in and rises 8 px, 200 ms after the workspace empties.
        Text {
            id: quote
            text: "« " + Voice.text + " »"
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
                        PauseAnimation { duration: voice.shown ? Anim.d(200) : 0 }
                        NumberAnimation { duration: Anim.panel; easing.type: Anim.easing }
                    }
                }
            }

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: voice.shown ? Anim.d(200) : 0 }
                    NumberAnimation { duration: Anim.panel; easing.type: Anim.easing }
                }
            }
        }

        // The second line of the desktop: draws left to right under the quote.
        Rectangle {
            width: 420
            height: 1
            color: Theme.borderStrong

            transform: Scale {
                xScale: voice.shown ? 1 : 0

                Behavior on xScale {
                    SequentialAnimation {
                        PauseAnimation { duration: voice.shown ? Anim.d(260) : 0 }
                        NumberAnimation { duration: Math.round(Anim.panel * 1.6); easing.type: Anim.easing }
                    }
                }
            }
        }

        Text {
            text: Voice.meta
            font.family: Theme.fontMono
            font.pixelSize: 12
            color: Theme.muted
            opacity: voice.shown ? 1 : 0

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: voice.shown ? Anim.d(260) : 0 }
                    NumberAnimation { duration: Anim.panel; easing.type: Anim.easing }
                }
            }
        }
    }
}
