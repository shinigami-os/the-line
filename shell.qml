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

        function close(): void {
            UiState.close();
        }

        function clockFace(): void {
            ClockFace.toggle();
        }
    }
}
