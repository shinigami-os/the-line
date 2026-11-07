pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// The emoji picker's list (assets/emoji.txt, built by scripts/build-emoji.py) and the ones used lately
// (~/.local/state/the-line/emoji-recent.json).
Singleton {
    id: root

    property var all: []      // { char, group, name }
    property var recent: []   // chars, most recent first

    // Every word of the query in the name; nothing typed: the recent ones, then everything.
    function search(query) {
        const words = query.trim().toLowerCase().split(/\s+/).filter(w => w !== "");
        if (words.length === 0) {
            const rec = recent.map(c => all.find(e => e.char === c)).filter(e => e);
            return rec.concat(all.filter(e => !recent.includes(e.char)));
        }
        return all.filter(e => words.every(w => e.name.includes(w) || e.group.startsWith(w)));
    }

    function pick(char) {
        Quickshell.execDetached(["wl-copy", char]);
        recent = [char].concat(recent.filter(c => c !== char)).slice(0, 24);
        recentFile.setText(JSON.stringify(recent));
    }

    FileView {
        path: Qt.resolvedUrl("../assets/emoji.txt").toString().replace("file://", "")
        onLoaded: {
            root.all = text().split("\n").filter(l => l !== "" && !l.startsWith("#")).map(l => {
                const f = l.split("\t");
                return { char: f[0], group: f[1], name: f[2] ?? "" };
            });
        }
    }

    FileView {
        id: recentFile
        path: Quickshell.env("HOME") + "/.local/state/the-line/emoji-recent.json"
        printErrors: false
        onLoaded: {
            try {
                root.recent = JSON.parse(text());
            } catch (e) {
                root.recent = [];
            }
        }
    }
}
