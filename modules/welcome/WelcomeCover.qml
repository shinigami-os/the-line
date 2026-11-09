import QtQuick
import qs.services

// Black over a screen while the welcome story runs. On the story screen it sits under the line and the tiles; on the
// others it covers everything, so nothing of the story shows there. The finale lifts it, once the wallpaper is up.
Rectangle {
    id: cover

    property bool lifted: false

    color: "black"
    opacity: lifted ? 0 : 1
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation { duration: Anim.d(1300); easing.type: Easing.InOutQuad }
    }
}
