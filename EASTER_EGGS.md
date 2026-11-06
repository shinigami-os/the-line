# Easter eggs

Every easter egg hidden in The Line, so nothing is lost and each one stays readable in the code.

| Where | How | What happens | Code |
|---|---|---|---|
| Clock panel | Click today's date in the calendar | The analog clock becomes a binary clock (BCD, HH MM SS), and the top-row clock shows Unix time. Click again to go back. Kept until reboot. | `services/ClockFace.qml`, `modules/tiles/BinaryClock.qml` |
