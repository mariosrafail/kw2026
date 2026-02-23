import os
import re
import secrets
import uuid
import logging
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Optional

import bcrypt
import psycopg
from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel


USERNAME_RE = re.compile(r"^[A-Za-z0-9_]{3,16}$")


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


@dataclass(frozen=True)
class Settings:
    database_url: str
    listen_host: str
    listen_port: int
    session_ttl_hours: int


def _load_settings() -> Settings:
    database_url = os.environ.get("DATABASE_URL", "").strip()
    if not database_url:
        raise RuntimeError("DATABASE_URL is required")
    return Settings(
        database_url=database_url,
        listen_host=os.environ.get("AUTH_API_HOST", "127.0.0.1").strip() or "127.0.0.1",
        listen_port=int(os.environ.get("AUTH_API_PORT", "8090")),
        session_ttl_hours=int(os.environ.get("AUTH_API_SESSION_TTL_HOURS", "168")),
    )


SETTINGS = _load_settings()

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("kw-auth-api")

app = FastAPI(title="kw auth api", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _db():
    return psycopg.connect(SETTINGS.database_url, autocommit=True)


def _init_schema() -> None:
    with _db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                create table if not exists accounts (
                  id uuid primary key,
                  username text not null unique,
                  password_hash text not null,
                  created_at timestamptz not null default now()
                );
                """
            )
            cur.execute(
                """
                create table if not exists sessions (
                  token text primary key,
                  account_id uuid not null references accounts(id) on delete cascade,
                  created_at timestamptz not null default now(),
                  expires_at timestamptz not null
                );
                """
            )
            cur.execute("create index if not exists sessions_account_id_idx on sessions(account_id);")
            cur.execute("create index if not exists sessions_expires_at_idx on sessions(expires_at);")
            # Cleanup any expired sessions.
            cur.execute("delete from sessions where expires_at <= now();")
            # Allow multiple active sessions per account.
            cur.execute("drop index if exists sessions_one_per_account_uidx;")
            cur.execute(
                """
                create table if not exists wallets (
                  account_id uuid primary key references accounts(id) on delete cascade,
                  coins integer not null default 0,
                  clk integer not null default 0,
                  updated_at timestamptz not null default now()
                );
                """
            )
            cur.execute("create index if not exists wallets_updated_at_idx on wallets(updated_at);")
            cur.execute(
                """
                create table if not exists inventory_skins (
                  account_id uuid not null references accounts(id) on delete cascade,
                  character_id text not null,
                  skin_index integer not null,
                  purchased_at timestamptz not null default now(),
                  primary key (account_id, character_id, skin_index)
                );
                """
            )
            cur.execute("create index if not exists inventory_skins_account_idx on inventory_skins(account_id);")


@app.on_event("startup")
def _on_startup() -> None:
    log.info("Starting auth API (host=%s port=%d)", SETTINGS.listen_host, SETTINGS.listen_port)
    try:
        _init_schema()
    except Exception:
        # Don't log DATABASE_URL. Just the stack trace.
        log.exception("Schema init failed. Check DATABASE_URL connectivity/permissions.")
        raise
    log.info("Schema ready (tables: accounts, sessions)")


class AuthRequest(BaseModel):
    username: str
    password: str
    force: bool = False


class AuthResponse(BaseModel):
    token: str
    username: str


class MeResponse(BaseModel):
    username: str


class OwnedSkin(BaseModel):
    character_id: str
    skin_index: int


class ProfileResponse(BaseModel):
    username: str
    coins: int
    clk: int
    owned_skins: list[OwnedSkin]


class PurchaseSkinRequest(BaseModel):
    character_id: str
    skin_index: int


def _normalize_username(raw: str) -> str:
    return (raw or "").strip()


def _validate_username(username: str) -> None:
    if not USERNAME_RE.match(username):
        raise HTTPException(status_code=400, detail="username must be 3-16 chars: letters, numbers, underscore")


def _validate_password(password: str) -> None:
    if password is None:
        raise HTTPException(status_code=400, detail="password required")
    password = str(password)
    if len(password) < 4:
        raise HTTPException(status_code=400, detail="password too short")
    if len(password) > 72:
        raise HTTPException(status_code=400, detail="password too long")


def _hash_password(password: str) -> str:
    salt = bcrypt.gensalt(rounds=12)
    pw_hash = bcrypt.hashpw(password.encode("utf-8"), salt)
    return pw_hash.decode("utf-8")


def _verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))
    except Exception:
        return False


def _create_session(account_id: str) -> str:
    account_uuid = uuid.UUID(str(account_id))
    token = secrets.token_urlsafe(32)
    expires_at = _utc_now() + timedelta(hours=SETTINGS.session_ttl_hours)
    now = _utc_now()
    with _db() as conn:
        with conn.cursor() as cur:
            # Ensure old sessions don't block re-login.
            cur.execute("delete from sessions where account_id = %s and expires_at <= %s", (account_uuid, now))
            cur.execute(
                "insert into sessions (token, account_id, expires_at) values (%s, %s, %s)",
                (token, account_uuid, expires_at),
            )
    return token


def _ensure_wallet(account_uuid: uuid.UUID) -> None:
    with _db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                insert into wallets (account_id, coins, clk)
                values (%s, %s, %s)
                on conflict (account_id) do nothing
                """,
                (account_uuid, 9999, 9999),
            )


