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
    property var byChar: ({})
    property var recent: []   // chars, most recent first

    // Recent ones first (those that still exist), then everything else.
    readonly property var defaultList: {
        if (all.length === 0)
            return [];
        const seen = {};
        const rec = [];
        for (const c of recent) {
            if (byChar[c]) {
                rec.push(byChar[c]);
                seen[c] = true;
            }
        }
        return rec.concat(all.filter(e => !seen[e.char]));
    }

    // Every word of the query in the name; nothing typed: the recent ones, then everything.
    function search(query) {
        const words = query.trim().toLowerCase().split(/\s+/).filter(w => w !== "");
        if (words.length === 0)
            return defaultList;
        return all.filter(e => words.every(w => e.name.includes(w) || e.group.startsWith(w)));
    }

    function pick(char) {
        Quickshell.execDetached(["wl-copy", char]);
        recent = [char].concat(recent.filter(c => c !== char)).slice(0, 24);
        recentFile.setText(JSON.stringify(recent));
    }

    FileView {
        // read the first time the picker opens, not at login
        path: UiState.emojiScreen !== "" || root.all.length > 0 ? Qt.resolvedUrl("../assets/emoji.txt").toString().replace("file://", "") : ""
        onLoaded: {
            const map = {};
            root.all = text().split("\n").filter(l => l !== "" && !l.startsWith("#")).map(l => {
                const f = l.split("\t");
                const item = { char: f[0], group: f[1], name: f[2] ?? "" };
                map[item.char] = item;
                return item;
            });
            root.byChar = map;
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
