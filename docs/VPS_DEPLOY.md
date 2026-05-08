# VPS Deployment (kw-test-server)

Scope: server-side deployment only (Docker/Caddy/endpoints/docs).  
Host:
- Public IPv4: `64.225.102.179`
- Private IPv4: `10.114.0.2`
- OS: Ubuntu 24.04 LTS
- Region: FRA1
- Repo path on VPS: `/root/kw2026`

## Cloudflare DNS (manual changes)
Set Cloudflare to DNS-only first (no proxy/orange cloud).

Required:
- `A` record
  - Name: `play`
  - Content: `64.225.102.179`
  - Proxy status: `DNS only`

Optional:
- `A` record
  - Name: `updates`
  - Content: `64.225.102.179`
  - Proxy status: `DNS only`

Also remove/disable old Cloudflare Tunnel public hostname routes pointing to local PC for:
- `play.outrage.ink`
- `play.outrage.ink/auth`
- `play.outrage.ink/ws`
- `updates.outrage.ink`
- any other hostname still routing to local machine/tunnel.

## Expected architecture
- `kw_public_proxy` (Caddy): public `80/443`
- `kw_server` (Godot): internal `8080`, `KW_NETWORK_TRANSPORT=websocket`
- `kw_auth_api` (FastAPI): internal `8090`, reads `DATABASE_URL` from env
- `kw_updates_http` (nginx): internal `80` static web/export files

Public endpoints:
- `https://play.outrage.ink`
- `https://play.outrage.ink/auth/health`
- `wss://play.outrage.ink/ws`

## VPS commands (exact flow)
```bash
cd /root/kw2026
git pull
docker compose -f docker-compose.server.remote.yml down
docker system prune -af
docker builder prune -af
docker compose -f docker-compose.server.remote.yml up -d --build
docker ps
docker logs kw_server --tail 100
docker logs kw_auth_api --tail 100
docker logs kw_public_proxy --tail 100
```

## Environment file
Use `.env` on VPS (not committed secrets).  
Reference template in repo: `.env.vps.example`.

Required values:
- `DATABASE_URL=...`
- `KW_NETWORK_TRANSPORT=websocket`
- `KW_GAME_PORT=8080`

## Route behavior
Production domain route:
- `/ws*` -> `kw_server:8080`
- `/auth/*` -> `kw_auth_api:8090` (prefix stripped by Caddy `handle_path`)
- `/` -> `kw_updates_http:80`

Raw IP diagnostics:
- `http://64.225.102.179` is HTTP-only diagnostic routing.
- Do not use `https://64.225.102.179` as success criteria.

If `http://64.225.102.179` redirects to `https://64.225.102.179`, do not use IP for HTTPS testing.  
Use domain HTTPS checks after DNS/tunnel cleanup is complete.

## Test commands
```bash
curl -v http://64.225.102.179/auth/health
curl -v https://play.outrage.ink/auth/health
```

## Success indicators
1. Caddy logs show certificate issuance success for `play.outrage.ink` (after DNS is correct).
2. `curl -v https://play.outrage.ink/auth/health` returns `200`.
3. Game server logs indicate WebSocket server mode, for example:
   - `[NET] transport = websocket`
   - `[NET] websocket url = ws://0.0.0.0:8080`
   - `Server started on port 8080 using websocket`
4. Client ONLINE logs show:
   - `[NET] mode = ONLINE`
   - `[NET] route = VPS dedicated server`
   - `[NET] auth endpoint = https://play.outrage.ink/auth`
   - `[NET] websocket endpoint = wss://play.outrage.ink/ws`

## Notes for 512MB VPS
Current server image (`barichello/godot-ci`) is heavy.  
Recommended next step (without gameplay changes):
- build/export dedicated server binary in CI or local build machine
- run lightweight runtime container on VPS for lower memory footprint.
