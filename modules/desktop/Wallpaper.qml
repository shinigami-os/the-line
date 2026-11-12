import QtQuick
import TheLine.Ui
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import qs.services

// The wallpaper of one screen, on the background layer: a picture, an animated GIF, or a video (mp4, webm, mkv,
// mov; looped, without sound, decoded by Qt's ffmpeg). Black while it loads, or if there is none.
// It fades in slowly at login; `ready` tells the line when it has, so the shell's intro starts after it.
// `paused` stills an animated one (a fullscreen window over it, or on battery).
PanelWindow {
    id: win

    property bool paused: false
    readonly property string path: Config.wallpaperFor(screen?.name ?? "")
    readonly property string kind: Config.wallpaperKind(path)
    readonly property bool ready: loader.item?.ready ?? false

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

    Loader {
        id: loader
        anchors.fill: parent
        sourceComponent: win.kind === "video" ? video : win.kind === "gif" ? gif : still
    }

    Component {
        id: still

        Image {
            readonly property bool ready: status === Image.Error || (status === Image.Ready && opacity === 1)

            source: win.path !== "" ? "file://" + win.path : ""
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

    Component {
        id: gif

        AnimatedImage {
            readonly property bool ready: status === AnimatedImage.Error || (status === AnimatedImage.Ready && opacity === 1)

            source: "file://" + win.path
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            paused: win.paused
            opacity: status === AnimatedImage.Ready ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: Anim.d(600) }
            }
        }
    }

    // No AudioOutput: the player opens no sound stream at all.
    Component {
        id: video

        Item {
            readonly property bool loaded: player.mediaStatus === MediaPlayer.LoadedMedia || player.mediaStatus === MediaPlayer.BufferedMedia
                || player.mediaStatus === MediaPlayer.BufferingMedia || player.mediaStatus === MediaPlayer.EndOfMedia
            readonly property bool ready: player.error !== MediaPlayer.NoError || (loaded && out.opacity === 1)

            MediaPlayer {
                id: player
                source: "file://" + win.path
                loops: MediaPlayer.Infinite
                videoOutput: out
                onMediaStatusChanged: if (mediaStatus === MediaPlayer.LoadedMedia && !win.paused) play()
                onErrorOccurred: (error, message) => console.warn("wallpaper:", message)
            }

            Connections {
                target: win

                function onPausedChanged() {
                    if (win.paused)
                        player.pause();
                    else
                        player.play();
                }
            }

            VideoOutput {
                id: out
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop
                opacity: parent.loaded ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: Anim.d(600) }
                }
            }
        }
    }
}
