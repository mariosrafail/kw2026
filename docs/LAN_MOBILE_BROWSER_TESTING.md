# LAN Mobile Browser Testing (HTTPS/WSS)

## Why this setup exists
- Browsers cannot act as raw WebSocket listen servers for multiplayer hosting.
- Godot Web clients are browser clients only.
- Mobile browsers require a secure context for reliable Web features.
- If the page is HTTPS, browser will block insecure `http://` and `ws://` targets.

For LAN browser testing, the PC should run the game server. Phones/tablets join as clients.

## Target architecture
- Page: `https://LAN_IP:9000/kw.html`
- Auth: `https://LAN_IP:9000/auth`
- WebSocket: `wss://LAN_IP:9000/ws`

All are same-origin through a local HTTPS reverse proxy (Caddy).

## Files
- Compose stack: `docker-compose.lan-https.local.yml`
- Caddy config: `Caddyfile.lan-https.local`

## Prerequisites
1. Build/export your Godot Web build into a folder containing:
   - `kw.html` (or `index.html`)
   - runtime `.js`
   - `.wasm`
   - `.pck`
2. Set `KW_LAN_IP` to your PC LAN IP (for example `192.168.1.5`).
3. Optionally set `WEB_EXPORT_DIR` (defaults to `./build/web`).

## Run
```powershell
$env:KW_LAN_IP = "192.168.1.5"
$env:WEB_EXPORT_DIR = "./build/web"
docker compose -f docker-compose.lan-https.local.yml up -d --build
```

Open on phone:
- `https://192.168.1.5:9000/kw.html`

## Certificate trust note (important)
This setup uses `tls internal` (Caddy local CA).  
For a true secure context on mobile browsers, trust Caddy's root CA on the phone.

You can copy CA from the Caddy data volume:
- `/data/caddy/pki/authorities/local/root.crt`

If the cert is not trusted, browser may show security warnings and secure-context behavior can be limited.

## Expected game networking in LAN mode
- Auth login goes to: `https://LAN_IP:9000/auth/login`
- WebSocket connect goes to: `wss://LAN_IP:9000/ws`
- Host server remains PC-side `kw_server` (not browser-hosted).

The game selects these LAN endpoints automatically when:
- page protocol is HTTPS
- page hostname is private LAN IP (`192.168.x.x`, `10.x.x.x`, `172.16-31.x.x`) or localhost.

## Stop
```powershell
docker compose -f docker-compose.lan-https.local.yml down
```
