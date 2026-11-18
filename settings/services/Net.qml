pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Settings > Network, through NetworkManager's nmcli: the Wi-Fi radio, the networks around (scanned while the
// section is open), the saved ones, the cable, this computer's address. Connecting to a new secured network takes
// its password from the app; a saved one connects with what NetworkManager keeps.
Singleton {
    id: root

    property bool wifiEnabled: true
    property var networks: []        // [{ ssid, signal, secure, active, known }], strongest first, connected on top
    property var known: []           // saved Wi-Fi connection names
    property string wired: "—"       // the cable: "connected", "unplugged", ...
    property string address: "—"     // IPv4 on the local network
    property string publicAddress: "—"   // as the internet sees it: asked to api.ipify.org, only while the section is open
    property string busy: ""         // the SSID being connected to
    property string error: ""        // the last failure, said plainly
    property bool scanning: false    // true while the Network section is shown: scans every 12 s

    function set(key, value) {
        if (key === "wifiEnabled") {
            wifiEnabled = value;
            run(["nmcli", "radio", "wifi", value ? "on" : "off"]);
        }
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

    function refresh(rescan) {
        if (!radio.running)
            radio.running = true;
        if (!saved.running)
            saved.running = true;
        if (!list.running) {
            list.command = ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,SSID", "dev", "wifi", "list", "--rescan", rescan ? "yes" : "no"];
            list.running = true;
        }
        if (!devices.running)
            devices.running = true;
        if (!ip.running)
            ip.running = true;
    }

    function connect(net, password) {
        error = "";
        busy = net.ssid;
        if (net.known && password === "")
            run(["nmcli", "con", "up", "id", net.ssid]);
        else if (net.secure)
            run(["nmcli", "dev", "wifi", "connect", net.ssid, "password", password]);
        else
            run(["nmcli", "dev", "wifi", "connect", net.ssid]);
    }

    function disconnect(net) {
        run(["nmcli", "con", "down", "id", net.ssid]);
    }

    function forget(net) {
        run(["nmcli", "con", "delete", "id", net.ssid]);
    }

    function run(cmd) {
        action.command = cmd;
        action.running = true;
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
            root.refresh(false);
        }
    }

    Process {
        id: radio
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: root.wifiEnabled = text.trim() === "enabled"
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

    Process {
        id: devices
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                const eth = text.split("\n").map(l => root.fields(l)).find(f => f[0] === "ethernet");
                root.wired = !eth ? "no port" : eth[1].startsWith("connected") ? "connected" : eth[1] === "unavailable" ? "unplugged" : eth[1];
            }
        }
    }

    Process {
        id: ip
        command: ["sh", "-c", "ip -4 -o addr show scope global | awk '{ print $4 }' | cut -d/ -f1 | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: root.address = text.trim() || "—"
        }
    }

    // The public address: one HTTPS request to api.ipify.org when the Network section opens, then every 5 minutes
    // while it stays open. Nothing is sent but the request itself.
    onScanningChanged: if (scanning && !outside.running) outside.running = true

    Process {
        id: outside
        command: ["curl", "-s", "-4", "--max-time", "6", "https://api.ipify.org"]
        stdout: StdioCollector {
            onStreamFinished: {
                const ip = text.trim();
                root.publicAddress = /^\d{1,3}(\.\d{1,3}){3}$/.test(ip) ? ip : "offline";
            }
        }
    }

    Timer {
        running: root.scanning
        repeat: true
        interval: 300000
        onTriggered: if (!outside.running) outside.running = true
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: root.scanning ? 12000 : 30000
        onTriggered: root.refresh(root.scanning)
    }
}
