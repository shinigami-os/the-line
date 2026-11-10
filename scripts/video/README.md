# Demo video runner

Drives the desktop for the presentation video and films it (`wf-recorder`). Captions and the pressed keys are drawn by
the shell itself (`services/Demo.qml`, `modules/demo/`), so they are in the recording: nothing to edit in.

    run.py demo.script --dry-run        the estimated length, nothing touched (the video must stay under 2 minutes)
    run.py demo.script --list           the scenes
    run.py demo.script --no-record      rehearse on the screen
    run.py demo.script                  film everything  ->  ~/Videos/the-line-demo/demo-takeNN.mp4 (+ .timeline.txt)
    run.py demo.script --scene 3,4      film only these scenes (each one is a restart point)

- **It starts the recording itself.** In a terminal: `python3 ~/Documents/Kira-Linux/the-line/scripts/video/run.py ~/Documents/Kira-Linux/the-line/scripts/video/demo.script`
  (3 s countdown, then `wf-recorder` on the primary screen, then the scenes, then it stops and prints the timeline). The terminal can be on
  another screen: the runner takes the keyboard on the filmed screen while it runs, so to stop it early use `pkill -INT -f video/run.py`
  from anywhere (Ctrl+C in its terminal would go nowhere: that terminal does not have the keyboard).
- Music: `playerctl play` is the first command of the video and `playerctl pause` the last (nothing else touches the player).
- The script language is described at the top of `demo.script`. Every pause there is short on purpose.
- Run it from a terminal of the filmed session (it uses `hyprctl`, `wtype`, `qs`, `wf-recorder`, `playerctl`).
- Shortcuts are sent by name (`key SUPER+N`), not typed: Hyprland ignores Super from a virtual keyboard. The table
  is `shortcut()` in `run.py`; a new combo is one line.
- The window shortcuts (`SUPER+Q`, `SUPER+F`...) only act on windows the script opened: yours are never touched.
- The take uses workspaces 3, 5 and 8 of the filmed screen (made there on demand): they must not exist on another screen.
- `drag-window` (the workspace overview scene) holds the mouse button with `ydotool`; the runner starts `ydotoold` if it is not
  running (your user needs access to /dev/uinput). The shell tells the runner where the thumbnails are (`qs ipc call line overviewPoint`).
- Before a take: music player ready (paused), nothing private on screen, the default wallpaper if wanted.
- The run ends on the workspace it started on; the timeline file lists the real length of each scene and the cut points.

Not there (yet): clicking (the settings pages are opened by name), a lock / login scene (it needs a real password).
