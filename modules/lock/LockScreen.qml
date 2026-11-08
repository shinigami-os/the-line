import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// The session lock (ext-session-lock): while Lock.locked, every screen shows a LockSurface and nothing else gets a
// key or a click.
WlSessionLock {
    locked: Lock.locked

    WlSessionLockSurface {
        id: lockSurface
        color: "black"

        LockSurface {
            anchors.fill: parent
            screenName: lockSurface.screen?.name ?? ""
        }
    }
}
