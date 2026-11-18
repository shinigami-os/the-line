import QtQuick
import TheLine.Ui
import qs.services

// The way back from the lock, drawn by the shell's own surface (TheLine) once the lock is let go. It starts from the
// lock's last frame exactly (the blurred wallpaper, the line across the middle full of accent), then the line rises to
// the top and becomes the real line again, wiping the darkness up with it: the desktop shows below it as it goes; the
// tiles unfold after it (TheLine).
Item {
    id: curtain

    required property string screenName

    readonly property real midY: Math.round(height / 2)
    property real rise: 1     // 0 in the middle, 1 at the top (where it rests: hidden)
    readonly property real lineY: Math.round(midY + (10 - midY) * rise)

    visible: UiState.unlocking || rise < 1

    Connections {
        target: UiState

        function onUnlockingChanged() {
            if (UiState.unlocking) {
                curtain.rise = 0;
                riseAnim.restart();
            }
        }
    }

    SequentialAnimation {
        id: riseAnim
        PauseAnimation { duration: 80 }   // the lock's frame, held while the lock goes
        NumberAnimation {
            target: curtain
            property: "rise"
            from: 0
            to: 1
            duration: Anim.d(720)
            easing.type: Easing.InOutQuart
        }
        ScriptAction { script: UiState.unlocking = false }
    }

    // only above the line
    Item {
        width: curtain.width
        height: curtain.lineY
        clip: true

        // Only while there is something to hand over: the blurred wallpaper costs a decode and its buffers.
        Loader {
            active: Lock.locked || UiState.unlocking || curtain.rise < 1
            width: curtain.width
            height: curtain.height
            sourceComponent: LockBackdrop {
                screenName: curtain.screenName
            }
        }
    }

    // The line, going home: full accent at first, back to the line's grey as it reaches the top.
    Rectangle {
        y: curtain.lineY
        width: curtain.width
        height: 1
        color: Theme.borderStrong
    }
    Rectangle {
        y: curtain.lineY - 1
        width: curtain.width
        height: 3
        color: Theme.accent
        opacity: 1 - curtain.rise
    }
}
