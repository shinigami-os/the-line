pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit

// The polkit agent: when an app asks for an admin password, The Line asks it (CenterDialog on the focused screen).
Singleton {
    id: root

    readonly property bool active: agent.isActive
    readonly property var flow: agent.flow
    property bool failed: false     // the last password was wrong
    property string screen: ""      // where the dialog opens

    function submit(text) {
        failed = false;
        flow?.submit(text);
    }

    function cancel() {
        flow?.cancelAuthenticationRequest();
    }

    PolkitAgent {
        id: agent

        onAuthenticationRequestStarted: {
            root.failed = false;
            root.screen = Hyprland.focusedMonitor?.name ?? Hyprland.monitors.values[0]?.name ?? "";
        }
    }

    Connections {
        target: root.flow

        function onAuthenticationFailed() {
            root.failed = true;
        }
    }
}
