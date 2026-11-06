pragma Singleton

import QtQuick
import Quickshell

// Every colour and font The Line uses lives here.
Singleton {
    readonly property color bg: "#000000"
    readonly property color surface: "#1B1A18"
    readonly property color surface2: "#24221F"
    readonly property color border: "#3A3631"
    readonly property color borderStrong: "#5A544C"
    readonly property color text: "#ECE8E1"
    readonly property color muted: "#9C968C"
    readonly property color accent: Config.accent
    readonly property color accentDeep: "#7B2FF7"
    readonly property color accentText: "#0F0D12"
    readonly property color ok: "#6CC495"
    readonly property color error: "#EF7A5E"

    // A toggled control: accent at 14% over surface.
    readonly property color accentTint: Qt.tint(surface, Qt.rgba(accent.r, accent.g, accent.b, 0.14))

    readonly property string fontUi: "Raleway"
    readonly property string fontMono: Qt.fontFamilies().indexOf("IBM Plex Mono") >= 0 ? "IBM Plex Mono" : "JetBrains Mono"

    // Tile geometry: every tile hangs from the line at y = 10 and shares this height.
    readonly property int tileHeight: 42
    readonly property int wsCell: 20   // one workspace cell on the ruler

    // Square corners, always.
    readonly property int radius: 0
}
