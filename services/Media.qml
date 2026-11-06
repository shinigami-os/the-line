pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The MPRIS player the shell follows: the one playing, or else the first one that has a track.
Singleton {
    id: root

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values.find(p => (p.trackTitle ?? "") !== "") ?? null
    readonly property bool active: player !== null
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string title: player?.trackTitle || "Unknown track"
    readonly property string artist: player?.trackArtist ?? ""
    readonly property real length: player?.length ?? 0
    readonly property real position: player?.position ?? 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

    function format(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    function toggle() {
        if (player?.canTogglePlaying)
            player.togglePlaying();
    }

    // MPRIS doesn't push the position; ask for it once a second while playing.
    Timer {
        running: root.playing
        repeat: true
        interval: 1000
        onTriggered: root.player.positionChanged()
    }
}
