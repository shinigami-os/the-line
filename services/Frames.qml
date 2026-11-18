pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// One still frame of each video wallpaper, for its thumbnail and for the accent (matugen reads pictures):
// taken a second in by mpv, kept in ~/.cache/the-line/frames (a cache: deleting it only costs the time to remake it).
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.cache/the-line/frames"
    property var have: ({})        // video path -> true once its frame exists
    property var waiting: []       // [{ path, then }]: called with the frame's path once it exists
    property var queue: []

    function of(path) {
        return dir + "/" + Qt.md5(path) + ".png";
    }

    // Makes the missing frames of `paths`, one mpv after the other; `then(frame)` for a single path.
    function make(paths, then) {
        const list = [].concat(paths);
        if (then && list.length === 1) {
            if (have[list[0]]) {
                then(of(list[0]));
                return;
            }
            waiting = waiting.concat([{ path: list[0], then: then }]);
        }
        queue = queue.concat(list.filter(p => !have[p] && queue.indexOf(p) < 0));
        next();
    }

    function next() {
        if (proc.running || queue.length === 0)
            return;
        const path = queue[0];
        queue = queue.slice(1);
        proc.path = path;
        proc.command = ["sh", "-c", "[ -s \"$2\" ] && exit 0; mkdir -p \"$3\"; t=$(mktemp -d) || exit 1; "
            + "mpv --no-config --really-quiet --ao=null --hwdec=no --vo=image --vo-image-format=png --vo-image-outdir=\"$t\" "
            + "--frames=1 --start=1 -- \"$1\" >/dev/null 2>&1 || mpv --no-config --really-quiet --ao=null --hwdec=no --vo=image "
            + "--vo-image-format=png --vo-image-outdir=\"$t\" --frames=1 -- \"$1\" >/dev/null 2>&1; "
            + "f=$(ls \"$t\"/*.png 2>/dev/null | head -n1); [ -n \"$f\" ] && mv \"$f\" \"$2\"; rm -rf \"$t\"; [ -s \"$2\" ]",
            "sh", path, of(path), dir];
        proc.running = true;
    }

    Process {
        id: proc

        property string path

        onExited: code => {
            const path = proc.path;
            if (code === 0) {
                const h = Object.assign({}, root.have);
                h[path] = true;
                root.have = h;
            }
            const done = root.waiting.filter(w => w.path === path);
            root.waiting = root.waiting.filter(w => w.path !== path);
            if (code === 0)
                done.forEach(w => w.then(root.of(path)));
            root.next();
        }
    }
}
