pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.modules.common
import qs.services

// Settings > Workspaces > Apps on their workspace. One line per app, with a ruler of the ten workspaces (the one it
// opens on lit), and "add an app" last, which opens a search over the open windows and the installed apps.
// Keyboard: ↑↓ lines · ←→ workspace · Delete removes · Enter on "add an app" searches (Enter adds, Esc closes).
// The list lives in config.json (workspaceApps); the shell writes the Hyprland rules from it.
Item {
    id: rules

    property bool active: false
    property int cursor: 0
    property bool adding: false
    property string query: ""
    property int pick: 0
    readonly property var list: Config.workspaceApps ?? []

    signal picked
    signal refocus

    implicitHeight: lines.implicitHeight + (adding ? 8 + addBox.height : 0)

    function save(next) {
        Config.set("workspaceApps", next);
    }

    function setWorkspace(i, ws) {
        const next = list.slice();
        next[i] = Object.assign({}, next[i], { workspace: Math.max(1, Math.min(10, ws)) });
        save(next);
    }

    function remove(i) {
        const next = list.slice();
        next.splice(i, 1);
        save(next);
        cursor = Math.min(cursor, next.length);
    }

    // What can be added: open windows first (their class is certain), then installed apps.
    readonly property var candidates: {
        const seen = {};
        const out = [];
        for (const r of list)
            seen[r.class] = true;
        for (const t of Hyprland.toplevels.values) {
            const cls = t.lastIpcObject?.class ?? "";
            if (cls === "" || seen[cls])
                continue;
            seen[cls] = true;
            const entry = DesktopEntries.heuristicLookup(cls);
            out.push({ class: cls, name: entry?.name ?? cls, detail: "open now", workspace: t.workspace?.id ?? 1 });
        }
        for (const a of DesktopEntries.applications.values) {
            if (a.noDisplay)
                continue;
            const cls = a.startupClass || a.id;
            if (!cls || seen[cls])
                continue;
            seen[cls] = true;
            out.push({ class: cls, name: a.name, detail: a.genericName || "", workspace: 1 });
        }
        return out;
    }
    readonly property var matches: {
        const q = query.trim().toLowerCase();
        return candidates.filter(c => q === "" || c.name.toLowerCase().includes(q) || c.class.toLowerCase().includes(q)).slice(0, 6);
    }

    function startAdding() {
        Hyprland.refreshToplevels();
        adding = true;
        query = "";
        pick = 0;
        field.text = "";
        field.focusInput();
    }

    function stopAdding() {
        adding = false;
        refocus();
    }

    function add(c) {
        if (!c)
            return;
        const next = list.concat([{ class: c.class, name: c.name, workspace: Math.max(1, Math.min(10, c.workspace)) }]);
        save(next);
        cursor = next.length - 1;
        stopAdding();
    }

    function key(event) {
        const k = event.key;
        const n = list.length;
        if (k === Qt.Key_Up && cursor > 0) {
            cursor--;
            return true;
        }
        if (k === Qt.Key_Down && cursor < n) {
            cursor++;
            return true;
        }
        if (cursor < n && (k === Qt.Key_Left || k === Qt.Key_Right)) {
            setWorkspace(cursor, list[cursor].workspace + (k === Qt.Key_Left ? -1 : 1));
            return true;
        }
        if (cursor < n && (k === Qt.Key_Delete || k === Qt.Key_Backspace)) {
            remove(cursor);
            return true;
        }
        if (cursor === n && (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)) {
            startAdding();
            return true;
        }
        return false;
    }

    Column {
        id: lines
        width: parent.width

        Repeater {
            model: rules.list

            Item {
                id: line

                required property var modelData
                required property int index
                readonly property bool under: rules.active && rules.cursor === index

                width: lines.width
                height: 34

                Rectangle {
                    anchors.fill: parent
                    color: line.under ? Theme.surface : "transparent"
                }
                Text {
                    id: appName
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: line.modelData.name ?? line.modelData.class
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Theme.text
                }
                Text {
                    anchors.left: appName.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: line.modelData.class
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    color: Theme.muted
                }

                // The ten workspaces, the app's lit like the marker on the line.
                Row {
                    id: ruler
                    anchors.right: removeText.left
                    anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: 10

                        Item {
                            id: cell

                            required property int index
                            readonly property bool lit: line.modelData.workspace === index + 1

                            width: 20
                            height: 22

                            Text {
                                anchors.centerIn: parent
                                text: String((cell.index + 1) % 10)
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                                color: cell.lit ? Theme.accent : Theme.muted
                            }
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 0
                                width: 12
                                height: 2
                                color: Theme.accent
                                visible: cell.lit
                            }
                            TapHandler {
                                onTapped: {
                                    rules.picked();
                                    rules.cursor = line.index;
                                    rules.setWorkspace(line.index, cell.index + 1);
                                }
                            }
                        }
                    }
                }

                Text {
                    id: removeText
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "remove"
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    color: removeHover.hovered ? Theme.error : Theme.muted

                    HoverHandler {
                        id: removeHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: rules.remove(line.index)
                    }
                }

                HoverHandler {
                    onHoveredChanged: if (hovered && rules.active) rules.cursor = line.index
                }
            }
        }

        // The last line: add an app.
        Item {
            width: lines.width
            height: 34

            Rectangle {
                anchors.fill: parent
                color: rules.active && rules.cursor === rules.list.length && !rules.adding ? Theme.surface : "transparent"
            }
            Text {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                text: rules.list.length === 0 ? "+ add an app   (none yet: every app opens where you are)" : "+ add an app"
                font.family: Theme.fontMono
                font.pixelSize: 11
                color: Theme.accent
            }
            HoverHandler {
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: if (hovered && rules.active) rules.cursor = rules.list.length
            }
            TapHandler {
                onTapped: {
                    rules.picked();
                    rules.cursor = rules.list.length;
                    rules.startAdding();
                }
            }
        }
    }

    // The search for an app to add.
    Column {
        id: addBox

        visible: rules.adding
        y: lines.implicitHeight + 8
        width: parent.width
        spacing: 0

        SearchField {
            id: field

            width: parent.width
            placeholder: "Which app? (open windows first)"
            onTextChanged: {
                rules.query = text;
                rules.pick = 0;
            }
            onMoved: (dx, dy) => {
                if (dy !== 0 && rules.matches.length > 0)
                    rules.pick = (rules.pick + dy + rules.matches.length) % rules.matches.length;
            }
            onAccepted: rules.add(rules.matches[rules.pick])
            onCancelled: rules.stopAdding()
        }

        Repeater {
            model: rules.adding ? rules.matches : []

            Rectangle {
                id: match

                required property var modelData
                required property int index

                width: addBox.width
                height: 32
                color: index === rules.pick ? Theme.surface : "transparent"

                Text {
                    id: matchName
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: match.modelData.name
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Theme.text
                }
                Text {
                    anchors.left: matchName.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: match.modelData.class + (match.modelData.detail ? "  ·  " + match.modelData.detail : "")
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    color: Theme.muted
                }
                HoverHandler {
                    onHoveredChanged: if (hovered) rules.pick = match.index
                }
                TapHandler {
                    onTapped: rules.add(match.modelData)
                }
            }
        }
    }
}
