# Demo video runner

Drives the desktop for the presentation video and films it (`wf-recorder`). Captions and the pressed keys are drawn by
the shell itself (`services/Demo.qml`, `modules/demo/`), so they are in the recording: nothing to edit in.

    run.py demo.script --dry-run        the estimated length, nothing touched (the video must stay under 2 minutes)
    run.py demo.script --list           the scenes
    run.py demo.script --no-record      rehearse on the screen
    run.py demo.script                  film everything  ->  ~/Videos/the-line-demo/demo-takeNN.mp4 (+ .timeline.txt)
    run.py demo.script --scene 3,4      film only these scenes (each one is a restart point)

- The script language is described at the top of `demo.script`. Every pause there is short on purpose.
- Run it from a terminal of the filmed session (it uses `hyprctl`, `wtype`, `qs`, `wf-recorder`, `playerctl`).
- Shortcuts are sent by name (`key SUPER+N`), not typed: Hyprland ignores Super from a virtual keyboard. The table
  is `shortcut()` in `run.py`; a new combo is one line.
- The window shortcuts (`SUPER+Q`, `SUPER+F`...) only act on windows the script opened: yours are never touched.
- The take uses workspaces 3, 5 and 8 of the filmed screen (made there on demand): they must not exist on another screen.
- Before a take: music player ready (paused), nothing private on screen, the default wallpaper if wanted.
- The run ends on the workspace it started on; the timeline file lists the real length of each scene and the cut points.

Not there (yet): clicking (the settings pages are opened by name), a lock / login scene (it needs a real password).
