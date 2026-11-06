pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property var now: clock.date ?? new Date()

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}
