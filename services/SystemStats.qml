pragma Singleton

import QtQuick
import TheLine.Ui
import Quickshell
import Quickshell.Io
import TheLine.Core

// CPU, memory, load, temperatures and processes. The reading (/proc once a second, the sensors every two) is done by
// TheLine.Core's SystemSampler on a thread of its own; this file only hands its figures on. The process list (top) is
// only asked for while `watching`.
Singleton {
    id: root

    readonly property int historyLength: 60

    readonly property real cpu: sampler.cpu          // 0..1
    readonly property var cores: sampler.cores       // 0..1 per core
    readonly property real ram: sampler.ram
    readonly property real swap: sampler.swap
    readonly property real ramUsedKiB: sampler.ramUsedKiB
    readonly property real ramTotalKiB: sampler.ramTotalKiB
    readonly property real swapUsedKiB: sampler.swapUsedKiB
    readonly property real swapTotalKiB: sampler.swapTotalKiB
    readonly property string load: sampler.load      // "0.42 0.38 0.30"
    readonly property real uptime: sampler.uptime    // seconds, whole minutes
    property var cpuHistory: new Array(historyLength).fill(0)
    property var processes: [] // [{ name, cpu, mem }], busiest first

    // Temperatures, °C (NaN when there is no such sensor). A GPU is only read where its sensor costs nothing: an
    // NVIDIA card asleep would be woken up by asking it, so it is left alone.
    readonly property real cpuTemp: sampler.cpuTemp
    readonly property real gpuTemp: sampler.gpuTemp
    readonly property var temps: sampler.temps       // [{ group: "CPU", label: "Core 0", c: 41, crit: 100 }], grouped, CPU first

    // The dashboard is open (on whichever screen): the per-core loads and the sensor list are only kept while it is.
    readonly property bool watching: UiState.openPanel === "tp"

    function formatKiB(kib) {
        if (kib >= 1048576)
            return (kib / 1048576).toFixed(1) + " GiB";
        return Math.round(kib / 1024) + " MiB";
    }

    function formatUptime(seconds) {
        const h = Math.floor(seconds / 3600), m = Math.floor((seconds % 3600) / 60);
        return (h > 0 ? h + " h " : "") + m + " min";
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

    SystemSampler {
        id: sampler
        watching: root.watching
        onSampled: root.cpuHistory = root.cpuHistory.slice(1).concat(sampler.cpu)
    }

    // Sampled on the clock's own tick, not on a timer of its own: the new figures land in the same frame as the
    // new second, so the line redraws once a second instead of twice.
    Connections {
        target: Time
        function onTick() {
            sampler.tick();
        }
    }
    Component.onCompleted: sampler.tick()

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
