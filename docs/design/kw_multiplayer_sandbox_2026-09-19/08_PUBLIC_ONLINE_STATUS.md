# KW 3D Public Online Status

Date: 2026-09-19
Current published build: alpha-0.1.38

## Public entry
- Portal / updater: https://portal-fresh-pleasant-peoples.trycloudflare.com/
- Public gameplay: wss://portal-fresh-pleasant-peoples.trycloudflare.com/game
- No router port forwarding is used.
- This is a Cloudflare Quick Tunnel. The hostname is temporary and can change if the tunnel process restarts.

## Main game flow
1. F5 / retail launch opens res://scenes/ui/main_menu.tscn.
2. The original main menu visual design, intro, hover animations and I HATE THIS GAME UI are retained.
3. FIGHT uses the original expand transition.
4. The original animated warrior-face loading overlay appears.
5. The game opens the 3D online room browser.
6. CREATE ROOM connects the first player to the public authority and makes that player host.
7. JOIN ROOM connects the second player.
8. Both Ready, host Start Match, first to 10 kills.

## Server stack
Docker compose: docker-compose.kw3d-lan.yml

Services:
- kw_3d_duel_server: ENet LAN fallback on UDP 18886
- kw_3d_duel_ws: WebSocket authority server on TCP 18887
- kw_lan_portal: nginx/update portal on TCP 8082
- nginx proxies /game to kw_3d_duel_ws:18887 with WebSocket upgrade headers.

Cloudflare Quick Tunnel currently runs on the host and exposes nginx :8082 over HTTPS/WSS.

## Verification
Verified with two exported retail kw.exe clients:
- both started at the real main_menu.tscn
- FIGHT -> loading -> 3D flow
- both connected through the public WSS Cloudflare URL
- both reached the same MATCH
- host actor 1, player 2 actor 2
- RTT observed in final exported QA: ~42ms and ~25ms

The updater independently resolves the public HTTPS manifest and verifies kw.exe and kw.pck SHA-256 hashes.

## Publishing
For the currently active public URL:
tools/Publish_KW_Online.ps1

You can pass another tunnel URL:
powershell -ExecutionPolicy Bypass -File tools/Publish_KW_Online.ps1 -PublicBaseUrl "https://NEW.trycloudflare.com"

Because a Quick Tunnel URL is temporary, if it changes the project must be republished so the exported client and updater point to the new WSS/HTTPS endpoint.
