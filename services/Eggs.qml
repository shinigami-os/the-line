pragma Singleton

import QtQuick
import TheLine.Ui
import Quickshell
import Quickshell.Wayland

// The easter eggs that keep a state or a clock (EASTER_EGGS.md lists them all, with where each one lives).
Singleton {
    id: root

    // Triple click on the workspace ruler's active numeral: the numerals in 4-bit binary, until the next one.
    property bool binaryWorkspaces: false

    // Calendar: a click on the week numbers turns them into each week's day of the year (today's in binary).
    property bool dayOfYear: false

    // A single accent tick in the middle of the line for the first minute of a new day.
    property bool midnightTick: false

    // Uptime crossing a power of two in minutes (1024, 2048, 4096…): the number in binary, drawn on the line as
    // dashes (1) and dots (0) for a few seconds. "" when nothing shows.
    property string powerOfTwo: ""

    // Long idle on an empty desktop: the workspace marker blinks "kira" in Morse, slowly, once per idle spell.
    property bool morsePlaying: false
    property bool morseLit: true

    // ------------------------------------------------------------------ the clock

    property int lastMinute: -1
    property real lastUptimeMin: -1

    Connections {
        target: Time

        function onTick() {
            const now = Time.now;
            const m = now.getHours() * 60 + now.getMinutes();
            if (m === root.lastMinute)
                return;
            const first = root.lastMinute < 0;
            root.lastMinute = m;
            if (first)
                return;
            // 13:37: the pulse runs along the line once, with nothing to announce
            if (m === 13 * 60 + 37)
                LineState.pulse(false);
            if (m === 0) {
                root.midnightTick = true;
                midnight.restart();
            }
        }
    }
    Timer {
        id: midnight
        interval: 60 * 1000
        onTriggered: root.midnightTick = false
    }

    Connections {
        target: SystemStats

        function onUptimeChanged() {
            const min = Math.floor(SystemStats.uptime / 60);
            const before = root.lastUptimeMin;
            root.lastUptimeMin = min;
            if (before < 0 || min === before)
                return;
            for (let p = 1024; p <= min; p *= 2) {
                if (before < p) {
                    root.powerOfTwo = p.toString(2);
                    powerHold.restart();
                    break;
                }
            }
        }
    }
    Timer {
        id: powerHold
        interval: 8000
        onTriggered: root.powerOfTwo = ""
    }

    // ------------------------------------------------------------------ Morse

    // "kira": -.- .. .-. .-   one unit is 300 ms; dot 1, dash 3, inside a letter 1, between letters 3.
    readonly property int unit: 300
    readonly property var morse: {
        const letters = ["-.-", "..", ".-.", ".-"];
        const steps = [];   // [lit, units]
        letters.forEach((l, i) => {
            if (i > 0)
                steps.push([false, 3]);
            l.split("").forEach((c, j) => {
                if (j > 0)
                    steps.push([false, 1]);
                steps.push([true, c === "-" ? 3 : 1]);
            });
        });
        return steps;
    }
    property int morseStep: 0

    IdleMonitor {
        id: idle
        timeout: 5 * 60
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle) {
                root.morseStep = -1;
                root.morseLit = false;
                root.morsePlaying = true;
                morseTimer.interval = 2 * root.unit;   // a beat dark before it starts
                morseTimer.restart();
            } else {
                morseTimer.stop();
                root.morsePlaying = false;
                root.morseLit = true;
            }
        }
    }
    Timer {
        id: morseTimer
        onTriggered: {
            root.morseStep++;
            if (root.morseStep >= root.morse.length) {
                root.morsePlaying = false;   // then quiet, until the next idle spell
                root.morseLit = true;
                return;
            }
            const [lit, units] = root.morse[root.morseStep];
            root.morseLit = lit;
            interval = units * root.unit;
            restart();
        }
    }

    // ------------------------------------------------------------------ the launcher

    // Commands typed in the launcher that answer instead of running (they look like any command to run).
    function command(query) {
        const q = query.trim().toLowerCase().replace(/\s+/g, " ");
        if (q === "sudo make me a sandwich" || q === "make me a sandwich")
            return { id: q.startsWith("sudo") ? "sandwich" : "what" };
        if (/^(sudo )?rm -rf (\/|\/\*|--no-preserve-root \/)$/.test(q))
            return { id: "rm" };
        if (q === "whoami")
            return { id: "whoami" };
        return null;
    }

    function run(egg, screen) {
        if (egg.id === "sandwich")
            Voice.say("okay.", screen);
        else if (egg.id === "what")
            Voice.say("what? make it yourself.", screen);
        else if (egg.id === "rm")
            Voice.say("nice try.", screen);
        else if (egg.id === "whoami")
            Voice.say(Session.user, screen, true);
    }
}
