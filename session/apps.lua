-- Your app keys. This file is yours: The Line and its updates never overwrite it.
hl.bind("SUPER+Return", hl.dsp.exec_cmd("foot"), { desc = "Apps: Terminal" })
hl.bind("SUPER+E", hl.dsp.exec_cmd("foot --app-id=yazi yazi"), { desc = "Apps: Files (yazi)" })
hl.bind("SUPER+SHIFT+E", hl.dsp.exec_cmd("xdg-open \"$HOME\""), { desc = "Apps: Default file manager" })
