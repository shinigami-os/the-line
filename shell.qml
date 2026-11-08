//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs.modules.line
import qs.services

ShellRoot {
    id: root

    readonly property var screens: Quickshell.screens.filter(s => Config.screenFilter.length === 0 || Config.screenFilter.includes(s.name))

    property real lastSuperTap: 0

    // The focused screen, or the first one The Line runs on.
    function focusedScreen() {
        const focused = Hyprland.focusedMonitor?.name ?? "";
        const names = screens.map(s => s.name);
        return names.includes(focused) ? focused : names[0];
    }

    // Panels opened from the keyboard go to the focused screen.
    function toggleFocused(panel) {
        UiState.toggle(focusedScreen(), panel);
    }

    // Easter egg: on a laptop, Kira says something when the charger is plugged in or pulled out.
    readonly property var pluggedLines: ["i've got the power.", "plugged in. unlimited power. almost.", "charging. feel the volts.", "back on the grid at {battery}."]
    readonly property var unpluggedLines: ["on battery. make it count.", "unplugged. every watt counts now.", "cord cut. we ride on {battery}.", "wireless mode. stay close to a socket."]

    Connections {
        target: UPower

        function onOnBatteryChanged() {
            if (!(UPower.displayDevice?.isLaptopBattery ?? false))
                return;
            const lines = UPower.onBattery ? root.unpluggedLines : root.pluggedLines;
            Voice.say(lines[Math.floor(Math.random() * lines.length)], root.focusedScreen());
        }
    }

    // Quickshell doesn't always update a workspace's fullscreen state when an app leaves fullscreen by itself (F11),
    // nor window classes and titles: re-read them after the matching Hyprland events.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "submap")
                UiState.resizing = event.data === "resize";
            // Re-read only when something we show changed, and once things settle (debounced): re-reading on
            // every workspace event while SUPER+scroll creates and destroys workspaces crashed Quickshell.
            if (event.name === "fullscreen") {
                refreshWorkspaces.restart();
                refreshWorkspacesLate.restart();
                refreshToplevels.restart();   // the mode: real fullscreen or maximized (TheLine.fullscreen)
            }
            if (["openwindow", "closewindow", "windowtitlev2", "movewindowv2"].includes(event.name))
                refreshToplevels.restart();
        }
    }
    Timer {
        id: refreshWorkspaces
        interval: 120
        onTriggered: Hyprland.refreshWorkspaces()
    }
    // Hyprland can still report the old state 120 ms after leaving fullscreen: read it once more later.
    Timer {
        id: refreshWorkspacesLate
        interval: 700
        onTriggered: {
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
        }
    }
    // And while a workspace counts as fullscreen, keep checking: a stale "fullscreen" would keep the line hidden
    // until the next toggle. It heals within 2.5 s whatever missed the change.
    Timer {
        running: Hyprland.workspaces.values.some(w => w.hasFullscreen)
        repeat: true
        interval: 2500
        onTriggered: {
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();   // maximized or really fullscreen
        }
    }
    Timer {
        id: refreshToplevels
        interval: 120
        onTriggered: Hyprland.refreshToplevels()
    }

    Variants {
        model: root.screens

        TheLine {}
    }

    // Hyprland binds, e.g. hl.bind("SUPER+SPACE", hl.dsp.global("the-line:launcher"))
    component Shortcut: GlobalShortcut {
        appid: "the-line"
    }

    Shortcut {
        name: "launcher"
        description: "Open the launcher"
        onPressed: root.toggleFocused("tl")
    }
    // Tapping Super alone: bound on the key's release, which reaches the shell as a release.
    Shortcut {
        name: "launcherTap"
        description: "Open the launcher (tap Super); tap twice for the workspace overview"
        onReleased: {
            // A second tap right after the first turns the launcher into the workspace overview (same tile).
            const now = Date.now();
            if (now - root.lastSuperTap < 400) {
                root.lastSuperTap = 0;
                UiState.openPanel = "tw";
                UiState.openScreen = root.focusedScreen();
            } else {
                root.lastSuperTap = now;
                // A tap while the overview is open closes it; otherwise it toggles the launcher.
                if (UiState.openPanel === "tw")
                    UiState.close();
                else
                    root.toggleFocused("tl");
            }
        }
    }
    Shortcut {
        name: "cheatsheet"
        description: "Every shortcut, in one sheet"
        onPressed: {
            const here = root.focusedScreen();
            UiState.sheetScreen = UiState.sheetScreen === here ? "" : here;
        }
    }
    // The power menu: on Log out from CTRL+ALT+Delete, on Power off from the power button. Again to close.
    property real lastPowerButton: 0
    function togglePower(selected) {
        const here = root.focusedScreen();
        UiState.powerSelected = selected;
        UiState.powerScreen = UiState.powerScreen === here ? "" : here;
    }
    Shortcut {
        name: "power"
        description: "Power menu"
        onPressed: root.togglePower(0)
    }
    Shortcut {
        name: "powerButton"
        description: "Power menu, on Power off (the power button)"
        onPressed: root.togglePower(3)
    }
    // The line's dialogs: open on the focused screen, closed by the same key.
    function toggleDialog(key) {
        const here = root.focusedScreen();
        UiState[key] = UiState[key] === here ? "" : here;
    }
    Shortcut {
        name: "clipboard"
        description: "Clipboard history"
        onPressed: root.toggleDialog("clipScreen")
    }
    Shortcut {
        name: "wallpapers"
        description: "Wallpaper picker"
        onPressed: root.toggleDialog("wallScreen")
    }
    Shortcut {
        name: "visualiser"
        description: "Music visualiser on the line"
        onPressed: Visualiser.toggle()
    }
    Shortcut {
        name: "emoji"
        description: "Emoji picker"
        onPressed: root.toggleDialog("emojiScreen")
    }
    Shortcut {
        name: "notifications"
        description: "Open notifications and calendar"
        onPressed: root.toggleFocused("tc")
    }
    Shortcut {
        name: "quicksettings"
        description: "Open quick settings"
        onPressed: root.toggleFocused("tr")
    }
    Shortcut {
        name: "performance"
        description: "Open the performance dashboard"
        onPressed: root.toggleFocused("tp")
    }

    // qs -p <path> ipc call line <function> ...
    IpcHandler {
        target: "line"

        function notify(app: string, title: string, body: string): void {
            Notifs.push(app, title, body);
        }

        function gauge(kind: string, value: real): void {
            LineState.showGauge(kind, value);
        }

        function toggle(screen: string, panel: string): void {
            UiState.toggle(screen, panel);
        }

        function toggleFocused(panel: string): void {
            root.toggleFocused(panel);
        }

        // Opens the launcher on the focused screen with this search typed in.
        function search(text: string): void {
            if (UiState.openPanel !== "tl")
                root.toggleFocused("tl");
            UiState.launcherQuery = text;
        }

        // Says a line on top of the windows of the focused screen, like the power easter egg.
        function say(text: string): void {
            Voice.say(text, root.focusedScreen());
        }

        function cheatsheet(): void {
            const here = root.focusedScreen();
            UiState.sheetScreen = UiState.sheetScreen === here ? "" : here;
        }

        // Opens the cheat sheet on a given tab (0 = Desktop).
        function cheatsheetTab(index: int): void {
            UiState.sheetTab = index;
            UiState.sheetScreen = root.focusedScreen();
        }

        // The frozen screens of an area screenshot (session/the-line-shot).
        function freeze(on: bool): void {
            UiState.frozen = on;
        }

        // Volume, screen brightness and keyboard backlight keys: one step up (1) or down (-1), the size of the
        // "levelStep" setting. The level shows on the line, and its name and value in the clock tile.
        function volumeStep(direction: int): void {
            Audio.step(direction * Config.levelStep / 100);
        }

        function brightnessStep(direction: int): void {
            Brightness.step(direction);
        }

        function kbdStep(direction: int): void {
            KbdBacklight.step(direction);
        }

        function power(): void {
            root.togglePower(0);
        }

        // Settings > Workspaces: forget a remembered floating app.
        function forgetFloat(cls: string): void {
            FloatMemory.forget(cls);
        }

        // The power button, from acpid (session/ has no part in it: a dispatched global arrives as a key
        // release, so Shortcut.onPressed never fires).
        // The button often comes in twice per press (two ACPI devices report it): the second one is dropped.
        function powerButton(): void {
            const now = Date.now();
            if (now - root.lastPowerButton < 800)
                return;
            root.lastPowerButton = now;
            if (Config.powerButton === "suspend")
                Power.suspend();
            else if (Config.powerButton === "lock")
                Power.lock();
            else if (Config.powerButton !== "nothing")
                root.togglePower(3);
        }

        function clipboard(): void {
            root.toggleDialog("clipScreen");
        }

        function emoji(): void {
            root.toggleDialog("emojiScreen");
        }

        function visualiser(): void {
            Visualiser.toggle();
        }

        function wallpapers(): void {
            root.toggleDialog("wallScreen");
        }

        // Float / tile the focused window (SUPER+ALT+Space), remembering floated apps (FloatMemory).
        function toggleFloat(): void {
            FloatMemory.toggle();
        }

        function overview(): void {
            UiState.openPanel = "tw";
            UiState.openScreen = root.focusedScreen();
        }

        function close(): void {
            UiState.close();
        }

        function clockFace(): void {
            ClockFace.toggle();
        }
    }
}
