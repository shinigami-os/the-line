pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default sink volume. Any change after startup is shown on the line.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    property bool armed: false

    PwObjectTracker {
        objects: [root.sink]
    }

    onVolumeChanged: if (armed) LineState.showGauge("vol", muted ? 0 : volume)
    onMutedChanged: if (armed) LineState.showGauge("vol", muted ? 0 : volume)

    // Ignore the values PipeWire reports while it connects.
    Timer {
        running: true
        interval: 1500
        onTriggered: root.armed = true
    }
}
