pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Accent from the wallpaper: matugen picks the image's most saturated source colour, and the accent is its
// primary tone 60 (what Kira violet is to the default wallpaper). Runs when a wallpaper is set with the setting on,
// and when the setting is turned on.
Singleton {
    id: root

    function fromWallpaper(path) {
        if (path === "")
            return;
        proc.running = false;
        proc.command = ["matugen", "image", path, "--dry-run", "-j", "hex", "--prefer", "saturation", "-t", "scheme-vibrant"];
        proc.running = true;
    }

    // The settings app's own way of setting a wallpaper.
    function setWallpaper(path) {
        Config.set("wallpaper", path);
        if (Config.accentFromWallpaper)
            fromWallpaper(path);
    }

    Connections {
        target: Config

        function onAccentFromWallpaperChanged() {
            if (Config.loadedOnce && Config.accentFromWallpaper)
                root.fromWallpaper(Config.wallpaper);
        }
    }

    Process {
        id: proc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const color = JSON.parse(text).palettes.primary["60"].color;
                    if (/^#[0-9a-f]{6}$/i.test(color))
                        Config.set("accent", color.toUpperCase());
                } catch (e) {
                    console.warn("accent: matugen", e);
                }
            }
        }
    }
}
