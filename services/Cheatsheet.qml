pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// What the cheat sheet (SUPER+F1) shows, read live so it is always the real thing:
//   Desktop  Hyprland's binds (hyprctl binds -j), grouped by the "Group: what it does" of their desc,
//            and the touchpad gestures from the session config and ~/.config/the-line/hypr/custom.lua
//   foot     foot's own defaults (/etc/xdg/foot/foot.ini) with ~/.config/foot/foot.ini on top
//   zsh      the shell's key bindings (bindkey), for the editing commands worth knowing
//   yazi     yazi's default keymap (built into the binary) with ~/.config/yazi/keymap.toml on top
// A tab only shows when there is something in it. Each tab: [{ group, rows: [{ keys: [[cap, ...], ...], text }] }]
Singleton {
    id: root

    property var desktop: []
    property var foot: []
    property var zsh: []
    property var yazi: []

    readonly property var tabs: [
        { name: "Desktop", groups: desktop },
        { name: "foot", groups: foot },
        { name: "zsh", groups: zsh },
        { name: "yazi", groups: yazi }
    ].filter(t => t.groups.length > 0)

    function refresh() {
        if (!binds.running)
            binds.running = true;
        if (!bindkey.running)
            bindkey.running = true;
        if (!yaziKeys.running)
            yaziKeys.running = true;
        footDefaults.reload();
        footUser.reload();
        sessionConfig.reload();
        customConfig.reload();
        buildFoot();
    }

    // ------------------------------------------------------------------ Hyprland

    readonly property var keyNames: ({
        "Return": "Enter", "Escape": "Esc", "space": "Space", "Space": "Space", "semicolon": ";", "Print": "Print",
        "Left": "←", "Right": "→", "Up": "↑", "Down": "↓", "End": "End", "Home": "Home", "Delete": "Delete",
        "Super_L": "Super", "mouse_up": "Scroll up", "mouse_down": "Scroll down",
        "mouse:272": "Left drag", "mouse:273": "Right drag",
        "XF86AudioRaiseVolume": "Volume +", "XF86AudioLowerVolume": "Volume −", "XF86AudioMute": "Mute",
        "XF86AudioPlay": "Play", "XF86AudioPause": "Pause", "XF86AudioNext": "Next", "XF86AudioPrev": "Previous",
        "XF86MonBrightnessUp": "Brightness +", "XF86MonBrightnessDown": "Brightness −", "XF86PowerOff": "Power button"
    })

    function keyName(key) {
        const code = key.match(/^code:(\d+)$/);
        if (code) {
            const n = Number(code[1]) - 9;   // keycodes 10..19 are the 1..0 row
            return n >= 1 && n <= 10 ? String(n % 10) : key;
        }
        if (keyNames[key] !== undefined)
            return keyNames[key];
        return key.length === 1 ? key.toUpperCase() : key;
    }

    // Binds made with "code:N" come back with an empty key (and, from Lua, a keycode of 0).
    function keyOf(b) {
        return (b.key ?? "") === "" && b.keycode ? "code:" + b.keycode : (b.key ?? "");
    }

    function capsOf(b) {
        const caps = [];
        const mods = [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]];
        for (const [bit, name] of mods)
            if ((b.modmask & bit) && !(b.key === "Super_L" && name === "Super"))
                caps.push(name);
        caps.push(keyName(keyOf(b)) + (b.key === "Super_L" && b.release ? " (tap)" : ""));
        return caps;
    }

    function buildDesktop(list) {
        const groups = {};
        const order = [];
        const add = (group, text, caps) => {
            if (!groups[group]) {
                groups[group] = { group: group, rows: [], byText: {} };
                order.push(group);
            }
            const g = groups[group];
            if (g.byText[text] === undefined) {
                g.byText[text] = g.rows.length;
                g.rows.push({ keys: [], text: text });
            }
            g.rows[g.byText[text]].keys.push(caps);
        };
        for (const b of list) {
            const desc = b.description ?? "";
            if (desc === "")
                continue;
            const m = desc.match(/^([^:]+):\s*(.*)$/);
            const group = m ? m[1] : "Apps";
            let text = m ? m[2] : desc.replace(/^Launch\s+/, "");
            text = text.charAt(0).toUpperCase() + text.slice(1);
            let caps = capsOf(b);
            // Ten binds that differ only by their number (workspaces): one row, "1 – 0".
            const num = text.match(/^(.*?)\s(\d+)(\s.*)?$/);
            const k = keyOf(b);
            if (num && (k === "" || /^code:\d+$/.test(k))) {
                text = num[1] + " 1 – 10" + (num[3] ?? "");
                caps = caps.slice(0, -1).concat("1 – 0");
            }
            const key = caps.join("+");
            const g = groups[group];
            const existing = g ? g.rows[g.byText[text]] : null;
            if (existing && existing.keys.some(k => k.join("+") === key))
                continue;
            add(group, text, caps);
        }
        // Touchpad gestures, from the configs.
        for (const gst of gestures())
            add("Touchpad", gst.text, [gst.fingers + " fingers", gst.direction]);
        const preferred = ["The Line", "Apps", "Windows", "Workspaces", "Resize mode", "Session", "Volume and brightness", "Media", "Screenshots and tools", "Touchpad"];
        order.sort((a, b) => (preferred.indexOf(a) + 1 || 99) - (preferred.indexOf(b) + 1 || 99));
        desktop = order.map(name => ({ group: name, rows: groups[name].rows.map(r => ({ keys: r.keys, text: r.text })) }));
    }

    readonly property var gestureActions: ({
        "workspace": "Switch workspace", "fullscreen": "Fullscreen", "move": "Move the window",
        "resize": "Resize the window", "float": "Float / tile", "close": "Close the window", "special": "Scratchpad"
    })

    function gestures() {
        const out = [];
        const re = /hl\.gesture\(\{\s*fingers\s*=\s*(\d+)\s*,\s*direction\s*=\s*"(\w+)"\s*,\s*action\s*=\s*"(\w+)"/g;
        for (const text of [sessionConfig.text(), customConfig.text()]) {
            let m;
            while ((m = re.exec(text)) !== null)
                out.push({ fingers: m[1], direction: m[2], text: gestureActions[m[3]] ?? m[3] });
        }
        return out;
    }

    Process {
        id: binds
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.buildDesktop(JSON.parse(text));
                } catch (e) {
                    console.warn("cheatsheet: hyprctl binds", e);
                }
            }
        }
    }

    FileView {
        id: sessionConfig
        path: Qt.resolvedUrl("../session/hyprland.lua").toString().replace("file://", "")
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: customConfig
        path: Quickshell.env("HOME") + "/.config/the-line/hypr/custom.lua"
        blockLoading: true
        printErrors: false
    }

    // ------------------------------------------------------------------ foot

    readonly property var footActions: ({
        "clipboard-copy": ["Clipboard", "Copy"], "clipboard-paste": ["Clipboard", "Paste"],
        "primary-paste": ["Clipboard", "Paste the selection"],
        "search-start": ["Search", "Search the scrollback"],
        "scrollback-up-page": ["Scroll", "Page up"], "scrollback-down-page": ["Scroll", "Page down"],
        "scrollback-up-half-page": ["Scroll", "Half a page up"], "scrollback-down-half-page": ["Scroll", "Half a page down"],
        "scrollback-up-line": ["Scroll", "One line up"], "scrollback-down-line": ["Scroll", "One line down"],
        "scrollback-home": ["Scroll", "To the top"], "scrollback-end": ["Scroll", "To the bottom"],
        "prompt-prev": ["Commands", "Previous command"], "prompt-next": ["Commands", "Next command"],
        "font-increase": ["Text", "Bigger"], "font-decrease": ["Text", "Smaller"], "font-reset": ["Text", "Normal size"],
        "spawn-terminal": ["Window", "New terminal here"], "fullscreen": ["Window", "Fullscreen"],
        "show-urls-launch": ["Links", "Open a link"], "show-urls-copy": ["Links", "Copy a link"],
        "unicode-input": ["Text", "Type a unicode character"]
    })

    // Bytes sent by [text-bindings] that have a meaning worth showing.
    readonly property var footTexts: ({
        "\\x03": ["Commands", "Interrupt (Ctrl+C)"], "\\x17": ["Editing", "Delete the previous word"],
        "\\x1bd": ["Editing", "Delete the next word"]
    })

    function footKeys(value) {
        return value.replace(/\[[^\]]*\]/g, "").replace(/#.*$/, "").trim().split(/\s+/)
            .filter(k => k !== "" && k !== "none" && !k.startsWith("XF86"))
            .map(k => k.split("+").map(p => ({ "Control": "Ctrl", "Page_Up": "Page Up", "Page_Down": "Page Down", "BackSpace": "Backspace", "KP_Add": "Num +", "KP_Subtract": "Num −", "KP_0": "Num 0", "plus": "+", "minus": "−", "equal": "=", "Up": "↑", "Down": "↓" }[p] ?? (p.length === 1 ? p.toUpperCase() : p))));
    }

    // Reads an ini file's [section]; `commented` also takes "# key=value" lines (foot's defaults file).
    function iniSection(text, section, commented) {
        const out = {};
        let inside = false;
        for (let line of text.split("\n")) {
            line = line.trim();
            if (line.startsWith("[")) {
                inside = line === "[" + section + "]";
                continue;
            }
            if (!inside)
                continue;
            if (commented && line.startsWith("#"))
                line = line.replace(/^#\s*/, "");
            else if (line.startsWith("#") || line.startsWith(";"))
                continue;
            const eq = line.indexOf("=");
            if (eq > 0)
                out[line.slice(0, eq).trim()] = line.slice(eq + 1).trim();
        }
        return out;
    }

    function buildFoot() {
        const defaults = footDefaults.text();
        if (defaults === "") {
            foot = [];
            return;
        }
        const user = footUser.text();
        const keys = Object.assign(iniSection(defaults, "key-bindings", true), iniSection(user, "key-bindings", false));
        const texts = iniSection(user, "text-bindings", false);
        const groups = {};
        const order = [];
        const add = (g, text, caps) => {
            if (caps.length === 0)
                return;
            if (!groups[g]) {
                groups[g] = [];
                order.push(g);
            }
            groups[g].push({ keys: caps, text: text });
        };
        for (const action in footActions)
            if (keys[action] !== undefined)
                add(footActions[action][0], footActions[action][1], footKeys(keys[action]));
        for (const bytes in texts)
            if (footTexts[bytes])
                add(footTexts[bytes][0], footTexts[bytes][1], footKeys(texts[bytes]));
        foot = order.map(g => ({ group: g, rows: groups[g] }));
    }

    FileView {
        id: footDefaults
        path: "/etc/xdg/foot/foot.ini"
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: footUser
        path: Quickshell.env("HOME") + "/.config/foot/foot.ini"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: {
            reload();
            root.buildFoot();
        }
    }

    // ------------------------------------------------------------------ zsh

    readonly property var zshWidgets: ({
        "beginning-of-line": ["Moving", "Start of the line"], "end-of-line": ["Moving", "End of the line"],
        "backward-word": ["Moving", "One word back"], "forward-word": ["Moving", "One word forward"],
        "accept-suggestion-or-forward-word": ["Moving", "One word forward (or take the suggestion's next word)"],
        "backward-kill-word": ["Editing", "Delete the previous word"], "kill-word": ["Editing", "Delete the next word"],
        "kill-line": ["Editing", "Delete to the end of the line"], "backward-kill-line": ["Editing", "Delete to the start of the line"],
        "kill-whole-line": ["Editing", "Delete the whole line"], "yank": ["Editing", "Paste what was deleted"],
        "undo": ["Editing", "Undo"], "transpose-chars": ["Editing", "Swap two letters"],
        "history-incremental-search-backward": ["History", "Search the history"],
        "history-search-backward": ["History", "Previous command starting the same"],
        "history-search-forward": ["History", "Next command starting the same"],
        "autosuggest-accept": ["History", "Take the grey suggestion"],
        "push-line": ["Line", "Set the line aside, type another, get it back"],
        "clear-screen": ["Line", "Clear the screen"], "expand-or-complete": ["Line", "Complete"],
        "edit-command-line": ["Line", "Edit the line in your editor"]
    })

    readonly property var zshSequences: ({
        "^[[A": "↑", "^[[B": "↓", "^[[C": "→", "^[[D": "←", "^[OA": "↑", "^[OB": "↓", "^[OC": "→", "^[OD": "←",
        "^[[1;5A": "Ctrl+↑", "^[[1;5B": "Ctrl+↓", "^[[1;5C": "Ctrl+→", "^[[1;5D": "Ctrl+←",
        "^[[3~": "Delete", "^[[3;5~": "Ctrl+Delete", "^[[H": "Home", "^[[F": "End", "^[OH": "Home", "^[OF": "End",
        "^@": "Ctrl+Space", "^?": "Backspace", "^I": "Tab", "^H": "Ctrl+Backspace"
    })

    function zshKey(seq) {
        if (zshSequences[seq])
            return zshSequences[seq].split("+");
        if (/^\^[A-Z]$/.test(seq))
            return ["Ctrl", seq[1]];
        if (/^\^\[[a-z]$/.test(seq))
            return ["Alt", seq[2].toUpperCase()];
        if (/^\^X\^[A-Z]$/.test(seq))
            return ["Ctrl", "X", "Ctrl", seq[3]];
        return null;   // anything else is too obscure for a cheat sheet
    }

    Process {
        id: bindkey
        command: ["sh", "-c", "command -v zsh >/dev/null && zsh -ic 'bindkey' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const groups = {};
                const order = [];
                const byWidget = {};
                for (const line of text.split("\n")) {
                    const m = line.match(/^"(.*)" (\S+)$/);
                    if (!m || !root.zshWidgets[m[2]])
                        continue;
                    const caps = root.zshKey(m[1].replace(/\\\\/g, "\\\\"));
                    if (!caps)
                        continue;
                    const [g, t] = root.zshWidgets[m[2]];
                    if (!groups[g]) {
                        groups[g] = [];
                        order.push(g);
                    }
                    if (byWidget[m[2]] === undefined) {
                        byWidget[m[2]] = groups[g].length;
                        groups[g].push({ keys: [], text: t });
                    }
                    groups[g][byWidget[m[2]]].keys.push(caps);
                }
                const preferred = ["Moving", "Editing", "History", "Line"];
                order.sort((a, b) => preferred.indexOf(a) - preferred.indexOf(b));
                root.zsh = order.map(g => ({ group: g, rows: groups[g] }));
            }
        }
    }

    // ------------------------------------------------------------------ yazi

    // Every command of yazi's default keymap, by what it runs (a list of commands joined with "; "):
    // [group, what it does]. A command not listed here (one of yours) shows yazi's own desc, under "Yours".
    readonly property var yaziCommands: ({
        "mgr": {
            "quit": ["Basics", "Quit"],
            "quit --no-cwd-file": ["Basics", "Quit without writing the cwd file"],
            "close": ["Basics", "Close the tab (quits on the last one)"],
            "suspend": ["Basics", "Suspend (fg in the shell to come back)"],
            "escape": ["Basics", "Cancel: visual mode, the selection or the search"],
            "help": ["Basics", "Help: every key of the current view"],
            "tasks:show": ["Basics", "Task manager"],
            "arrow prev": ["Moving", "Previous file"],
            "arrow next": ["Moving", "Next file"],
            "arrow top": ["Moving", "First file"],
            "arrow bot": ["Moving", "Last file"],
            "arrow -50%": ["Moving", "Half a page up"],
            "arrow 50%": ["Moving", "Half a page down"],
            "arrow -100%": ["Moving", "One page up"],
            "arrow 100%": ["Moving", "One page down"],
            "leave": ["Folders", "Parent folder"],
            "enter": ["Folders", "Into the folder"],
            "back": ["Folders", "Back to the previous folder"],
            "forward": ["Folders", "Forward to the next folder"],
            "cd ~": ["Folders", "Home"],
            "cd ~/.config": ["Folders", "~/.config"],
            "cd ~/Downloads": ["Folders", "~/Downloads"],
            "plugin trash": ["Folders", "The trash"],
            "cd --interactive": ["Folders", "Type a folder to go to"],
            "follow": ["Folders", "Follow the symlink"],
            "plugin zoxide": ["Folders", "Jump to a folder (zoxide)"],
            "plugin fzf": ["Folders", "Jump to a file or folder (fzf)"],
            "toggle; arrow 1": ["Selecting", "Select or unselect, then next file"],
            "toggle_all --state=on": ["Selecting", "Select all"],
            "toggle_all": ["Selecting", "Invert the selection"],
            "visual_mode": ["Selecting", "Visual mode: select a range"],
            "visual_mode --unset": ["Selecting", "Visual mode: unselect a range"],
            "open": ["Files", "Open"],
            "open --interactive": ["Files", "Open with… (pick the app)"],
            "yank": ["Files", "Copy"],
            "yank --cut": ["Files", "Cut"],
            "paste": ["Files", "Paste"],
            "paste --force": ["Files", "Paste, overwriting what is there"],
            "unyank": ["Files", "Forget the copy or cut"],
            "link": ["Files", "Symlink the copied files (absolute path)"],
            "link --relative": ["Files", "Symlink the copied files (relative path)"],
            "hardlink": ["Files", "Hardlink the copied files"],
            "remove": ["Files", "Move to the trash"],
            "remove --permanently": ["Files", "Delete for good"],
            "create": ["Files", "New file (end the name with / for a folder)"],
            "bulk_create": ["Files", "New files, several at once"],
            "rename --cursor=before_ext": ["Files", "Rename (several selected: all at once)"],
            "shell --interactive": ["Files", "Run a shell command"],
            "shell --block --interactive": ["Files", "Run a shell command and wait for it"],
            "copy path": ["Copy to the clipboard", "The file's path"],
            "copy url": ["Copy to the clipboard", "The file's URL"],
            "copy dirpath": ["Copy to the clipboard", "The folder's path"],
            "copy dirurl": ["Copy to the clipboard", "The folder's URL"],
            "copy filename": ["Copy to the clipboard", "The file's name"],
            "copy name_without_ext": ["Copy to the clipboard", "The name without its extension"],
            "search --via=fd": ["Search", "Search names, in every subfolder (fd)"],
            "search --via=rg": ["Search", "Search contents, in every subfolder (ripgrep)"],
            "escape --search": ["Search", "Stop the search"],
            "filter --smart": ["Search", "Filter this folder"],
            "find --smart": ["Search", "Find in this folder"],
            "find --previous --smart": ["Search", "Find, backwards"],
            "find_arrow": ["Search", "Next match"],
            "find_arrow --previous": ["Search", "Previous match"],
            "hidden toggle": ["View", "Show or hide hidden files"],
            "seek -5": ["View", "Scroll the preview up"],
            "seek 5": ["View", "Scroll the preview down"],
            "spot": ["View", "Spot: the file's details"],
            "linemode size": ["View", "Beside the names: size"],
            "linemode permissions": ["View", "Beside the names: permissions"],
            "linemode btime": ["View", "Beside the names: created"],
            "linemode mtime": ["View", "Beside the names: modified"],
            "linemode owner": ["View", "Beside the names: owner"],
            "linemode none": ["View", "Beside the names: nothing"],
            "sort mtime --reverse=no; linemode mtime": ["Sorting", "Modified"],
            "sort mtime --reverse=yes; linemode mtime": ["Sorting", "Modified, reversed"],
            "sort btime --reverse=no; linemode btime": ["Sorting", "Created"],
            "sort btime --reverse=yes; linemode btime": ["Sorting", "Created, reversed"],
            "sort extension --reverse=no": ["Sorting", "Extension"],
            "sort extension --reverse=yes": ["Sorting", "Extension, reversed"],
            "sort alphabetical --reverse=no": ["Sorting", "Alphabetical"],
            "sort alphabetical --reverse=yes": ["Sorting", "Alphabetical, reversed"],
            "sort natural --reverse=no": ["Sorting", "Natural (file2 before file10)"],
            "sort natural --reverse=yes": ["Sorting", "Natural, reversed"],
            "sort size --reverse=no; linemode size": ["Sorting", "Size"],
            "sort size --reverse=yes; linemode size": ["Sorting", "Size, reversed"],
            "sort random --reverse=no": ["Sorting", "Random"],
            "tab_create --current": ["Tabs", "New tab here"],
            "tab_rename --interactive": ["Tabs", "Rename the tab"],
            "tab_switch -1 --relative": ["Tabs", "Previous tab"],
            "tab_switch 1 --relative": ["Tabs", "Next tab"],
            "tab_swap -1": ["Tabs", "Move the tab left"],
            "tab_swap 1": ["Tabs", "Move the tab right"]
        },
        // The other views: only what you need to get through them.
        "input": {
            "close --submit": ["Text boxes (rename, search…)", "Done"],
            "escape": ["Text boxes (rename, search…)", "Normal mode (vi keys); again to cancel"],
            "close": ["Text boxes (rename, search…)", "Cancel"],
            "kill backward": ["Text boxes (rename, search…)", "Delete the previous word"],
            "kill bol": ["Text boxes (rename, search…)", "Delete to the start"],
            "recall -1": ["Text boxes (rename, search…)", "Previous entry (history)"],
            "recall 1": ["Text boxes (rename, search…)", "Next entry (history)"]
        },
        "confirm": {
            "close --submit": ["Questions", "Yes"],
            "close": ["Questions", "No"]
        },
        "pick": {
            "close --submit": ["Open with… list", "Open with this one"],
            "close": ["Open with… list", "Cancel"]
        },
        "tasks": {
            "inspect": ["Task manager", "Show the task's output"],
            "cancel": ["Task manager", "Cancel the task"],
            "close": ["Task manager", "Close"]
        },
        "spot": {
            "swipe prev": ["Spot", "Previous file"],
            "swipe next": ["Spot", "Next file"],
            "copy cell": ["Spot", "Copy the selected value"],
            "close": ["Spot", "Close"]
        }
    })

    // Bindings that only work with a program yazi calls.
    readonly property var yaziNeeds: ({
        "search --via=fd": "fd", "search --via=rg": "rg", "plugin fzf": "fzf", "plugin zoxide": "zoxide"
    })

    readonly property var yaziKeyNames: ({
        "Esc": "Esc", "Enter": "Enter", "Tab": "Tab", "BackTab": "Shift+Tab", "Space": "Space", "Backspace": "Backspace",
        "Delete": "Delete", "Insert": "Insert", "Up": "↑", "Down": "↓", "Left": "←", "Right": "→",
        "Home": "Home", "End": "End", "PageUp": "Page Up", "PageDown": "Page Down", "lt": "<", "gt": ">"
    })

    // One step of an `on`: "g", "G" (Shift+G), "<C-a>", "<A-S-k>", "<Enter>", "<C-->".
    function yaziStep(step) {
        const caps = [];
        let key = step;
        if (step.length > 2 && step.startsWith("<") && step.endsWith(">")) {
            key = step.slice(1, -1);
            const mods = { "C": "Ctrl", "A": "Alt", "S": "Shift", "D": "Super" };
            while (key.length > 2 && key[1] === "-" && mods[key[0]]) {
                caps.push(mods[key[0]]);
                key = key.slice(2);
            }
            key = yaziKeyNames[key] ?? key;
        }
        // Keys are case-sensitive: an upper-case letter is that letter with Shift.
        if (/^[A-Z]$/.test(key) && caps.indexOf("Shift") < 0)
            caps.push("Shift");
        caps.push(key.length === 1 ? key.toUpperCase() : key);
        return caps;
    }

    // A whole `on` (a chord is several steps): the caps, with "›" between the steps.
    function yaziCaps(on) {
        let caps = [];
        on.forEach((step, i) => caps = caps.concat(i > 0 ? ["›"] : [], yaziStep(step)));
        return caps;
    }

    function tomlStrings(value) {
        const out = [];
        const re = /"((?:[^"\\]|\\.)*)"|'([^']*)'/g;
        let m;
        while ((m = re.exec(value)) !== null)
            out.push(m[1] !== undefined ? m[1].replace(/\\(.)/g, "$1") : m[2]);
        return out;
    }

    // The keymap entries of a keymap.toml, by section: { mgr: { keymap: [...], prepend_keymap: [...], ... } }.
    // Enough TOML for yazi's keymaps: inline tables { on = ..., run = ..., desc = ... } in the three arrays.
    function parseYaziKeymap(text) {
        const out = {};
        let section = "";
        let list = "";
        for (const part of text.replace(/^\s*#.*$/gm, "").split(/^\s*\[([\w.]+)\]\s*$/m)) {
            // split with a capture group alternates between bodies and section names
            if (/^[\w.]+$/.test(part)) {
                section = part.replace(/^manager$/, "mgr");
                continue;
            }
            if (section === "")
                continue;
            out[section] = out[section] ?? {};
            // quoted strings may hold braces and brackets themselves (on = "{", on = [ "]" ])
            const re = /(prepend_keymap|append_keymap|keymap)\s*=\s*\[|\{((?:"(?:[^"\\]|\\.)*"|'[^']*'|[^{}"'])*)\}/g;
            let m;
            while ((m = re.exec(part)) !== null) {
                if (m[1]) {
                    list = m[1];
                    out[section][list] = out[section][list] ?? [];
                    continue;
                }
                const field = name => {
                    const f = m[2].match(new RegExp("\\b" + name + "\\s*=\\s*(\\[(?:\"(?:[^\"\\\\]|\\\\.)*\"|'[^']*'|[^\\]\"'])*\\]|\"(?:[^\"\\\\]|\\\\.)*\"|'[^']*')"));
                    return f ? root.tomlStrings(f[1]) : [];
                };
                const on = field("on");
                if (list !== "" && on.length > 0)
                    out[section][list].push({ on: on, run: field("run").join("; "), desc: field("desc")[0] ?? "" });
            }
        }
        return out;
    }

    function buildYazi(defaults, user, tools) {
        const def = parseYaziKeymap(defaults);
        const mine = parseYaziKeymap(user);
        const groups = {};
        const order = [];
        for (const section in yaziCommands) {
            const d = def[section] ?? {};
            const u = mine[section] ?? {};
            // yazi's order: your prepend_keymap, then your keymap (or the defaults), then your append_keymap;
            // the first binding of a key wins.
            const all = (u.prepend_keymap ?? []).concat(u.keymap ?? d.keymap ?? [], u.append_keymap ?? []);
            const taken = {};
            const tabs = [];
            for (const b of all) {
                const id = b.on.join(" ");
                if (taken[id])
                    continue;
                taken[id] = true;
                if (b.run === "" || b.run === "noop" || b.on[0] === "<C-[>")   // <C-[> is the terminal's Esc
                    continue;
                if (yaziNeeds[b.run] && tools.indexOf(yaziNeeds[b.run]) < 0)
                    continue;
                // in a text box a plain letter types itself; it only acts in vi normal mode
                if (section === "input" && b.on.length === 1 && b.on[0].length === 1)
                    continue;
                if (section === "mgr" && /^tab_switch \d+$/.test(b.run) && b.on.length === 1) {
                    tabs.push(b.on[0]);
                    continue;
                }
                const known = yaziCommands[section][b.run];
                if (!known && section !== "mgr")
                    continue;
                const [g, text] = known ?? ["Yours", b.desc || b.run];
                if (!groups[g]) {
                    groups[g] = { rows: [], byText: {} };
                    order.push(g);
                }
                if (groups[g].byText[text] === undefined) {
                    groups[g].byText[text] = groups[g].rows.length;
                    groups[g].rows.push({ keys: [], text: text });
                }
                groups[g].rows[groups[g].byText[text]].keys.push(yaziCaps(b.on));
            }
            // tab_switch 0..8 on 1..9: one row, like the workspaces
            if (tabs.length > 1 && groups["Tabs"])
                groups["Tabs"].rows.splice(1, 0, { keys: [[tabs[0] + " – " + tabs[tabs.length - 1]]], text: "Go to tab " + tabs[0] + " – " + tabs[tabs.length - 1] });
        }
        const preferred = ["Basics", "Moving", "Folders", "Selecting", "Files", "Copy to the clipboard", "Search", "View", "Sorting", "Tabs", "Yours",
            "Text boxes (rename, search…)", "Questions", "Open with… list", "Task manager", "Spot"];
        order.sort((a, b) => (preferred.indexOf(a) + 1 || 99) - (preferred.indexOf(b) + 1 || 99));
        yazi = order.map(g => ({ group: g, rows: groups[g].rows }));
    }

    // The default keymap is a TOML file built into the yazi binary, from its "#:schema ...keymap.json" line up
    // to its [help] section. Then your keymap.toml and which helper programs are installed.
    Process {
        id: yaziKeys
        command: ["sh", "-c", "y=$(command -v yazi) || exit 0; "
            + "LC_ALL=C sed -n '/^#:schema https:\\/\\/yazi-rs\\.github\\.io\\/schemas\\/keymap\\.json$/,/^\\[help\\]$/p' \"$y\"; "
            + "echo '#==user'; cat \"${YAZI_CONFIG_HOME:-$HOME/.config/yazi}/keymap.toml\" 2>/dev/null; "
            + "echo '#==tools'; for t in fd rg fzf zoxide; do command -v $t >/dev/null && echo $t; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const u = text.indexOf("\n#==user\n");
                const t = text.indexOf("\n#==tools\n");
                if (u < 0 || t < 0 || u === 0) {
                    root.yazi = [];
                    return;
                }
                root.buildYazi(text.slice(0, u), text.slice(u + 9, t), text.slice(t + 10).split("\n"));
            }
        }
    }

    Component.onCompleted: refresh()
}
