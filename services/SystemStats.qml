pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory, load and processes. /proc is read once a second; the process list (top) only while `watching`.
Singleton {
    id: root

    readonly property int historyLength: 60

    property real cpu: 0       // 0..1
    property var cores: []     // 0..1 per core
    property real ram: 0
    property real swap: 0
    property real ramUsedKiB: 0
    property real ramTotalKiB: 0
    property real swapUsedKiB: 0
    property real swapTotalKiB: 0
    property string load: ""   // "0.42 0.38 0.30"
    property real uptime: 0    // seconds
    property var cpuHistory: new Array(historyLength).fill(0)
    property var processes: [] // [{ name, cpu, mem }], busiest first

    // The dashboard sets this while it is open.
    property bool watching: false

    property var _prev: ({})

    function formatKiB(kib) {
        if (kib >= 1048576)
            return (kib / 1048576).toFixed(1) + " GiB";
        return Math.round(kib / 1024) + " MiB";
    }

    function formatUptime(seconds) {
        const h = Math.floor(seconds / 3600), m = Math.floor((seconds % 3600) / 60);
        return (h > 0 ? h + " h " : "") + m + " min";
    }

    function sample() {
        const loads = [];
        for (const line of procStat.text().split("\n")) {
            if (!line.startsWith("cpu"))
                continue;
            const f = line.trim().split(/\s+/);
            const v = f.slice(1).map(Number);
            const idle = v[3] + v[4];
            const total = v.reduce((a, b) => a + b, 0);
            const prev = _prev[f[0]];
            const load = prev && total > prev.total ? 1 - (idle - prev.idle) / (total - prev.total) : 0;
            _prev[f[0]] = { idle: idle, total: total };
            if (f[0] === "cpu")
                cpu = load;
            else
                loads.push(load);
        }
        cores = loads;
        cpuHistory = cpuHistory.slice(1).concat(cpu);

        const mem = {};
        for (const line of procMem.text().split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m)
                mem[m[1]] = Number(m[2]);
        }
        ramTotalKiB = mem.MemTotal ?? 0;
        ramUsedKiB = ramTotalKiB - (mem.MemAvailable ?? 0);
        swapTotalKiB = mem.SwapTotal ?? 0;
        swapUsedKiB = swapTotalKiB - (mem.SwapFree ?? 0);
        ram = ramTotalKiB > 0 ? ramUsedKiB / ramTotalKiB : 0;
        swap = swapTotalKiB > 0 ? swapUsedKiB / swapTotalKiB : 0;

        load = procLoad.text().trim().split(" ").slice(0, 3).join(" ");
        uptime = Number(procUptime.text().trim().split(" ")[0]) || 0;
    }

    // RES column of top: KiB, or with an m / g suffix.
    function _resToKiB(res) {
        const n = parseFloat(res);
        if (res.endsWith("g"))
            return n * 1048576;
        if (res.endsWith("m"))
            return n * 1024;
        return n;
    }

    FileView {
        id: procStat
        path: "/proc/stat"
        blockLoading: true
    }
    FileView {
        id: procMem
        path: "/proc/meminfo"
        blockLoading: true
    }
    FileView {
        id: procLoad
        path: "/proc/loadavg"
        blockLoading: true
    }
    FileView {
        id: procUptime
        path: "/proc/uptime"
        blockLoading: true
    }

    // Sampled on the clock's own tick, not on a timer of its own: the new figures land in the same frame as the
    // new second, so the line redraws once a second instead of twice.
    function tick() {
        procStat.reload();
        procMem.reload();
        procLoad.reload();
        procUptime.reload();
        root.sample();
    }
    Component.onCompleted: tick()
    Connections {
        target: Time
        function onNowChanged() {
            root.tick();
        }
    }

    // Second iteration of top, so the CPU figures are live and not averaged since boot.
    Process {
        id: top
        command: ["top", "-b", "-n", "2", "-d", "0.6", "-w", "200", "-o", "%CPU"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const head = lines.map(l => l.trim().startsWith("PID ")).lastIndexOf(true);
                if (head < 0)
                    return;
                root.processes = lines.slice(head + 1, head + 6).filter(l => l.trim() !== "").map(l => {
                    const f = l.trim().split(/\s+/);
                    return { name: f.slice(11).join(" "), cpu: Number(f[8]), mem: root._resToKiB(f[5]) };
                });
            }
        }
    }

    Timer {
        running: root.watching
        repeat: true
        triggeredOnStart: true
        interval: 2500
        onTriggered: if (!top.running) top.running = true
    }
}
