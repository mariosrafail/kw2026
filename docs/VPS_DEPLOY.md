# VPS Deployment

Scope: production online runtime on the dedicated VPS.

Host:
- Public IPv4: `64.225.102.179`
- Private IPv4: `10.114.0.2`
- OS: Ubuntu 24.04 LTS
- Repo path on VPS: `/root/kw2026`
- Compose file: `docker-compose.server.remote.yml`

## Architecture

Production traffic goes directly to the VPS:

`Client -> play.outrage.ink -> VPS Caddy -> Docker services`

Services:
- `kw_public_proxy` (Caddy): public `80/443`
- `kw_server` (Godot): internal `8080`, `KW_NETWORK_TRANSPORT=websocket`
- `kw_auth_api` (FastAPI): internal `8090`
- `kw_updates_http` (static web export): internal `80`

Routes:
- `/auth/*` -> `kw_auth_api:8090`, with `/auth` stripped by Caddy
- `/ws*` -> `kw_server:8080`, with `/ws` stripped by Caddy
- `/` -> `kw_updates_http:80`

Cloudflare may be used as the DNS provider only. Do not use a proxy/orange-cloud setting for `play.outrage.ink`, and do not use a Tunnel route for `play.outrage.ink`, `/auth`, or `/ws`. The DNS `A` record for `play.outrage.ink` should point directly to `64.225.102.179`.

## Public Endpoints

Browser and normal production builds:
- Auth: `https://play.outrage.ink/auth`
- WebSocket: `wss://play.outrage.ink/ws`

Native diagnostic direct-IP mode:
- Auth: `http://64.225.102.179/auth`
- WebSocket through Caddy: `ws://64.225.102.179/ws`
- WebSocket direct to Godot, if port `8080` is published: `ws://64.225.102.179:8080`

Browsers served from HTTPS pages must use `wss://`, not `ws://`. Direct-IP HTTP/WS mode is for diagnostics and native builds; browsers can block mixed insecure `http://` or `ws://` requests when the page was loaded over HTTPS.

## Deploy

```bash
cd /root/kw2026
git pull
docker compose -f docker-compose.server.remote.yml down
docker compose -f docker-compose.server.remote.yml up -d --build
docker compose -f docker-compose.server.remote.yml ps
```

Environment is read from the VPS `.env` file. Required values:
- `DATABASE_URL=...`
- `KW_NETWORK_TRANSPORT=websocket`
- `KW_GAME_PORT=8080`

## Logs

```bash
docker logs kw_auth_api --tail 100
docker logs kw_server --tail 100
docker logs kw_public_proxy --tail 100
```

Expected `kw_server` startup:
- `[NET] transport = websocket`
- `[NET] websocket url = ws://0.0.0.0:8080`
- `Server started on port 8080 using websocket`

## Verification

Auth health:

```bash
curl -v https://play.outrage.ink/auth/health
```

Expected result: HTTP `200` with `{"ok":true,...}`.

WebSocket handshake:

```bash
curl -vk \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  -H "Sec-WebSocket-Version: 13" \
  https://play.outrage.ink/ws
```

Expected result: HTTP `101 Switching Protocols`.

Client online logs should include:
- `[AUTH] response code = 200 action=profile`
- `[NET] websocket endpoint = wss://play.outrage.ink/ws`
- `[NET] connected = true`

## Native Direct-IP Profile

For native/exe diagnostics, use a launcher config like:

```json
{
  "update_manifest_url": "http://64.225.102.179/kw/update_manifest.json",
  "auth_api_base_url": "http://64.225.102.179/auth",
  "default_host": "ws://64.225.102.179/ws",
  "default_port": 80
}
```

The production launcher config should use:

```json
{
  "update_manifest_url": "https://play.outrage.ink/kw/update_manifest.json",
  "auth_api_base_url": "https://play.outrage.ink/auth",
  "default_host": "wss://play.outrage.ink/ws",
  "default_port": 443
}
```

## Notes

The dedicated server starts from `res://scenes/server_boot.tscn`, not the UI lobby scene. This keeps the headless server from depending on UI-only resources such as fonts while still using the same runtime networking stack.
