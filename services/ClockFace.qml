pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Which face the clock panel shows. Kept in the runtime directory: it survives shell restarts, not a reboot.
// (Click today's date in the calendar.)
Singleton {
    id: root

    property bool binary: false

    function toggle() {
        binary = !binary;
        file.setText(binary ? "binary\n" : "analog\n");
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/the-line-clock"
        printErrors: false
        onLoaded: root.binary = text().trim() === "binary"
    }
}
