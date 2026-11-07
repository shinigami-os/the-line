pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// The clipboard history, from cliphist (recorded by session/the-line-clipboard). Images get a thumbnail, decoded
// into the runtime directory.
Singleton {
    id: root

    property var entries: []   // newest first: { id, text, image: { format, w, h, size } | null, thumb }
    readonly property string thumbDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/the-line-clip"

    function refresh() {
        if (!lister.running)
            lister.running = true;
    }

    function copy(id) {
        Quickshell.execDetached(["sh", "-c", "cliphist decode " + Number(id) + " | wl-copy"]);
    }

    function remove(id) {
        entries = entries.filter(e => e.id !== id);
        Quickshell.execDetached(["sh", "-c", "printf '%s\\t\\n' " + Number(id) + " | cliphist delete"]);
    }

    function wipe() {
        entries = [];
        Quickshell.execDetached(["cliphist", "wipe"]);
    }

    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab <= 0)
                        continue;
                    const id = Number(line.slice(0, tab));
                    const preview = line.slice(tab + 1);
                    const m = preview.match(/^\[\[ binary data (.+?) (png|jpe?g|webp|bmp|gif) (\d+)x(\d+) \]\]$/);
                    list.push({
                        id: id,
                        text: m ? "" : preview,
                        image: m ? { size: m[1], format: m[2], w: Number(m[3]), h: Number(m[4]) } : null,
                        thumb: m ? "file://" + root.thumbDir + "/" + id + "." + m[2] : ""
                    });
                }
                root.entries = list;
                // Thumbnails for the most recent images.
                const ids = list.filter(e => e.image).slice(0, 40).map(e => e.id + "." + e.image.format);
                if (ids.length > 0) {
                    thumbs.command = ["sh", "-c", "mkdir -p '" + root.thumbDir + "' && cd '" + root.thumbDir + "' && for f in " + ids.join(" ")
                        + "; do [ -s \"$f\" ] || cliphist decode \"${f%%.*}\" > \"$f\"; done"];
                    thumbs.running = true;
                }
            }
        }
    }

    // When the thumbnails are written, re-announce the entries so the images load.
    Process {
        id: thumbs
        onExited: root.entries = root.entries.slice()
    }
}
