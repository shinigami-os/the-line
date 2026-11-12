import QtQuick
import qs.services

// The line and everything that happens on it: music progress, workspace marker, level gauge, notification pulse.
// Lives in the same surface as the tiles but is stacked above them.
Item {
    id: line

    required property int workspace   // 1..10, the active workspace of this screen
    property string screenName
    property bool musicShown: true     // music progress (gone once the music part leaves in fullscreen)
    property bool markerShown: true    // workspace marker (gone once the tiles fold up)
    property bool tileShown: true      // a clock tile the pulse can draw
    property bool quietDesktop: false  // no window on this screen's workspace (the Morse easter egg)
    property bool spectrumShown: false // the music visualiser (Visualiser), once the tiles have folded
    property real reach: 1             // 1 = edge to edge, 0 = withdrawn into both screen edges

    readonly property real lineWidth: width

    // The line itself: it comes out of both edges of the screen, one half from each side.
    Rectangle {
        x: 0
        y: 10
        width: Math.ceil(line.lineWidth / 2 * line.reach)
        height: 1
        color: Theme.borderStrong
    }
    Rectangle {
        x: line.lineWidth - width
        y: 10
        width: Math.ceil(line.lineWidth / 2 * line.reach)
        height: 1
        color: Theme.borderStrong
    }

    // Music visualiser: the frequencies as ticks hanging from the line, like a ruler that plays. One tick every 6 px
    // whatever the screen's width (a wide screen gets more of them, not wider gaps), each one reading cava's bands
    // in between. Mirrored from the middle: the lowest ones there, the highest at both edges. Louder is longer and
    // brighter. One canvas per screen: hundreds of items redrawn 60 times a second would cost far more.
    Canvas {
        id: spectrum

        readonly property int gap: 6
        readonly property int half: Math.floor(line.lineWidth / 2 / gap)

        anchors.fill: parent
        visible: opacity > 0
        opacity: line.spectrumShown && Visualiser.on ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Anim.panel }
        }

        Connections {
            target: Visualiser
            enabled: spectrum.visible

            function onBarsChanged() {
                spectrum.requestPaint();
            }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const bars = Visualiser.bars;
            const n = bars.length;
            if (n === 0)
                return;
            const mid = line.lineWidth / 2;
            const room = Theme.tileHeight - 8;
            const c = Theme.accent;
            for (let i = 0; i < half; i++) {
                const f = i / Math.max(1, half - 1) * (n - 1);
                const lo = Math.floor(f);
                const v = bars[lo] + ((bars[Math.min(n - 1, lo + 1)] ?? 0) - bars[lo]) * (f - lo);
                const h = Math.round(2 + v * room);
                ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.3 + 0.7 * v);
                const off = Math.round(i * gap + gap / 2);
                ctx.fillRect(mid + off - 1, 11, 2, h);
                ctx.fillRect(mid - off - 1, 11, 2, h);
            }
        }
    }

    // Level gauge: the whole line becomes the bar. No popup.
    Rectangle {
        y: 9
        x: 0
        height: 3
        width: LineState.gaugeValue * line.lineWidth
        color: Theme.accent
        // On a withdrawn line it waits until the line is mostly drawn back.
        opacity: LineState.gaugeKind !== "" && line.reach > 0.6 ? 1 : 0

        Behavior on width {
            NumberAnimation { duration: Anim.base; easing.type: Anim.easing }
        }
        Behavior on opacity {
            NumberAnimation { duration: Anim.base }
        }
    }

    // Easter egg: the gauge passing 42% leaves a tiny tick there for a second.
    Rectangle {
        x: Math.round(0.42 * line.lineWidth)
        y: 12
        width: 1
        height: 5
        color: Theme.accent
        opacity: fortyTwo.running ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Anim.base }
        }

        Timer {
            id: fortyTwo
            interval: 1000
        }
        Connections {
            target: LineState

            function onGaugeValueChanged() {
                if (LineState.gaugeKind !== "" && Math.round(LineState.gaugeValue * 100) === 42)
                    fortyTwo.restart();
            }
        }
    }

    // Easter egg: midnight, a single accent tick in the middle of the line for the new day's first minute.
    Rectangle {
        x: Math.round(line.lineWidth / 2)
        y: 11
        width: 1
        height: 6
        color: Theme.accent
        opacity: Eggs.midnightTick && line.reach === 1 ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Anim.panel }
        }
    }

    // Easter egg: the uptime crossing a power of two in minutes (1024, 2048…), written in binary in the middle of
    // the line: a dash for each 1, a dot for each 0.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 9
        spacing: 4
        opacity: Eggs.powerOfTwo !== "" && line.reach === 1 ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: Anim.panel }
        }

        Repeater {
            model: Eggs.powerOfTwo.split("")

            Rectangle {
                required property string modelData
                width: modelData === "1" ? 12 : 3
                height: 3
                color: modelData === "1" ? Theme.accent : Theme.muted
            }
        }
    }

    // Music progress: on the line, exactly above the music part of the top-left tile. Creeps forward each second.
    Rectangle {
        x: 16 + Theme.wsBlockW
        y: 10
        // whole pixels, no animation: it redraws only when it really moves (an animation here redrew every
        // screen without pause while music played)
        width: Math.round(Media.progress * Theme.musicW)
        height: 1
        color: Theme.accent
        opacity: Media.active && line.musicShown ? 0.85 : 0
        Behavior on opacity {
            NumberAnimation { duration: Anim.base }
        }
    }

        // Workspace marker: slides along the line, in step with the workspace switch.
    Rectangle {
        y: 9
        width: 14
        height: 3
        color: Theme.accent
        // Easter egg: long idle on an empty desktop, it blinks "kira" in Morse (Eggs).
        opacity: !line.markerShown ? 0 : Eggs.morsePlaying && line.quietDesktop && !Eggs.morseLit ? 0.12 : 1

        // (the Morse blinks are cut, not faded: a fade is an animation, and any animation redraws every window)
        Behavior on opacity {
            enabled: !Eggs.morsePlaying
            NumberAnimation { duration: Anim.base }
        }

        // Centred over the active cell of the workspace ruler (tile at 16, ruler 13 px in).
        x: 16 + 13 + Theme.wsCell / 2 - 7 + (Math.max(1, Math.min(10, line.workspace)) - 1) * Theme.wsCell

        Behavior on x {
            NumberAnimation { duration: Anim.workspace; easing.type: Anim.easing }
        }
    }

    // Notification pulse: two dashes run in along the line and meet at the centre, then turn back, run out to the
    // toast's top corners and down its sides while the clock tile's frame grows with them (see ClockTile).
    PulseDash {
        anchors.fill: parent
        centerX: line.width / 2
        tileShown: line.tileShown
        visible: LineState.pulseActive && LineState.pulseOn(line.screenName)
    }
    PulseDash {
        anchors.fill: parent
        centerX: line.width / 2
        tileShown: line.tileShown
        visible: LineState.pulseActive && LineState.pulseOn(line.screenName)
        transform: Scale {
            origin.x: line.width / 2
            xScale: -1
        }
    }
}
