pragma Singleton

import QtQuick
import TheLine.Ui
import Quickshell

// The shell's own sizes: the workspace part of the top-left tile. (The tile height is the design language's: Theme.)
Singleton {
    readonly property int wsCell: 20                   // one workspace cell on the ruler
    readonly property int wsBlockW: 26 + 10 * wsCell   // workspace part of the top-left tile
    readonly property int musicW: 200                  // music part of the top-left tile, added while a player is active
}
