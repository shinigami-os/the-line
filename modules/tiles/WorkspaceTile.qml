import QtQuick
import Quickshell.Hyprland
import qs.modules.common
import qs.services

// Top-left tile: ten workspace numerals hung under ticks on the line, and the window title under them.
// It grows into the launcher: open an app or run a command. The panel's height follows the number of results.
Tile {
    id: tile

    required property string screenName
    required property int workspace   // active workspace of this screen

    readonly property var toplevel: Hyprland.activeToplevel

    // Launcher state. The query lives in UiState so IPC can open the launcher with a search typed in.
    readonly property string query: UiState.launcherQuery
    property int selected: 0
    readonly property int maxRows: 6
    readonly property var apps: Apps.search(query, maxRows)
    readonly property bool showRun: query.trim() !== "" && apps.length === 0
    readonly property var results: showRun ? [{ kind: "run" }] : apps.map(a => ({ kind: "app", app: a }))

    function occupied(n) {
        const ws = Hyprland.workspaces.values.find(w => w.id === n);
        return !!ws && ws.toplevels.values.length > 0;
    }

    function move(delta) {
        if (results.length > 0)
            selected = (selected + delta + results.length) % results.length;
    }

    function activate(index) {
        const r = results[index];
        if (!r)
            return;
        if (r.kind === "app")
            Apps.launch(r.app);
        else
            Apps.runInTerminal(query.trim());
        UiState.close();
    }

    function complete() {
        const r = results[selected];
        if (r?.kind === "app")
            UiState.launcherQuery = r.app.name;
    }

    anchorSide: "left"
    restW: 26 + 10 * Theme.wsCell
    openW: 560
    // Search field, section label, one row per result, footer.
    openH: Theme.tileHeight + 12 + 48 + 24 + Math.max(1, results.length) * 32 + 34 + 12
    mode: UiState.isOpen(screenName, "tl") ? "open" : "rest"

    onQueryChanged: selected = 0
    onOpenChanged: {
        if (open)
            search.forceActiveFocus();
        else
            UiState.launcherQuery = "";
    }

    Item {
        anchors.fill: parent

        // Workspace ruler: 10 cells, ticks hanging from the line.
        Row {
            x: 13
            y: 1

            Repeater {
                model: 10

                Item {
                    id: cell

                    required property int index
                    readonly property int n: index + 1
                    readonly property bool active: n === tile.workspace
                    readonly property bool busy: tile.occupied(n)

                    width: Theme.wsCell
                    height: 20

                    Rectangle {
                        x: Theme.wsCell / 2 - 1
                        width: 1
                        height: cell.active ? 0 : (cell.busy ? 7 : 4)
                        color: cell.busy ? Theme.muted : Theme.borderStrong
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        text: cell.n % 10
                        font.family: Theme.fontUi
                        font.pixelSize: 12
                        font.weight: cell.active ? Font.Bold : Font.Medium
                        color: cell.active ? Theme.accent : (cell.busy ? Theme.text : (cellHover.hovered ? Theme.text : Theme.muted))
                    }

                    HoverHandler {
                        id: cellHover
                    }
                    TapHandler {
                        onTapped: Hyprland.dispatch("workspace " + cell.n)
                    }
                }
            }
        }

        // Window title under the numerals. It opens the launcher, and uses the extra room while open.
        Row {
            id: titleRow
            x: 13
            y: 22
            width: (tile.open ? tile.width - 26 - who.width - 12 : tile.restW - 26)
            spacing: 8
            clip: true

            Text {
                text: tile.toplevel ? (tile.toplevel.title || "Untitled") : "Desktop"
                font.family: Theme.fontUi
                font.pixelSize: 12
                font.weight: Font.Medium
                color: titleHover.hovered ? Theme.accent : Theme.text
                elide: Text.ElideRight
                width: Math.min(implicitWidth, tile.open ? titleRow.width * 0.7 : 130)
            }
            Text {
                text: tile.toplevel ? (tile.toplevel.lastIpcObject?.class ?? "") : "no windows"
                font.family: Theme.fontMono
                font.pixelSize: 10
                color: Theme.muted
            }

            HoverHandler {
                id: titleHover
            }
            TapHandler {
                onTapped: UiState.toggle(tile.screenName, "tl")
            }
        }

        // user@host, written on the right while the launcher is open.
        Text {
            id: who
            anchors.right: parent.right
            anchors.rightMargin: 13
            y: 22
            text: Session.user + "@" + Session.host.toLowerCase()
            font.family: Theme.fontMono
            font.pixelSize: 10
            color: Theme.muted
            opacity: tile.open ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: Anim.base }
            }
        }
    }

    bodyData: [
        Column {
            id: launcher

            x: 13
            y: 12
            width: tile.openW - 26
            spacing: 0

            component Section: Text {
                width: launcher.width
                height: 24
                leftPadding: 4
                verticalAlignment: Text.AlignVCenter
                font.family: Theme.fontUi
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.9
                color: Theme.muted
            }

            // Search field.
            PanelItem {
                order: 0
                shown: tile.open
                width: launcher.width
                height: 48

                Rectangle {
                    width: parent.width
                    height: 40
                    color: Theme.bg
                    border.width: 1
                    border.color: search.activeFocus ? Theme.accent : Theme.borderStrong

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
                        id: search

                        anchors.left: prompt.right
                        anchors.leftMargin: 10
                        anchors.right: escCap.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: tile.query
                        onTextEdited: UiState.launcherQuery = text
                        font.family: Theme.fontUi
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentText
                        clip: true

                        Keys.onUpPressed: tile.move(-1)
                        Keys.onDownPressed: tile.move(1)
                        Keys.onReturnPressed: tile.activate(tile.selected)
                        Keys.onEnterPressed: tile.activate(tile.selected)
                        Keys.onEscapePressed: UiState.close()
                        Keys.onTabPressed: tile.complete()

                        Text {
                            visible: search.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Open, run or find"
                            font: search.font
                            color: Theme.muted
                        }
                    }

                    Rectangle {
                        id: escCap
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: escText.implicitWidth + 12
                        height: 18
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.borderStrong

                        Text {
                            id: escText
                            anchors.centerIn: parent
                            text: "Esc"
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            color: Theme.muted
                        }
                    }
                }
            }

            PanelItem {
                order: 1
                shown: tile.open
                width: launcher.width
                height: 24

                Section {
                    text: tile.showRun ? "RUN" : "APPS"
                }
            }

            // Six app slots (or the run row when nothing matches).
            Repeater {
                model: tile.maxRows

                PanelItem {
                    id: appSlot

                    required property int index
                    readonly property var result: tile.results[index] ?? null

                    visible: result !== null
                    order: 2 + index
                    shown: tile.open
                    width: launcher.width
                    height: 32

                    LauncherRow {
                        width: parent.width
                        selected: tile.selected === appSlot.index
                        glyph: appSlot.result?.kind === "run" ? "$" : Apps.glyph(appSlot.result?.app?.name ?? "")
                        name: appSlot.result?.kind === "run" ? tile.query.trim() : (appSlot.result?.app?.name ?? "")
                        monoName: appSlot.result?.kind === "run"
                        description: appSlot.result?.kind === "run" ? "run in terminal" : (appSlot.result?.app?.genericName || appSlot.result?.app?.comment || "")
                        keycap: tile.selected === appSlot.index ? "↵" : ""
                        onHovered: tile.selected = appSlot.index
                        onActivated: tile.activate(appSlot.index)
                    }
                }
            }

            PanelItem {
                order: 2 + tile.maxRows
                shown: tile.open
                width: launcher.width
                height: 34

                Rectangle {
                    y: 8
                    width: parent.width
                    height: 1
                    color: Theme.border
                }
                Row {
                    x: 4
                    y: 16
                    spacing: 16

                    Repeater {
                        model: ["↵ open", "↑↓ move", "Tab complete", "Esc close"]

                        Text {
                            required property string modelData

                            text: modelData
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            color: Theme.muted
                        }
                    }
                }
            }
        }
    ]
}
