import QtQuick
import TheLine.Ui
import qs.services

// The paragraphs of a beat, centred, rising in one after the other like Kira's voice does (KiraVoice): the first one
// big, the others quieter. *words* are lit in the accent. A short line draws itself under the block.
Item {
    id: narration

    property var paragraphs: []
    property bool shown: false
    // True once the last paragraph has landed (what waits for it: the offer, the hint).
    property bool settled: false

    readonly property real blockW: Math.min(940, width - 160)
    readonly property int step: Anim.d(430)

    implicitHeight: col.implicitHeight + 40

    function markup(text) {
        const esc = text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        return esc.replace(/\*(.+?)\*/g, "<font color=\"" + Theme.accent + "\">$1</font>");
    }

    onShownChanged: {
        settled = false;
        if (shown)
            settle.restart();
        else
            settle.stop();
    }

    Timer {
        id: settle
        interval: Anim.d(150 + 500) + narration.paragraphs.length * narration.step
        onTriggered: narration.settled = true
    }

    Column {
        id: col
        width: narration.blockW
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 18

        Repeater {
            model: narration.paragraphs

            Text {
                id: para

                required property string modelData
                required property int index

                width: col.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
                text: narration.markup(modelData)
                lineHeight: 1.18
                font.family: Theme.fontUi
                font.pixelSize: index === 0 ? 34 : 18
                font.weight: index === 0 ? Font.Light : Font.Normal
                color: index === 0 ? Theme.text : Theme.muted
                opacity: narration.shown ? 1 : 0

                transform: Translate {
                    y: narration.shown ? 0 : 10

                    Behavior on y {
                        SequentialAnimation {
                            PauseAnimation { duration: narration.shown ? Anim.d(150) + para.index * narration.step : 0 }
                            NumberAnimation { duration: narration.shown ? Anim.d(500) : Anim.exitFade; easing.type: Anim.easing }
                        }
                    }
                }
                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation { duration: narration.shown ? Anim.d(150) + para.index * narration.step : 0 }
                        NumberAnimation { duration: narration.shown ? Anim.d(500) : Anim.exitFade; easing.type: Anim.easing }
                    }
                }
            }
        }
    }

    // The line under the words, drawn from the middle.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: col.implicitHeight + 24
        width: Math.min(300, col.width * 0.4)
        height: 1
        color: Theme.borderStrong

        transform: Scale {
            origin.x: 150
            xScale: narration.shown ? 1 : 0

            Behavior on xScale {
                NumberAnimation { duration: narration.shown ? Anim.d(700) : Anim.exitFade; easing.type: Anim.easing }
            }
        }
    }
}
