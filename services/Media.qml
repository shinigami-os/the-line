pragma Singleton

import QtQuick
import TheLine.Ui
import Quickshell
import Quickshell.Services.Mpris

// The MPRIS player the shell follows: the one picked in the music panel, else the one playing,
// else the first one that has a track.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property var pinned: null

    readonly property var player: (pinned && players.includes(pinned) ? pinned : null)
        ?? players.find(p => p.isPlaying) ?? players.find(p => (p.trackTitle ?? "") !== "") ?? null
    readonly property bool active: player !== null
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string title: player?.trackTitle || "Unknown track"
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string album: player?.trackAlbum ?? ""
    readonly property string art: player?.trackArtUrl ?? ""
    readonly property string source: player?.identity ?? ""
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

    function next() {
        if (player?.canGoNext)
            player.next();
    }

    function previous() {
        if (player?.canGoPrevious)
            player.previous();
    }

    function seek(fraction) {
        if (player?.canSeek && length > 0)
            player.position = Math.max(0, Math.min(1, fraction)) * length;
    }

    function toggleShuffle() {
        if (player?.shuffleSupported)
            player.shuffle = !player.shuffle;
    }

    // Off → playlist → track → off.
    function cycleLoop() {
        if (!player?.loopSupported)
            return;
        player.loopState = player.loopState === MprisLoopState.None ? MprisLoopState.Playlist
            : (player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None);
    }

    readonly property string loopLabel: !player?.loopSupported ? "" : (player.loopState === MprisLoopState.Track ? "loop · track"
        : (player.loopState === MprisLoopState.Playlist ? "loop · all" : "loop · off"))

    // MPRIS doesn't push the position; ask for it once a second while playing, on the clock's own tick, so the
    // track time and the progress land in the same frame as the new second.
    Connections {
        target: Time
        enabled: root.playing
        function onTick() {
            root.player.positionChanged();
        }
    }
}
