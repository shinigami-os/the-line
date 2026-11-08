import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.modules.common
import qs.services

// Top-left tile: ten workspace numerals hung under ticks on the line, and the window title under them.
// While a player is active, a music part is added on the right (its progress runs on the line above it).
// The workspace part grows into the launcher, the music part into the music panel.
// It grows into the launcher: open an app or run a command. The panel's height follows the number of results.
Tile {
    id: tile

    required property string screenName
    required property int workspace   // active workspace of this screen
    property bool musicHidden: false  // fullscreen: the music part leaves first

    readonly property bool musicShown: Media.active && !musicHidden

    // The focused window, the same on every screen. The desktop counts as an app: on a workspace without windows
    // nothing is focused (Hyprland drops the focus), and the tile says "Desktop" (Quickshell keeps reporting the
    // last window, so it is checked against the focused workspace).
    readonly property var toplevel: {
        const wins = Hyprland.focusedWorkspace?.toplevels?.values ?? [];
        if (wins.length === 0)
            return null;
        const t = Hyprland.activeToplevel ?? Hyprland.toplevels.values.find(w => w.activated) ?? null;
        return t && wins.includes(t) ? t : wins[0];
    }

    // The app's name; its window title only when several windows of that app are open (to tell them apart).
    readonly property string appClass: toplevel?.lastIpcObject?.class ?? ""
    readonly property string appName: {
        if (!toplevel)
            return "Desktop";
        const entry = appClass !== "" ? DesktopEntries.heuristicLookup(appClass) : null;
        if (entry?.name)
            return entry.name;
        const c = appClass.split(".").pop();
        return c !== "" ? c.charAt(0).toUpperCase() + c.slice(1) : (toplevel.title || "Untitled");
    }
    readonly property int instances: appClass === "" ? 0 : Hyprland.toplevels.values.filter(t => (t.lastIpcObject?.class ?? "") === appClass).length
    readonly property string detail: instances > 1 ? (toplevel?.title ?? "") : ""

    // Launcher state. The query lives in UiState so IPC can open the launcher with a search typed in.
    readonly property string query: UiState.launcherQuery
    property int selected: 0
    readonly property int maxRows: 6
    readonly property bool showCalc: kind === "tl" && Calc.result !== ""
    readonly property var apps: Apps.search(query, showCalc ? maxRows - 1 : maxRows)
    readonly property bool showRun: query.trim() !== "" && apps.length === 0 && !showCalc
    readonly property var results: (showCalc ? [{ kind: "calc" }] : []).concat(showRun ? [{ kind: "run" }] : apps.map(a => ({ kind: "app", app: a })))

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
        else if (r.kind === "calc")
            Calc.copy();
        else
            Apps.runInTerminal(query.trim());
        UiState.close();
    }

    function complete() {
        const r = results[selected];
        if (r?.kind === "app")
            UiState.launcherQuery = r.app.name;
        else if (r?.kind === "calc")
            UiState.launcherQuery = Calc.result;
    }

    // Which panel is open on this screen: "tl" launcher, "tm" music, "tw" workspace overview (double tap Super).
    readonly property string kind: ["tl", "tm", "tw"].find(k => UiState.isOpen(screenName, k)) ?? ""

    anchorSide: "left"
    restW: Theme.wsBlockW + (musicShown ? Theme.musicW : 0)
    openW: kind === "tw" ? 26 + 5 * 168 + 4 * 10 : 560
    // Launcher: search field, section label, one row per result, footer.
    openH: Theme.tileHeight + (kind === "tw" ? 12 + overviewPanel.implicitH + 12
        : kind === "tm" ? 12 + musicPanel.implicitHeight + 6
        : 12 + 48 + 24 + Math.max(1, results.length) * 32 + 34 + 12)
    mode: kind !== "" ? "open" : "rest"

    onQueryChanged: selected = 0
    onKindChanged: {
        if (kind === "tl")
            search.forceActiveFocus();
        else
            UiState.launcherQuery = "";
    }

    // The music panel can't stay open without a player.
    Connections {
        target: Media

        function onActiveChanged() {
            if (!Media.active && tile.kind === "tm")
                UiState.close();
        }
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

                    // Optional (config "workspaceIcons"): the icon of the workspace's first app instead of its numeral.
                    readonly property string iconName: {
                        if (!Config.workspaceIcons || !cell.busy)
                            return "";
                        const ws = Hyprland.workspaces.values.find(w => w.id === cell.n);
                        const cls = ws?.toplevels?.values?.[0]?.lastIpcObject?.class ?? "";
                        const name = cls === "" ? "" : (DesktopEntries.heuristicLookup(cls)?.icon ?? "");
                        // An icon the theme doesn't have: keep the numeral.
                        return name !== "" ? Quickshell.iconPath(name, true) : "";
                    }

                    IconImage {
                        visible: cell.iconName !== ""
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        implicitSize: 13
                        source: cell.iconName
                    }

                    Text {
                        visible: cell.iconName === ""
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
                        // Hyprland 0.55 takes Lua dispatchers.
                        onTapped: Hyprland.dispatch("hl.dsp.focus({ workspace = " + cell.n + " })")
                    }
                }
            }
        }

        // Window title under the numerals. It opens the launcher, and uses the extra room while open.
        Row {
            id: titleRow
            x: 13
            y: 22
            width: tile.open && !Media.active ? tile.width - 26 - who.width - 12 : Theme.wsBlockW - 26
            spacing: 8
            clip: true

            Text {
                id: appText
                text: tile.appName
                font.family: Theme.fontUi
                font.pixelSize: 12
                font.weight: Font.Medium
                color: titleHover.hovered ? Theme.accent : Theme.text
                elide: Text.ElideRight
                width: Math.min(implicitWidth, titleRow.width)
            }
            Text {
                visible: text !== ""
                text: tile.detail
                font.family: Theme.fontMono
                font.pixelSize: 10
                color: Theme.muted
                elide: Text.ElideRight
                width: Math.max(0, Math.min(implicitWidth, titleRow.width - appText.width - titleRow.spacing))
                anchors.baseline: appText.baseline
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
            opacity: tile.open && !Media.active ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: Anim.base }
            }
        }
    }

    // Music: play/pause, track, time. It takes the rest of the top row while the launcher is open.
    Item {
        id: music

        x: Theme.wsBlockW
        width: tile.open ? tile.width - Theme.wsBlockW : Theme.musicW
        height: Theme.tileHeight - 1
        clip: true

        // Appears as the reverse of how it leaves: the frame grows first, then the content fades in.
        opacity: tile.musicShown ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: tile.musicShown ? Anim.panel : 0 }
                NumberAnimation {
                    duration: tile.musicShown ? Anim.base : Anim.exitFade
                    easing.type: tile.musicShown ? Anim.easing : Easing.Linear
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: UiState.toggle(tile.screenName, "tm")
        }

        Rectangle {
            width: 1
            height: parent.height
            color: Theme.border
        }

        Rectangle {
            id: play

            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            color: "transparent"
            border.width: 1
            border.color: playHover.hovered ? Theme.accent : Theme.borderStrong

            Behavior on border.color {
                ColorAnimation { duration: Anim.hover }
            }

            // Pause: two bars. Play: a triangle.
            Row {
                visible: Media.playing
                anchors.centerIn: parent
                spacing: 3

                Rectangle { width: 2.5; height: 9; color: Theme.text }
                Rectangle { width: 2.5; height: 9; color: Theme.text }
            }
            Shape {
                visible: !Media.playing
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 1
                width: 8
                height: 10
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillColor: Theme.text
                    startX: 0
                    startY: 0
                    PathLine { x: 8; y: 5 }
                    PathLine { x: 0; y: 10 }
                    PathLine { x: 0; y: 0 }
                }
            }

            HoverHandler {
                id: playHover
            }
            MouseArea {
                anchors.fill: parent
                onClicked: Media.toggle()
            }
        }

        Column {
            anchors.left: play.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: tile.open && Media.artist !== "" ? Media.title + "  ·  " + Media.artist : Media.title
                elide: Text.ElideRight
                font.family: Theme.fontUi
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Theme.text
            }
            Text {
                text: Media.format(Media.position) + " / " + Media.format(Media.length)
                font.family: Theme.fontMono
                font.pixelSize: 10
                color: Theme.muted
            }
        }
    }

    bodyData: [
        // Only exists while open: its live window captures crashed Quickshell when torn down mid-switch or on reload.
        Loader {
            id: overviewPanel

            readonly property real implicitH: item?.implicitHeight ?? (2 * (95 + 20) + 10)

            x: 13
            y: 12
            active: tile.kind === "tw" || overviewLinger.running
            sourceComponent: WorkspaceOverview {
                enabled: tile.kind === "tw"
                shown: tile.kind === "tw"
                active: tile.workspace
            }

            // Kept a moment after closing, so its items can fade out with the frame.
            Timer {
                id: overviewLinger
                interval: Anim.panel + Anim.closeLead
            }
            Connections {
                target: tile
                function onKindChanged() {
                    if (tile.kind !== "tw")
                        overviewLinger.restart();
                }
            }
        },

        MusicPanel {
            id: musicPanel

            x: 13
            y: 12
            width: tile.openW - 26
            enabled: tile.kind === "tm"
            shown: tile.kind === "tm"
        },

        Column {
            id: launcher

            x: 13
            y: 12
            width: tile.openW - 26
            enabled: tile.kind === "tl"
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
                shown: tile.kind === "tl"
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
                shown: tile.kind === "tl"
                width: launcher.width
                height: 24

                Section {
                    text: tile.showCalc ? (tile.apps.length > 0 ? "CALC · APPS" : "CALC") : tile.showRun ? "RUN" : "APPS"
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
                    shown: tile.kind === "tl"
                    width: launcher.width
                    height: 32

                    LauncherRow {
                        width: parent.width
                        selected: tile.selected === appSlot.index
                        readonly property string kind: appSlot.result?.kind ?? ""

                        glyph: kind === "run" ? "$" : kind === "calc" ? "=" : Apps.glyph(appSlot.result?.app?.name ?? "")
                        icon: appSlot.result?.kind === "app" && (appSlot.result.app.icon ?? "") !== "" ? Quickshell.iconPath(appSlot.result.app.icon, true) : ""
                        name: kind === "run" ? tile.query.trim() : kind === "calc" ? Calc.result : (appSlot.result?.app?.name ?? "")
                        monoName: kind === "run" || kind === "calc"
                        description: kind === "run" ? "run in terminal" : kind === "calc" ? "copy · Tab to keep going" : (appSlot.result?.app?.genericName || appSlot.result?.app?.comment || "")
                        keycap: tile.selected === appSlot.index ? "↵" : ""
                        onHovered: tile.selected = appSlot.index
                        onActivated: tile.activate(appSlot.index)
                    }
                }
            }

            PanelItem {
                order: 2 + tile.maxRows
                shown: tile.kind === "tl"
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
