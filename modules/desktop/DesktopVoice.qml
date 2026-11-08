import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Kira's voice on an empty workspace. Its own surface on the bottom layer, so any window opening covers it
// instead of passing under it. A new quote each time it appears, and every five minutes while it stays.
PanelWindow {
    id: win

    property bool active: false

    // Briefly hidden to swap the quote.
    property bool resting: false

    anchors {
        left: true
        bottom: true
    }
    implicitWidth: Math.max(1, voice.width + 32)
    implicitHeight: voice.height + 22 + 8
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "the-line-voice"

    onActiveChanged: if (active) Voice.next()

    Timer {
        running: win.active
        repeat: true
        interval: 5 * 60 * 1000
        onTriggered: {
            win.resting = true;
            swap.restart();
        }
    }
    Timer {
        id: swap
        interval: Anim.panel + 100
        onTriggered: {
            Voice.next();
            win.resting = false;
        }
    }

    KiraVoice {
        id: voice
        x: 16
        y: parent.height - 22 - height
        text: Voice.text
        decode: Voice.currentDecode
        shown: win.active && !win.resting
    }
}
