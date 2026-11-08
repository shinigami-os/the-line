pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Settings > Default apps: which app opens what, as xdg-open sees it (~/.config/mimeapps.list, written by xdg-mime).
// The apps offered for a kind are the ones that say they open it (the mimeinfo.cache files of the system, Flatpak
// and yours). The terminal is The Line's own setting (config.json "terminal").
Singleton {
    id: root

    readonly property var kinds: ({
        browser: ["x-scheme-handler/https", "x-scheme-handler/http", "text/html"],
        files: ["inode/directory"],
        mail: ["x-scheme-handler/mailto"],
        images: ["image/png", "image/jpeg", "image/gif", "image/webp", "image/bmp", "image/tiff", "image/svg+xml"],
        video: ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime"],
        music: ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav"],
        text: ["text/plain"],
        pdf: ["application/pdf"]
    })

    property var current: ({})      // kind -> desktop id ("firefox.desktop"), or ""
    property var offered: ({})      // mime -> [desktop ids]

    // The app's name from its desktop entry, or the id.
    function nameOf(id) {
        if (!id)
            return "none";
        const short = id.replace(/\.desktop$/, "");
        const e = DesktopEntries.applications.values.find(a => a.id === short);
        return e ? e.name : short;
    }

    // The apps that open a kind: those that open its first type, the one in use first.
    function choices(kind) {
        const list = (offered[kinds[kind][0]] ?? []).slice();
        const cur = current[kind] ?? "";
        if (cur !== "" && list.indexOf(cur) < 0)
            list.unshift(cur);
        return list.filter((id, i) => list.indexOf(id) === i);
    }

    function set(kind, id) {
        const c = Object.assign({}, current);
        c[kind] = id;
        current = c;
        Quickshell.execDetached(["xdg-mime", "default", id].concat(kinds[kind]));
    }

    function terminals() {
        // one per command: the entry named after it first ("foot", not "Foot Server" which runs foot too)
        const list = DesktopEntries.applications.values.filter(e => (e.categories ?? []).indexOf("TerminalEmulator") >= 0)
            .map(e => ({ value: (e.command ?? [])[0] ?? e.id, label: e.name, own: e.id === ((e.command ?? [])[0] ?? "") }))
            .sort((a, b) => b.own - a.own);
        return list.filter((t, i) => list.findIndex(o => o.value === t.value) === i).map(t => ({ value: t.value, label: t.label }));
    }

    function refresh() {
        if (!reader.running)
            reader.running = true;
    }

    Process {
        id: reader
        running: true
        command: ["sh", "-c", "for k in \"$@\"; do echo \"default ${k%%=*} $(xdg-mime query default ${k#*=} 2>/dev/null)\"; done; "
            + "cat /usr/share/applications/mimeinfo.cache /usr/local/share/applications/mimeinfo.cache "
            + "/var/lib/flatpak/exports/share/applications/mimeinfo.cache \"$HOME/.local/share/flatpak/exports/share/applications/mimeinfo.cache\" "
            + "\"$HOME/.local/share/applications/mimeinfo.cache\" 2>/dev/null",
            "sh"].concat(Object.keys(root.kinds).map(k => k + "=" + root.kinds[k][0]))
        stdout: StdioCollector {
            onStreamFinished: {
                const cur = {};
                const off = {};
                for (const l of text.split("\n")) {
                    let m = l.match(/^default (\w+) ?(.*)$/);
                    if (m) {
                        cur[m[1]] = m[2].trim();
                        continue;
                    }
                    m = l.match(/^([\w.+-]+\/[\w.+-]+)=(.*)$/);
                    if (m)
                        off[m[1]] = (off[m[1]] ?? []).concat(m[2].split(";").filter(x => x !== ""));
                }
                root.current = cur;
                root.offered = off;
            }
        }
    }
}
