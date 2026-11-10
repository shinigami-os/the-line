#!/usr/bin/env python3
"""Drives the desktop for The Line's demo video, and films it.

    run.py demo.script                  record the whole script (about two minutes)
    run.py demo.script --scene 3,4      record only these scenes (each is a restart point)
    run.py demo.script --no-record      rehearse on the screen, no recording
    run.py demo.script --dry-run        print the timeline and the estimated length, touch nothing
    run.py demo.script --list           the scenes

The script (demo.script) is one command per line, see the header of that file. Captions and the pressed keys are drawn
by the shell itself (services/Demo.qml), so they are in the recording: no editing needed. Run it from a terminal on
the session that is filmed; stop with Ctrl+C (the recording is closed properly).
"""

import argparse
import glob
import json
import os
import random
import shlex
import signal
import socket
import subprocess
import sys
import threading
import time

HOME = ["1"]   # the workspace every run starts on (`home` in the script)
SHELL_DIR = os.environ.get("THE_LINE_DIR", "/usr/share/the-line")
FLATPAK = os.path.exists("/.flatpak-info")   # a sandboxed terminal (VS Code): reach the host's tools


def host(cmd):
    return ["flatpak-spawn", "--host"] + cmd if FLATPAK else cmd


def sh(cmd, **kw):
    return subprocess.run(host(cmd), capture_output=True, text=True, **kw)


# ---------------------------------------------------------------------------------------------- Hyprland and the shell

_sock = None


def hypr(message):
    """One request to Hyprland's socket (fast enough for a pointer move every frame). None if it can't be reached."""
    global _sock
    if FLATPAK:
        return None
    if _sock is None:
        run_dir = os.environ.get("XDG_RUNTIME_DIR", "/run/user/%d" % os.getuid())
        found = sorted(glob.glob(run_dir + "/hypr/*/.socket.sock"), key=os.path.getmtime)
        _sock = found[-1] if found else ""
    if not _sock:
        return None
    s = socket.socket(socket.AF_UNIX)
    try:
        s.connect(_sock)
        s.send(message.encode())
        return s.recv(65536).decode()
    finally:
        s.close()


def dispatch(expr):
    if hypr("/dispatch " + expr) is None:
        sh(["hyprctl", "dispatch", expr])


def clients():
    out = sh(["hyprctl", "clients", "-j"]).stdout
    return json.loads(out) if out.strip() else []


def monitor(name):
    mons = json.loads(sh(["hyprctl", "monitors", "-j"]).stdout)
    for m in mons:
        if m["name"] == name:
            return m
    raise SystemExit("no screen called %s (hyprctl monitors)" % name)


def ipc_out(*args):
    return sh(["qs", "-p", SHELL_DIR, "ipc", "call", "line"] + [str(a) for a in args]).stdout.strip()


