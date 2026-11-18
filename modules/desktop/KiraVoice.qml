import QtQuick
import TheLine.Ui
import qs.services

// Kira's voice: a line of text and, under it, a second line of the desktop drawn to the same length.
// Appearing mirrors leaving: leaving, the text and the line go together and the line takes longer; appearing,
// the line starts first and the text rises in after it, both landing together (650 ms).
Item {
    id: voice

    property string text
    property bool shown: false
    // Easter egg: the line types itself in binary first, then resolves into its text, letter by letter.
    property bool decode: false

    property int typed: 0
    property int resolved: 0
    property int noise: 0   // bumped each step, so the unresolved bits flicker
    readonly property string drawn: {
        if (!decode)
            return text;
        noise;
        let out = "";
        for (let i = 0; i < Math.min(typed, text.length); i++) {
            const c = text[i];
            out += i < resolved || c === " " ? c : (Math.random() < 0.5 ? "0" : "1");
        }
        return out;
    }

    function startDecode() {
        typed = 0;
        resolved = 0;
        decodeStart.stop();
        decodeStep.stop();
        if (decode && shown)
            decodeStart.restart();
    }

    // A quote's live figures ({cpu}, {load}) change under the reader: that must not restart the decoding, which
    // would then never finish. A new quote arrives while the voice is hidden, and showing it starts the decoding.
    onShownChanged: startDecode()
    onDecodeChanged: startDecode()

    Timer {
        id: decodeStart
        interval: Anim.d(230)
        onTriggered: decodeStep.start()
    }
    Timer {
        id: decodeStep
        interval: 32
        repeat: true
        onTriggered: {
            voice.noise++;
            if (voice.typed < voice.text.length)
                voice.typed++;
            else if (voice.noise % 2 === 0 && voice.resolved < voice.text.length)
                voice.resolved++;
            else if (voice.resolved >= voice.text.length)
                stop();
        }
    }

    width: col.implicitWidth
    height: col.implicitHeight

    // The full text's width, for the line under a quote that is still being decoded.
    Text {
        id: lineMeasure
        visible: false
        text: voice.decode ? voice.text : ""
        font: quote.font
    }

    Column {
        id: col
        spacing: 10

        Text {
            id: quote
            text: voice.drawn
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
            width: voice.decode ? lineMeasure.implicitWidth : quote.implicitWidth
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
