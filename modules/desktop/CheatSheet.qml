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
    boxWidth: Math.min(1080, width - 80)
    // As tall as the content, up to 70% of the screen (it scrolls beyond).
    boxHeight: Math.min(62 + cols.implicitHeight + 22, Math.round(height * 0.7))

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
        Keys.onBacktabPressed: sheet.tab = (sheet.tab + sheet.tabs.length - 1) % sheet.tabs.length

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

            // Hairlines between the columns (outside the columns, so they don't feed their own height).
            Repeater {
                model: 2

                Rectangle {
                    required property int index

                    x: (index + 1) * ((sheet.boxWidth - 44 - 2 * 41) / 3 + 41) - 21
                    width: 1
                    height: cols.implicitHeight
                    color: Theme.border
                }
            }

            Row {
                id: cols
                spacing: 41

                Repeater {
                    model: sheet.columns

                    Column {
                        id: column

                        required property var modelData
                        required property int index

                        width: (sheet.boxWidth - 44 - 2 * 41) / 3
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

                                        // "What it does ....... keys": the description on the left, the keys on the
                                        // right (one combination per line), a dotted leader between them.
                                        Item {
                                            id: row

                                            required property var modelData
                                            readonly property real descEnd: Math.min(desc.implicitWidth, desc.width)

                                            width: groupCol.width
                                            height: Math.max(keyCol.implicitHeight, desc.implicitHeight) + 2

                                            Column {
                                                id: keyCol
                                                anchors.right: parent.right
                                                spacing: 3

                                                Repeater {
                                                    model: row.modelData.keys

                                                    Row {
                                                        id: combo

                                                        required property var modelData

                                                        anchors.right: parent.right
                                                        spacing: 3

                                                        Repeater {
                                                            model: combo.modelData

                                                            // "›" between the steps of a chord (yazi's g › g) is a mark, not a key
                                                            Rectangle {
                                                                required property string modelData
                                                                readonly property bool then: modelData === "›"

                                                                width: capText.implicitWidth + (then ? 2 : 10)
                                                                height: 17
                                                                color: "transparent"
                                                                border.width: then ? 0 : 1
                                                                border.color: Theme.borderStrong

                                                                Text {
                                                                    id: capText
                                                                    anchors.centerIn: parent
                                                                    text: parent.modelData
                                                                    font.family: Theme.fontMono
                                                                    font.pixelSize: 10
                                                                    color: parent.then ? Theme.muted : Theme.text
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            Text {
                                                id: desc
                                                width: Math.max(40, row.width - keyCol.implicitWidth - 20)
                                                text: row.modelData.text
                                                wrapMode: Text.Wrap
                                                font.family: Theme.fontUi
                                                font.pixelSize: 12
                                                font.weight: Font.Medium
                                                color: Theme.text
                                            }

                                            Row {
                                                x: row.descEnd + 6
                                                y: 10
                                                spacing: 3

                                                Repeater {
                                                    model: Math.max(0, Math.floor((row.width - keyCol.implicitWidth - row.descEnd - 14) / 4))

                                                    Rectangle {
                                                        width: 1
                                                        height: 1
                                                        color: Theme.borderStrong
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
    }
}
