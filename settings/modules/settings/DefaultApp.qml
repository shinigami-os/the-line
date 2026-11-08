pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// Settings > Default apps: the app that opens one kind of file or link (setting.app: browser, files, images...,
// or terminal). Enter shows the apps that can; ↑↓ and Enter pick one, Esc closes the list.
Item {
    id: row

    property var setting
    property bool active: false
    property bool open: false
    property int pick: 0

    signal picked

    readonly property bool terminal: setting?.app === "terminal"
    readonly property var options: !setting ? [] : terminal ? Defaults.terminals()
        : Defaults.choices(setting.app).map(id => ({ value: id, label: Defaults.nameOf(id) }))
    readonly property string value: !setting ? "" : terminal ? Config.terminal : Defaults.current[setting.app] ?? ""
    readonly property string valueName: terminal ? (options.find(o => o.value === value)?.label ?? value) : Defaults.nameOf(value)

    implicitHeight: open ? 34 + options.length * 34 : 34
    readonly property real cursorY: open ? (pick + 1) * 34 : 0

    onActiveChanged: if (!active) open = false

    function choose(o) {
        if (terminal)
            Config.set("terminal", o.value);
        else
            Defaults.set(setting.app, o.value);
        open = false;
    }

    function key(event) {
        const k = event.key;
        if (!open) {
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
                open = true;
                pick = Math.max(0, options.findIndex(o => o.value === value));
                return true;
            }
            return false;
        }
        if (k === Qt.Key_Up || k === Qt.Key_Down) {
            pick = (pick + (k === Qt.Key_Up ? -1 : 1) + options.length) % Math.max(1, options.length);
            return true;
        }
        if ((k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) && options[pick]) {
            choose(options[pick]);
            return true;
        }
        if (k === Qt.Key_Escape || k === Qt.Key_Left) {
            open = false;
            return true;
        }
        return true;
    }

    Column {
        width: parent.width

        ListLine {
            width: row.width
            name: row.valueName
            detail: row.options.length === 0 ? "no app says it opens this" : row.open ? "" : row.options.length + (row.options.length === 1 ? " app can" : " apps can")
            trailing: row.active && !row.open ? "↵ change" : ""
            lit: true
            under: row.active && !row.open
            onClicked: {
                row.picked();
                row.open = !row.open;
                row.pick = Math.max(0, row.options.findIndex(o => o.value === row.value));
            }
        }

        Repeater {
            model: row.open ? row.options : []

            ListLine {
                required property var modelData
                required property int index

                width: row.width
                name: "    " + modelData.label
                detail: modelData.value
                trailing: modelData.value === row.value ? "in use" : ""
                under: index === row.pick
                onEntered: row.pick = index
                onClicked: row.choose(modelData)
            }
        }
    }
}
