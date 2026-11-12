pragma ComponentBehavior: Bound

import QtQuick
import TheLine.Ui
import Quickshell
import Quickshell.Wayland
import qs.services

// The demo video's captions and key display, on the primary screen, above everything and never in the way of a click
// (see services/Demo.qml). The window only exists while one of them shows (and fades out).
Variants {
    model: Quickshell.screens.filter(s => s.name === Config.primaryScreen)

    Scope {
        id: holder

        required property ShellScreen modelData

        readonly property bool wanted: Demo.caption !== "" || Demo.keys.length > 0
        property bool lingering: false

        onWantedChanged: {
            if (wanted)
                lingering = true;
            else
                lingerTimer.restart();
        }

        Timer {
            id: lingerTimer
            interval: 800
            onTriggered: holder.lingering = false
        }

        LazyLoader {
            active: holder.wanted || holder.lingering

            PanelWindow {
                id: win

                // what was shown last stays while it fades out
                property string captionText: Demo.caption
                property var keyCaps: Demo.keys

                screen: holder.modelData
                // a band along the bottom only (a transparent window over the whole screen blanks it)
                anchors {
                    bottom: true
                    left: true
                    right: true
                }
                implicitHeight: 220
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                WlrLayershell.namespace: "the-line-demo"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                mask: Region {}

                Connections {
                    target: Demo

                    function onCaptionChanged() {
                        if (Demo.caption !== "")
                            win.captionText = Demo.caption;
                    }
                    function onKeysChanged() {
                        if (Demo.keys.length > 0)
                            win.keyCaps = Demo.keys;
                    }
                }

                // A caption: a short accent marker, the text under it, on a dark plate.
                Rectangle {
                    id: captionBox

                    readonly property bool shown: Demo.caption !== ""

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height - 40 - height + (shown ? 0 : 12)
                    width: Math.min(parent.width - 160, captionLabel.implicitWidth + 72)
                    height: captionLabel.implicitHeight + 52
                    color: Qt.rgba(0, 0, 0, 0.72)
                    border.width: 1
                    border.color: Theme.border
                    opacity: shown ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: captionBox.shown ? Anim.d(320) : Anim.exitFade; easing.type: Anim.easing }
                    }
                    Behavior on y {
                        NumberAnimation { duration: Anim.d(320); easing.type: Anim.easing }
                    }

                    Rectangle {
                        x: 36
                        y: 18
                        width: 14
                        height: 3
                        color: Theme.accent
                    }
                    Text {
                        id: captionLabel
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 34
                        width: parent.width - 72
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: win.captionText
                        font.family: Theme.fontUi
                        font.pixelSize: 30
                        font.weight: Font.Light
                        color: Theme.text
                    }
                }

                // The keys that were just pressed, as caps.
                Row {
                    id: keyBox

                    readonly property bool shown: Demo.keys.length > 0

                    anchors.right: parent.right
                    anchors.rightMargin: 48
                    y: parent.height - 40 - height + (shown ? 0 : 10)
                    spacing: 8
                    opacity: shown ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: keyBox.shown ? Anim.d(160) : Anim.exitFade; easing.type: Anim.easing }
                    }
                    Behavior on y {
                        NumberAnimation { duration: Anim.d(160); easing.type: Anim.easing }
                    }

                    Repeater {
                        model: win.keyCaps

                        Rectangle {
                            id: cap

                            required property string modelData
                            required property int index

                            width: Math.max(46, capLabel.implicitWidth + 28)
                            height: 46
                            color: Qt.rgba(0, 0, 0, 0.78)
                            border.width: 1
                            border.color: cap.index === win.keyCaps.length - 1 ? Theme.accent : Theme.borderStrong

                            Text {
                                id: capLabel
                                anchors.centerIn: parent
                                text: cap.modelData
                                font.family: Theme.fontMono
                                font.pixelSize: 17
                                color: Theme.text
                            }
                        }
                    }
                }
            }
        }
    }
}
