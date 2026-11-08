//@ pragma AppId the-line-settings

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.settings
import qs.services

// The Line's settings app: its own process and window (app-id "the-line-settings"), sharing Theme, Anim, Config and
// the common components with the shell. Started by session/the-line-settings (SUPER+I, the launcher).
ShellRoot {
    FloatingWindow {
        id: win

        title: "Settings"
        implicitWidth: 1120
        implicitHeight: 740
        color: Theme.bg

        // Closing the window ends the app.
        onVisibleChanged: if (!visible) Qt.quit()

        SettingsView {
            id: view
            anchors.fill: parent
            Component.onCompleted: {
                const section = Quickshell.env("THE_LINE_SETTINGS_SECTION");
                if (section)
                    view.open(section);
            }
        }
    }

    IpcHandler {
        target: "settings"

        // Brings the window forward, on a section if one is given.
        function open(section: string): void {
            if (section !== "")
                view.open(section);
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = \"class:the-line-settings\" })"]);
        }
    }
}
