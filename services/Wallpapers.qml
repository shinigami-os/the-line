pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Every wallpaper to pick from: The Line's (assets/wallpapers), Kira's, and yours (~/Pictures/Wallpapers,
// ~/.local/share/wallpapers): pictures, animated GIFs and videos (mp4, webm, mkv, mov). Read again by refresh().
// Shared by Settings > Appearance and the shell's picker (SUPER+T).
Singleton {
    id: root

    property var files: []
    property bool loaded: false

    function refresh() {
        if (!proc.running)
            proc.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: proc
        command: ["sh", "-c", "for d in \"$1/assets/wallpapers\" /usr/share/kira/wallpapers \"$HOME/Pictures/Wallpapers\" \"$HOME/.local/share/wallpapers\"; do "
            + "find \"$d\" -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' "
            + "-o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \\) 2>/dev/null | sort; done",
            "sh", Config.shellRoot]
        stdout: StdioCollector {
            onStreamFinished: {
                root.files = text.split("\n").filter(f => f !== "");
                root.loaded = true;
                Frames.make(root.files.filter(f => Config.wallpaperKind(f) === "video"));
            }
        }
    }
}
