//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.line
import qs.services

ShellRoot {
    id: root

    readonly property var screens: Quickshell.screens.filter(s => Config.screenFilter.length === 0 || Config.screenFilter.includes(s.name))

    // Panels opened from the keyboard go to the focused screen (or the first one The Line runs on).
    function toggleFocused(panel) {
        const focused = Hyprland.focusedMonitor?.name ?? "";
        const names = screens.map(s => s.name);
        UiState.toggle(names.includes(focused) ? focused : names[0], panel);
    }

    Variants {
        model: root.screens

        TheLine {}
    }

    // Hyprland binds, e.g. hl.bind("SUPER+SPACE", hl.dsp.global("the-line:launcher"))
    component Shortcut: GlobalShortcut {
        appid: "the-line"
    }

    // Hold Super for the key hints. Bound on press and on release:
    //   hl.bind("SUPER_L", hl.dsp.global("the-line:hints"), { ignore_mods = true, transparent = true })
    //   hl.bind("SUPER_L", hl.dsp.global("the-line:hints"), { ignore_mods = true, transparent = true, release = true })
    // They only show after 250 ms, so quick Super shortcuts don't flash them.
    Shortcut {
        name: "hints"
        description: "Hold to show key hints"
        onPressed: hintsDelay.restart()
        onReleased: {
            hintsDelay.stop();
            UiState.hints = false;
        }
    }

    Timer {
        id: hintsDelay
        interval: 250
        onTriggered: UiState.hints = true
    }

    Shortcut {
        name: "launcher"
        description: "Open the launcher"
        onPressed: root.toggleFocused("tl")
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

        function hints(on: bool): void {
            UiState.hints = on;
        }

        function close(): void {
            UiState.close();
        }

        function clockFace(): void {
            ClockFace.toggle();
        }
    }
}
