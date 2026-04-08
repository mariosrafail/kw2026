import json
import os
import uuid
from pathlib import Path

import bcrypt
import psycopg


ROOT = Path(__file__).resolve().parents[2]
ENV_PATH = ROOT / ".env"

ACCOUNT_USERNAMES = ["Markos", "Giannis", "Erebus", "Kostas"]
ACCOUNT_PASSWORD = "1234"

ALLOWED_WARRIORS = ["outrage", "erebus", "tasko", "juice", "madam", "celler", "kotro", "nova", "hindi", "loker", "gan", "veila"]
ALLOWED_WEAPONS = ["uzi", "ak47", "shotgun", "grenade"]


def load_database_url() -> str:
    env_value = os.environ.get("DATABASE_URL", "").strip()
    if env_value:
        return env_value
    if ENV_PATH.exists():
        for raw_line in ENV_PATH.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            if key.strip() == "DATABASE_URL":
                return value.strip()
    raise RuntimeError("DATABASE_URL not found in environment or .env")


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(rounds=12)).decode("utf-8")


def warrior_skin_indices() -> dict[str, list[int]]:
    out: dict[str, list[int]] = {}
    for warrior_id in ALLOWED_WARRIORS:
        manifest_path = ROOT / "assets" / "warriors" / warrior_id / "skin_manifest.json"
        payload = json.loads(manifest_path.read_text(encoding="utf-8"))
        indices = sorted({max(0, int(entry.get("index", 0))) for entry in payload.get("skins", [])})
        if 0 not in indices:
            indices.insert(0, 0)
        out[warrior_id] = indices
    return out


def weapon_skin_indices() -> dict[str, list[int]]:
    common = list(range(0, 22))
    return {
        "uzi": common[:],
        "ak47": common[:] + [100],
        "shotgun": common[:],
        "grenade": common[:],
    }


def ensure_schema(cur) -> None:
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
        create table if not exists wallets (
            account_id uuid primary key references accounts(id) on delete cascade,
            coins integer not null default 0,
            clk integer not null default 0,
            updated_at timestamptz not null default now()
        );
        """
    )
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
    cur.execute(
        """
        create table if not exists account_loadouts (
            account_id uuid primary key references accounts(id) on delete cascade,
            owned_warriors jsonb not null default '["outrage"]'::jsonb,
            owned_warrior_skins_by_warrior jsonb not null default '{"outrage":[0],"erebus":[0],"tasko":[0],"juice":[0],"madam":[0],"celler":[0],"kotro":[0],"nova":[0],"hindi":[0],"loker":[0],"gan":[0],"veila":[0]}'::jsonb,
            equipped_warrior_skin_by_warrior jsonb not null default '{"outrage":0,"erebus":0,"tasko":0,"juice":0,"madam":0,"celler":0,"kotro":0,"nova":0,"hindi":0,"loker":0,"gan":0,"veila":0}'::jsonb,
            selected_warrior_id text not null default 'outrage',
            selected_warrior_skin integer not null default 0,
            equipped_weapon_skin_by_weapon jsonb not null default '{"uzi":0,"ak47":0,"shotgun":0,"grenade":0}'::jsonb,
            selected_weapon_id text not null default 'uzi',
            selected_weapon_skin integer not null default 0,
            updated_at timestamptz not null default now()
        );
        """
    )


def upsert_account(cur, username: str, password_hash: str, warrior_skins: dict[str, list[int]], weapon_skins: dict[str, list[int]]) -> None:
    cur.execute("select id from accounts where username = %s", (username,))
    row = cur.fetchone()
    account_id = row[0] if row else uuid.uuid4()
    cur.execute(
        """
        insert into accounts (id, username, email, password_hash)
        values (%s, %s, null, %s)
        on conflict (username) do update set
            password_hash = excluded.password_hash
        """,
        (account_id, username, password_hash),
    )

    cur.execute(
        """
        insert into wallets (account_id, coins, clk, updated_at)
        values (%s, %s, %s, now())
        on conflict (account_id) do update set
            coins = excluded.coins,
            clk = excluded.clk,
            updated_at = now()
        """,
        (account_id, 9999, 9999),
    )

    cur.execute("delete from inventory_skins where account_id = %s", (account_id,))
    for warrior_id, indices in warrior_skins.items():
        for skin_index in indices:
            if skin_index <= 0:
                continue
            cur.execute(
                """
                insert into inventory_skins (account_id, character_id, skin_index)
                values (%s, %s, %s)
                on conflict (account_id, character_id, skin_index) do nothing
                """,
                (account_id, warrior_id, skin_index),
            )

    cur.execute("delete from inventory_weapons where account_id = %s", (account_id,))
    for weapon_id in ALLOWED_WEAPONS:
        cur.execute(
            """
            insert into inventory_weapons (account_id, weapon_id)
            values (%s, %s)
            on conflict (account_id, weapon_id) do nothing
            """,
            (account_id, weapon_id),
        )

    cur.execute("delete from inventory_weapon_skins where account_id = %s", (account_id,))
    for weapon_id, indices in weapon_skins.items():
        for skin_index in indices:
            cur.execute(
                """
                insert into inventory_weapon_skins (account_id, weapon_id, skin_index)
                values (%s, %s, %s)
                on conflict (account_id, weapon_id, skin_index) do nothing
                """,
                (account_id, weapon_id, skin_index),
            )

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
            account_id,
            json.dumps(ALLOWED_WARRIORS),
            json.dumps(warrior_skins),
            json.dumps({warrior_id: 0 for warrior_id in ALLOWED_WARRIORS}),
            "outrage",
            0,
            json.dumps({"uzi": 0, "ak47": 0, "shotgun": 0, "grenade": 0}),
            "uzi",
            0,
        ),
    )


def main() -> None:
    database_url = load_database_url()
    warrior_skins = warrior_skin_indices()
    weapon_skins = weapon_skin_indices()
    with psycopg.connect(database_url, autocommit=False) as conn:
        with conn.cursor() as cur:
            ensure_schema(cur)
            for username in ACCOUNT_USERNAMES:
                upsert_account(cur, username, hash_password(ACCOUNT_PASSWORD), warrior_skins, weapon_skins)
        conn.commit()
    print("Seeded accounts: %s" % ", ".join(ACCOUNT_USERNAMES))


if __name__ == "__main__":
    main()
