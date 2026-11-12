import QtQuick
import TheLine.Ui
import QtQuick.Effects
import qs.services

// Behind the lock: the screen's wallpaper (a video's still frame), blurred and dimmed. The unlock curtain draws the
// same one, so the handover from the lock to the desktop doesn't show a seam.
Item {
    id: backdrop

    required property string screenName

    readonly property string path: Config.wallpaperFor(screenName)

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    Image {
        id: picture
        anchors.fill: parent
        visible: false
        source: backdrop.path === "" ? "" : Config.wallpaperKind(backdrop.path) === "video"
            ? (Frames.have[backdrop.path] ? "file://" + Frames.of(backdrop.path) : "") : "file://" + backdrop.path
        sourceSize.width: Math.round(backdrop.width / 2)
        sourceSize.height: Math.round(backdrop.height / 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: true
    }

    MultiEffect {
        anchors.fill: parent
        source: picture
        visible: picture.status === Image.Ready
        blurEnabled: true
        blurMax: 64
        blur: 1
        saturation: -0.2
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.74
    }
}
