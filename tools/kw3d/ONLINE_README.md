# KW 3D online foundation

Full guide: `docs/design/kw_multiplayer_sandbox_2026-09-19/06_IMPLEMENTATION_STATUS.md`.

Open `res://scenes/prototypes/kw_3d_multiplayer.tscn` and run F6.
For two local clients, run `Play_Online_Two_Clients.cmd` in this directory.
The original solo scene remains `res://scenes/prototypes/kw_3d_prototype.tscn`.

Trusted-LAN prototype only. Local helper binds 127.0.0.1:18886 by default.
No public matchmaking, console export or cloud hosting is configured.
Esc / Start opens settings. G / RB / R1 throws the server-owned grenade.
Settings and rebinding are available from the network menu.
