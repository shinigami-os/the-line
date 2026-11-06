pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Who and where: user name and host name.
Singleton {
    readonly property string user: Quickshell.env("USER") ?? ""
    readonly property string host: hostFile.text().trim()

    FileView {
        id: hostFile
        path: "/etc/hostname"
        blockLoading: true
    }
}
