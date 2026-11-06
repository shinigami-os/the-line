pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Kira's dev environments: the kira-devkit-* recipes known to flux, and whether each one is installed.
Singleton {
    id: root

    property var kits: []   // [{ name, description, installed }]

    function refresh() {
        if (!lister.running)
            lister.running = true;
    }

    function search(query, limit) {
        const q = query.trim().toLowerCase();
        const hits = q === "" ? kits : kits.filter(k => k.name.includes(q) || k.description.toLowerCase().includes(q));
        return hits.slice().sort((a, b) => (b.installed - a.installed) || a.name.localeCompare(b.name)).slice(0, limit);
    }

    function install(kit) {
        Apps.runInTerminal("sudo flux install " + kit.name);
    }

    Process {
        id: lister
        command: ["sh", "-c", "for d in /var/lib/flux/recipes/kira-devkit-*; do n=${d##*/}; "
            + "desc=$(grep -m1 '^description' \"$d/kotodama\" | cut -d'\"' -f2); "
            + "[ -e /var/lib/flux/installed/$n ] && s=1 || s=0; echo \"$n|$s|$desc\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.kits = text.split("\n").filter(l => l.includes("|")).map(l => {
                    const f = l.split("|");
                    return { name: f[0], installed: f[1] === "1", description: f.slice(2).join("|") };
                });
            }
        }
    }

    Component.onCompleted: refresh()
}
