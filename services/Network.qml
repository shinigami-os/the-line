pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Wi-Fi state through NetworkManager's nmcli.
Singleton {
    id: root

    property bool wifiEnabled: true
    property string ssid: ""
    property int signal: 0   // 0..100

    readonly property bool connected: wifiEnabled && ssid !== ""
    readonly property string label: !wifiEnabled ? "off" : (ssid !== "" ? ssid : "not connected")

    function setWifi(on) {
        wifiEnabled = on;
        toggler.command = ["nmcli", "radio", "wifi", on ? "on" : "off"];
        toggler.running = true;
    }

    function refresh() {
        if (!radio.running)
            radio.running = true;
        if (!active.running)
            active.running = true;
    }

    Process {
        id: radio
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: root.wifiEnabled = text.trim() === "enabled"
        }
    }

    Process {
        id: active
        command: ["nmcli", "-t", "-f", "ACTIVE,SIGNAL,SSID", "dev", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                // yes:72:MATRIXBOX (colons inside the SSID are escaped as \:)
                const line = text.split("\n").find(l => l.startsWith("yes:"));
                const rest = line ? line.slice(4) : "";
                const sep = rest.indexOf(":");
                root.signal = line ? Number(rest.slice(0, sep)) : 0;
                root.ssid = line ? rest.slice(sep + 1).replace(/\\:/g, ":") : "";
            }
        }
    }

    Process {
        id: toggler
        onRunningChanged: if (!running) refreshSoon.restart()
    }

    Timer {
        id: refreshSoon
        interval: 1500
        onTriggered: root.refresh()
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 8000
        onTriggered: root.refresh()
    }
}