def ydotoold():
    """The mouse button (ydotool) needs its daemon: start it if it is not running."""
    if sh(["pgrep", "-x", "ydotoold"]).returncode != 0:
        subprocess.Popen(host(["ydotoold"]), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        time.sleep(0.8)


def ipc(*args):
    sh(["qs", "-p", SHELL_DIR, "ipc", "call", "line"] + [str(a) for a in args])


# ---------------------------------------------------------------------------------------------- the shortcuts

ARROWS = {"LEFT": "left", "RIGHT": "right", "UP": "up", "DOWN": "down"}
GLOBALS = {"N": "notifications", "A": "quicksettings", "P": "performance", "F1": "cheatsheet", "V": "clipboard",
           "T": "wallpapers", "M": "visualiser", ";": "emoji", "L": "lock"}
WS_KEYS = {str(n % 10): n for n in range(1, 11)}


def shortcut(combo):
    """What a Hyprland bind (session/hyprland.lua) does, as a function: wtype can't press Super for the compositor.
    Returns a callable, or None for a combo it doesn't know."""
    parts = combo.upper().split("+")
    mods, key = set(parts[:-1]), parts[-1]
    if mods == {"SUPER"}:
        if key in GLOBALS:
            return lambda: dispatch('hl.dsp.global("the-line:%s")' % GLOBALS[key])
        if key == "I":
            return lambda: sh([SHELL_DIR + "/session/the-line-settings"])
        if key == "F":
            return lambda: dispatch("hl.dsp.window.fullscreen()")
        if key == "Q":
            return lambda: dispatch("hl.dsp.window.close()")
        if key == "R":
            return lambda: dispatch('hl.dsp.submap("resize")')
        if key == "Y":
            return lambda: dispatch('hl.dsp.layout("togglesplit")')
        if key in ARROWS:
            return lambda: dispatch('hl.dsp.focus({ direction = "%s" })' % ARROWS[key])
        if key in WS_KEYS:
            return lambda: dispatch("hl.dsp.focus({ workspace = %d })" % WS_KEYS[key])
    if mods == {"SUPER", "SHIFT"} and key in ARROWS:
        return lambda: dispatch('hl.dsp.window.move({ direction = "%s" })' % ARROWS[key])
    if mods == {"SUPER", "ALT"} and key == "SPACE":
        return lambda: ipc("toggleFloat")
    if mods == {"SUPER", "SHIFT"} and key in WS_KEYS:
        return lambda: dispatch("hl.dsp.window.move({ workspace = %d, follow = true })" % WS_KEYS[key])
    return None


# These act on the focused window: only ever on a window the script opened (never on yours).
WINDOW_KEYS = {"SUPER+R", "SUPER+Q", "SUPER+F", "SUPER+Y", "SUPER+SHIFT+LEFT", "SUPER+SHIFT+RIGHT", "SUPER+SHIFT+UP",
               "SUPER+SHIFT+DOWN", "SUPER+ALT+SPACE"}
KEY_LABELS = {"RETURN": "ENTER", "ESCAPE": "ESC", "BACKSPACE": "BKSP", "SPACE": "SPACE"}


# ---------------------------------------------------------------------------------------------- the script

class Step:
    def __init__(self, line_no, verb, args):
        self.line_no, self.verb, self.args = line_no, verb, args


class Scene:
    def __init__(self, number, title, target):
        self.number, self.title, self.target, self.steps = number, title, target, []


def parse(path):
    scenes, scene = [], None
    for n, raw in enumerate(open(path, encoding="utf-8"), 1):
        lexer = shlex.shlex(raw, posix=True)
        lexer.whitespace_split = True
        lexer.commenters = "#"
        try:
            words = list(lexer)
        except ValueError as e:
            raise SystemExit("%s:%d: %s" % (path, n, e))
        if not words:
            continue
        verb, args = words[0], words[1:]
        if verb == "home":
            HOME[0] = args[0]
        elif verb == "scene":
            scene = Scene(int(args[0]), args[1], float(args[2]) if len(args) > 2 else 0)
            scenes.append(scene)
        elif scene is None:
            raise SystemExit("%s:%d: a command before the first `scene`" % (path, n))
        else:
            scene.steps.append(Step(n, verb, args))
    return scenes


def estimate(step):
    """Seconds a step takes (for --dry-run and the report)."""
    v, a = step.verb, step.args
    if v == "wait":
        return float(a[0])
    if v == "type":
        return 0.25 + 0.075 * len(a[0])
    if v == "glide":
        return int(a[2]) / 1000
    if v == "drag-window":
        return 2.1 + int(a[2]) / 1000
    if v == "hold-pointer-top":
        return 0.5 + int(a[0]) / 1000
    if v.startswith("run") or v == "settings":
        return 1.3
    if v == "reset":
        return 1.0
    if v in ("key", "press", "tap-super", "double-tap-super"):
        return 0.25
    return 0.05


# ---------------------------------------------------------------------------------------------- the runner

class Runner:
    def __init__(self, screen):
        self.screen = screen
        self.mon = monitor(screen)
        self.owned = set()          # addresses of the windows the script opened (reset closes only those)
        self.t0 = time.time()
        self.log = []               # (seconds, kind, text)

    def now(self):
        return time.time() - self.t0

    def note(self, kind, text):
        self.log.append((self.now(), kind, text))

    # keys and the key display
    def show_keys(self, label):
        ipc("keys", label)

    def keys(self, combo):
        act = shortcut(combo)
        if act is None:
            raise SystemExit("don't know the shortcut %s (run.py: shortcut())" % combo)
        if combo.upper() in WINDOW_KEYS and not self.focused_is_ours():
            print("  (skipped %s: the focused window is not one the script opened)" % combo, file=sys.stderr)
            return
        self.show_keys(combo.upper())
        act()

    def focused_is_ours(self):
        out = sh(["hyprctl", "activewindow", "-j"]).stdout
        try:
            return json.loads(out).get("address") in self.owned
        except ValueError:
            return False

    def press(self, name):
        self.show_keys(KEY_LABELS.get(name.upper(), name.upper()))
        sh(["wtype", "-k", name])

    def mouse(self, state):
        sh(["ydotool", "click", "0x40" if state == "down" else "0x80"])

    def drag_window(self, src, dst, ms):
        """In the workspace overview: take the first window of workspace src and drop it on workspace dst."""
        ydotoold()
        a = ipc_out("overviewPoint", self.screen, src, 0)
        b = ipc_out("overviewPoint", self.screen, dst, -1)
        if not a or not b:
            print("  (drag-window: the overview is not open, or has no window on workspace %s)" % src, file=sys.stderr)
            return
        x0, y0 = [int(v) for v in a.split(",")]
        x1, y1 = [int(v) for v in b.split(",")]
        self.glide(x0, y0, 600)
        time.sleep(0.3)
        self.mouse("down")
        time.sleep(0.15)
        self.glide(x0 + 10, y0 + 6, 120)   # past the drag threshold
        self.glide(x1, y1, ms)
        time.sleep(0.5)                     # the target cell lit
        self.mouse("up")
        time.sleep(0.4)

    def resize(self, direction, steps):
        """The resize mode's arrow keys (40 px a step, as in session/hyprland.lua), one step at a time."""
        dx, dy = {"left": (-40, 0), "right": (40, 0), "up": (0, -40), "down": (0, 40)}[direction]
        self.show_keys({"left": "←", "right": "→", "up": "↑", "down": "↓"}[direction])
        for _ in range(steps):
            dispatch("hl.dsp.window.resize({ x = %d, y = %d, relative = true })" % (dx, dy))
            time.sleep(0.07)

    def notify_later(self, low, high, title, bodies):
        """A notification at a random moment in the next low..high seconds, whatever the scene is doing then."""
        delay = random.uniform(low, high)
        threading.Timer(delay, lambda: ipc("notify", "The Line", title, random.choice(bodies))).start()

    def type(self, text):
        sh(["wtype", "-d", "75", text])

    # the pointer
    def pointer(self):
        out = hypr("j/cursorpos") if not FLATPAK else sh(["hyprctl", "cursorpos", "-j"]).stdout
        p = json.loads(out)
        return p["x"], p["y"]

    def move(self, x, y):
        dispatch("hl.dsp.cursor.move({x=%d,y=%d})" % (round(x), round(y)))

    def glide(self, x, y, ms):
        """To x,y of the filmed screen in ms, eased, one step per frame."""
        x0, y0 = self.pointer()
        x1, y1 = self.mon["x"] + x, self.mon["y"] + y
        steps = max(1, int(ms / 1000 * 60))
        for i in range(1, steps + 1):
            t = i / steps
            e = t * t * (3 - 2 * t)
            self.move(x0 + (x1 - x0) * e, y0 + (y1 - y0) * e)
            time.sleep(ms / 1000 / steps)

    # windows
    def goto(self, ws):
        """A workspace on the filmed screen (focus the screen first: a new workspace is made on the focused one)."""
        dispatch('hl.dsp.focus({ monitor = "%s" })' % self.screen)
        dispatch("hl.dsp.focus({ workspace = %s })" % ws)

    def launch(self, ws, command):
        if ws:
            self.goto(ws)
            time.sleep(0.35)
        before = {c["address"] for c in clients()}
        subprocess.Popen(host(command), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        for _ in range(40):
            time.sleep(0.15)
            new = {c["address"] for c in clients()} - before
            if new:
                self.owned |= new
                time.sleep(0.45)    # its opening animation
                return
        print("  (no new window for %s)" % " ".join(command), file=sys.stderr)

    def active_workspace(self):
        for m in json.loads(sh(["hyprctl", "monitors", "-j"]).stdout):
            if m["name"] == self.screen:
                return m["activeWorkspace"]["id"]
        return 1

    def reset(self, ws="1"):
        ipc("close")
        for c in clients():
            if c["address"] in self.owned or c["class"] == "the-line-settings":
                dispatch('hl.dsp.window.close({ window = "address:%s" })' % c["address"])
        self.owned.clear()
        time.sleep(0.5)
        self.goto(ws)
        self.move(self.mon["x"] + self.mon["width"] / 2, self.mon["y"] + self.mon["height"] / 2)
        time.sleep(0.4)

    # one command
    def do(self, step):
        v, a = step.verb, step.args
        if v == "wait":
            time.sleep(float(a[0]))
        elif v == "caption":
            ipc("caption", a[0], a[1] if len(a) > 1 else 3)
        elif v == "keycast":
            ipc("keycast", "true" if a[0] == "on" else "false")
        elif v == "key":
            self.keys(a[0])
        elif v == "tap-super":
            self.show_keys("SUPER")
            ipc("toggleFocused", "tl")
        elif v == "double-tap-super":
            self.show_keys("SUPER ×2")
            ipc("overview")
        elif v == "type":
            self.type(a[0])
        elif v == "press":
            self.press(a[0])
        elif v == "drag-window":
            self.drag_window(a[0], a[1], int(a[2]))
        elif v == "resize":
            if self.focused_is_ours():
                self.resize(a[0], int(a[1]))
        elif v == "resize-end":
            self.show_keys("ESC")
            dispatch('hl.dsp.submap("reset")')
        elif v == "notify-later":
            self.notify_later(float(a[0]), float(a[1]), a[2], a[3:])
        elif v == "ws":
            self.show_keys("SUPER+" + ("0" if a[0] == "10" else a[0]))
            self.goto(a[0])
        elif v == "run" or v.startswith("run@"):
            self.launch(v[4:], a)
        elif v == "settings":
            # (the launcher script stays in the foreground when it has to start the app: don't wait for it)
            opened = any(c["class"] == "the-line-settings" for c in clients())
            subprocess.Popen(host([SHELL_DIR + "/session/the-line-settings", a[0]]), stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
            time.sleep(0.9 if opened else 2.2)
        elif v == "ipc":
            ipc(*a)
        elif v == "shell":
            sh(["sh", "-c", " ".join(a)])
        elif v == "glide":
            self.glide(float(a[0]), float(a[1]), int(a[2]))
        elif v == "hold-pointer-top":
            x, _ = self.pointer()
            self.glide(x - self.mon["x"], 0, 500)
            time.sleep(int(a[0]) / 1000)
        elif v == "mark":
            self.note("mark", a[0])
        elif v == "reset":
            self.reset(a[0] if a else "1")
        else:
            raise SystemExit("line %d: unknown command %s" % (step.line_no, v))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("script")
    ap.add_argument("--scene", help="only these scenes, e.g. 3 or 3,4")
    ap.add_argument("--screen", default=None, help="the filmed screen (default: Config primaryScreen, else the focused one)")
    ap.add_argument("--out", default=os.path.expanduser("~/Videos/the-line-demo"))
    ap.add_argument("--max", type=float, default=120, help="the length the whole thing must stay under, seconds")
    ap.add_argument("--no-record", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--countdown", type=int, default=3)
    opts = ap.parse_args()

    scenes = parse(opts.script)
    if opts.list:
        for s in scenes:
            print("%2d  %-28s target %3.0fs  %2d commands" % (s.number, s.title, s.target, len(s.steps)))
        return
    if opts.scene:
        wanted = {int(n) for n in opts.scene.split(",")}
        scenes = [s for s in scenes if s.number in wanted]
        if not scenes:
            raise SystemExit("no such scene")

    if opts.dry_run:
        total = 0
        for s in scenes:
            est = sum(estimate(st) for st in s.steps)
            total += est
            print("%2d  %-28s about %5.1fs (target %3.0fs)%s" % (s.number, s.title, est, s.target,
                                                                "   <- over" if s.target and est > s.target * 1.1 else ""))
        print("    %-28s about %5.1fs (limit %.0fs)%s" % ("TOTAL", total, opts.max, "   <- TOO LONG" if total > opts.max else ""))
        return

    config = os.path.expanduser("~/.config/the-line/config.json")
    screen = opts.screen or (json.load(open(config)).get("primaryScreen") if os.path.exists(config) else "") or None
    if not screen:
        screen = [m for m in json.loads(sh(["hyprctl", "monitors", "-j"]).stdout) if m["focused"]][0]["name"]
    runner = Runner(screen)
    back = runner.active_workspace()    # where the user was: the run ends there

    recorder = None
    name = "demo" if not opts.scene else "scenes-" + opts.scene.replace(",", "-")
    os.makedirs(opts.out, exist_ok=True)
    take = 1
    while glob.glob("%s/%s-take%02d.*" % (opts.out, name, take)):
        take += 1
    base = "%s/%s-take%02d" % (opts.out, name, take)

    print("filming %s (%dx%d), scenes %s" % (screen, runner.mon["width"], runner.mon["height"], [s.number for s in scenes]))
    for i in range(opts.countdown, 0, -1):
        print("  starting in %d..." % i, end="\r", flush=True)
        time.sleep(1)
    ipc("keycast", "true")
    runner.reset(HOME[0])
    if not opts.no_record:
        recorder = subprocess.Popen(host(["wf-recorder", "-o", screen, "-r", "60", "-x", "yuv420p", "-p", "preset=veryfast",
                                          "-p", "crf=17", "-f", base + ".mp4"]), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(1.2)

    runner.t0 = time.time()
    report = []
    try:
        for s in scenes:
            start = runner.now()
            runner.note("scene", "%d %s" % (s.number, s.title))
            print("== %d. %s" % (s.number, s.title))
            for st in s.steps:
                runner.do(st)
            report.append((s, runner.now() - start))
    except KeyboardInterrupt:
        print("\nstopped")
    finally:
        if recorder:
            sh(["pkill", "-INT", "-x", "wf-recorder"])
            recorder.wait(timeout=20)
        dispatch('hl.dsp.submap("reset")')
        runner.reset(str(back))

    total = sum(d for _, d in report)
    lines = ["%2d  %-28s %6.1fs  (target %3.0fs)" % (s.number, s.title, d, s.target) for s, d in report]
    lines.append("    %-28s %6.1fs  (limit %.0fs)%s" % ("TOTAL", total, opts.max, "   TOO LONG" if total > opts.max else ""))
    lines += ["", "cut points"] + ["%7.1fs  %s  %s" % (t, k, x) for t, k, x in runner.log]
    print("\n".join(lines))
    with open(base + ".timeline.txt", "w") as f:
        f.write("\n".join(lines) + "\n")
    if recorder:
        print("\n" + base + ".mp4")


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    main()
