# Easter eggs

Every easter egg hidden in The Line, so nothing is lost and each one stays readable in the code.

| Where | How | What happens | Code |
|---|---|---|---|
| Clock panel | Click today's date in the calendar | The analog clock becomes a binary clock (BCD, HH MM SS), and the top-row clock shows Unix time. Click again to go back. Kept until reboot. | `services/ClockFace.qml`, `modules/tiles/BinaryClock.qml` |
| Laptops only | Plug the charger in, or pull it out | Kira says a line about it on top of the windows of the focused screen ("i've got the power.", "cord cut. we ride on 66%."...), for 5 s. | `shell.qml` (`pluggedLines`, `unpluggedLines`), `services/Voice.qml` (`say`) |
