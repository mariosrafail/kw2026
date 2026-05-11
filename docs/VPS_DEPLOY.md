# VPS Deployment

Scope: production online runtime on the DigitalOcean VPS using the public IP directly.

Host:
- Public IPv4: `64.225.102.179`
- Private IPv4: `10.114.0.2`
- OS: Ubuntu 24.04 LTS
- Repo path on VPS: `/root/kw2026`
- Compose file: `docker-compose.server.remote.yml`

## Architecture

Production traffic goes directly to the VPS:

`Client -> 64.225.102.179 -> VPS Caddy -> Docker services`

Services:
- `kw_public_proxy` (Caddy): public `80`
- `kw_server` (Godot): public UDP `8080`, `KW_NETWORK_TRANSPORT=enet`
- `kw_auth_api` (FastAPI): internal `8090`
- `kw_updates_http` (static web export): internal `80`

Routes:
- `/auth/*` -> `kw_auth_api:8090`, with `/auth` stripped by Caddy
- Native gameplay connects directly to UDP `64.225.102.179:8080`
- `/` -> `kw_updates_http:80`

No domain, Cloudflare, DDNS, or TLS is required for the native launcher profile.

## Public Endpoints

Native production build:
- Auth: `http://64.225.102.179/auth`
- Game: `enet://64.225.102.179:8080` (Godot ENet/UDP)
- Updates: `http://64.225.102.179/kw/update_manifest.json`

The web build must be served over HTTP when using `ws://` and `http://`. Browsers loaded from an HTTPS page will block these insecure endpoints.

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
- `KW_NETWORK_TRANSPORT=enet`
- `KW_GAME_PORT=8080`

## Logs

```bash
docker logs kw_auth_api --tail 100
docker logs kw_server --tail 100
docker logs kw_public_proxy --tail 100
```

Expected `kw_server` startup:
- `Server started on port 8080 using enet`

## Verification

Auth health:

```bash
curl -v http://64.225.102.179/auth/health
```

Expected result: HTTP `200` with `{"ok":true,...}`.

Client online logs should include:
- `[AUTH] response code = 200 action=profile`
- `[NET] enet endpoint = 64.225.102.179:8080`
- `[NET] connected = true`

## Launcher Config

Use:

```json
{
  "update_manifest_url": "http://64.225.102.179/kw/update_manifest.json",
  "auth_api_base_url": "http://64.225.102.179/auth",
  "default_host": "64.225.102.179",
  "default_port": 8080
}
```

## Notes

The dedicated server starts from `res://scenes/server_boot.tscn`, not the UI lobby scene. This keeps the headless server from depending on UI-only resources such as fonts while still using the same runtime networking stack.