def _wallet_for_account(account_uuid: uuid.UUID) -> tuple[int, int]:
    _ensure_wallet(account_uuid)
    with _db() as conn:
        with conn.cursor() as cur:
            cur.execute("select coins, clk from wallets where account_id = %s", (account_uuid,))
            row = cur.fetchone()
            if not row:
                return 0, 0
            return int(row[0]), int(row[1])


def _owned_skins_for_account(account_uuid: uuid.UUID) -> list[OwnedSkin]:
    with _db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                select character_id, skin_index
                from inventory_skins
                where account_id = %s
                order by character_id, skin_index
                """,
                (account_uuid,),
            )
            out: list[OwnedSkin] = []
            for character_id, skin_index in cur.fetchall():
                out.append(OwnedSkin(character_id=str(character_id), skin_index=int(skin_index)))
            return out


def _normalize_character_id(raw: str) -> str:
    return (raw or "").strip().lower()


def _skin_cost_clk(character_id: str, skin_index: int) -> int:
    # "Classic" (index 1) is always free/unlocked.
    if skin_index <= 1:
        return 0
    return 10


def _account_for_token(token: str) -> Optional[tuple[str, str]]:
    if not token:
        return None
    now = _utc_now()
    with _db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                select a.id::text, a.username
                from sessions s
                join accounts a on a.id = s.account_id
                where s.token = %s and s.expires_at > %s
                """,
                (token, now),
            )
            row = cur.fetchone()
            if not row:
                return None
            return str(row[0]), str(row[1])


def _bearer_token(authorization: Optional[str]) -> str:
    if not authorization:
        return ""
    parts = authorization.split(" ", 1)
    if len(parts) != 2:
        return ""
    if parts[0].lower() != "bearer":
        return ""
    return parts[1].strip()

@app.post("/logout")
def logout(authorization: Optional[str] = Header(default=None)):
    token = _bearer_token(authorization)
    if not token:
        raise HTTPException(status_code=401, detail="unauthorized")

    with _db() as conn:
        with conn.cursor() as cur:
            cur.execute("delete from sessions where token = %s", (token,))
    return {"ok": True}


@app.get("/health")
def health():
    return {"ok": True, "time": _utc_now().isoformat()}


@app.post("/register", response_model=AuthResponse)
def register(req: AuthRequest):
    username = _normalize_username(req.username)
    _validate_username(username)
    _validate_password(req.password)

    pw_hash = _hash_password(req.password)
    account_id = str(uuid.uuid4())
    try:
        with _db() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "insert into accounts (id, username, password_hash) values (%s, %s, %s)",
                    (account_id, username, pw_hash),
                )
    except psycopg.errors.UniqueViolation:
        raise HTTPException(status_code=409, detail="username already exists")

    _ensure_wallet(uuid.UUID(account_id))

    token = _create_session(account_id)
    return AuthResponse(token=token, username=username)


@app.post("/login", response_model=AuthResponse)
def login(req: AuthRequest):
    username = _normalize_username(req.username)
    _validate_username(username)
    _validate_password(req.password)

    with _db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "select id::text, password_hash from accounts where username = %s",
                (username,),
            )
            row = cur.fetchone()
            if not row:
                raise HTTPException(status_code=401, detail="invalid credentials")
            account_id, pw_hash = str(row[0]), str(row[1])

    if not _verify_password(req.password, pw_hash):
        raise HTTPException(status_code=401, detail="invalid credentials")

    if bool(req.force):
        with _db() as conn:
            with conn.cursor() as cur:
                cur.execute("delete from sessions where account_id = %s", (uuid.UUID(account_id),))

    token = _create_session(account_id)
    return AuthResponse(token=token, username=username)


