pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Wi-Fi state through NetworkManager's nmcli.
Singleton {
    id: root

    property bool wifiEnabled: true
    property string ssid: ""

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
        command: ["nmcli", "-t", "-f", "ACTIVE,SSID", "dev", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.split("\n").find(l => l.startsWith("yes:"));
                root.ssid = line ? line.slice(4) : "";
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
