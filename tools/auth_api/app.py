import os
import json
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
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
ALLOWED_WEAPONS = ("uzi", "ak47", "shotgun", "grenade")
DEFAULT_WEAPON_ID = "uzi"


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
                                    email text,
                                    password_hash text not null,
                                    created_at timestamptz not null default now()
                                );
                                """
                        )
                        cur.execute("alter table accounts add column if not exists email text;")
                        cur.execute("create unique index if not exists accounts_email_uidx on accounts ((lower(email))) where email is not null;")
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
                        cur.execute("delete from sessions where expires_at <= now();")
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
                        cur.execute(
                                """
                                create table if not exists inventory_weapons (
                                    account_id uuid not null references accounts(id) on delete cascade,
                                    weapon_id text not null,
                                    purchased_at timestamptz not null default now(),
                                    primary key (account_id, weapon_id)
                                );
                                """
                        )
                        cur.execute("create index if not exists inventory_weapons_account_idx on inventory_weapons(account_id);")
                        cur.execute(
                                """
                                create table if not exists inventory_weapon_skins (
                                    account_id uuid not null references accounts(id) on delete cascade,
                                    weapon_id text not null,
                                    skin_index integer not null,
                                    purchased_at timestamptz not null default now(),
                                    primary key (account_id, weapon_id, skin_index)
                                );
                                """
                        )
                        cur.execute("create index if not exists inventory_weapon_skins_account_idx on inventory_weapon_skins(account_id);")
                        cur.execute(
                                """
                                create table if not exists account_loadouts (
                                    account_id uuid primary key references accounts(id) on delete cascade,
                                    owned_warriors jsonb not null default '["outrage"]'::jsonb,
                                    owned_warrior_skins_by_warrior jsonb not null default '{"outrage":[0],"erebus":[0],"tasko":[0]}'::jsonb,
                                    equipped_warrior_skin_by_warrior jsonb not null default '{"outrage":0,"erebus":0,"tasko":0}'::jsonb,
                                    selected_warrior_id text not null default 'outrage',
                                    selected_warrior_skin integer not null default 0,
                                    equipped_weapon_skin_by_weapon jsonb not null default '{"uzi":0,"ak47":0,"shotgun":0,"grenade":0}'::jsonb,
                                    selected_weapon_id text not null default 'uzi',
                                    selected_weapon_skin integer not null default 0,
                                    updated_at timestamptz not null default now()
                                );
                                """
                        )
                        cur.execute("create index if not exists account_loadouts_updated_at_idx on account_loadouts(updated_at);")


@app.on_event("startup")
def _on_startup() -> None:
    log.info("Starting auth API (host=%s port=%d)", SETTINGS.listen_host, SETTINGS.listen_port)
    try:
        _init_schema()
    except Exception:
        # Don't log DATABASE_URL. Just the stack trace.
        log.exception("Schema init failed. Check DATABASE_URL connectivity/permissions.")
        raise
    log.info("Schema ready (tables: accounts, sessions, wallets, inventory_*)")


class AuthRequest(BaseModel):
    username: str = ""
    email: str = ""
    password: str
    force: bool = False


class AuthResponse(BaseModel):
    token: str
    username: str
    email: str = ""


class MeResponse(BaseModel):
    username: str
    email: str = ""


class OwnedSkin(BaseModel):
    character_id: str
    skin_index: int


class ProfileResponse(BaseModel):
    username: str
    email: str = ""
    coins: int
    clk: int
    owned_warriors: list[str] = []
    owned_skins: list[OwnedSkin]
    owned_warrior_skins_by_warrior: dict[str, list[int]] = {}
    equipped_warrior_skin_by_warrior: dict[str, int] = {}
    selected_warrior_id: str = "outrage"
    selected_warrior_skin: int = 0
    owned_weapons: list[str] = []
    owned_weapon_skins_by_weapon: dict[str, list[int]] = {}
    equipped_weapon_skin_by_weapon: dict[str, int] = {}
    selected_weapon_id: str = DEFAULT_WEAPON_ID
    selected_weapon_skin: int = 0


class PurchaseSkinRequest(BaseModel):
    character_id: str
    skin_index: int


class WalletUpdateRequest(BaseModel):
    coins: Optional[int] = None
    clk: Optional[int] = None
    owned_warriors: Optional[list[str]] = None
    owned_skins: Optional[list[OwnedSkin]] = None
    owned_warrior_skins_by_warrior: Optional[dict[str, list[int]]] = None
    equipped_warrior_skin_by_warrior: Optional[dict[str, int]] = None
    selected_warrior_id: Optional[str] = None
    selected_warrior_skin: Optional[int] = None
    owned_weapons: Optional[list[str]] = None
    owned_weapon_skins_by_weapon: Optional[dict[str, list[int]]] = None
    equipped_weapon_skin_by_weapon: Optional[dict[str, int]] = None
    selected_weapon_id: Optional[str] = None
    selected_weapon_skin: Optional[int] = None


DEFAULT_WARRIOR_ID = "outrage"
ALLOWED_WARRIORS = ("outrage", "erebus", "tasko")


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


def _normalize_email(raw: str) -> str:
    return (raw or "").strip().lower()


def _validate_email(email: str) -> None:
    if not EMAIL_RE.match(email):
        raise HTTPException(status_code=400, detail="email is invalid")


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
            _ensure_wallet_cur(cur, account_uuid)


def _ensure_wallet_cur(cur, account_uuid: uuid.UUID) -> None:
    cur.execute(
        """
        insert into wallets (account_id, coins, clk)
        values (%s, %s, %s)
        on conflict (account_id) do nothing
        """,
        (account_uuid, 9999, 9999),
    )


def _wallet_for_account_cur(cur, account_uuid: uuid.UUID) -> tuple[int, int]:
    _ensure_wallet_cur(cur, account_uuid)
    cur.execute("select coins, clk from wallets where account_id = %s", (account_uuid,))
    row = cur.fetchone()
    if not row:
        return 0, 0
    return int(row[0]), int(row[1])


def _owned_skins_for_account_cur(cur, account_uuid: uuid.UUID) -> list[OwnedSkin]:
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


def _ensure_weapon_inventory_defaults_cur(cur, account_uuid: uuid.UUID) -> None:
    cur.execute(
        """
        insert into inventory_weapons (account_id, weapon_id)
        values (%s, %s)
        on conflict (account_id, weapon_id) do nothing
        """,
        (account_uuid, DEFAULT_WEAPON_ID),
    )
    cur.execute(
        """
        insert into inventory_weapon_skins (account_id, weapon_id, skin_index)
        values (%s, %s, %s)
        on conflict (account_id, weapon_id, skin_index) do nothing
        """,
        (account_uuid, DEFAULT_WEAPON_ID, 0),
    )


def _owned_weapons_for_account_cur(cur, account_uuid: uuid.UUID) -> list[str]:
    _ensure_weapon_inventory_defaults_cur(cur, account_uuid)
    cur.execute(
        """
        select weapon_id
        from inventory_weapons
        where account_id = %s
        order by weapon_id
        """,
        (account_uuid,),
    )
    raw = [str(row[0]) for row in cur.fetchall()]
    return _normalize_owned_weapons(raw)


def _owned_weapon_skins_for_account_cur(cur, account_uuid: uuid.UUID, owned_weapons: list[str]) -> dict[str, list[int]]:
    owned_set = set(_normalize_owned_weapons(owned_weapons))
    out: dict[str, list[int]] = {wid: [0] for wid in ALLOWED_WEAPONS}
    cur.execute(
        """
        select weapon_id, skin_index
        from inventory_weapon_skins
        where account_id = %s
        order by weapon_id, skin_index
        """,
        (account_uuid,),
    )
    for weapon_id, skin_index in cur.fetchall():
        wid = _normalize_weapon_id(str(weapon_id))
        if wid not in ALLOWED_WEAPONS or wid not in owned_set:
            continue
        idx = max(0, int(skin_index))
        arr = out.get(wid, [0])
        if idx not in arr:
            arr.append(idx)
        out[wid] = sorted(arr)

    for wid in ALLOWED_WEAPONS:
        if wid not in owned_set:
            out[wid] = [0]
        elif 0 not in out[wid]:
            out[wid].insert(0, 0)
    return out


def _ensure_account_loadout_defaults_cur(cur, account_uuid: uuid.UUID) -> None:
    cur.execute(
        """
        insert into account_loadouts (
            account_id,
            owned_warriors,
            owned_warrior_skins_by_warrior,
            equipped_warrior_skin_by_warrior,
            selected_warrior_id,
            selected_warrior_skin,
            equipped_weapon_skin_by_weapon,
            selected_weapon_id,
            selected_weapon_skin
        )
        values (%s, %s::jsonb, %s::jsonb, %s::jsonb, %s, %s, %s::jsonb, %s, %s)
        on conflict (account_id) do nothing
        """,
        (
            account_uuid,
            json.dumps([DEFAULT_WARRIOR_ID]),
            json.dumps(_normalize_owned_warrior_skins({}, [DEFAULT_WARRIOR_ID])),
            json.dumps(_normalize_equipped_warrior_skins({})),
            DEFAULT_WARRIOR_ID,
            0,
            json.dumps(_normalize_equipped_weapon_skins({})),
            DEFAULT_WEAPON_ID,
            0,
        ),
    )


def _loadout_for_account_cur(cur, account_uuid: uuid.UUID) -> dict[str, object]:
    _ensure_account_loadout_defaults_cur(cur, account_uuid)
    cur.execute(
        """
        select
            owned_warriors,
            owned_warrior_skins_by_warrior,
            equipped_warrior_skin_by_warrior,
            selected_warrior_id,
            selected_warrior_skin,
            equipped_weapon_skin_by_weapon,
            selected_weapon_id,
            selected_weapon_skin
        from account_loadouts
        where account_id = %s
        """,
        (account_uuid,),
    )
    row = cur.fetchone()
    if not row:
        return {
            "owned_warriors": [DEFAULT_WARRIOR_ID],
            "owned_warrior_skins_by_warrior": _normalize_owned_warrior_skins({}, [DEFAULT_WARRIOR_ID]),
            "equipped_warrior_skin_by_warrior": _normalize_equipped_warrior_skins({}),
            "selected_warrior_id": DEFAULT_WARRIOR_ID,
            "selected_warrior_skin": 0,
            "equipped_weapon_skin_by_weapon": _normalize_equipped_weapon_skins({}),
            "selected_weapon_id": DEFAULT_WEAPON_ID,
            "selected_weapon_skin": 0,
        }
    owned_warriors = _normalize_owned_warriors(list(row[0] or [DEFAULT_WARRIOR_ID]))
    return {
        "owned_warriors": owned_warriors,
        "owned_warrior_skins_by_warrior": _normalize_owned_warrior_skins(row[1] or {}, owned_warriors),
        "equipped_warrior_skin_by_warrior": _normalize_equipped_warrior_skins(row[2] or {}),
        "selected_warrior_id": _normalize_warrior_id(str(row[3] or DEFAULT_WARRIOR_ID)),
        "selected_warrior_skin": max(0, int(row[4] or 0)),
        "equipped_weapon_skin_by_weapon": _normalize_equipped_weapon_skins(row[5] or {}),
        "selected_weapon_id": _normalize_weapon_id(str(row[6] or DEFAULT_WEAPON_ID)) or DEFAULT_WEAPON_ID,
        "selected_weapon_skin": max(0, int(row[7] or 0)),
    }


def _wallet_for_account(account_uuid: uuid.UUID) -> tuple[int, int]:
    with _db() as conn:
        with conn.cursor() as cur:
            return _wallet_for_account_cur(cur, account_uuid)


def _owned_skins_for_account(account_uuid: uuid.UUID) -> list[OwnedSkin]:
    with _db() as conn:
        with conn.cursor() as cur:
            return _owned_skins_for_account_cur(cur, account_uuid)


def _normalize_weapon_id(raw: str) -> str:
    return (raw or "").strip().lower()


def _normalize_warrior_id(raw: str) -> str:
    normalized = (raw or "").strip().lower()
    if normalized not in ALLOWED_WARRIORS:
        return DEFAULT_WARRIOR_ID
    return normalized


def _normalize_owned_warriors(raw_warriors: list[str]) -> list[str]:
    out: list[str] = []
    for item in raw_warriors:
        wid = _normalize_warrior_id(str(item))
        if wid not in out:
            out.append(wid)
    if DEFAULT_WARRIOR_ID not in out:
        out.append(DEFAULT_WARRIOR_ID)
    return out


def _normalize_owned_warrior_skins(raw_value: object, owned_warriors: list[str]) -> dict[str, list[int]]:
    owned_set = set(_normalize_owned_warriors(owned_warriors))
    out: dict[str, list[int]] = {wid: [0] for wid in ALLOWED_WARRIORS}
    if isinstance(raw_value, dict):
        for raw_key, raw_arr in raw_value.items():
            wid = _normalize_warrior_id(str(raw_key))
            arr = [0]
            if isinstance(raw_arr, list):
                for value in raw_arr:
                    idx = max(0, int(value))
                    if idx not in arr:
                        arr.append(idx)
            arr.sort()
            out[wid] = arr
    for wid in ALLOWED_WARRIORS:
        if wid not in owned_set:
            out[wid] = [0]
        elif 0 not in out[wid]:
            out[wid].insert(0, 0)
            out[wid] = sorted(set(out[wid]))
    return out


def _normalize_equipped_warrior_skins(raw_value: object) -> dict[str, int]:
    out: dict[str, int] = {wid: 0 for wid in ALLOWED_WARRIORS}
    if isinstance(raw_value, dict):
        for raw_key, raw_skin in raw_value.items():
            wid = _normalize_warrior_id(str(raw_key))
            out[wid] = max(0, int(raw_skin))
    return out


def _normalize_owned_weapons(raw_weapons: list[str]) -> list[str]:
    out: list[str] = []
    for item in raw_weapons:
        wid = _normalize_weapon_id(str(item))
        if wid in ALLOWED_WEAPONS and wid not in out:
            out.append(wid)
    if DEFAULT_WEAPON_ID not in out:
        out.append(DEFAULT_WEAPON_ID)
    return out


def _normalize_equipped_weapon_skins(raw_value: object) -> dict[str, int]:
    out: dict[str, int] = {wid: 0 for wid in ALLOWED_WEAPONS}
    if isinstance(raw_value, dict):
        for raw_key, raw_skin in raw_value.items():
            wid = _normalize_weapon_id(str(raw_key))
            if wid in ALLOWED_WEAPONS:
                out[wid] = max(0, int(raw_skin))
    return out


def _ensure_weapon_inventory_defaults(account_uuid: uuid.UUID) -> None:
    with _db() as conn:
        with conn.cursor() as cur:
            _ensure_weapon_inventory_defaults_cur(cur, account_uuid)


def _owned_weapons_for_account(account_uuid: uuid.UUID) -> list[str]:
    with _db() as conn:
        with conn.cursor() as cur:
            return _owned_weapons_for_account_cur(cur, account_uuid)


def _owned_weapon_skins_for_account(account_uuid: uuid.UUID, owned_weapons: list[str]) -> dict[str, list[int]]:
    with _db() as conn:
        with conn.cursor() as cur:
            return _owned_weapon_skins_for_account_cur(cur, account_uuid, owned_weapons)


def _ensure_account_loadout_defaults(account_uuid: uuid.UUID) -> None:
    with _db() as conn:
        with conn.cursor() as cur:
            _ensure_account_loadout_defaults_cur(cur, account_uuid)


def _loadout_for_account(account_uuid: uuid.UUID) -> dict[str, object]:
    with _db() as conn:
        with conn.cursor() as cur:
            return _loadout_for_account_cur(cur, account_uuid)


def _profile_for_account(account_uuid: uuid.UUID, username: str, email: str) -> ProfileResponse:
    with _db() as conn:
        with conn.cursor() as cur:
            coins, clk = _wallet_for_account_cur(cur, account_uuid)
            owned_skins = _owned_skins_for_account_cur(cur, account_uuid)
            loadout = _loadout_for_account_cur(cur, account_uuid)
            owned_weapons = _owned_weapons_for_account_cur(cur, account_uuid)
            owned_weapon_skins_by_weapon = _owned_weapon_skins_for_account_cur(cur, account_uuid, owned_weapons)
    selected_weapon_id = str(loadout.get("selected_weapon_id", DEFAULT_WEAPON_ID))
    if selected_weapon_id not in ALLOWED_WEAPONS:
        selected_weapon_id = DEFAULT_WEAPON_ID
    selected_weapon_skin = max(0, int(loadout.get("selected_weapon_skin", 0)))
    if selected_weapon_skin not in owned_weapon_skins_by_weapon.get(selected_weapon_id, [0]):
        selected_weapon_skin = 0
    equipped_weapon_skin_by_weapon = _normalize_equipped_weapon_skins(loadout.get("equipped_weapon_skin_by_weapon", {}))
    equipped_weapon_skin_by_weapon[selected_weapon_id] = selected_weapon_skin

    owned_warriors = _normalize_owned_warriors(loadout.get("owned_warriors", [DEFAULT_WARRIOR_ID]))
    owned_warrior_skins_by_warrior = _normalize_owned_warrior_skins(loadout.get("owned_warrior_skins_by_warrior", {}), owned_warriors)
    for skin in owned_skins:
        wid = _normalize_warrior_id(skin.character_id)
        arr = owned_warrior_skins_by_warrior.get(wid, [0])
        idx = max(0, int(skin.skin_index))
        if idx not in arr:
            arr.append(idx)
            arr.sort()
        owned_warrior_skins_by_warrior[wid] = arr
        if wid not in owned_warriors:
            owned_warriors.append(wid)
    selected_warrior_id = _normalize_warrior_id(str(loadout.get("selected_warrior_id", DEFAULT_WARRIOR_ID)))
    if selected_warrior_id not in owned_warriors:
        selected_warrior_id = DEFAULT_WARRIOR_ID
    selected_warrior_skin = max(0, int(loadout.get("selected_warrior_skin", 0)))
    if selected_warrior_skin not in owned_warrior_skins_by_warrior.get(selected_warrior_id, [0]):
        selected_warrior_skin = 0
    equipped_warrior_skin_by_warrior = _normalize_equipped_warrior_skins(loadout.get("equipped_warrior_skin_by_warrior", {}))
    equipped_warrior_skin_by_warrior[selected_warrior_id] = selected_warrior_skin

    return ProfileResponse(
        username=username,
        email=email,
        coins=coins,
        clk=clk,
        owned_warriors=owned_warriors,
        owned_skins=owned_skins,
        owned_warrior_skins_by_warrior=owned_warrior_skins_by_warrior,
        equipped_warrior_skin_by_warrior=equipped_warrior_skin_by_warrior,
        selected_warrior_id=selected_warrior_id,
        selected_warrior_skin=selected_warrior_skin,
        owned_weapons=owned_weapons,
        owned_weapon_skins_by_weapon=owned_weapon_skins_by_weapon,
        equipped_weapon_skin_by_weapon=equipped_weapon_skin_by_weapon,
        selected_weapon_id=selected_weapon_id,
        selected_weapon_skin=selected_weapon_skin,
    )


def _normalize_character_id(raw: str) -> str:
    return (raw or "").strip().lower()


def _skin_cost_coins(character_id: str, skin_index: int) -> int:
    if skin_index <= 0:
        return 0
    if character_id == "outrage":
        return 250 + skin_index * 120
    return 250 + skin_index * 120


def _account_for_token(token: str) -> Optional[tuple[str, str, str]]:
    if not token:
        return None
    now = _utc_now()
    with _db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                select a.id::text, a.username, coalesce(a.email, '')
                from sessions s
                join accounts a on a.id = s.account_id
                where s.token = %s and s.expires_at > %s
                """,
                (token, now),
            )
            row = cur.fetchone()
            if not row:
                return None
            return str(row[0]), str(row[1]), str(row[2] or "")


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
    email = _normalize_email(req.email)
    if email:
        _validate_email(email)
    _validate_password(req.password)

    pw_hash = _hash_password(req.password)
    account_id = str(uuid.uuid4())
    try:
        with _db() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "insert into accounts (id, username, email, password_hash) values (%s, %s, %s, %s)",
                    (account_id, username, email if email else None, pw_hash),
                )
    except psycopg.errors.UniqueViolation:
        raise HTTPException(status_code=409, detail="username or email already exists")

    _ensure_wallet(uuid.UUID(account_id))

    token = _create_session(account_id)
    return AuthResponse(token=token, username=username, email=email)


