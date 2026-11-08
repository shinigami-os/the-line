pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.modules.common
import qs.services

// Settings > Input > Keyboard layout: the layout in use; Enter searches every layout and variant xkb knows
// ("french", "bépo", "dvorak", "de"), Enter picks one. The first line goes back to the console's own (vconsole.conf).
Item {
    id: picker

    property var setting
    property bool active: false
    property bool searching: false
    property string query: ""
    property int pick: 0
    property var layouts: []        // [{ layout, variant, name }]
    property string consoleLayout: "us"

    signal picked
    signal refocus

    readonly property string inUse: Config.kbLayout === "" ? "" : Config.kbLayout + (Config.kbVariant !== "" ? ":" + Config.kbVariant : "")
    readonly property var matches: {
        const q = query.trim().toLowerCase();
        const first = [{ layout: "", variant: "", name: "The console's layout (" + consoleLayout + ")" }];
        if (q === "")
            return first;
        return layouts.filter(l => l.name.toLowerCase().includes(q) || (l.layout + (l.variant ? ":" + l.variant : "")) === q || l.layout === q)
            .slice(0, 7);
    }

    implicitHeight: searching ? 44 + matches.length * 34 : 40

    function nameOf(code) {
        if (code === "")
            return "The console's (" + consoleLayout + ")";
        const [l, v] = code.split(":");
        return layouts.find(x => x.layout === l && x.variant === (v ?? ""))?.name ?? code;
    }

    function choose(entry) {
        Config.set("kbLayout", entry.layout);
        Config.set("kbVariant", entry.variant);
        stop();
    }

    function start() {
        searching = true;
        query = "";
        pick = 0;
        field.text = "";
        field.focusInput();
    }

    function stop() {
        searching = false;
        refocus();
    }

    function key(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            start();
            return true;
        }
        return false;
    }

    // xkb's list: "! layout" lines are "  fr   French", "! variant" lines "  azerty   fr: French (AZERTY)".
    Process {
        running: true
        command: ["sh", "-c", "cat /usr/share/X11/xkb/rules/evdev.lst; echo '! console'; sed -n 's/^KEYMAP=//p' /etc/vconsole.conf"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                let part = "";
                for (const line of text.split("\n")) {
                    if (line.startsWith("!")) {
                        part = line.slice(1).trim();
                        continue;
                    }
                    if (part === "console") {
                        if (line.trim() !== "")
                            picker.consoleLayout = line.trim().replace(/['"]/g, "").toLowerCase();
                        continue;
                    }
                    const m = line.match(/^\s+(\S+)\s+(.*)$/);
                    if (!m)
                        continue;
                    if (part === "layout")
                        out.push({ layout: m[1], variant: "", name: m[2] });
                    else if (part === "variant") {
                        const v = m[2].match(/^(\S+):\s*(.*)$/);
                        if (v)
                            out.push({ layout: v[1], variant: m[1], name: v[2] });
                    }
                }
                picker.layouts = out;
            }
        }
    }

    Text {
        visible: !picker.searching
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        text: picker.nameOf(picker.inUse) + (picker.active ? "      ↵ change" : "")
        font.family: Theme.fontMono
        font.pixelSize: 12
        color: Theme.text

        TapHandler {
            onTapped: {
                picker.picked();
                picker.start();
            }
        }
    }

    Column {
        visible: picker.searching
        width: parent.width

        SearchField {
            id: field

            width: parent.width
            placeholder: "A language or a layout (French, bépo, Dvorak, de…)"
            onTextChanged: {
                picker.query = text;
                picker.pick = 0;
            }
            onMoved: (dx, dy) => {
                if (dy !== 0 && picker.matches.length > 0)
                    picker.pick = (picker.pick + dy + picker.matches.length) % picker.matches.length;
            }
            onAccepted: if (picker.matches.length > 0) picker.choose(picker.matches[picker.pick])
            onCancelled: picker.stop()
        }

        Repeater {
            model: picker.searching ? picker.matches : []

            ListLine {
                required property var modelData
                required property int index

                width: picker.width
                name: modelData.name
                detail: modelData.layout === "" ? "" : modelData.layout + (modelData.variant ? ":" + modelData.variant : "")
                under: index === picker.pick
                onEntered: picker.pick = index
                onClicked: picker.choose(modelData)
            }
        }
    }
}
