pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Settings > Sound, on Quickshell's PipeWire service: outputs and inputs (the default one lit), their volume and
// mute, and every app playing with its own volume.
Singleton {
    id: root

    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var outputs: nodes.filter(n => n.isSink && !n.isStream)
    readonly property var inputs: nodes.filter(n => !n.isSink && !n.isStream)
    // Apps playing: in Quickshell a playback stream is a sink stream (it takes the app's audio to an output).
    readonly property var streams: nodes.filter(n => n.isStream && n.isSink)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property int outputVolume: Math.round((sink?.audio?.volume ?? 0) * 100)
    readonly property bool outputMuted: sink?.audio?.muted ?? false
    readonly property int inputVolume: Math.round((source?.audio?.volume ?? 0) * 100)
    readonly property bool inputMuted: source?.audio?.muted ?? false

    function set(key, value) {
        if (key === "outputVolume" && sink?.audio)
            sink.audio.volume = value / 100;
        else if (key === "outputMuted" && sink?.audio)
            sink.audio.muted = value;
        else if (key === "inputVolume" && source?.audio)
            source.audio.volume = value / 100;
        else if (key === "inputMuted" && source?.audio)
            source.audio.muted = value;
    }

    function setDefault(node) {
        if (node.isSink)
            Pipewire.preferredDefaultAudioSink = node;
        else
            Pipewire.preferredDefaultAudioSource = node;
    }

    // A device's name as people know it.
    function label(node) {
        return node.description || node.nickname || node.name;
    }

    // An app stream's name: the app, then what it plays.
    function appName(node) {
        return node.properties["application.name"] || node.description || node.name;
    }

    // Volume and mute are only live on tracked nodes.
    PwObjectTracker {
        objects: root.nodes
    }
}
