pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Accent from the wallpaper: matugen picks the image's source colour, and the accent is its primary tone 60 (what
// Kira violet is to the default wallpaper). Busy, many-coloured wallpapers (Kira's default) offer matugen several
// candidates: --prefer saturation takes the most vivid one, which is what an accent wants (checked on every shipped
// wallpaper). Black and white ones have none: --fallback-color makes that Kira violet, kept as is.
// Runs when the primary screen's wallpaper changes with the setting on, and when the setting is turned on. A video
// gives its still frame (Frames); a GIF is read as it is.
Singleton {
    id: root

    readonly property string kira: "#9A5CFF"

    function fromWallpaper(path) {
        if (path === "")
            return;
        if (Config.wallpaperKind(path) === "video") {
            Frames.make(path, frame => root.fromPicture(frame));
            return;
        }
        fromPicture(path);
    }

    function fromPicture(path) {
        proc.running = false;
        proc.command = ["matugen", "image", path, "--dry-run", "-j", "hex", "--prefer", "saturation", "-t", "scheme-vibrant",
            "--fallback-color", root.kira];
        proc.running = true;
    }

    // Setting a wallpaper (the settings app, and the shell's picker): for every screen (screen "", their own ones go), or for one.
    // The same as every screen's takes that screen's own away.
    function setWallpaper(path, screen) {
        const before = Config.wallpaperFor(Config.primaryScreen);
        if (!screen) {
            if (Object.keys(Config.wallpapers ?? {}).length > 0)
                Config.set("wallpapers", {});
            Config.set("wallpaper", path);
        } else {
            const own = Object.assign({}, Config.wallpapers ?? {});
            if (path === Config.wallpaper)
                delete own[screen];
            else
                own[screen] = path;
            Config.set("wallpapers", own);
        }
        const after = Config.wallpaperFor(Config.primaryScreen);
        if (Config.accentFromWallpaper && after !== before)
            fromWallpaper(after);
    }

    Connections {
        target: Config

        // turned on in the settings app: it picks the accent (the shell shares this file and would do it twice)
        function onAccentFromWallpaperChanged() {
            if (Config.loadedOnce && Config.accentFromWallpaper && !Config.inShell)
                root.fromWallpaper(Config.wallpaperFor(Config.primaryScreen));
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
