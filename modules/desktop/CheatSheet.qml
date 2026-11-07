import QtQuick
import qs.modules.common
import qs.services

// Every shortcut, in one sheet (SUPER+F1). Grown from the line like the other dialogs. Tabs (← → or a click):
// the desktop, then each app Kira ships that has shortcuts. Everything comes from Cheatsheet, read live.
CenterDialog {
    id: sheet

    required property string screenName

    property int tab: 0
    readonly property var tabs: Cheatsheet.tabs
    readonly property var groups: tabs[Math.min(tab, tabs.length - 1)]?.groups ?? []

    // Groups shared out over three columns, each going to the shortest one.
    readonly property var columns: {
        const cols = [[], [], []];
        const heights = [0, 0, 0];
        for (const g of groups) {
            const i = heights.indexOf(Math.min(...heights));
            cols[i].push(g);
            heights[i] += g.rows.length + 2;
        }
        return cols;
    }

    open: UiState.sheetScreen === screenName
    onOutsideClicked: UiState.sheetScreen = ""
    boxWidth: Math.min(1040, width - 80)
    boxHeight: Math.min(660, height - 120)

    onOpenChanged: {
        if (open) {
            tab = UiState.sheetTab;
            UiState.sheetTab = 0;
            Cheatsheet.refresh();
        }
    }
    onContentShownChanged: if (contentShown) keys.forceActiveFocus()

    Item {
        id: keys

        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: UiState.sheetScreen = ""
        Keys.onLeftPressed: sheet.tab = (sheet.tab + sheet.tabs.length - 1) % sheet.tabs.length
        Keys.onRightPressed: sheet.tab = (sheet.tab + 1) % sheet.tabs.length
        Keys.onTabPressed: sheet.tab = (sheet.tab + 1) % sheet.tabs.length

        // Header: the title, and the tabs with their marker.
        PanelItem {
            order: 0
            shown: sheet.contentShown
            x: 22
            y: 18
            width: sheet.boxWidth - 44
            height: 30

            Text {
                text: "EVERY SHORTCUT"
                font.family: Theme.fontUi
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.9
                color: Theme.muted
            }

            Row {
                id: tabRow
                anchors.right: parent.right
                spacing: 22

                Repeater {
                    model: sheet.tabs

                    Text {
                        id: tabText

                        required property var modelData
                        required property int index

                        text: modelData.name
                        font.family: Theme.fontUi
                        font.pixelSize: 13
                        font.weight: index === sheet.tab ? Font.DemiBold : Font.Medium
                        color: index === sheet.tab ? Theme.text : (tabHover.hovered ? Theme.text : Theme.muted)

                        HoverHandler {
                            id: tabHover
                        }
                        TapHandler {
                            onTapped: sheet.tab = tabText.index
                        }
                    }
                }
            }

            // The marker under the active tab: the same 14 x 3 bar as on the line.
            Rectangle {
                readonly property Item current: tabRow.children[sheet.tab] ?? null

                y: 22
                x: tabRow.x + (current ? current.x + current.width / 2 - 7 : 0)
                width: 14
                height: 3
                color: Theme.accent

                Behavior on x {
                    NumberAnimation { duration: Anim.workspace; easing.type: Anim.easing }
                }
            }

            Rectangle {
                y: 29
                width: parent.width
                height: 1
                color: Theme.border
            }
        }

        Flickable {
            x: 22
            y: 62
            width: sheet.boxWidth - 44
            height: sheet.boxHeight - 62 - 18
            contentHeight: cols.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: cols
                spacing: 28

                Repeater {
                    model: sheet.columns

                    Column {
                        id: column

                        required property var modelData
                        required property int index

                        width: (sheet.boxWidth - 44 - 2 * 28) / 3
                        spacing: 18

                        Repeater {
                            model: column.modelData

                            PanelItem {
                                id: group

                                required property var modelData
                                required property int index

                                order: 1 + column.index + group.index * 3
                                shown: sheet.contentShown
                                width: column.width
                                height: groupCol.implicitHeight

                                Column {
                                    id: groupCol
                                    width: parent.width
                                    spacing: 6

                                    Text {
                                        text: group.modelData.group.toUpperCase()
                                        font.family: Theme.fontUi
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 0.9
                                        color: Theme.muted
                                    }

                                    Repeater {
                                        model: group.modelData.rows

                                        Item {
                                            id: row

                                            required property var modelData

                                            width: groupCol.width
                                            height: Math.max(capsFlow.implicitHeight, desc.implicitHeight)

                                            Flow {
                                                id: capsFlow
                                                width: 150
                                                spacing: 3

                                                Repeater {
                                                    model: row.modelData.keys.length

                                                    Row {
                                                        id: combo

                                                        required property int index

                                                        spacing: 3

                                                        Text {
                                                            visible: combo.index > 0
                                                            text: "/"
                                                            font.family: Theme.fontMono
                                                            font.pixelSize: 10
                                                            color: Theme.muted
                                                        }

                                                        Repeater {
                                                            model: row.modelData.keys[combo.index]

                                                            Rectangle {
                                                                required property string modelData

                                                                width: capText.implicitWidth + 10
                                                                height: 17
                                                                color: "transparent"
                                                                border.width: 1
                                                                border.color: Theme.borderStrong

                                                                Text {
                                                                    id: capText
                                                                    anchors.centerIn: parent
                                                                    text: parent.modelData
                                                                    font.family: Theme.fontMono
                                                                    font.pixelSize: 10
                                                                    color: Theme.text
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            Text {
                                                id: desc
                                                x: 158
                                                width: parent.width - 158
                                                text: row.modelData.text
                                                wrapMode: Text.Wrap
                                                font.family: Theme.fontUi
                                                font.pixelSize: 12
                                                font.weight: Font.Medium
                                                color: Theme.text
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
