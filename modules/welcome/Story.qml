pragma ComponentBehavior: Bound

import QtQuick
import TheLine.Ui
import qs.services

// The story's own layer, on the story screen only (TheLine): the narration under the line, an offer (a setting) when a
// beat has one, the progress along the bottom, and the question "skip the story?". Clicks go on (right click: back).
// The keys are handled by Welcome.key; TheLine hands them over.
Item {
    id: story

    // The beat being told lags the real one a moment, so the words leave before the next ones arrive.
    property int told: 0
    property bool telling: false

    readonly property bool ready: Welcome.lineOn && !Welcome.finale

    anchors.fill: parent
    opacity: Welcome.finale ? 0 : 1

    Behavior on opacity {
        NumberAnimation { duration: Anim.d(700); easing.type: Anim.easing }
    }

    Connections {
        target: Welcome

        function onBeatChanged() {
            story.telling = false;
            swap.restart();
        }
        function onLineOnChanged() {
            if (Welcome.lineOn)
                swap.restart();
        }
    }
    Timer {
        id: swap
        interval: Anim.d(220)
        onTriggered: {
            story.told = Welcome.beat;
            story.telling = story.ready;
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (Welcome.asking || Welcome.finale)
                return;
            if (mouse.button === Qt.RightButton)
                Welcome.prev();
            else
                Welcome.next();
        }
    }

    // ------------------------------------------------------------------ the words

    Narration {
        id: narration
        x: (parent.width - width) / 2
        y: Math.round(parent.height * 0.56)
        width: parent.width
        paragraphs: Welcome.paragraphs(Welcome.beats[story.told].id)
        shown: story.telling && !Welcome.asking
    }

    // The offer: a prompt, then the options, hanging from a short line under the words.
    Item {
        id: offer

        readonly property var options: Welcome.beats[story.told].offer ? Welcome.offers[Welcome.beats[story.told].offer] : []
        readonly property bool shown: story.telling && narration.settled && options.length > 0 && !Welcome.asking

        x: (parent.width - width) / 2
        y: narration.y + narration.implicitHeight + 28
        width: Math.min(parent.width - 120, row.implicitWidth + 40)
        height: 92
        opacity: shown ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: offer.shown ? Anim.d(420) : Anim.exitFade }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Welcome.t(Welcome.beats[story.told].id + ".offer")
            font.family: Theme.fontMono
            font.pixelSize: 12
            color: Theme.muted
        }

        Row {
            id: row
            anchors.horizontalCenter: parent.horizontalCenter
            y: 30
            spacing: 20

            Repeater {
                model: offer.options

                Item {
                    id: option

                    required property var modelData
                    readonly property bool current: modelData.on()

                    width: modelData.color ? 22 : label.implicitWidth
                    height: 44

                    // an accent swatch, framed when it is the one in use
                    Rectangle {
                        visible: option.modelData.color !== undefined
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 20
                        height: 20
                        color: option.modelData.color ?? "transparent"
                        border.width: option.current ? 2 : 0
                        border.color: Theme.text
                    }
                    Text {
                        id: label
                        visible: option.modelData.color === undefined
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 1
                        text: option.modelData.label
                        font.family: Theme.fontUi
                        font.pixelSize: 15
                        font.weight: option.current ? Font.DemiBold : Font.Normal
                        color: option.current ? Theme.text : Theme.muted
                    }
                    Rectangle {
                        visible: option.modelData.color === undefined
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 26
                        width: option.current ? parent.width : 0
                        height: 2
                        color: Theme.accent

                        Behavior on width {
                            NumberAnimation { duration: Anim.base; easing.type: Anim.easing }
                        }
                    }
                    Text {
                        visible: option.modelData.key !== ""
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 30
                        text: option.modelData.key
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        color: Theme.borderStrong
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: option.modelData.pick()
                    }
                }
            }
        }

        // the name of the swatch in use, and how to walk through them
        Text {
            visible: Welcome.beats[story.told].offer === "accent"
            anchors.horizontalCenter: parent.horizontalCenter
            y: 76
            text: {
                const on = offer.options.find(o => o.on());
                return (on ? on.label.toLowerCase() : "") + "   ↑↓ choose";
            }
            font.family: Theme.fontMono
            font.pixelSize: 11
            color: Theme.muted
        }
        Text {
            visible: Welcome.beats[story.told].offer !== "accent"
            anchors.horizontalCenter: parent.horizontalCenter
            y: 66
            text: "↑↓ choose"
            font.family: Theme.fontMono
            font.pixelSize: 11
            color: Theme.borderStrong
        }
    }

    // ------------------------------------------------------------------ progress and hint

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - 54
        spacing: 14
        opacity: story.ready ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Anim.d(600) }
        }

        Repeater {
            model: Welcome.beats.length

            Rectangle {
                required property int index
                readonly property bool here: index === Welcome.beat

                anchors.bottom: parent.bottom
                width: here ? 14 : 1
                height: here ? 3 : index < Welcome.beat ? 8 : 5
                color: here ? Theme.accent : index < Welcome.beat ? Theme.muted : Theme.borderStrong

                Behavior on width {
                    NumberAnimation { duration: Anim.base; easing.type: Anim.easing }
                }
                Behavior on height {
                    NumberAnimation { duration: Anim.base; easing.type: Anim.easing }
                }
            }
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - 38
        text: Welcome.t("ui.hint")
        font.family: Theme.fontMono
        font.pixelSize: 11
        color: Theme.borderStrong
        opacity: narration.settled && story.ready && !Welcome.asking ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Anim.d(500) }
        }
    }

    // ------------------------------------------------------------------ skip?

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.78)
        opacity: Welcome.asking ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: Anim.base }
        }

        Column {
            anchors.centerIn: parent
            spacing: 18

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Welcome.t("ui.skip")
                font.family: Theme.fontUi
                font.pixelSize: 30
                font.weight: Font.Light
                color: Theme.text
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 36

                Text {
                    text: Welcome.t("ui.skip.yes")
                    font.family: Theme.fontMono
                    font.pixelSize: 13
                    color: Theme.muted

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: Welcome.finish()
                    }
                }
                Text {
                    text: Welcome.t("ui.skip.no")
                    font.family: Theme.fontMono
                    font.pixelSize: 13
                    color: Theme.text

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: Welcome.asking = false
                    }
                }
            }
        }
    }
}
