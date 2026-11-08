# Easter eggs

Every easter egg hidden in The Line, so nothing is lost and each one stays readable in the code.

| Where | How | What happens | Code |
|---|---|---|---|
| Clock panel | Click today's date in the calendar | The analog clock becomes a binary clock (BCD, HH MM SS), and the top-row clock shows Unix time. Click again to go back. Kept until reboot. | `services/ClockFace.qml`, `modules/tiles/BinaryClock.qml` |
| Laptops only | Plug the charger in, or pull it out | Kira says a line about it on top of the windows of the focused screen ("i've got the power.", "cord cut. we ride on 66%."...), for 5 s. | `shell.qml` (`pluggedLines`, `unpluggedLines`), `services/Voice.qml` (`say`) |
| Workspace ruler | Triple click the active workspace's numeral | The ten numerals turn into 4-bit binary (`0001` … `1010`). Triple click again to go back. Kept until the shell restarts. | `services/Eggs.qml` (`binaryWorkspaces`), `modules/tiles/WorkspaceTile.qml` (`tripleTap`) |
| The line | Be there at 13:37 | The notification pulse runs along the line once, with nothing to announce. | `services/Eggs.qml` |
| The line | Be there at midnight | A single accent tick hangs in the middle of the line for the new day's first minute. | `services/Eggs.qml` (`midnightTick`), `modules/line/Line.qml` |
| The line | Stay up: uptime crosses 1024 minutes, then 2048, 4096… | The number, in binary, on the middle of the line for 8 s: a dash for each 1, a dot for each 0. | `services/Eggs.qml` (`powerOfTwo`), `modules/line/Line.qml` |
| Workspace marker | Leave the computer idle 5 minutes on an empty workspace | The marker blinks "kira" in Morse (-.- .. .-. .-), slowly, once, then goes quiet until the next idle spell. | `services/Eggs.qml` (Morse), `modules/line/Line.qml` |
| Launcher | Type `sudo make me a sandwich`, `rm -rf /` or `whoami` and press Enter | They look like any command to run, but Kira answers instead: "okay.", "nice try.", or your user name typed in binary, then decoded. (`make me a sandwich` without sudo gets told off.) | `services/Eggs.qml` (`command`, `run`) |
| Calendar | Click a week number | The column shows each week's day of the year, and the current week shows today's in binary. Click again to go back. | `services/Eggs.qml` (`dayOfYear`), `modules/tiles/Calendar.qml` |
| The line | Set the volume or brightness to exactly 42% | The gauge leaves a tiny accent tick at 42% for a second. | `modules/line/Line.qml` (`fortyTwo`) |
| Kira's voice | Wait for it: one quote in 25 | The quote types itself in binary first, then resolves into its text, letter by letter. | `services/Voice.qml` (`currentDecode`), `modules/desktop/KiraVoice.qml` (`decode`) |