@app.get("/me", response_model=MeResponse)
def me(authorization: Optional[str] = Header(default=None)):
    token = _bearer_token(authorization)
    account = _account_for_token(token)
    if not account:
        raise HTTPException(status_code=401, detail="unauthorized")
    _account_id, username = account
    return MeResponse(username=username)


@app.get("/profile", response_model=ProfileResponse)
def profile(authorization: Optional[str] = Header(default=None)):
    token = _bearer_token(authorization)
    account = _account_for_token(token)
    if not account:
        raise HTTPException(status_code=401, detail="unauthorized")
    account_id, username = account
    account_uuid = uuid.UUID(account_id)
    coins, clk = _wallet_for_account(account_uuid)
    owned = _owned_skins_for_account(account_uuid)
    return ProfileResponse(username=username, coins=coins, clk=clk, owned_skins=owned)


@app.post("/purchase/skin", response_model=ProfileResponse)
def purchase_skin(req: PurchaseSkinRequest, authorization: Optional[str] = Header(default=None)):
    token = _bearer_token(authorization)
    account = _account_for_token(token)
    if not account:
        raise HTTPException(status_code=401, detail="unauthorized")
    account_id, username = account
    account_uuid = uuid.UUID(account_id)

    character_id = _normalize_character_id(req.character_id)
    if not character_id:
        raise HTTPException(status_code=400, detail="character_id required")
    skin_index = int(req.skin_index)
    if skin_index <= 0:
        raise HTTPException(status_code=400, detail="invalid skin_index")

    cost_clk = _skin_cost_clk(character_id, skin_index)
    if cost_clk <= 0:
        coins, clk = _wallet_for_account(account_uuid)
        owned = _owned_skins_for_account(account_uuid)
        return ProfileResponse(username=username, coins=coins, clk=clk, owned_skins=owned)

    # Transaction: check wallet + ownership then deduct + insert.
    with psycopg.connect(SETTINGS.database_url, autocommit=False) as conn:
        with conn.cursor() as cur:
            cur.execute("delete from sessions where expires_at <= now()")
            cur.execute(
                """
                insert into wallets (account_id, coins, clk)
                values (%s, %s, %s)
                on conflict (account_id) do nothing
                """,
                (account_uuid, 9999, 9999),
            )
            cur.execute("select coins, clk from wallets where account_id = %s for update", (account_uuid,))
            row = cur.fetchone()
            if not row:
                raise HTTPException(status_code=500, detail="wallet missing")
            coins = int(row[0])
            clk = int(row[1])

            cur.execute(
                """
                select 1 from inventory_skins
                where account_id = %s and character_id = %s and skin_index = %s
                """,
                (account_uuid, character_id, skin_index),
            )
            if cur.fetchone():
                log.info(
                    "purchase_skin noop (already owned): user=%s skin=%s/%d clk=%d",
                    username,
                    character_id,
                    skin_index,
                    clk,
                )
                conn.commit()
            else:
                if clk < cost_clk:
                    conn.rollback()
                    raise HTTPException(status_code=402, detail="not enough CLK")
                cur.execute(
                    "update wallets set clk = clk - %s, updated_at = now() where account_id = %s",
                    (cost_clk, account_uuid),
                )
                if cur.rowcount != 1:
                    conn.rollback()
                    raise HTTPException(status_code=500, detail="wallet update failed")
                cur.execute(
                    """
                    insert into inventory_skins (account_id, character_id, skin_index)
                    values (%s, %s, %s)
                    """,
                    (account_uuid, character_id, skin_index),
                )
                cur.execute("select coins, clk from wallets where account_id = %s", (account_uuid,))
                row2 = cur.fetchone()
                if row2:
                    coins2_tx = int(row2[0])
                    clk2_tx = int(row2[1])
                else:
                    coins2_tx = coins
                    clk2_tx = clk - cost_clk
                log.info(
                    "purchase_skin ok: user=%s skin=%s/%d cost_clk=%d clk_before=%d clk_after=%d",
                    username,
                    character_id,
                    skin_index,
                    cost_clk,
                    clk,
                    clk2_tx,
                )
                conn.commit()

    coins2, clk2 = _wallet_for_account(account_uuid)
    owned2 = _owned_skins_for_account(account_uuid)
    return ProfileResponse(username=username, coins=coins2, clk=clk2, owned_skins=owned2)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=SETTINGS.listen_host, port=SETTINGS.listen_port, reload=False)
