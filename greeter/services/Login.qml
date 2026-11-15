pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

// Signing in through greetd: the users (/etc/passwd, uid 1000-59999 with a real shell, the last one first), the
// sessions (/usr/share/wayland-sessions; The Line first), the conversation with PAM, and the launch.
// The conversation with PAM starts as soon as a user is picked, not when Enter is pressed: with a face or a fingerprint
// in greetd's PAM stack (howdy, fprintd) it runs first, says what it sees, and signs in by itself; the password typed
// meanwhile waits for PAM's question.
//   phase  "" → "checking" (the password is out) → "granted" (the greeter plays its way out, then launch())
//          → back to "" with `refused` bumped when it is wrong
// QS_TESTING=1: nothing reaches greetd; "test" is the password, Esc leaves. QS_WINDOW=1 (with GREETD_SOCK): the
// greeter in a window of the session talking to a greetd that is not the real one (a fake, to try the whole path).
Singleton {
    id: root

    readonly property bool testing: Quickshell.env("QS_TESTING") === "1"
    readonly property bool windowed: testing || Quickshell.env("QS_WINDOW") === "1"
    readonly property string stateDir: "/var/lib/greetd"
    readonly property string launchedMarker: "/run/greetd/launched"

    property var users: []          // [{ name, realName, home }]
    property int userIndex: 0
    readonly property var user: users[userIndex] ?? null
    property var sessions: []       // [{ name, cmd: [], desktop }]
    property int sessionIndex: 0
    readonly property var session: sessions[sessionIndex] ?? null

    property string phase: ""
    property string message: ""
    property bool messageIsError: false
    property int refused: 0
    property bool asking: false      // PAM is waiting for the password

    property string _password: ""
    property bool _starting: false

    onUserChanged: {
        Config.home = user?.home ?? "";
        begin();
    }

    function nextUser(by) {
        if (users.length > 0 && phase === "")
            userIndex = (userIndex + by + users.length) % users.length;
    }

    function nextSession() {
        if (sessions.length > 0)
            sessionIndex = (sessionIndex + 1) % sessions.length;
    }

    // A fresh conversation with PAM for the picked user (a running one is cancelled first).
    function begin() {
        asking = false;
        if (testing) {
            asking = !!user;
            return;
        }
        if (!user || !Greetd.available)
            return;
        _starting = true;
        poll.restart();
    }

    Timer {
        id: poll
        interval: 100
        repeat: true
        onTriggered: {
            if (!root._starting || !root.user) {
                stop();
                return;
            }
            if (Greetd.state === GreetdState.Inactive) {
                root._starting = false;
                stop();
                Greetd.createSession(root.user.name);
            } else {
                Greetd.cancelSession();
            }
        }
    }

    function signIn(password) {
        if (phase !== "" || !user || !session)
            return;
        phase = "checking";
        message = "";
        messageIsError = false;
        _password = password;
        if (testing) {
            testCheck.restart();
        } else if (asking) {
            Greetd.respond(_password);
            _password = "";
            asking = false;
        } else if (!_starting && Greetd.state === GreetdState.Inactive) {
            begin();   // the password goes out with PAM's question
        }
    }

    function refuse(text) {
        _password = "";
        phase = "";
        message = text;
        messageIsError = true;
        refused++;
        begin();
    }

    // Called by the greeter once its way out has played.
    function launch() {
        if (testing) {
            Qt.quit();
            return;
        }
        Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" > \"$3/last-user\"; printf %s \"$2\" > \"$3/last-session\"; touch \"$4\"",
            "sh", user.name, session.name, stateDir, launchedMarker]);
        // DesktopNames=Hyprland;the-line → XDG_CURRENT_DESKTOP=Hyprland:the-line
        const env = ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=" + session.desktop.split(";")[0],
            "XDG_CURRENT_DESKTOP=" + session.desktop.split(";").filter(d => d !== "").join(":")];
        Greetd.launch(session.cmd, env);
    }

    // Test mode only: a way out.
    function leave() {
        if (testing)
            Qt.quit();
    }

    function reboot() {
        if (!windowed)
            Quickshell.execDetached(["loginctl", "reboot"]);
    }

    function powerOff() {
        if (!windowed)
            Quickshell.execDetached(["loginctl", "poweroff"]);
    }

    Timer {
        id: testCheck
        interval: 700
        onTriggered: {
            if (root._password === "test") {
                root._password = "";
                root.phase = "granted";
            } else {
                root.refuse("not this one");
            }
        }
    }

    Connections {
        target: root.testing ? null : Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                if (root._password !== "") {
                    Greetd.respond(root._password);
                    root._password = "";
                } else {
                    root.asking = true;
                }
            } else if (message !== "") {
                root.message = message;
                root.messageIsError = error;
            }
        }
        function onAuthFailure(message) {
            Greetd.cancelSession();
            root.refuse(root.phase === "checking" ? "not this one" : message || "not recognised");
        }
        function onReadyToLaunch() {
            root.asking = false;
            root.phase = "granted";
        }
        function onError(error) {
            Greetd.cancelSession();
            root.refuse("something went wrong, try again");
        }
    }

    // Users and the last one; sessions and the last one.
    Process {
        running: true
        command: ["sh", "-c", "cat /etc/passwd; echo '#last'; cat \"$1/last-user\" 2>/dev/null; echo; echo '#lastsession'; "
            + "cat \"$1/last-session\" 2>/dev/null; echo; for f in /usr/share/wayland-sessions/*.desktop; do [ -f \"$f\" ] || continue; "
            + "echo '#session'; { cat \"$f\"; echo; } | sed -n -e 's/^Name=/name=/p' -e 's/^Exec=/exec=/p' -e 's/^DesktopNames=/desktop=/p' | head -n 3; done",
            "sh", root.stateDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("\n");
                const users = [];
                const sessions = [];
                let mode = "passwd";
                let last = "";
                let lastSession = "";
                let cur = null;
                for (const line of parts) {
                    if (line === "#last" || line === "#lastsession") {
                        mode = line.slice(1);
                        continue;
                    }
                    if (line === "#session") {
                        mode = "session";
                        cur = { name: "", cmd: [], desktop: "" };
                        sessions.push(cur);
                        continue;
                    }
                    if (mode === "passwd") {
                        const f = line.split(":");
                        if (f.length < 7)
                            continue;
                        const uid = Number(f[2]);
                        if (uid < 1000 || uid >= 60000 || /(nologin|false)$/.test(f[6]))
                            continue;
                        users.push({ name: f[0], realName: f[4].split(",")[0] || f[0], home: f[5] });
                    } else if (mode === "last" && line.trim() !== "") {
                        last = line.trim();
                    } else if (mode === "lastsession" && line.trim() !== "") {
                        lastSession = line.trim();
                    } else if (mode === "session" && cur) {
                        if (line.startsWith("name="))
                            cur.name = line.slice(5);
                        else if (line.startsWith("exec="))
                            cur.cmd = line.slice(5).replace(/ %[a-zA-Z]/g, "").split(" ").filter(w => w !== "");
                        else if (line.startsWith("desktop="))
                            cur.desktop = line.slice(8);
                    }
                }
                const valid = sessions.filter(s => s.name !== "" && s.cmd.length > 0)
                    .map(s => Object.assign(s, { desktop: s.desktop || s.name }));
                valid.sort((a, b) => (b.name === "The Line") - (a.name === "The Line"));
                root.users = users;
                root.userIndex = Math.max(0, users.findIndex(u => u.name === last));
                root.sessions = valid;
                root.sessionIndex = Math.max(0, valid.findIndex(s => s.name === lastSession));
                root.begin();
            }
        }
    }
}
