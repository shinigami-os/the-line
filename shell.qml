//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import Quickshell
import Quickshell.Io
import qs.modules.line
import qs.services

ShellRoot {
    Variants {
        model: Quickshell.screens.filter(s => Config.screenFilter.length === 0 || Config.screenFilter.includes(s.name))

        TheLine {}
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

        function close(): void {
            UiState.close();
        }

        function clockFace(): void {
            ClockFace.toggle();
        }
    }
}
