pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU, RAM and swap load, read from /proc once a second. `cpuHistory` feeds the graph in the status tile.
Singleton {
    id: root

    readonly property int historyLength: 24

    property real cpu: 0       // 0..1
    property real ram: 0
    property real swap: 0
    property var cpuHistory: new Array(historyLength).fill(0)

    property real _idle: 0
    property real _total: 0

    function sample() {
        const stat = procStat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        const idle = stat[3] + stat[4];
        const total = stat.reduce((a, b) => a + b, 0);
        if (_total > 0 && total > _total)
            cpu = 1 - (idle - _idle) / (total - _total);
        _idle = idle;
        _total = total;
        cpuHistory = cpuHistory.slice(1).concat(cpu);

        const mem = {};
        for (const line of procMem.text().split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m)
                mem[m[1]] = Number(m[2]);
        }
        ram = mem.MemTotal > 0 ? 1 - mem.MemAvailable / mem.MemTotal : 0;
        swap = mem.SwapTotal > 0 ? 1 - mem.SwapFree / mem.SwapTotal : 0;
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

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 1000
        onTriggered: {
            procStat.reload();
            procMem.reload();
            root.sample();
        }
    }
}
