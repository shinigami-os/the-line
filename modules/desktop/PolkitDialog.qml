import QtQuick
import qs.modules.common
import qs.services

// The polkit agent's dialog: what is asked, the password, and the answer.
CenterDialog {
    id: dialog

    required property string screenName

    open: Polkit.active && Polkit.screen === screenName
    boxWidth: 480
    boxHeight: 204

    onContentShownChanged: if (contentShown) password.forceActiveFocus()
    onOpenChanged: if (!open) password.text = ""

    Column {
        x: 20
        y: 18
        width: dialog.boxWidth - 40
        spacing: 10

        PanelItem {
            order: 0
            shown: dialog.contentShown
            width: parent.width
            height: 16

            Text {
                text: "AUTHENTICATION"
                font.family: Theme.fontUi
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.9
                color: Theme.muted
            }
            Text {
                anchors.right: parent.right
                text: Polkit.flow?.actionId ?? ""
                width: Math.min(implicitWidth, parent.width - 140)
                elide: Text.ElideLeft
                font.family: Theme.fontMono
                font.pixelSize: 10
                color: Theme.muted
            }
        }

        PanelItem {
            order: 1
            shown: dialog.contentShown
            width: parent.width
            height: 52

            Text {
                width: parent.width
                text: Polkit.flow?.message ?? ""
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                font.family: Theme.fontUi
                font.pixelSize: 14
                font.weight: Font.Medium
                color: Theme.text
            }
        }

        // Password.
        PanelItem {
            order: 2
            shown: dialog.contentShown
            width: parent.width
            height: 40

            Rectangle {
                anchors.fill: parent
                color: Theme.bg
                border.width: 1
                border.color: Polkit.failed ? Theme.error : (password.activeFocus ? Theme.accent : Theme.borderStrong)

                Behavior on border.color {
                    ColorAnimation { duration: Anim.hover }
                }

                Text {
                    id: prompt
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                    color: Theme.accent
                }

                TextInput {
                    id: password

                    anchors.left: prompt.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: (Polkit.flow?.responseVisible ?? false) ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                    color: Theme.text
                    selectionColor: Theme.accent
                    clip: true

                    Keys.onReturnPressed: Polkit.submit(text)
                    Keys.onEnterPressed: Polkit.submit(text)
                    Keys.onEscapePressed: Polkit.cancel()
                    onTextEdited: if (Polkit.failed) Polkit.failed = false

                    Text {
                        visible: password.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: (Polkit.flow?.inputPrompt ?? "Password").replace(/:\s*$/, "")
                        font.family: Theme.fontUi
                        font.pixelSize: 14
                        color: Theme.muted
                    }
                }
            }
        }

        // The answer, and the two ways out.
        PanelItem {
            order: 3
            shown: dialog.contentShown
            width: parent.width
            height: 36

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Polkit.failed ? "Wrong password. Try again." : (Polkit.flow?.supplementaryMessage ?? "")
                width: parent.width - buttons.width - 12
                elide: Text.ElideRight
                font.family: Theme.fontUi
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Polkit.failed || (Polkit.flow?.supplementaryIsError ?? false) ? Theme.error : Theme.muted
            }

            Row {
                id: buttons
                anchors.right: parent.right
                spacing: 8

                Repeater {
                    model: [{ label: "Cancel", key: "Esc", main: false }, { label: "Authenticate", key: "↵", main: true }]

                    Rectangle {
                        id: button

                        required property var modelData

                        width: row.implicitWidth + 24
                        height: 36
                        color: hover.hovered ? Theme.surface2 : "transparent"
                        border.width: 1
                        border.color: button.modelData.main ? Theme.accent : Theme.borderStrong

                        Behavior on color {
                            ColorAnimation { duration: Anim.hover }
                        }

                        Row {
                            id: row
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: button.modelData.label
                                font.family: Theme.fontUi
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: Theme.text
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: button.modelData.key
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                                color: Theme.muted
                            }
                        }

                        HoverHandler {
                            id: hover
                        }
                        TapHandler {
                            onTapped: button.modelData.main ? Polkit.submit(password.text) : Polkit.cancel()
                        }
                    }
                }
            }
        }
    }
}
