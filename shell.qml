//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs.modules.line
import qs.services

ShellRoot {
    id: root

    readonly property var screens: Quickshell.screens.filter(s => Config.screenFilter.length === 0 || Config.screenFilter.includes(s.name))

    // The focused screen, or the first one The Line runs on.
    function focusedScreen() {
        const focused = Hyprland.focusedMonitor?.name ?? "";
        const names = screens.map(s => s.name);
        return names.includes(focused) ? focused : names[0];
    }

    // Panels opened from the keyboard go to the focused screen.
    function toggleFocused(panel) {
        UiState.toggle(focusedScreen(), panel);
    }

    // Easter egg: on a laptop, Kira says something when the charger is plugged in or pulled out.
    readonly property var pluggedLines: ["i've got the power.", "plugged in. unlimited power. almost.", "charging. feel the volts.", "back on the grid at {battery}."]
    readonly property var unpluggedLines: ["on battery. make it count.", "unplugged. every watt counts now.", "cord cut. we ride on {battery}.", "wireless mode. stay close to a socket."]

    Connections {
        target: UPower

        function onOnBatteryChanged() {
            if (!(UPower.displayDevice?.isLaptopBattery ?? false))
                return;
            const lines = UPower.onBattery ? root.unpluggedLines : root.pluggedLines;
            Voice.say(lines[Math.floor(Math.random() * lines.length)], root.focusedScreen());
        }
    }

    // Quickshell doesn't always update a workspace's fullscreen state when an app leaves fullscreen by itself (F11):
    // re-read the workspaces on every fullscreen or window event, and once more just after.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (["fullscreen", "openwindow", "closewindow", "movewindowv2", "workspacev2"].includes(event.name)) {
                Hyprland.refreshWorkspaces();
                refreshAgain.restart();
            }
            if (event.name === "submap")
                UiState.resizing = event.data === "resize";
            // Window classes and titles (the workspace tile names the app, and counts its windows).
            if (["openwindow", "closewindow", "windowtitlev2", "movewindowv2"].includes(event.name))
                Hyprland.refreshToplevels();
        }
    }
    Timer {
        id: refreshAgain
        interval: 150
        onTriggered: {
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
        }
    }

    Variants {
        model: root.screens

        TheLine {}
    }

    // Hyprland binds, e.g. hl.bind("SUPER+SPACE", hl.dsp.global("the-line:launcher"))
    component Shortcut: GlobalShortcut {
        appid: "the-line"
    }

    Shortcut {
        name: "launcher"
        description: "Open the launcher"
        onPressed: root.toggleFocused("tl")
    }
    // Tapping Super alone: bound on the key's release, which reaches the shell as a release.
    Shortcut {
        name: "launcherTap"
        description: "Open the launcher (tap Super)"
        onReleased: root.toggleFocused("tl")
    }
    Shortcut {
        name: "notifications"
        description: "Open notifications and calendar"
        onPressed: root.toggleFocused("tc")
    }
    Shortcut {
        name: "quicksettings"
        description: "Open quick settings"
        onPressed: root.toggleFocused("tr")
    }
    Shortcut {
        name: "performance"
        description: "Open the performance dashboard"
        onPressed: root.toggleFocused("tp")
    }

    // qs -p <path> ipc call line <function> ...
    IpcHandler {
        target: "line"

        function notify(app: string, title: string, body: string): void {
            Notifs.push(app, title, body);
        }

        function gauge(kind: string, value: real): void {
            LineState.showGauge(kind, value);
        }

        function toggle(screen: string, panel: string): void {
            UiState.toggle(screen, panel);
        }

        function toggleFocused(panel: string): void {
            root.toggleFocused(panel);
        }

        // Opens the launcher on the focused screen with this search typed in.
        function search(text: string): void {
            if (UiState.openPanel !== "tl")
                root.toggleFocused("tl");
            UiState.launcherQuery = text;
        }

        // Says a line on top of the windows of the focused screen, like the power easter egg.
        function say(text: string): void {
            Voice.say(text, root.focusedScreen());
        }

        function close(): void {
            UiState.close();
        }

        function clockFace(): void {
            ClockFace.toggle();
        }
    }
}
