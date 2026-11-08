pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Settings > Appearance > Icons: the icon themes installed (cursor-only themes left out), by their own name.
Singleton {
    id: root

    property var choices: [{ value: "", label: "automatic" }]

    Process {
        running: true
        command: ["sh", "-c", "for d in \"$HOME/.icons\" \"$HOME/.local/share/icons\" /usr/local/share/icons /usr/share/icons; do "
            + "for t in \"$d\"/*/index.theme; do [ -f \"$t\" ] || continue; grep -q '^Directories=' \"$t\" || continue; "
            + "grep -q '^Hidden=true' \"$t\" && continue; "
            + "printf '%s\\t%s\\n' \"$(basename \"$(dirname \"$t\")\")\" \"$(sed -n 's/^Name=//p' \"$t\" | head -1)\"; done; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                const list = [];
                for (const line of text.split("\n")) {
                    const [dir, name] = line.split("\t");
                    if (!dir || seen[dir] || dir === "hicolor" || dir === "default")
                        continue;
                    seen[dir] = true;
                    list.push({ value: dir, label: name || dir });
                }
                list.sort((a, b) => a.label.localeCompare(b.label));
                root.choices = [{ value: "", label: "automatic" }].concat(list);
            }
        }
    }
}
