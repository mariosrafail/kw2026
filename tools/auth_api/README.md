# Auth API (accounts)

Minimal HTTP API used by the Godot client for `register` / `login` and basic session tokens.

## Setup

1. Create an env var with your Postgres URL:

PowerShell:

```powershell
$env:DATABASE_URL="postgresql://<user>:<password>@<host>/<db>?sslmode=require"
```

2. Install deps (Python 3.10+ recommended):

```powershell
python -m pip install -r tools/auth_api/requirements.txt
```

3. Run:

```powershell
python tools/auth_api/app.py
```

Server listens on `http://127.0.0.1:8090` by default.

## Endpoints

- `GET /health`
- `POST /register` `{ "email": "...", "username": "...", "password": "..." }`
- `POST /login` `{ "username": "...", "password": "...", "force": false }` or `{ "email": "...", "password": "...", "force": false }`
- `GET /me` with header `Authorization: Bearer <token>`
- `POST /logout` with header `Authorization: Bearer <token>` (deletes the current session token)
- `GET /profile` with header `Authorization: Bearer <token>` (returns wallet + owned skins)
- `POST /purchase/skin` `{ "character_id": "outrage", "skin_index": 12 }` with header `Authorization: Bearer <token>`
- `POST /wallet/update` `{ "coins": 9800, "clk": 9999 }` with header `Authorization: Bearer <token>` (updates wallet and returns fresh profile)
