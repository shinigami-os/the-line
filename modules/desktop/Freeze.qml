import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// The frozen screen while an area screenshot is being selected (session/the-line-shot): this screen's capture,
// shown over everything, so the picture holds still and the cursor isn't part of it.
PanelWindow {
    id: win

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    visible: UiState.frozen
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "the-line-freeze"

    Image {
        anchors.fill: parent
        source: UiState.frozen ? "file://" + Quickshell.env("XDG_RUNTIME_DIR") + "/the-line-freeze/" + win.screen.name + ".png" : ""
        cache: false
        asynchronous: false
    }
}
