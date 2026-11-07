import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// The wallpaper, on the background layer. Black while the image loads, or if there is none.
// It fades in slowly at login; `ready` tells the line when it has, so the shell's intro starts after it.
PanelWindow {
    readonly property bool ready: image.status === Image.Error || (image.status === Image.Ready && image.opacity === 1)

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.bg
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "the-line-wallpaper"

    Image {
        id: image
        anchors.fill: parent
        source: Config.wallpaper !== "" ? "file://" + Config.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: width
        sourceSize.height: height
        opacity: status === Image.Ready ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Anim.d(600) }
        }
    }
}
