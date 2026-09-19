# KW 3D LAN distribution status

Date: 2026-09-19
Current build: alpha-0.1.33

## Runtime
- F5 / retail main scene: res://scenes/prototypes/kw_3d_lan_duel.tscn
- LAN duel: two players, Ready/Start flow, first to 10 kills.
- Dedicated Docker server: UDP 18886.
- LAN portal: http://192.168.1.154:8082/
- Existing legacy Python update server on 8081 is intentionally left untouched.

## Portable updater
- Source: tools/updater/kw_updater.py
- Built file: build/updater/KWUpdater.exe
- Web copy: updates_site/kw/KWUpdater.exe
- The updater is a single self-contained Windows EXE. It does not require .NET or Python on the target PC.
- It compares SHA-256 for kw.exe and kw.pck independently and downloads only changed files.
- Verified alpha-0.1.32 -> alpha-0.1.33: kw.exe unchanged, only kw.pck downloaded (34,059,572 bytes).

## Docker
- Compose: docker-compose.kw3d-lan.yml
- Game server image definition: Dockerfile.kw3d_server
- Portal nginx config: updates_site/nginx/kw_lan_portal.conf
- Start: tools/kw3d/Start_KW_LAN_Stack.cmd
- Stop: tools/kw3d/Stop_KW_LAN_Stack.cmd

## Publishing the next LAN build
1. Change CLIENT_VERSION in scripts/main.gd.
2. Run tools/Publish_KW_LAN.ps1.
3. The script exports Windows, publishes the manifest/files, copies the portable updater, ensures Docker is running, and restarts the game server.

## Public internet
This setup is intentionally LAN-only. No router port-forwarding or Cloudflare Tunnel is configured yet.
