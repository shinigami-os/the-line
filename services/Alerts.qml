import QtQuick
import TheLine.Ui
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// What makes the line flash and the middle tile say why (LineState.alert): the Wi-Fi dropping, the disk nearly
// full, the CPU too hot, a microphone opened by an app. The battery is in shell.qml, a recording in session/the-line-record,
// anything else (a build, an alarm) through `the-line-alert`. Each one fires on the way in, not while it lasts.
Scope {
    id: root

    // ---- Wi-Fi: it was connected and is not, without the user turning it off
    property bool wasConnected: false

    Connections {
        target: Network

        function onConnectedChanged() {
            if (Network.connected) {
                root.wasConnected = true;
            } else if (root.wasConnected && Network.wifiEnabled) {
                root.wasConnected = false;
                LineState.alert("Wi-Fi dropped", "", Theme.error, 2);
            } else if (!Network.wifiEnabled) {
                root.wasConnected = false;
            }
        }
    }

    // ---- CPU temperature: once when it crosses 90 °C, again only after it has cooled under 80
    property bool hot: false

    Connections {
        target: SystemStats

        function onCpuTempChanged() {
            const t = SystemStats.cpuTemp;
            if (isNaN(t))
                return;
            if (!root.hot && t >= 90) {
                root.hot = true;
                LineState.alert("CPU too hot", Math.round(t) + " °C", Theme.error, 3);
            } else if (root.hot && t < 80) {
                root.hot = false;
            }
        }
    }

    // ---- disk: the root partition at 95 % or more, checked every 10 minutes, said once until it is under 90
    property bool diskWarned: false

    Timer {
        interval: 600000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: df.running = true
    }

    Process {
        id: df
        command: ["df", "-P", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.split("\n")[1]?.match(/(\d+)%/);
                const pct = m ? parseInt(m[1]) : 0;
                if (pct >= 95 && !root.diskWarned) {
                    root.diskWarned = true;
                    LineState.alert("Disk nearly full", pct + " %", Theme.error, 2);
                } else if (pct < 90) {
                    root.diskWarned = false;
                }
            }
        }
    }

    // ---- microphone: an app starts capturing
    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    property var capturing: []

    readonly property var captureNames: Pipewire.nodes.values
        .filter(n => n.isStream && !n.isSink && (n.properties["media.class"] ?? "") === "Stream/Input/Audio")
        .map(n => n.properties["application.name"] ?? n.name ?? "an app")

    onCaptureNamesChanged: {
        const fresh = captureNames.filter(n => capturing.indexOf(n) < 0);
        capturing = captureNames;
        if (fresh.length > 0)
            LineState.alert("Microphone in use", fresh[0], Theme.error, 1);
    }
}
