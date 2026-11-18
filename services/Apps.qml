pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Desktop applications, searched by the launcher. Launch counts are kept in ~/.local/state/the-line/apps.json
// so the apps you open most come first when the search is empty.
Singleton {
    id: root

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/the-line"
    readonly property var all: DesktopEntries.applications.values.filter(a => !a.noDisplay)
    property var counts: ({})

    // Two-letter mono glyph for an app: initials of the first two words, or its first two letters.
    function glyph(name) {
        const words = name.split(/[\s\-_.]+/).filter(w => w.length > 0);
        return (words.length > 1 ? words[0][0] + words[1][0] : name.slice(0, 2)).toLowerCase();
    }

    // The apps with their searchable text lowercased and split once, not on every keystroke.
    readonly property var index: all.map(a => {
        const name = a.name.toLowerCase();
        return { app: a, name: name, words: name.split(/[\s\-_.]+/), generic: (a.genericName ?? "").toLowerCase(),
            keywords: (a.keywords ?? []).map(k => k.toLowerCase()), comment: (a.comment ?? "").toLowerCase() };
    })
    // Most launched first, then by name: what an empty search shows.
    readonly property var byUse: all.slice().sort((a, b) => (counts[b.id] ?? 0) - (counts[a.id] ?? 0) || a.name.localeCompare(b.name))

    function score(e, q) {
        let s = 0;
        if (e.name.startsWith(q))
            s = 100;
        else if (e.words.some(w => w.startsWith(q)))
            s = 80;
        else if (e.name.includes(q))
            s = 60;
        else if (e.generic.includes(q) || e.keywords.some(k => k.includes(q)))
            s = 40;
        else if (e.comment.includes(q))
            s = 20;
        return s > 0 ? s + Math.min(15, Math.log2(1 + (counts[e.app.id] ?? 0)) * 3) : 0;
    }

    function search(query, limit) {
        const q = query.trim().toLowerCase();
        if (q === "")
            return byUse.slice(0, limit);
        return index.map(e => ({ app: e.app, s: score(e, q) })).filter(x => x.s > 0).sort((a, b) => b.s - a.s || a.app.name.localeCompare(b.app.name)).slice(0, limit).map(x => x.app);
    }

    function launch(app) {
        const c = Object.assign({}, counts);
        c[app.id] = (c[app.id] ?? 0) + 1;
        counts = c;
        file.setText(JSON.stringify(counts));
        app.execute();
    }

    // Runs a shell command in a terminal that stays open afterwards.
    function runInTerminal(command) {
        Quickshell.execDetached([Config.terminal, "-e", "sh", "-c", command + "; exec \"${SHELL:-sh}\""]);
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", stateDir])

    FileView {
        id: file
        path: root.stateDir + "/apps.json"
        printErrors: false
        onLoaded: {
            try {
                root.counts = JSON.parse(text());
            } catch (e) {
                root.counts = {};
            }
        }
    }
}