@app.post("/login", response_model=AuthResponse)
def login(req: AuthRequest):
    username = _normalize_username(req.username)
    email = _normalize_email(req.email)
    _validate_password(req.password)

    lookup_is_email = False
    lookup_value = username
    if email:
        _validate_email(email)
        lookup_is_email = True
        lookup_value = email
    elif "@" in username:
        email_candidate = _normalize_email(username)
        _validate_email(email_candidate)
        lookup_is_email = True
        lookup_value = email_candidate
    else:
        _validate_username(username)

    with _db() as conn:
        with conn.cursor() as cur:
            if lookup_is_email:
                cur.execute(
                    "select id::text, username, coalesce(email, ''), password_hash from accounts where lower(email) = lower(%s)",
                    (lookup_value,),
                )
            else:
                cur.execute(
                    "select id::text, username, coalesce(email, ''), password_hash from accounts where username = %s",
                    (lookup_value,),
                )
            row = cur.fetchone()
            if not row:
                raise HTTPException(status_code=401, detail="invalid credentials")
            account_id, resolved_username, resolved_email, pw_hash = str(row[0]), str(row[1]), str(row[2] or ""), str(row[3])

    if not _verify_password(req.password, pw_hash):
        raise HTTPException(status_code=401, detail="invalid credentials")

    if bool(req.force):
        with _db() as conn:
            with conn.cursor() as cur:
                cur.execute("delete from sessions where account_id = %s", (uuid.UUID(account_id),))

    token = _create_session(account_id)
    return AuthResponse(token=token, username=resolved_username, email=resolved_email)


