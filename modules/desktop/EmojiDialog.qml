import QtQuick
import TheLine.Ui
import qs.services

// The emoji picker (SUPER+semicolon), grown from the line: the recent ones first, then everything; type to search
// by name. Enter or a click copies it.
CenterDialog {
    id: dialog

    required property string screenName

    readonly property int columns: 12
    readonly property real cell: 44
    property int selected: 0
    readonly property var shown: visible ? Emoji.search(search.text) : []

    open: UiState.emojiScreen === screenName
    boxWidth: 40 + columns * cell
    boxHeight: Math.min(18 + 30 + 50 + Math.max(grid.contentHeight, cell) + 12 + 30, Math.round(height * 0.7))
    onOutsideClicked: UiState.emojiScreen = ""

    onOpenChanged: {
        if (open) {
            search.text = "";
            selected = 0;
        }
    }
    onContentShownChanged: if (contentShown) search.focusInput()

    function choose() {
        const e = shown[selected];
        if (!e)
            return;
        Emoji.pick(e.char);
        UiState.emojiScreen = "";
    }

    Column {
        x: 20
        y: 18
        width: dialog.boxWidth - 40

        PanelItem {
            order: 0
            shown: dialog.contentShown
            width: parent.width
            height: 30

            Text {
                text: "EMOJI"
                font.family: Theme.fontUi
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.9
                color: Theme.muted
            }
            Text {
                anchors.right: parent.right
                text: dialog.shown[dialog.selected]?.name ?? ""
                width: Math.min(implicitWidth, parent.width - 80)
                elide: Text.ElideRight
                font.family: Theme.fontMono
                font.pixelSize: 10
                color: Theme.text
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
                placeholder: "Find an emoji by name"
                sideArrowsMove: true
                onTextChanged: dialog.selected = 0
                onMoved: (dx, dy) => dialog.selected = Math.max(0, Math.min(dialog.shown.length - 1, dialog.selected + dx + dy * dialog.columns))
                onAccepted: dialog.choose()
                onCancelled: UiState.emojiScreen = ""
            }
        }

        PanelItem {
            order: 2
            shown: dialog.contentShown
            width: parent.width
            height: dialog.boxHeight - 18 - 30 - 50 - 30 - 12

            GridView {
                id: grid

                anchors.fill: parent
                clip: true
                cellWidth: dialog.cell
                cellHeight: dialog.cell
                model: dialog.shown
                currentIndex: dialog.selected
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

                delegate: Rectangle {
                    id: emoji

                    required property var modelData
                    required property int index
                    readonly property bool chosen: index === dialog.selected

                    width: dialog.cell
                    height: dialog.cell
                    color: chosen || hover.hovered ? Theme.surface2 : "transparent"
                    border.width: chosen ? 1 : 0
                    border.color: Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: emoji.modelData.char
                        font.family: "Twemoji"
                        font.pixelSize: 24
                    }

                    HoverHandler {
                        id: hover
                    }
                    TapHandler {
                        onTapped: {
                            dialog.selected = emoji.index;
                            dialog.choose();
                        }
                    }
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
                text: "↵ copy · ← → ↑ ↓ move · Esc close"
                font.family: Theme.fontMono
                font.pixelSize: 10
                color: Theme.muted
            }
        }
    }
}
