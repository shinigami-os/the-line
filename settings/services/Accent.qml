pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Accent from the wallpaper: matugen picks the image's source colour, and the accent is its primary tone 60 (what
// Kira violet is to the default wallpaper). Busy, many-coloured wallpapers (Kira's default) offer matugen several
// candidates: --prefer saturation takes the most vivid one, which is what an accent wants (checked on every shipped
// wallpaper). Black and white ones have none: --fallback-color makes that Kira violet, kept as is.
// Runs when a wallpaper is set with the setting on, and when the setting is turned on.
Singleton {
    id: root

    readonly property string kira: "#9A5CFF"

    function fromWallpaper(path) {
        if (path === "")
            return;
        proc.running = false;
        proc.command = ["matugen", "image", path, "--dry-run", "-j", "hex", "--prefer", "saturation", "-t", "scheme-vibrant",
            "--fallback-color", root.kira];
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
                    const json = JSON.parse(text);
                    // no colour in the image: matugen fell back to Kira violet, which stays exactly itself
                    const noColour = json.colors.source_color.default.color.toUpperCase() === root.kira;
                    const color = noColour ? root.kira : json.palettes.primary["60"].color;
                    if (/^#[0-9a-f]{6}$/i.test(color))
                        Config.set("accent", color.toUpperCase());
                } catch (e) {
                    console.warn("accent: matugen", e);
                }
            }
        }
    }
}
