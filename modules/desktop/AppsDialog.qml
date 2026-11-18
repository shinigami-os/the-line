import QtQuick
import Quickshell
import Quickshell.Widgets
import TheLine.Ui
import qs.services

// Every installed app (SUPER+SHIFT+A), grown from the line: a grid of icons, A to Z; type to narrow it by name.
// Enter or a click launches it.
CenterDialog {
    id: dialog

    required property string screenName

    readonly property int columns: 5
    readonly property real cellW: 128
    readonly property real cellH: 92
    property int selected: 0
    readonly property var shown: visible ? Apps.search(search.text, 1000, true) : []

    open: UiState.appsScreen === screenName
    boxWidth: 40 + columns * cellW
    boxHeight: Math.min(18 + 30 + 50 + Math.max(grid.contentHeight, cellH) + 12 + 30, Math.round(height * 0.75))
    onOutsideClicked: UiState.appsScreen = ""

    onOpenChanged: {
        if (open) {
            search.text = "";
            selected = 0;
        }
    }
    onContentShownChanged: if (contentShown) search.focusInput()

    function choose() {
        const app = shown[selected];
        if (!app)
            return;
        UiState.appsScreen = "";
        Apps.launch(app);
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
                text: "APPS"
                font.family: Theme.fontUi
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.9
                color: Theme.muted
            }
            Text {
                anchors.right: parent.right
                text: dialog.shown.length + (dialog.shown.length === 1 ? " app" : " apps")
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
                placeholder: "Find an app by name"
                sideArrowsMove: true
                onTextChanged: dialog.selected = 0
                onMoved: (dx, dy) => dialog.selected = Math.max(0, Math.min(dialog.shown.length - 1, dialog.selected + dx + dy * dialog.columns))
                onAccepted: dialog.choose()
                onCancelled: UiState.appsScreen = ""
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
                cellWidth: dialog.cellW
                cellHeight: dialog.cellH
                model: dialog.shown
                currentIndex: dialog.selected
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

                delegate: Rectangle {
                    id: cell

                    required property var modelData
                    required property int index
                    readonly property bool chosen: index === dialog.selected
                    readonly property string icon: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""

                    width: dialog.cellW
                    height: dialog.cellH
                    color: chosen || hover.hovered ? Theme.surface2 : "transparent"
                    border.width: chosen ? 1 : 0
                    border.color: Theme.accent

                    IconImage {
                        visible: cell.icon !== ""
                        x: (parent.width - width) / 2
                        y: 14
                        implicitSize: 40
                        source: cell.icon
                    }
                    // an app without an icon: its initials in a box, as in the launcher
                    Rectangle {
                        visible: cell.icon === ""
                        x: (parent.width - width) / 2
                        y: 14
                        width: 40
                        height: 40
                        color: "transparent"
                        border.width: 1
                        border.color: cell.chosen ? Theme.accent : Theme.borderStrong

                        Text {
                            anchors.centerIn: parent
                            text: Apps.glyph(cell.modelData.name)
                            font.family: Theme.fontMono
                            font.pixelSize: 14
                            color: cell.chosen ? Theme.accent : Theme.text
                        }
                    }
                    Text {
                        x: 6
                        y: 62
                        width: parent.width - 12
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.name
                        elide: Text.ElideRight
                        font.family: Theme.fontUi
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Theme.text
                    }

                    HoverHandler {
                        id: hover
                    }
                    TapHandler {
                        onTapped: {
                            dialog.selected = cell.index;
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
                text: "↵ launch · ← → ↑ ↓ move · Esc close"
                font.family: Theme.fontMono
                font.pixelSize: 10
                color: Theme.muted
            }
        }
    }
}
