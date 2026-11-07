import QtQuick
import qs.modules.common
import qs.services

// Clipboard history (SUPER+V), grown from the line. Text in mono, images as thumbnails. Enter copies the chosen
// one back, Shift+Delete removes it, Ctrl+Shift+Delete clears it all.
CenterDialog {
    id: dialog

    required property string screenName

    property int selected: 0
    readonly property var shown: {
        const q = search.text.trim().toLowerCase();
        return q === "" ? Clipboard.entries : Clipboard.entries.filter(e => e.text.toLowerCase().includes(q) || (e.image && e.image.format.includes(q)));
    }

    open: UiState.clipScreen === screenName
    boxWidth: 640
    boxHeight: Math.min(18 + 16 + 14 + 40 + 10 + Math.max(list.contentHeight, 40) + 10 + 30, Math.round(height * 0.7))
    onOutsideClicked: UiState.clipScreen = ""

    onOpenChanged: {
        if (open) {
            search.text = "";
            selected = 0;
            Clipboard.refresh();
        }
    }
    onContentShownChanged: if (contentShown) search.focusInput()

    function choose() {
        const e = shown[selected];
        if (!e)
            return;
        Clipboard.copy(e.id);
        UiState.clipScreen = "";
    }

    Column {
        x: 20
        y: 18
        width: dialog.boxWidth - 40
        spacing: 0

        PanelItem {
            order: 0
            shown: dialog.contentShown
            width: parent.width
            height: 30

            Text {
                text: "CLIPBOARD"
                font.family: Theme.fontUi
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.9
                color: Theme.muted
            }
            Text {
                anchors.right: parent.right
                text: Clipboard.entries.length + (Clipboard.entries.length === 1 ? " item" : " items") + " · up to " + Config.clipboardMax
                font.family: Theme.fontMono
                font.pixelSize: 10
                color: Theme.muted
            }
        }

        PanelItem {
            order: 1
            shown: dialog.contentShown
            width: parent.width
            height: 50

            SearchField {
                id: search
                width: parent.width
                placeholder: "Find in the history"
                onTextChanged: dialog.selected = 0
                onMoved: (dx, dy) => dialog.selected = Math.max(0, Math.min(dialog.shown.length - 1, dialog.selected + dy))
                onAccepted: dialog.choose()
                onCancelled: UiState.clipScreen = ""
                onKeyPressed: event => {
                    if (event.key !== Qt.Key_Delete || !(event.modifiers & Qt.ShiftModifier))
                        return;
                    if (event.modifiers & Qt.ControlModifier)
                        Clipboard.wipe();
                    else if (dialog.shown[dialog.selected])
                        Clipboard.remove(dialog.shown[dialog.selected].id);
                    event.accepted = true;
                }
            }
        }

        PanelItem {
            order: 2
            shown: dialog.contentShown
            width: parent.width
            height: dialog.boxHeight - 18 - 30 - 50 - 40

            ListView {
                id: list

                anchors.fill: parent
                clip: true
                model: dialog.shown
                currentIndex: dialog.selected
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Rectangle {
                    id: entry

                    required property var modelData
                    required property int index
                    readonly property bool chosen: index === dialog.selected

                    width: list.width
                    height: modelData.image ? 70 : 32
                    color: chosen ? Theme.surface2 : (hover.hovered ? Theme.surface2 : "transparent")

                    Rectangle {
                        visible: entry.chosen
                        width: 2
                        height: parent.height
                        color: Theme.accent
                    }

                    Text {
                        visible: !entry.modelData.image
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 24
                        text: entry.modelData.text
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                        color: Theme.text
                    }

                    Row {
                        visible: !!entry.modelData.image
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 14

                        Rectangle {
                            width: 96
                            height: 56
                            color: Theme.bg
                            border.width: 1
                            border.color: Theme.border

                            Image {
                                anchors.fill: parent
                                anchors.margins: 1
                                source: entry.modelData.thumb
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                cache: false
                                sourceSize.width: 192
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.modelData.image ? entry.modelData.image.format + "  " + entry.modelData.image.w + " × " + entry.modelData.image.h + "  ·  " + entry.modelData.image.size : ""
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            color: Theme.muted
                        }
                    }

                    HoverHandler {
                        id: hover
                    }
                    TapHandler {
                        onTapped: {
                            dialog.selected = entry.index;
                            dialog.choose();
                        }
                    }
                }

                Text {
                    visible: dialog.shown.length === 0
                    y: 10
                    x: 4
                    text: Clipboard.entries.length === 0 ? "Nothing copied yet." : "Nothing matches."
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.muted
                }
            }
        }

        PanelItem {
            order: 3
            shown: dialog.contentShown
            width: parent.width
            height: 30

            Rectangle {
                y: 4
                width: parent.width
                height: 1
                color: Theme.border
            }
            Text {
                y: 12
                x: 4
                text: "↵ copy · ↑↓ move · Shift+Del remove · Ctrl+Shift+Del clear all · Esc close"
                font.family: Theme.fontMono
                font.pixelSize: 10
                color: Theme.muted
            }
        }
    }
}
