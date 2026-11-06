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

    function score(app, q) {
        const name = app.name.toLowerCase();
        let s = 0;
        if (name.startsWith(q))
            s = 100;
        else if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
            s = 80;
        else if (name.includes(q))
            s = 60;
        else if ((app.genericName ?? "").toLowerCase().includes(q) || (app.keywords ?? []).some(k => k.toLowerCase().includes(q)))
            s = 40;
        else if ((app.comment ?? "").toLowerCase().includes(q))
            s = 20;
        return s > 0 ? s + Math.min(15, Math.log2(1 + (counts[app.id] ?? 0)) * 3) : 0;
    }

    function search(query, limit) {
        const q = query.trim().toLowerCase();
        if (q === "")
            return all.slice().sort((a, b) => (counts[b.id] ?? 0) - (counts[a.id] ?? 0) || a.name.localeCompare(b.name)).slice(0, limit);
        return all.map(a => ({ app: a, s: score(a, q) })).filter(x => x.s > 0).sort((a, b) => b.s - a.s || a.app.name.localeCompare(b.app.name)).slice(0, limit).map(x => x.app);
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
