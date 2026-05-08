# VPS Deployment (DigitalOcean Ubuntu 24.04)

Target server:
- Public IP: `64.225.102.179`
- Private IP: `10.114.0.2`
- Region: FRA1

This setup keeps LAN/dev flows untouched and adds a dedicated VPS deployment path.

## 1. SSH and base packages

```bash
ssh root@64.225.102.179
apt update && apt upgrade -y
apt install -y git docker.io docker-compose-plugin ufw
systemctl enable --now docker
```

## 2. Firewall

```bash
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
ufw status
```

Only ports `80/443` are exposed publicly. Game/auth/web stay internal to Docker.
Direct public `:8080` is intentionally not exposed.

## 3. Clone repo and configure env

```bash
git clone <repo-url>
cd <repo-folder>
cp .env.example .env
nano .env
```

Set at least:
- `DATABASE_URL=...`
- `KW_NETWORK_TRANSPORT=websocket`
- `KW_GAME_PORT=8080`

## 4. Build and run stack

```bash
docker compose -f docker-compose.vps.yml up -d --build
docker ps
docker logs kw_server --tail 100
docker logs kw_auth_api --tail 100
docker logs kw_public_proxy --tail 100
```

## 5. DNS

Point `play.outrage.ink` to VPS:
- A record: `play` -> `64.225.102.179`

Cloudflare option:
- Start as `DNS only` for testing.
- Later you can enable proxy (orange cloud), but keep WebSocket support enabled.

## 6. Verify routes

Before DNS (raw IP test):

```bash
curl http://64.225.102.179
curl http://64.225.102.179/auth/health
```

WebSocket test before DNS:
- `ws://64.225.102.179/ws` (proxied through Caddy on port 80)

After DNS propagation:

```bash
curl https://play.outrage.ink/auth/health
```

Expected production endpoints:
- Auth: `https://play.outrage.ink/auth`
- WebSocket: `wss://play.outrage.ink/ws`

## 7. Web export/static files

`kw_web` serves files from `updates_site/kw`. Publish your latest web export there before testing browser clients:

```powershell
.\tools\publish_web_export_to_updates_site.ps1 -SourceDir "<web-export-folder>" -TargetDir "updates_site/kw"
```

Required files include:
- `kw.js`
- `kw.wasm`
- `kw.pck`
- `kw.audio.worklet.js`
- `kw.audio.position.worklet.js`

## 8. Architecture (vps compose)

- `kw_public_proxy` (Caddy): public `80/443`
- `kw_web` (nginx): internal `80`
- `kw_auth_api` (FastAPI): internal `8090`
- `kw_server` (Godot WebSocket): internal `8080`

Routing:
- `/ws` -> `kw_server:8080`
- `/auth/*` -> `kw_auth_api:8090` (prefix stripped by `handle_path`)
- `/` -> `kw_web:80`

## 9. Notes for 512 MB RAM VPS

- Current `Dockerfile.server` is heavy (`barichello/godot-ci`) and can consume significant RAM.
- Recommended next optimization: pre-export dedicated server binary and run with a lighter runtime image instead of full CI image.
- Keep only required services running on VPS and avoid opening debug ports.
