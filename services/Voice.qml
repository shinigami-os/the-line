pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Kira's voice: quotes from assets/quotes.txt plus the user's ~/.config/the-line/quotes.txt.
// A quote may hold {placeholders}; each one maps to a fixed value below, so a quotes file can never run anything.
Singleton {
    id: root

    property var quotes: []
    property string current: ""
    property int packages: 0

    // The quote with its placeholders filled in. Live: {uptime} keeps counting while it is shown.
    readonly property string text: render(current)

    // A one-off line said on top of the windows, on one screen, for a few seconds (easter eggs).
    property string eventText: ""
    property string eventScreen: ""
    readonly property bool eventActive: eventTimer.running

    function say(line, screen) {
        eventText = render(line);
        eventScreen = screen;
        eventTimer.restart();
    }

    function render(line) {
        return line.replace(/\{(\w+)\}/g, (match, key) => {
            const v = value(key);
            return v === undefined ? match : v;
        });
    }

    Timer {
        id: eventTimer
        interval: 5000
    }

    function value(key) {
        switch (key) {
        case "user": return Session.user;
        case "host": return Session.host.toLowerCase();
        case "uptime": return SystemStats.formatUptime(SystemStats.uptime);
        case "packages": return String(packages);
        case "kernel": return kernel.text().trim();
        case "swappiness": return swappiness.text().trim();
        case "load": return SystemStats.load.split(" ")[0] ?? "";
        case "cpu": return Math.round(SystemStats.cpu * 100) + "%";
        case "ram": return Math.round(SystemStats.ram * 100) + "%";
        case "battery": return Math.round((UPower.displayDevice?.percentage ?? 0) * 100) + "%";
        }
        return undefined;
    }

    function parse(text) {
        return text.split("\n").map(l => l.trim()).filter(l => l !== "" && !l.startsWith("#"));
    }

    function reload() {
        quotes = parse(shipped.text()).concat(parse(user.text()));
    }

    // A different quote from the last one. Called while the quote is hidden, never under the reader's eyes.
    function next() {
        if (quotes.length === 0)
            return;
        let q = current;
        for (let i = 0; i < 8 && q === current; i++)
            q = quotes[Math.floor(Math.random() * quotes.length)];
        current = q;
        if (!counter.running)
            counter.running = true;
    }

    FileView {
        id: shipped
        path: Qt.resolvedUrl("../assets/quotes.txt").toString().replace("file://", "")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.reload()
    }
    FileView {
        id: user
        path: Quickshell.env("HOME") + "/.config/the-line/quotes.txt"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.reload()
    }
    FileView {
        id: kernel
        path: "/proc/sys/kernel/osrelease"
        blockLoading: true
    }
    FileView {
        id: swappiness
        path: "/proc/sys/vm/swappiness"
        blockLoading: true
    }

    // Installed packages, as flux counts them.
    Process {
        id: counter
        command: ["sh", "-c", "ls /var/lib/flux/installed 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: root.packages = Number(text.trim()) || 0
        }
    }
}
