pragma Singleton

import QtQuick
import TheLine.Ui
import Quickshell
import Quickshell.Io

// CPU, memory, load, temperatures and processes. /proc is read once a second, the sensors every two seconds; the
// process list (top) only while `watching`.
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

    // Temperatures, °C (NaN when there is no such sensor). A GPU is only read where its sensor costs nothing: an
    // NVIDIA card asleep would be woken up by asking it, so it is left alone.
    property real cpuTemp: NaN
    property real gpuTemp: NaN
    property var temps: []     // [{ group: "CPU", label: "Core 0", c: 41, crit: 100 }], grouped, CPU first

    // The dashboard is open (on whichever screen): the per-core loads and the sensor list are only kept while it is.
    readonly property bool watching: UiState.openPanel === "tp"

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
            const isTotal = line.startsWith("cpu ");
            if (!isTotal && !watching && cores.length > 0)
                continue;
            const f = line.trim().split(/\s+/);
            const v = f.slice(1).map(Number);
            const idle = v[3] + v[4];
            const total = v.reduce((a, b) => a + b, 0);
            const prev = _prev[f[0]];
            const load = prev && total > prev.total ? 1 - (idle - prev.idle) / (total - prev.total) : 0;
            _prev[f[0]] = { idle: idle, total: total };
            if (isTotal)
                cpu = load;
            else
                loads.push(load);
        }
        if (watching || cores.length === 0)
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
        // whole minutes: nothing shows the seconds, and a new value every second rebuilt the labels
        uptime = Math.floor((Number(procUptime.text().trim().split(" ")[0]) || 0) / 60) * 60;
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
    Component.onCompleted: {
        tick();
        sensors.running = true;
    }
    Connections {
        target: Time
        function onTick() {
            root.tick();
            if (Date.now() % 2000 < 1000 && !sensors.running)
                sensors.running = true;
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

    // Every hwmon sensor: "chip|label|millidegrees|crit millidegrees" per line.
    readonly property var groups: ({ coretemp: "CPU", k10temp: "CPU", zenpower: "CPU", cpu_thermal: "CPU", amdgpu: "GPU",
        radeon: "GPU", nouveau: "GPU", nvme: "Disk", drivetemp: "Disk", acpitz: "Board", pch_cometlake: "Board" })
    readonly property var groupOrder: ["CPU", "GPU", "Disk", "Board", "Wi-Fi"]

    onWatchingChanged: if (watching && !sensors.running)
        sensors.running = true

    Process {
        id: sensors
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do n=$(cat \"$h/name\" 2>/dev/null); for t in \"$h\"/temp*_input; do [ -r \"$t\" ] || continue; b=${t%_input}; echo \"$n|$(cat \"${b}_label\" 2>/dev/null)|$(cat \"$t\" 2>/dev/null)|$(cat \"${b}_crit\" 2>/dev/null)\"; done; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                let cpu = NaN, cpuRank = 9, gpu = NaN;
                for (const line of text.split("\n")) {
                    const [chip, label, milli, crit] = line.split("|");
                    const c = Number(milli) / 1000;
                    if (!chip || !isFinite(c) || milli === "" || c <= 0)
                        continue;
                    const group = root.groups[chip] ?? (chip.startsWith("iwlwifi") ? "Wi-Fi" : chip);
                    // a sensor with no label of its own is named after what it measures, not its driver
                    const name = label.replace(/^Package id \d+$/, "Package") || ({ acpitz: "ACPI", nvme: "Drive" })[chip]
                        || (chip.startsWith("iwlwifi") ? "Card" : chip);
                    if (root.watching)
                        out.push({ group: group, label: name, c: Math.round(c), crit: crit ? Number(crit) / 1000 : NaN });
                    // the CPU's one figure: the package (Intel), Tctl / Tdie (AMD), else the first CPU sensor, else the board
                    const rank = /^Package/.test(label) || /^T(ctl|die)$/.test(label) ? 0 : group === "CPU" ? 1 : chip === "acpitz" ? 2 : 9;
                    if (rank < cpuRank) {
                        cpuRank = rank;
                        cpu = Math.round(c);
                    }
                    if (group === "GPU" && (isNaN(gpu) || /edge|junction/.test(label)))
                        gpu = Math.max(isNaN(gpu) ? 0 : gpu, Math.round(c));
                }
                if (root.watching) {
                    const order = g => { const i = root.groupOrder.indexOf(g); return i < 0 ? 99 : i; };
                    // cores in their own order (Core 2 before Core 10)
                    const num = l => Number((l.match(/\d+/) ?? ["0"])[0]);
                    out.sort((a, b) => order(a.group) - order(b.group) || a.group.localeCompare(b.group)
                        || (/^Package/.test(b.label) - /^Package/.test(a.label)) || num(a.label) - num(b.label));
                    root.temps = out;
                }
                if (!(isNaN(cpu) && isNaN(root.cpuTemp)))
                    root.cpuTemp = cpu;
                if (!(isNaN(gpu) && isNaN(root.gpuTemp)))
                    root.gpuTemp = gpu;
            }
        }
    }
}
