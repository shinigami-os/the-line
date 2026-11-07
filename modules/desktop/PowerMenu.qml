import QtQuick
import qs.modules.common
import qs.services

// The power menu (CTRL+ALT+Delete; the power button opens it on Power off). Grown from the line like the other
// dialogs, and the line keeps running through it: the actions stand above it, their keys below it, and the accent
// marker slides along it to the chosen one. Nothing happens on a press: holding Enter, the action's letter or the
// mouse fills the line under it; let go before it is full and it drains back. Once full, the accent runs out along
// the whole screen line, Kira says a word, the menu folds and the action runs.
CenterDialog {
    id: menu

    required property string screenName

    readonly property var actions: [
        { name: "Log out", key: "O", say: "see you around.", run: () => Power.logout() },
        { name: "Suspend", key: "S", say: "sleep tight.", run: () => Power.suspend() },
        { name: "Restart", key: "R", say: "be right back.", run: () => Power.restart() },
        { name: "Power off", key: "P", say: "going dark.", run: () => Power.poweroff(), danger: true }
    ]

    readonly property real cellW: (boxWidth - 40) / actions.length
    readonly property real lineY: boxHeight / 2   // the line inside the box: the screen's line, running on through
    property int selected: 0
    property real hold: 0                      // 0..1, how much of the line under the action is filled
    property bool confirmed: false
    property real sweep: 0                     // 0..1, the accent running out along the screen line

    open: UiState.powerScreen === screenName
    boxWidth: 640
    boxHeight: 168
    onOutsideClicked: if (!confirmed) UiState.powerScreen = ""

    onOpenChanged: {
        if (open) {
            selected = UiState.powerSelected;
            confirmed = false;
            hold = 0;
            sweep = 0;
        }
    }
    onContentShownChanged: if (contentShown) keys.forceActiveFocus()

    function startHold() {
        if (confirmed)
            return;
        drain.stop();
        fillUp.from = hold;
        fillUp.duration = Math.max(1, Math.round(Anim.d(700) * (1 - hold)));
        fillUp.restart();
    }

    function stopHold() {
        if (confirmed || hold === 0)
            return;
        fillUp.stop();
        drain.from = hold;
        drain.restart();
    }

    function confirm() {
        confirmed = true;
        Voice.say(actions[selected].say, screenName);
        sweepOut.restart();
    }

    NumberAnimation {
        id: fillUp
        target: menu
        property: "hold"
        to: 1
        easing.type: Easing.Linear
        onFinished: menu.confirm()
    }
    NumberAnimation {
        id: drain
        target: menu
        property: "hold"
        to: 0
        duration: Anim.base
        easing.type: Anim.easing
    }
    SequentialAnimation {
        id: sweepOut

        NumberAnimation {
            target: menu
            property: "sweep"
            from: 0
            to: 1
            duration: Anim.d(520)
            easing.type: Anim.easing
        }
        PauseAnimation { duration: Anim.d(500) }
        ScriptAction {
            script: {
                const action = menu.actions[menu.selected];
                UiState.powerScreen = "";
                runLater.action = action;
                runLater.restart();
            }
        }
    }
    // The action runs once the menu has folded.
    Timer {
        id: runLater
        property var action: null
        interval: menu.foldDelay + Anim.panel
        onTriggered: action?.run()
    }

    // The accent running out from the box along the screen line, both ways.
    Rectangle {
        parent: menu
        visible: menu.sweep > 0
        y: menu.mid
        x: (menu.width - menu.boxWidth) / 2 - width
        width: menu.sweep * (menu.width - menu.boxWidth) / 2
        height: 1
        color: Theme.accent
        z: 5
    }
    Rectangle {
        parent: menu
        visible: menu.sweep > 0
        y: menu.mid
        x: (menu.width + menu.boxWidth) / 2
        width: menu.sweep * (menu.width - menu.boxWidth) / 2
        height: 1
        color: Theme.accent
        z: 5
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: if (!menu.confirmed) UiState.powerScreen = ""
        Keys.onPressed: event => {
            if (event.isAutoRepeat || menu.confirmed)
                return;
            const letter = menu.actions.findIndex(a => a.key === event.text.toUpperCase());
            if (event.key === Qt.Key_Left || event.key === Qt.Key_H)
                menu.selected = (menu.selected + menu.actions.length - 1) % menu.actions.length;
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_K)
                menu.selected = (menu.selected + 1) % menu.actions.length;
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                menu.startHold();
            else if (letter >= 0 && event.text !== "") {
                menu.selected = letter;
                menu.startHold();
            } else
                return;
            event.accepted = true;
        }
        Keys.onReleased: event => {
            if (!event.isAutoRepeat)
                menu.stopHold();
        }

        // Header.
        PanelItem {
            order: 0
            shown: menu.contentShown
            x: 20
            y: 16
            width: menu.boxWidth - 40
            height: 16

            Text {
                text: "SESSION"
                font.family: Theme.fontUi
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.9
                color: Theme.muted
            }
            Text {
                anchors.right: parent.right
                text: Session.user + "@" + Session.host.toLowerCase() + " · up " + SystemStats.formatUptime(SystemStats.uptime)
                font.family: Theme.fontMono
                font.pixelSize: 10
                color: Theme.muted
            }
        }

        // The line through the menu.
        PanelItem {
            order: 1
            shown: menu.contentShown
            x: 20
            y: menu.lineY
            width: menu.boxWidth - 40
            height: 1

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.borderStrong
            }

            // Hold to confirm: the line under the chosen action fills with accent.
            Rectangle {
                x: menu.selected * menu.cellW
                y: -1
                width: menu.hold * menu.cellW
                height: 3
                color: menu.actions[menu.selected].danger ? Theme.error : Theme.accent
            }

            // The marker under the chosen action.
            Rectangle {
                x: menu.selected * menu.cellW + menu.cellW / 2 - 7
                y: -1
                width: 14
                height: 3
                color: Theme.accent
                opacity: menu.hold > 0 ? 0 : 1

                Behavior on x {
                    NumberAnimation { duration: Anim.workspace; easing.type: Anim.easing }
                }
            }
        }

        // The actions: names above the line, keys below.
        Repeater {
            model: menu.actions

            PanelItem {
                id: action

                required property var modelData
                required property int index
                readonly property bool chosen: menu.selected === index

                order: 2 + index
                shown: menu.contentShown
                x: 20 + index * menu.cellW
                y: 44
                width: menu.cellW
                height: menu.boxHeight - 44 - 16

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: menu.lineY - 44 - 32
                    text: action.modelData.name
                    font.family: Theme.fontUi
                    font.pixelSize: 15
                    font.weight: action.chosen ? Font.DemiBold : Font.Medium
                    color: action.modelData.danger ? Theme.error : (action.chosen ? Theme.text : Theme.muted)

                    Behavior on color {
                        ColorAnimation { duration: Anim.hover }
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: menu.lineY - 44 + 14
                    width: keyText.implicitWidth + 12
                    height: 18
                    color: "transparent"
                    border.width: 1
                    border.color: action.chosen ? Theme.accent : Theme.borderStrong

                    Text {
                        id: keyText
                        anchors.centerIn: parent
                        text: action.modelData.key
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        color: action.chosen ? Theme.accent : Theme.muted
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: if (!menu.confirmed && menu.hold === 0) menu.selected = action.index
                    onPressed: {
                        menu.selected = action.index;
                        menu.startHold();
                    }
                    onReleased: menu.stopHold()
                    onCanceled: menu.stopHold()
                }
            }
        }

        // How it works, in one line.
        PanelItem {
            order: 6
            shown: menu.contentShown
            x: 20
            y: menu.boxHeight - 30
            width: menu.boxWidth - 40
            height: 14

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: menu.confirmed ? "" : "hold to confirm · ← → choose · Esc cancel"
                font.family: Theme.fontMono
                font.pixelSize: 10
                color: Theme.muted
            }
        }
    }
}
