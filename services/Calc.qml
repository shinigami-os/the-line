pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The launcher's calculator: qalc on whatever looks like maths. qalc reads almost any word as a unit ("0ad" is
// 0 days), so a query counts only with an operator, a function call or a "to" conversion; "=" in front forces it.
Singleton {
    id: root

    readonly property string query: UiState.launcherQuery
    readonly property bool forced: query.trim().startsWith("=")
    readonly property string expr: (forced ? query.trim().slice(1) : query).trim()
    readonly property bool mathy: expr !== "" && (forced
        || (/^[\d.(\-√π]/.test(expr) && /[+\-*\/^%×÷()]|\bto\b|\bmod\b/.test(expr))
        || /^[a-z]+\s*\(/i.test(expr))
    // The answer for the current query, "" while there is none.
    readonly property string result: mathy && _for === expr ? _result : ""

    property string _for
    property string _result

    function accept(answer) {
        const a = answer.trim();
        if (a === "" || /error|warning/i.test(a))
            return "";
        // qalc echoes what it couldn't evaluate ("1 / 0", "x + 5"); keep only an actual answer
        if (a.replace(/\s+/g, "") === expr.replace(/\s+/g, "") || (!forced && !/\bto\b/.test(expr) && /^[^\d]*[a-z]{2,}/i.test(a)))
            return "";
        return a;
    }

    function copy() {
        if (result !== "")
            Quickshell.execDetached(["wl-copy", "--", result]);
    }

    // mathy is read when the timer fires: in this handler its binding may not have caught up with expr yet
    onExprChanged: debounce.restart()

    Timer {
        id: debounce
        interval: 90
        onTriggered: {
            if (!root.mathy)
                return;
            proc.running = false;
            proc.asked = root.expr;
            proc.command = ["qalc", "-t", "-s", "conv 0", root.expr];   // conv 0: "3.1 mi", not "3 mi + 188 yd + …"
            proc.running = true;
        }
    }

    Process {
        id: proc

        property string asked

        stdout: StdioCollector {
            onStreamFinished: {
                root._result = root.accept(text);
                root._for = proc.asked;
            }
        }
    }
}