@app.get("/me", response_model=MeResponse)
def me(authorization: Optional[str] = Header(default=None)):
    token = _bearer_token(authorization)
    account = _account_for_token(token)
    if not account:
        raise HTTPException(status_code=401, detail="unauthorized")
    _account_id, username, email = account
    return MeResponse(username=username, email=email)


@app.get("/profile", response_model=ProfileResponse)
def profile(authorization: Optional[str] = Header(default=None)):
    token = _bearer_token(authorization)
    account = _account_for_token(token)
    if not account:
        raise HTTPException(status_code=401, detail="unauthorized")
    account_id, username, email = account
    account_uuid = uuid.UUID(account_id)
    return _profile_for_account(account_uuid, username, email)


@app.post("/purchase/skin", response_model=ProfileResponse)
def purchase_skin(req: PurchaseSkinRequest, authorization: Optional[str] = Header(default=None)):
    token = _bearer_token(authorization)
    account = _account_for_token(token)
    if not account:
        raise HTTPException(status_code=401, detail="unauthorized")
    account_id, username, email = account
    account_uuid = uuid.UUID(account_id)

    character_id = _normalize_character_id(req.character_id)
    if not character_id:
        raise HTTPException(status_code=400, detail="character_id required")
    skin_index = int(req.skin_index)
    if skin_index <= 0:
        raise HTTPException(status_code=400, detail="invalid skin_index")

    cost_coins = _skin_cost_coins(character_id, skin_index)
    if cost_coins <= 0:
        return _profile_for_account(account_uuid, username, email)

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
                if coins < cost_coins:
                    conn.rollback()
                    raise HTTPException(status_code=402, detail="not enough coins")
                cur.execute(
                    "update wallets set coins = coins - %s, updated_at = now() where account_id = %s",
                    (cost_coins, account_uuid),
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
                    coins2_tx = coins - cost_coins
                    clk2_tx = clk
                log.info(
                    "purchase_skin ok: user=%s skin=%s/%d cost_coins=%d coins_before=%d coins_after=%d",
                    username,
                    character_id,
                    skin_index,
                    cost_coins,
                    coins,
                    coins2_tx,
                )
                conn.commit()

    return _profile_for_account(account_uuid, username, email)


@app.post("/wallet/update", response_model=ProfileResponse)
def wallet_update(req: WalletUpdateRequest, authorization: Optional[str] = Header(default=None)):
    token = _bearer_token(authorization)
    account = _account_for_token(token)
    if not account:
        raise HTTPException(status_code=401, detail="unauthorized")

    if (
        req.coins is None
        and req.clk is None
        and req.owned_warriors is None
        and req.owned_skins is None
        and req.owned_warrior_skins_by_warrior is None
        and req.equipped_warrior_skin_by_warrior is None
        and req.selected_warrior_id is None
        and req.selected_warrior_skin is None
        and req.owned_weapons is None
        and req.owned_weapon_skins_by_weapon is None
        and req.equipped_weapon_skin_by_weapon is None
        and req.selected_weapon_id is None
        and req.selected_weapon_skin is None
    ):
        raise HTTPException(status_code=400, detail="wallet or inventory fields required")

    account_id, username, email = account
    account_uuid = uuid.UUID(account_id)
    with psycopg.connect(SETTINGS.database_url, autocommit=False) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                insert into wallets (account_id, coins, clk)
                values (%s, %s, %s)
                on conflict (account_id) do nothing
                """,
                (account_uuid, 9999, 9999),
            )

            set_clauses: list[str] = []
            params: list[object] = []
            if req.coins is not None:
                set_clauses.append("coins = %s")
                params.append(max(0, int(req.coins)))
            if req.clk is not None:
                set_clauses.append("clk = %s")
                params.append(max(0, int(req.clk)))
            if set_clauses:
                set_clauses.append("updated_at = now()")
                query = "update wallets set " + ", ".join(set_clauses) + " where account_id = %s"
                params.append(account_uuid)
                cur.execute(query, tuple(params))
                if cur.rowcount != 1:
                    conn.rollback()
                    raise HTTPException(status_code=500, detail="wallet update failed")

            if req.owned_skins is not None:
                cur.execute("delete from inventory_skins where account_id = %s", (account_uuid,))
                for item in req.owned_skins:
                    character_id = _normalize_character_id(item.character_id)
                    skin_index = max(0, int(item.skin_index))
                    if not character_id or skin_index <= 0:
                        continue
                    cur.execute(
                        """
                        insert into inventory_skins (account_id, character_id, skin_index)
                        values (%s, %s, %s)
                        on conflict (account_id, character_id, skin_index) do nothing
                        """,
                        (account_uuid, character_id, skin_index),
                    )

            _ensure_account_loadout_defaults(account_uuid)
            existing_loadout = _loadout_for_account(account_uuid)
            next_owned_warriors = _normalize_owned_warriors(req.owned_warriors) if req.owned_warriors is not None else _normalize_owned_warriors(existing_loadout.get("owned_warriors", [DEFAULT_WARRIOR_ID]))
            next_owned_warrior_skins_by_warrior = _normalize_owned_warrior_skins(
                req.owned_warrior_skins_by_warrior if req.owned_warrior_skins_by_warrior is not None else existing_loadout.get("owned_warrior_skins_by_warrior", {}),
                next_owned_warriors,
            )
            next_equipped_warrior_skin_by_warrior = _normalize_equipped_warrior_skins(
                req.equipped_warrior_skin_by_warrior if req.equipped_warrior_skin_by_warrior is not None else existing_loadout.get("equipped_warrior_skin_by_warrior", {}),
            )
            next_selected_warrior_id = _normalize_warrior_id(
                req.selected_warrior_id if req.selected_warrior_id is not None else str(existing_loadout.get("selected_warrior_id", DEFAULT_WARRIOR_ID))
            )
            if next_selected_warrior_id not in next_owned_warriors:
                next_selected_warrior_id = DEFAULT_WARRIOR_ID
            next_selected_warrior_skin = max(
                0,
                int(req.selected_warrior_skin if req.selected_warrior_skin is not None else int(existing_loadout.get("selected_warrior_skin", 0))),
            )
            if next_selected_warrior_skin not in next_owned_warrior_skins_by_warrior.get(next_selected_warrior_id, [0]):
                next_selected_warrior_skin = 0
            next_equipped_warrior_skin_by_warrior[next_selected_warrior_id] = next_selected_warrior_skin

            owned_weapons = None
            if req.owned_weapons is not None:
                owned_weapons = _normalize_owned_weapons(req.owned_weapons)
                cur.execute("delete from inventory_weapons where account_id = %s", (account_uuid,))
                for wid in owned_weapons:
                    cur.execute(
                        """
                        insert into inventory_weapons (account_id, weapon_id)
                        values (%s, %s)
                        on conflict (account_id, weapon_id) do nothing
                        """,
                        (account_uuid, wid),
                    )

            if req.owned_weapon_skins_by_weapon is not None:
                if owned_weapons is None:
                    cur.execute(
                        "select weapon_id from inventory_weapons where account_id = %s",
                        (account_uuid,),
                    )
                    owned_weapons = _normalize_owned_weapons([str(r[0]) for r in cur.fetchall()])
                owned_set = set(owned_weapons)
                cur.execute("delete from inventory_weapon_skins where account_id = %s", (account_uuid,))
                incoming = req.owned_weapon_skins_by_weapon
                for wid in ALLOWED_WEAPONS:
                    if wid not in owned_set:
                        continue
                    raw_arr = incoming.get(wid, [0])
                    normalized_arr: list[int] = [0]
                    for value in raw_arr:
                        idx = max(0, int(value))
                        if idx not in normalized_arr:
                            normalized_arr.append(idx)
                    for idx in normalized_arr:
                        cur.execute(
                            """
                            insert into inventory_weapon_skins (account_id, weapon_id, skin_index)
                            values (%s, %s, %s)
                            on conflict (account_id, weapon_id, skin_index) do nothing
                            """,
                            (account_uuid, wid, idx),
                        )

            if owned_weapons is None:
                cur.execute("select weapon_id from inventory_weapons where account_id = %s", (account_uuid,))
                owned_weapons = _normalize_owned_weapons([str(r[0]) for r in cur.fetchall()])
            next_equipped_weapon_skin_by_weapon = _normalize_equipped_weapon_skins(
                req.equipped_weapon_skin_by_weapon if req.equipped_weapon_skin_by_weapon is not None else existing_loadout.get("equipped_weapon_skin_by_weapon", {}),
            )
            next_selected_weapon_id = _normalize_weapon_id(
                req.selected_weapon_id if req.selected_weapon_id is not None else str(existing_loadout.get("selected_weapon_id", DEFAULT_WEAPON_ID))
            )
            if next_selected_weapon_id not in ALLOWED_WEAPONS or next_selected_weapon_id not in owned_weapons:
                next_selected_weapon_id = DEFAULT_WEAPON_ID
            owned_weapon_skins_by_weapon = _owned_weapon_skins_for_account(account_uuid, owned_weapons)
            next_selected_weapon_skin = max(
                0,
                int(req.selected_weapon_skin if req.selected_weapon_skin is not None else int(existing_loadout.get("selected_weapon_skin", 0))),
            )
            if next_selected_weapon_skin not in owned_weapon_skins_by_weapon.get(next_selected_weapon_id, [0]):
                next_selected_weapon_skin = 0
            next_equipped_weapon_skin_by_weapon[next_selected_weapon_id] = next_selected_weapon_skin

            cur.execute(
                """
                insert into account_loadouts (
                    account_id,
                    owned_warriors,
                    owned_warrior_skins_by_warrior,
                    equipped_warrior_skin_by_warrior,
                    selected_warrior_id,
                    selected_warrior_skin,
                    equipped_weapon_skin_by_weapon,
                    selected_weapon_id,
                    selected_weapon_skin,
                    updated_at
                )
                values (%s, %s::jsonb, %s::jsonb, %s::jsonb, %s, %s, %s::jsonb, %s, %s, now())
                on conflict (account_id) do update set
                    owned_warriors = excluded.owned_warriors,
                    owned_warrior_skins_by_warrior = excluded.owned_warrior_skins_by_warrior,
                    equipped_warrior_skin_by_warrior = excluded.equipped_warrior_skin_by_warrior,
                    selected_warrior_id = excluded.selected_warrior_id,
                    selected_warrior_skin = excluded.selected_warrior_skin,
                    equipped_weapon_skin_by_weapon = excluded.equipped_weapon_skin_by_weapon,
                    selected_weapon_id = excluded.selected_weapon_id,
                    selected_weapon_skin = excluded.selected_weapon_skin,
                    updated_at = now()
                """,
                (
                    account_uuid,
                    json.dumps(next_owned_warriors),
                    json.dumps(next_owned_warrior_skins_by_warrior),
                    json.dumps(next_equipped_warrior_skin_by_warrior),
                    next_selected_warrior_id,
                    next_selected_warrior_skin,
                    json.dumps(next_equipped_weapon_skin_by_weapon),
                    next_selected_weapon_id,
                    next_selected_weapon_skin,
                ),
            )

            conn.commit()

    return _profile_for_account(account_uuid, username, email)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=SETTINGS.listen_host, port=SETTINGS.listen_port, reload=False)
