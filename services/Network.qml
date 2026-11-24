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

    // The networks around, for the status panel's Wi-Fi view: only kept while it is shown (`watching`).
    property var networks: []        // [{ ssid, signal, secure, active, known }], connected first, then saved, then strongest
    property var known: []           // saved Wi-Fi connection names
    property string busy: ""         // the SSID being connected to
    property string error: ""
    property bool watching: false

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
        if (watching)
            scan(false);
    }

    // nmcli -t escapes ":" inside a value as "\:".
    function fields(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            if (line[i] === "\\" && i + 1 < line.length) {
                cur += line[++i];
            } else if (line[i] === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += line[i];
            }
        }
        out.push(cur);
        return out;
    }

    function scan(rescan) {
        if (!saved.running)
            saved.running = true;
        if (!list.running) {
            list.command = ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,SSID", "dev", "wifi", "list", "--rescan", rescan ? "yes" : "no"];
            list.running = true;
        }
    }

    function connectTo(net, password) {
        error = "";
        busy = net.ssid;
        if (net.known && password === "")
            run(["nmcli", "con", "up", "id", net.ssid]);
        else if (net.secure)
            run(["nmcli", "dev", "wifi", "connect", net.ssid, "password", password]);
        else
            run(["nmcli", "dev", "wifi", "connect", net.ssid]);
    }

    function disconnectFrom(net) {
        run(["nmcli", "con", "down", "id", net.ssid]);
    }

    function run(cmd) {
        action.command = cmd;
        action.running = true;
    }

    onWatchingChanged: {
        error = "";
        if (watching)
            scan(true);
    }

    Process {
        id: action
        stderr: StdioCollector {
            id: actionErr
        }
        onExited: code => {
            if (code !== 0) {
                const msg = actionErr.text.trim().split("\n").pop().replace(/^Error:\s*/, "");
                root.error = /secrets|password|802-1x|psk/i.test(msg) ? "Wrong password, or the network refused it" : msg;
            }
            root.busy = "";
            root.refresh();
        }
    }

    Process {
        id: saved
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "con", "show"]
        stdout: StdioCollector {
            onStreamFinished: root.known = text.split("\n").map(l => root.fields(l)).filter(f => f[1] === "802-11-wireless").map(f => f[0])
        }
    }

    Process {
        id: list
        stdout: StdioCollector {
            onStreamFinished: {
                const best = {};
                for (const line of text.split("\n")) {
                    const f = root.fields(line);
                    if (f.length < 4 || f[3] === "")
                        continue;
                    const n = { ssid: f[3], signal: Number(f[1]) || 0, secure: f[2] !== "" && f[2] !== "--", active: f[0] === "*" };
                    const prev = best[n.ssid];
                    if (!prev || n.active || (!prev.active && n.signal > prev.signal))
                        best[n.ssid] = n;
                }
                const next = Object.values(best).map(n => Object.assign(n, { known: root.known.indexOf(n.ssid) >= 0 }))
                    .sort((a, b) => (b.active - a.active) || (b.known - a.known) || (b.signal - a.signal));
                if (JSON.stringify(next) !== JSON.stringify(root.networks))
                    root.networks = next;
            }
        }
    }

    // While the Wi-Fi view is open the list is rescanned every 10 s.
    Timer {
        running: root.watching && root.wifiEnabled
        repeat: true
        interval: 10000
        onTriggered: root.scan(true)
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
