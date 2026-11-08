pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Settings > System, Sign-in and the battery limit. Reading needs no password (the files are readable);
// changing goes through session/the-line-settings-helper with pkexec: The Line's polkit dialog asks once,
// then polkit keeps it for a few minutes (session/org.kira.the-line.settings.policy).
Singleton {
    id: root

    readonly property string user: Quickshell.env("USER")
    readonly property string helper: Quickshell.shellDir.replace(/\/settings\/?$/, "") + "/session/the-line-settings-helper"

    property string hostname: "—"
    property string timezone: "—"
    property bool ntp: true
    property var zones: []
    property string release: "—"
    property string kernel: "—"
    property string cpu: "—"
    property string memory: "—"
    property string uptime: "—"

    property var faces: []                 // [{ id, label, time }] from /etc/howdy/models/<user>.dat
    property bool faceHyprlock: false      // face sign-in turned on for unlocking the screen
    property bool faceGreetd: false        // ... for the login screen
    property string fingerprint: "—"

    property bool chargeSupported: false
    property int chargeLimit: 100

    property string busy: ""               // what the helper is doing, said plainly
    property string error: ""

    // Writes through the helper. `what` is shown while it runs ("Looking at you…").
    function run(args, what) {
        if (helperProc.running)
            return;
        error = "";
        busy = what ?? "Asking for your password…";
        helperProc.command = ["pkexec", helper].concat(args);
        helperProc.running = true;
    }

    function set(key, value) {
        if (key === "hostname")
            run(["hostname", String(value).trim()], "Renaming…");
        else if (key === "timezone")
            run(["timezone", value], "Moving the clock…");
        else if (key === "ntp")
            run(["ntp", value ? "on" : "off"]);
        else if (key === "time")
            run(["time", value], "Setting the clock…");
        else if (key === "faceHyprlock")
            run(["face-pam", "hyprlock", value ? "on" : "off"]);
        else if (key === "faceGreetd")
            run(["face-pam", "greetd", value ? "on" : "off"]);
        else if (key === "chargeLimit")
            run(["charge-limit", String(value)]);
    }

    function refresh() {
        if (!reader.running)
            reader.running = true;
    }

    Process {
        id: helperProc
        stderr: StdioCollector {
            id: helperErr
        }
        onExited: code => {
            // 126/127: the password dialog was cancelled, or refused
            if (code === 126 || code === 127)
                root.error = "Not changed: the password was cancelled or refused";
            else if (code !== 0)
                root.error = helperErr.text.trim().split("\n").pop() || "That didn't work";
            root.busy = "";
            root.refresh();
        }
    }

    // Everything readable in one pass, as "key=value" lines.
    Process {
        id: reader
        command: ["sh", "-c", [
            "echo hostname=$(cat /etc/hostname 2>/dev/null)",
            "echo timezone=$(readlink /etc/localtime | sed 's|.*/zoneinfo/||')",
            "[ -f /etc/sv/chronyd/down ] && echo ntp=off || echo ntp=on",
            "echo release=$(. /etc/kira-release 2>/dev/null; echo ${KIRA_BASE_VERSION:-})",
            "echo kernel=$(uname -r)",
            "echo cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2-)",
            "echo memory=$(awk '/MemTotal/ { printf \"%.0f GB\", $2 / 1048576 }' /proc/meminfo)",
            "echo uptime=$(awk '{ d = int($1 / 86400); h = int($1 % 86400 / 3600); m = int($1 % 3600 / 60); if (d) printf \"%d d \", d; printf \"%d h %02d min\", h, m }' /proc/uptime)",
            "grep -q 'pam_howdy.so  # the-line' /etc/pam.d/hyprlock 2>/dev/null && echo facehyprlock=1",
            "grep -q 'pam_howdy.so  # the-line' /etc/pam.d/greetd 2>/dev/null && echo facegreetd=1",
            "b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1); [ -n \"$b\" ] && [ -f \"$b/charge_control_end_threshold\" ] && echo charge=$(cat \"$b/charge_control_end_threshold\")",
            "echo fingerprint=$(fprintd-list \"$USER\" 2>&1 | head -n1)",
            "echo faces=$(cat /etc/howdy/models/$USER.dat 2>/dev/null | tr -d '\\n')"
        ].join("; ")]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {};
                for (const line of text.split("\n")) {
                    const eq = line.indexOf("=");
                    if (eq > 0)
                        v[line.slice(0, eq)] = line.slice(eq + 1).trim();
                }
                root.hostname = v.hostname || "—";
                root.timezone = v.timezone || "—";
                root.ntp = v.ntp !== "off";
                root.release = v.release || "—";
                root.kernel = v.kernel || "—";
                root.cpu = (v.cpu || "—").replace(/\s+/g, " ");
                root.memory = v.memory || "—";
                root.uptime = v.uptime || "—";
                root.faceHyprlock = v.facehyprlock === "1";
                root.faceGreetd = v.facegreetd === "1";
                root.chargeSupported = v.charge !== undefined;
                root.chargeLimit = Number(v.charge) || 100;
                root.fingerprint = /No devices/i.test(v.fingerprint ?? "") ? "no reader found"
                    : /Fingerprints for user/i.test(v.fingerprint ?? "") ? "ready" : "not available";
                try {
                    const models = JSON.parse(v.faces || "[]");
                    root.faces = models.map(m => ({ id: m.id, label: m.label, time: m.time }));
                } catch (e) {
                    root.faces = [];
                }
            }
        }
    }

    // Time zones: every Region/City file of the zone database (not the posix/ and right/ copies).
    Process {
        running: true
        command: ["sh", "-c", "cd /usr/share/zoneinfo && find . -type f | sed 's|^\\./||' | grep -E '^[A-Z][A-Za-z_-]+/[A-Za-z0-9_+/-]+$' | grep -v -E '^(posix|right)/' | sort; echo UTC"]
        stdout: StdioCollector {
            onStreamFinished: root.zones = text.split("\n").filter(z => z !== "")
        }
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 30000
        onTriggered: root.refresh()
    }
}
