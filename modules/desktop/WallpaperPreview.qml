import QtQuick
import qs.services

// While the wallpaper picker is open on this screen, the wallpaper under its marker covers the screen behind the
// line and the tiles, so it is seen with the shell on it before it is set. Each picture fades in over the last (two
// layers: the new one on top, the last one under it until then); a video shows its still frame. A moment's wait while
// the strip slides, so a held arrow key doesn't decode every picture on the way.
Item {
    id: preview

    property bool open: false
    property string path: ""

    property bool frontA: true

    visible: open || a.opacity > 0 || b.opacity > 0

    function sourceOf(p) {
        if (p === "")
            return "";
        if (Config.wallpaperKind(p) === "video")
            return Frames.have[p] ? "file://" + Frames.of(p) : "";
        return "file://" + p;
    }

    onPathChanged: settle.restart()
    onOpenChanged: {
        if (open) {
            // the last picture shown, from the time before, must not come back for a frame
            settle.stop();
            a.source = "";
            b.source = "";
            show();
        }
    }

    Timer {
        id: settle
        interval: Anim.d(140)
        onTriggered: preview.show()
    }

    function show() {
        const src = sourceOf(path);
        const front = frontA ? a : b;
        if (front.source.toString() === src && front.opacity > 0)
            return;
        const back = frontA ? b : a;
        back.source = src;
        frontA = !frontA;
    }

    Image {
        id: a
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: preview.width
        sourceSize.height: preview.height
        z: preview.frontA ? 1 : 0
        opacity: preview.open && status === Image.Ready ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Anim.panel; easing.type: Anim.easing }
        }
    }
    Image {
        id: b
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: preview.width
        sourceSize.height: preview.height
        z: preview.frontA ? 0 : 1
        opacity: preview.open && status === Image.Ready ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Anim.panel; easing.type: Anim.easing }
        }
    }
}
