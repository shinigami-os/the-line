pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.services

// The settings app: a line across the top, the spine coming down from it with every section as a tick, and the
// selected section's box growing up and down from the branch that leaves its tick (the way the dialogs open on the
// line). Typing anywhere draws a search field out of the top line and the box grows the results.
//
// Keyboard: ↑↓ sections · → / Enter into a section · ↑↓ settings · Enter / Space change · ←→ step a slider or a
// choice · Esc / ← back to the spine · Esc on the spine or Ctrl+Q quits · any letter searches.
Item {
    id: view

    // Where the keyboard is: "spine", "content" or "search".
    property string area: "spine"
    property int sectionIndex: Registry.sections.findIndex(s => s.id === "line")
    property int rowIndex: 0
    readonly property var section: Registry.sections[sectionIndex]
    readonly property var rows: Registry.settingsOf(section.id)

    // What the box shows: a section index, or -1 for the search results. It lags behind while the box folds.
    property int shown: sectionIndex
    property bool contentShown: false
    property real grow: 0

    property var currentRow: null   // the selected SettingRow, for the rows that take the keyboard themselves

    property string query: ""
    property int resultIndex: 0
    readonly property var results: Registry.search(query)

    readonly property int topLineY: 58
    readonly property int spineX: 44
    readonly property int rowH: 31
    readonly property int firstRowY: topLineY + 30

    function rowCenter(i) {
        return firstRowY + i * rowH + rowH / 2;
    }

    // Opens a section by id (IPC, the launcher), keyboard on its settings.
    function open(id) {
        const i = Registry.sections.findIndex(s => s.id === id);
        if (i < 0)
            return;
        endSearch();
        sectionIndex = i;
        area = rows.length > 0 ? "content" : "spine";
        rowIndex = 0;
    }

    function startSearch(text) {
        area = "search";
        query = text;
        search.text = text;
        search.focusInput();
    }

    function endSearch() {
        if (area !== "search")
            return;
        area = "spine";
        query = "";
        search.text = "";
        keys.forceActiveFocus();
    }

    function jump(result) {
        if (!result)
            return;
        endSearch();
        sectionIndex = Registry.sections.findIndex(s => s.id === result.section);
        if (result.kind === "setting") {
            area = "content";
            rowIndex = Registry.settingsOf(result.section).indexOf(result.setting);
        }
    }

    // A change of what the box shows: the content leaves, the box folds onto its branch, the branch moves,
    // the box grows again and the content arrives.
    readonly property int target: area === "search" ? -1 : sectionIndex
    onTargetChanged: swap.restart()
    Component.onCompleted: swap.restart()

    // Wi-Fi scans only while the Network section is on screen.
    Binding {
        target: Net
        property: "scanning"
        value: view.shown >= 0 && Registry.sections[view.shown].id === "network"
    }

    SequentialAnimation {
        id: swap

        ScriptAction { script: view.contentShown = false }
        PauseAnimation { duration: view.grow > 0 ? Anim.exitFade : 0 }
        NumberAnimation { target: view; property: "grow"; to: 0; duration: Math.round(Anim.base * view.grow); easing.type: Anim.easing }
        ScriptAction { script: view.shown = view.target }
        PauseAnimation { duration: Anim.d(60) }
        NumberAnimation { target: view; property: "grow"; to: 1; duration: Anim.panel; easing.type: Anim.easing }
        ScriptAction { script: view.contentShown = true }
    }

    // ------------------------------------------------------------------ keyboard

    Item {
        id: keys

        focus: true
        Keys.onPressed: event => {
            Registry.keyAt = Date.now();
            const k = event.key;
            // A screen change waits to be kept: Enter keeps it, Esc goes back, wherever the keyboard is.
            if (Displays.pending && (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Escape)) {
                if (k === Qt.Key_Escape)
                    Displays.revert();
                else
                    Displays.keep();
                event.accepted = true;
                return;
            }
            if (Binds.capturing && view.currentRow) {
                view.currentRow.key(event);
                event.accepted = true;
                return;
            }
            if (event.modifiers & Qt.ControlModifier) {
                if (k === Qt.Key_Q || k === Qt.Key_W)
                    Qt.quit();
                return;
            }
            const setting = view.rows[view.rowIndex];
            const custom = setting && Registry.isCustom(setting);
            const stepper = setting && setting.kind !== "toggle" && setting.kind !== "info" && !custom;
            if (view.area === "spine") {
                if (k === Qt.Key_Up || k === Qt.Key_Down) {
                    view.sectionIndex = Math.max(0, Math.min(Registry.sections.length - 1, view.sectionIndex + (k === Qt.Key_Up ? -1 : 1)));
                } else if (k === Qt.Key_Right || k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space || k === Qt.Key_Tab) {
                    if (view.rows.length > 0) {
                        view.area = "content";
                        view.rowIndex = 0;
                    }
                } else if (k === Qt.Key_Escape) {
                    Qt.quit();
                } else if (event.text.length === 1 && event.text.trim() !== "") {
                    view.startSearch(event.text);
                } else {
                    return;
                }
            } else {
                if (custom && view.currentRow && view.currentRow.setting.key === setting.key && view.currentRow.key(event)) {
                    event.accepted = true;
                    return;
                }
                if (k === Qt.Key_Up || k === Qt.Key_Down) {
                    view.rowIndex = Math.max(0, Math.min(view.rows.length - 1, view.rowIndex + (k === Qt.Key_Up ? -1 : 1)));
                } else if ((k === Qt.Key_Left || k === Qt.Key_Right) && stepper) {
                    Registry.step(setting, k === Qt.Key_Left ? -1 : 1);
                } else if ((k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) && !custom && setting.kind !== "info") {
                    Registry.step(setting, 1);
                } else if (k === Qt.Key_Left || k === Qt.Key_Escape || k === Qt.Key_Backspace || k === Qt.Key_Backtab) {
                    view.area = "spine";
                } else if (event.text.length === 1 && event.text.trim() !== "") {
                    view.startSearch(event.text);
                } else {
                    return;
                }
            }
            event.accepted = true;
        }
    }

    // ------------------------------------------------------------------ the top line and the search

    Text {
        x: view.spineX - 20
        y: 22
        text: "SETTINGS"
        font.family: Theme.fontUi
        font.pixelSize: 10
        font.weight: Font.DemiBold
        font.letterSpacing: 1.4
        color: Theme.muted
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 28
        y: 22
        opacity: view.area === "search" ? 0 : 1
        text: "type to search"
        font.family: Theme.fontMono
        font.pixelSize: 11
        color: Theme.muted

        Behavior on opacity {
            NumberAnimation { duration: Anim.hover }
        }
    }

    Rectangle {
        x: 16
        y: view.topLineY
        width: parent.width - 32
        height: 1
        color: Theme.borderStrong
    }

    // The search field draws itself out of the top line, from the spine to the right.
    Item {
        x: box.x
        y: view.topLineY - 20
        width: view.area === "search" ? box.width : 0
        height: 40
        clip: true

        Behavior on width {
            NumberAnimation { duration: Anim.panel; easing.type: Anim.easing }
        }

        SearchField {
            id: search

            width: box.width
            height: 40
            placeholder: "Search every setting"
            onTextChanged: {
                if (view.area !== "search")
                    return;
                if (text === "")
                    view.endSearch();
                else {
                    view.query = text;
                    view.resultIndex = 0;
                }
            }
            onMoved: (dx, dy) => {
                Registry.keyAt = Date.now();
                if (dy !== 0 && view.results.length > 0)
                    view.resultIndex = (view.resultIndex + dy + view.results.length) % view.results.length;
            }
            onAccepted: view.jump(view.results[view.resultIndex])
            onCancelled: view.endSearch()
        }
    }

    // ------------------------------------------------------------------ the spine

    Rectangle {
        x: view.spineX
        y: view.topLineY
        width: 1
        height: parent.height - view.topLineY - 28
        color: Theme.borderStrong
    }

    // The marker on the spine, at the selected section.
    Rectangle {
        x: view.spineX - 1
        y: view.rowCenter(view.sectionIndex) - height / 2
        width: 3
        height: 18
        color: Theme.accent
        opacity: view.area === "search" ? 0.35 : 1

        Behavior on y {
            NumberAnimation { duration: Anim.workspace; easing.type: Anim.easing }
        }
    }

    Repeater {
        model: Registry.sections

        Item {
            id: tick

            required property var modelData
            required property int index
            readonly property bool current: index === view.sectionIndex

            x: 0
            y: view.firstRowY + index * view.rowH
            width: view.spineX + 16 + name.implicitWidth + 8
            height: view.rowH

            Text {
                anchors.right: parent.left
                anchors.rightMargin: -(view.spineX - 10)
                anchors.verticalCenter: parent.verticalCenter
                text: String(tick.index + 1).padStart(2, "0")
                font.family: Theme.fontMono
                font.pixelSize: 10
                color: tick.current ? Theme.accent : Theme.muted
            }
            Rectangle {
                x: view.spineX
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 1
                color: Theme.borderStrong
            }
            Text {
                id: name
                x: view.spineX + 16
                anchors.verticalCenter: parent.verticalCenter
                text: tick.modelData.name
                font.family: Theme.fontUi
                font.pixelSize: 13
                font.weight: Font.Medium
                color: tick.current || hover.hovered ? Theme.text : Theme.muted
                // the active section grows a little, from its tick
                scale: tick.current ? 1.12 : 1
                transformOrigin: Item.Left

                Behavior on scale {
                    NumberAnimation { duration: Anim.panel; easing.type: Anim.easing }
                }

                opacity: (tick.modelData.plan !== "" && Registry.settingsOf(tick.modelData.id).length === 0) && !tick.current ? 0.6 : 1

                Behavior on color {
                    ColorAnimation { duration: Anim.hover }
                }
            }

            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: {
                    view.endSearch();
                    view.sectionIndex = tick.index;
                    view.area = "spine";
                    keys.forceActiveFocus();
                }
            }
        }
    }

    // ------------------------------------------------------------------ the box

    // Where the box hangs from: the shown section's tick, or the top line for the search.
    readonly property real branchY: shown < 0 ? box.y : Math.min(box.y + box.height - 1, rowCenter(shown))
    readonly property real branchFrom: {
        if (shown < 0)
            return spineX;
        return spineX + 16 + shownName.implicitWidth * 1.12 + 10;
    }

    // The shown section's name, measured (never drawn) for where the branch starts.
    Text {
        id: shownName
        visible: false
        text: view.shown >= 0 ? Registry.sections[view.shown].name : ""
        font.family: Theme.fontUi
        font.pixelSize: 13
        font.weight: Font.Medium
    }

    // The branch from the tick to the box.
    Rectangle {
        visible: view.shown >= 0
        x: view.branchFrom
        y: view.branchY
        width: Math.max(0, box.x - x)
        height: 1
        color: Theme.borderStrong
        opacity: view.grow > 0 ? 1 : 0.5
    }

    Item {
        id: box

        x: 268
        y: view.topLineY + 26
        width: parent.width - x - 28
        height: parent.height - y - 28

        // The visible part, grown up and down from the branch.
        Item {
            id: frame

            y: (view.branchY - box.y) * (1 - view.grow)
            width: parent.width
            height: Math.max(1, box.height * view.grow)
            clip: true

            Rectangle {
                anchors.fill: parent
                color: Theme.surface
                opacity: Math.min(1, view.grow * 1.4)
            }

            // The content is laid out at full size and revealed by the frame.
            Item {
                y: -frame.y
                width: box.width
                height: box.height

                Loader {
                    anchors.fill: parent
                    active: view.shown >= 0
                    sourceComponent: sectionView
                }
                Loader {
                    anchors.fill: parent
                    active: view.shown < 0
                    sourceComponent: resultsView
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.borderStrong }
            Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: Theme.borderStrong }
            Rectangle { width: 1; height: parent.height; color: Theme.borderStrong }
            Rectangle { x: parent.width - 1; width: 1; height: parent.height; color: Theme.borderStrong }
        }
    }

    // ------------------------------------------------------------------ a section

    Component {
        id: sectionView

        Item {
            id: page

            readonly property var sec: Registry.sections[view.shown]
            readonly property var settings: Registry.settingsOf(sec.id)
            // Groups and rows in order: { group } or { setting, index }.
            readonly property var items: {
                const out = [];
                let last = "";
                settings.forEach((s, i) => {
                    if (s.group !== last) {
                        out.push({ group: s.group });
                        last = s.group;
                    }
                    out.push({ setting: s, index: i });
                });
                return out;
            }

            PanelItem {
                order: 0
                shown: view.contentShown
                x: 28
                y: 22
                width: parent.width - 56
                height: 40

                Text {
                    id: title
                    text: page.sec.name
                    font.family: Theme.fontUi
                    font.pixelSize: 24
                    font.weight: Font.Light
                    color: Theme.text
                }
                Text {
                    anchors.left: title.right
                    anchors.leftMargin: 12
                    anchors.baseline: title.baseline
                    text: String(view.shown + 1).padStart(2, "0")
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    color: Theme.accent
                }
            }

            // What the system helper is doing, or why it didn't work (System, Sign-in, Power: the password prompts).
            Text {
                readonly property bool here: ["system", "signin", "power"].indexOf(page.sec.id) >= 0
                visible: here && (Sys.busy !== "" || Sys.error !== "")
                x: 28
                y: 60
                text: Sys.busy !== "" ? Sys.busy : Sys.error
                font.family: Theme.fontMono
                font.pixelSize: 11
                color: Sys.busy !== "" ? Theme.accent : Theme.error
            }

            // Displays: a change waiting to be kept, or why one was refused.
            Row {
                visible: page.sec.id === "displays" && (Displays.pending || Displays.error !== "")
                x: 28
                y: 60
                spacing: 18

                Text {
                    text: Displays.pending ? "Keep these settings? Going back in " + Displays.countdown + " s" : Displays.error
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    color: Displays.pending ? Theme.accent : Theme.error
                }
                Text {
                    visible: Displays.pending
                    text: "↵ keep"
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Theme.text

                    TapHandler {
                        onTapped: Displays.keep()
                    }
                }
                Text {
                    visible: Displays.pending
                    text: "Esc go back"
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    color: Theme.muted

                    TapHandler {
                        onTapped: Displays.revert()
                    }
                }
            }

            // Not built yet: what is coming.
            PanelItem {
                visible: page.settings.length === 0
                order: 1
                shown: view.contentShown
                x: 28
                y: 78
                width: parent.width - 56
                height: 60

                Column {
                    spacing: 6

                    Text {
                        text: "Coming next"
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        color: Theme.accent
                    }
                    Text {
                        text: page.sec.plan
                        font.family: Theme.fontUi
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: Theme.muted
                    }
                }
            }

            Flickable {
                id: flick

                x: 28
                y: 74
                width: parent.width - 56
                height: parent.height - y - 18
                contentHeight: list.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // Keeps the selected row in view; a row taller than the view keeps its own cursor's line in view.
                function reveal(item) {
                    const row = view.currentRow;
                    if (item.height > height - 40 && row && row.cursorY >= 0) {
                        follow();
                        return;
                    }
                    const top = item.y;
                    const bottom = item.y + item.height;
                    if (top < contentY)
                        contentY = Math.max(0, top - 30);
                    else if (bottom > contentY + height)
                        contentY = bottom - height + 8;
                }

                Behavior on contentY {
                    NumberAnimation { duration: Anim.base; easing.type: Anim.easing }
                }

                // Inside a tall row: its own cursor's line stays in view.
                function follow() {
                    const row = view.currentRow;
                    if (!row || row.cursorY < 0)
                        return;
                    const top = row.mapToItem(list, 0, row.cursorY).y;
                    if (top < contentY + 20)
                        contentY = Math.max(0, top - 40);
                    else if (top + row.cursorH > contentY + height - 8)
                        contentY = Math.min(list.implicitHeight - height, top + row.cursorH - height + 40);
                }

                Connections {
                    target: view.currentRow

                    function onCursorYChanged() {
                        flick.follow();
                    }
                }

                Column {
                    id: list
                    width: flick.width

                    Repeater {
                        model: page.items

                        PanelItem {
                            id: entry

                            required property var modelData
                            required property int index
                            readonly property bool isGroup: modelData.group !== undefined
                            readonly property bool selected: !isGroup && view.area === "content" && view.rowIndex === modelData.index

                            order: 1 + index
                            shown: view.contentShown
                            width: list.width
                            height: isGroup ? (index === 0 ? 26 : 44) : (rowLoader.item ? rowLoader.item.height : 52)

                            onSelectedChanged: {
                                if (selected) {
                                    view.currentRow = rowLoader.item;
                                    flick.reveal(entry);
                                }
                            }

                            Text {
                                visible: entry.isGroup
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                                text: (entry.modelData.group ?? "").toUpperCase()
                                font.family: Theme.fontUi
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.9
                                color: Theme.muted
                            }

                            Loader {
                                id: rowLoader
                                active: !entry.isGroup
                                width: parent.width
                                onLoaded: {
                                    if (entry.selected) {
                                        view.currentRow = item;
                                        revealLater.restart();
                                    }
                                }

                                // A jump selects the row before it exists: reveal it once the list has its heights.
                                Timer {
                                    id: revealLater
                                    interval: 50
                                    onTriggered: flick.reveal(entry)
                                }
                                sourceComponent: SettingRow {
                                    width: entry.width
                                    setting: entry.modelData.setting
                                    selected: entry.selected
                                    onRefocus: keys.forceActiveFocus()
                                    onPicked: {
                                        if (view.area === "search")
                                            return;
                                        view.area = "content";
                                        view.rowIndex = entry.modelData.index;
                                        keys.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------ search results

    Component {
        id: resultsView

        Item {
            PanelItem {
                order: 0
                shown: view.contentShown
                x: 28
                y: 22
                width: parent.width - 56
                height: 20

                Text {
                    text: view.results.length > 0 ? "RESULTS" : "NOTHING MATCHES"
                    font.family: Theme.fontUi
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.9
                    color: Theme.muted
                }
            }

            Column {
                x: 28
                y: 50
                width: parent.width - 56

                Repeater {
                    model: view.results

                    PanelItem {
                        id: result

                        required property var modelData
                        required property int index
                        readonly property bool selected: index === view.resultIndex

                        order: 1 + index
                        shown: view.contentShown
                        width: parent.width
                        height: 48

                        Rectangle {
                            anchors.fill: parent
                            color: result.selected ? Theme.surface2 : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: Anim.hover }
                            }
                        }
                        Rectangle {
                            width: 2
                            height: parent.height
                            color: Theme.accent
                            opacity: result.selected ? 1 : 0
                        }
                        Text {
                            id: resultLabel
                            x: 18
                            y: resultSub.visible ? 7 : (parent.height - height) / 2
                            text: Registry.highlight(result.modelData.label, view.query)
                            textFormat: Text.StyledText
                            font.family: Theme.fontUi
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: Theme.text
                        }
                        Text {
                            id: resultSub
                            x: 18
                            y: 27
                            visible: text !== ""
                            width: parent.width - 160
                            elide: Text.ElideRight
                            text: Registry.highlight(result.modelData.kind === "setting" ? (result.modelData.setting.sub ?? "") : (Registry.section(result.modelData.section)?.plan ?? ""), view.query)
                            textFormat: Text.StyledText
                            font.family: Theme.fontUi
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.muted
                        }
                        Text {
                            anchors.left: resultLabel.right
                            anchors.leftMargin: 14
                            anchors.baseline: resultLabel.baseline
                            text: result.modelData.where
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Theme.muted
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            text: result.modelData.kind === "setting" ? Registry.valueText(result.modelData.setting) : "›"
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            color: Theme.muted
                        }

                        HoverHandler {
                            onHoveredChanged: if (hovered && Registry.hoverPicks()) view.resultIndex = result.index
                        }
                        TapHandler {
                            onTapped: view.jump(result.modelData)
                        }
                    }
                }
            }
        }
    }
}
