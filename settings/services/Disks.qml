pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Settings > Storage: the disks and their partitions (lsblk), how full the mounted ones are (df), and, on demand,
// what fills your home (du, one level down). Nothing here changes anything.
Singleton {
    id: root

    property var disks: []        // [{ name, model, size, removable, parts: [{ name, label, fstype, size, mount, used }] }]
    property var home: []         // [{ path, name, size }], biggest first
    property real homeSize: 0
    property bool measuring: false
    property bool measured: false

    // 1 500 000 000 -> "1.5 GB"
    function size(bytes) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let v = Number(bytes);
        let i = 0;
        while (v >= 1000 && i < units.length - 1) {
            v /= 1000;
            i++;
        }
        return (v >= 100 || i === 0 ? Math.round(v) : v.toFixed(1)) + " " + units[i];
    }

    function refresh() {
        if (!reader.running)
            reader.running = true;
    }

    function measure() {
        if (du.running)
            return;
        measuring = true;
        du.running = true;
    }

    Process {
        id: reader
        running: true
        command: ["sh", "-c", "lsblk -J -b -o NAME,SIZE,TYPE,FSTYPE,LABEL,MODEL,RM,MOUNTPOINTS; echo '@@'; df -B1 --output=target,used 2>/dev/null | tail -n +2"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [json, dfText] = text.split("@@");
                const used = {};
                for (const l of (dfText ?? "").split("\n")) {
                    const m = l.trim().match(/^(\S+)\s+(\d+)$/);
                    if (m)
                        used[m[1]] = Number(m[2]);
                }
                try {
                    const devs = JSON.parse(json).blockdevices ?? [];
                    const part = p => {
                        const mount = (p.mountpoints ?? []).filter(x => x).sort((a, b) => a.length - b.length)[0] ?? "";
                        return { name: p.name, label: p.label ?? "", fstype: p.fstype ?? "", size: p.size, mount: mount, used: mount !== "" ? used[mount] ?? -1 : -1 };
                    };
                    root.disks = devs.filter(d => d.type === "disk" && !/^(zram|loop)/.test(d.name)).map(d => ({
                        name: d.name, model: (d.model ?? "").trim(), size: d.size, removable: d.rm === true || d.rm === "1",
                        parts: (d.children ?? []).filter(c => c.type === "part" || c.type === "crypt" || c.type === "lvm").map(part)
                            .concat((d.children ?? []).length === 0 && (d.mountpoints ?? []).some(x => x) ? [part(d)] : [])
                    }));
                } catch (e) {
                    console.warn("storage:", e);
                }
            }
        }
    }

    // One level under home, on this disk only (-x), biggest first.
    Process {
        id: du
        command: ["sh", "-c", "du -x -d1 -B1 \"$HOME\" 2>/dev/null | sort -rn | head -n 15"]
        stdout: StdioCollector {
            onStreamFinished: {
                const home = Quickshell.env("HOME");
                const out = [];
                for (const l of text.split("\n")) {
                    const m = l.match(/^(\d+)\s+(.*)$/);
                    if (!m)
                        continue;
                    if (m[2] === home)
                        root.homeSize = Number(m[1]);
                    else
                        out.push({ path: m[2], name: m[2].slice(home.length + 1), size: Number(m[1]) });
                }
                root.home = out;
                root.measuring = false;
                root.measured = true;
            }
        }
    }

    // A disk plugged in, a partition mounted.
    Timer {
        running: true
        repeat: true
        interval: 10000
        onTriggered: root.refresh()
    }
}
