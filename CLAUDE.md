# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**KW** is a multiplayer 2D top-down shooter built with Godot 4.3 (GDScript). It supports 2–8 players in arena maps with real-time combat, character abilities, and a lobby matchmaking system. Game modes: Deathmatch and CTF.

## Running Locally

```bash
# Terminal 1 - Headless server
godot --headless --mode=server --host=127.0.0.1 --port=8080

# Terminal 2 - Client 1
godot --mode=client --host=127.0.0.1 --port=8080

# Terminal 3 - Client 2 (optional)
godot --mode=client --host=127.0.0.1 --port=8080
```

Main scene: `scenes/lobby.tscn`

Auth API base URL is configured in `project.godot` → `kw/auth_api_base_url` (default `http://127.0.0.1:8090`). See `tools/auth_api/README.md` to run it locally.

## Build Commands

```powershell
.\tools\export_windows.ps1   # Export kw.exe + kw.pck to build/
.\tools\make_release.ps1     # Full release build in build/release/
.\tools\build_launcher.ps1   # Build C# WinForms launcher
```

## Diagnostics

```bash
# Validate map system
godot --headless -s tools/diag_map_catalog.gd

# Analyze RPC surface
python tools/check_rpc_surface.py
```

## Deployment (Docker)

```bash
# Local
docker-compose -f docker-compose.server.yml up

# Remote Docker context
docker compose -f docker-compose.server.remote.yml up -d --build
```

## Architecture

### Runtime Inheritance Chain (`scripts/app/`)

The core is a 7-level deep inheritance chain (known tech debt, see `REFACTORING_GUIDE.md`):

```
main.gd
  → main_runtime.gd
    → runtime_controller.gd   (main loop, _physics_process)
      → runtime_rpc_logic.gd  (all @rpc handlers)
        → runtime_setup_logic.gd  (service initialization, DI wiring)
          → runtime_session_logic.gd  (network session management)
            → runtime_world_logic.gd  (player tracking, lobby state)
              → runtime_shared.gd  (base class, shared constants)
```

Additional extracted logic lives in `scripts/app/runtime/`: `runtime_bot_logic.gd`, `runtime_ctf_logic.gd`, `runtime_spawn_logic.gd`, `runtime_weapon_logic.gd`, etc.

### Service Architecture

Services are `RefCounted` classes configured with callback-based DI via a `configure(refs: Dictionary, callbacks: Dictionary)` pattern. They are instantiated in `runtime_setup_logic.gd`. There are **no global autoloads** — all service references are injected.

Key services:
- `CombatFlowService` — server-side fire cooldowns, ammo tracking
- `ProjectileSystem` — projectile spawning and lifecycle
- `HitDamageResolver` — raycast hit detection, damage application
- `PlayerReplication` — state sync, input history, client prediction
- `SessionController` — connection management and retries
- `LobbyService` / `LobbyFlowController` — matchmaking UI and state
- `SpawnFlowService` — spawn point allocation
- `SkillsService` — ability cooldown and activation

### Network Model

- **Authority:** Server-authoritative. Clients predict local movement; server reconciles.
- **Input rate:** 90 Hz (clients → server)
- **Snapshot rate:** 45 Hz (server → all clients)
- **Lag compensation:** RTT estimation + 800 ms input history buffer for projectile correction
- **Combat RPCs** use `"reliable"`, **movement RPCs** use `"unreliable"`

All RPC methods are prefixed with `_rpc_` and documented in `docs/RPC_PROTOCOL.md`.

### Player Entity (`scripts/entities/`)

`player.gd` (class `NetPlayer`, extends `CharacterBody2D`) composes modular components in `player_components/`. Do not add logic directly to `player.gd`; instead extend or modify the relevant component:
- `player_movement.gd` — physics, jump, gravity
- `player_weapon_visual.gd` — gun sprite, aiming, recoil
- `player_modular_visual.gd` — head/torso/legs sprite rendering
- `player_fov.gd` — Area2D-based field-of-view detection
- `player_vitals_hud.gd` — health bar above player

### Adding Content

- **New weapon:** Extend `WeaponProfile` in `scripts/weapons/`, register in `GameConstants`.
- **New warrior/ability:** Extend `WarriorProfile` in `scripts/warriors/`, add `_skill_Q.gd` / `_skill_E.gd` files, register in `GameConstants`.
- **New map:** Extend `MapController` in `scripts/world/`, add scene, register in `MapCatalog`.
- **New RPC:** Add `@rpc` decorator in `runtime_rpc_logic.gd`, document in `docs/RPC_PROTOCOL.md`, update `ARCHITECTURE.md`.

### Constants

All magic numbers and string IDs (weapons, characters, maps, network timing, player stats) live in `scripts/constants/game_constants.gd`. Always use these; never hardcode IDs.

## Code Style

- **GDScript:** snake_case functions/variables, PascalCase class names with `class_name`, UPPER_SNAKE_CASE constants, leading `_` for private functions.
- **Type hints:** Always required on function parameters and return types.
- **Line length:** 100 soft / 120 hard limit, tabs for indentation.
- **RPC handlers:** Must include an authority check (`if not multiplayer.is_server(): return`) for server-only logic. Document authority level and call frequency in comments above the handler.
- **Services:** Always extend `RefCounted`, always use the `configure(refs, callbacks)` pattern.

## Key Documentation

- `ARCHITECTURE.md` — system design and RPC flow diagrams
- `docs/RPC_PROTOCOL.md` — full RPC specification (45+ methods)
- `REFACTORING_GUIDE.md` — planned migration from inheritance chain to `ServiceRegistry` + controllers
- `scripts/entities/player_components/README.md` — player component system
- `scripts/warriors/README.md` — warrior/ability system

## Known Tech Debt

- **7-level inheritance chain** in `scripts/app/` — refactoring plan in `REFACTORING_GUIDE.md`
- **Callback-based DI** (`configure()` with Dictionaries) — error-prone, lacks type safety
- **No DTOs** for network messages — loose Dictionaries used instead of typed structs
