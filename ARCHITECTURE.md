# KW Godot - Architecture Guide

## Project Overview

**KW** is a multiplayer 2D shooter with:

- Client-server network architecture
- Lobby-based matchmaking
- Real-time combat with lag compensation
- Character abilities/skills
- Multiple weapons and maps

## Directory Structure

```
scripts/
├── app/              # Core runtime & initialization
├── combat/           # Combat mechanics (damage, projectiles, skills)
├── effects/          # Visual effects (camera shake, particles)
├── entities/         # Game objects (Player, Projectiles)
│   └── player_components/  # Player sub-systems (movement, weapon, FOV)
├── input/            # Input handling
├── lobby/            # Lobby management
├── network/          # Multiplayer & RPC handling
├── skills/           # Character-specific abilities
├── ui/               # UI controllers
├── weapons/          # Weapon profiles (AK47, Uzi)
└── world/            # Map management & spawning

scenes/
├── main.tscn         # Game scene (combat)
├── lobby.tscn        # Lobby/connection scene
├── main_cyber.tscn   # Alternate map
├── main_test.tscn    # Test map
└── entities/         # Player & projectile scenes
```

## Core Architecture

### 1. Runtime Initialization (scripts/app/)

The `app/` folder has a **deep inheritance chain** that loads everything:

```
main.gd
  ↓ extends
main_runtime.gd
  ↓ extends
runtime_controller.gd       (_ready() initializes services)
  ↓ extends
runtime_rpc_logic.gd        (RPC handlers: spawn, despawn, sync, combat)
  ↓ extends
runtime_setup_logic.gd      (_init_services(), _configure_services())
  ↓ extends
runtime_session_logic.gd    (Network session management)
  ↓ extends
runtime_world_logic.gd      (Game state, player management, map control)
  ↓ extends
runtime_shared.gd           (Base class, constants, UI refs)
```

**Key Responsibilities:**

- `runtime_shared.gd` → Constants, UI node references, state variables
- `runtime_world_logic.gd` → Player/lobby tracking, state queries
- `runtime_session_logic.gd` → Network peer management
- `runtime_setup_logic.gd` → Service initialization & configuration
- `runtime_rpc_logic.gd` → RPC handlers (spawn, sync, combat events)
- `runtime_controller.gd` → Main loop (`_ready()`, `_physics_process()`)
- `main.gd` → Game-specific RPC overrides

### 2. Service Architecture

Services are **RefCounted singletons** that handle specific domains:

#### Core Services

- **PlayerReplication** - Player state sync, input tracking
- **CombatFlowService** - Server-side combat simulation
- **ProjectileSystem** - Projectile spawning & tracking
- **HitDamageResolver** - Damage calculation & hit detection

#### Network Services

- **SessionController** - Connection management, retry logic
- **ClientRpcFlowService** - Client-side RPC handlers
- **PlayerReplication** - Player spawn/despawn, state replication

#### Game Services

- **LobbyService** - Lobby list, player matchmaking
- **LobbyFlowController** - Lobby UI flow
- **MapCatalog** - Map registry & metadata
- **SpawnFlowService** - Spawn point calculation
- **SkillsService** - Character ability management

#### Utility Services

- **CombatEffects** - Visual/audio feedback
- **CameraShake** - Screen shake effects
- **ClientInputController** - Local input handling

**Service Pattern (Callback-based dependency injection):**

```gdscript
# Services are configured with state refs and callbacks
func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
    players = state_refs.get("players", {})
    send_spawn_projectile_cb = callbacks.get("send_spawn_projectile", Callable())
    # ...
```

**⚠️ Issue:** This callback pattern is hard to maintain. Better to use signals or direct refs.

### 3. Network Architecture

#### RPC Flow

1. **Client Input** → `_rpc_submit_input()` (unreliable_ordered, 90 Hz)
2. **Server Simulation** → Runs `_physics_process()` with received input
3. **Server Broadcast** → `_rpc_sync_player_state()` (unreliable_ordered, 45 Hz)
4. **Client Prediction** → Predicts own player, reconciles with server updates
5. **Combat RPC** → Projectiles, hits, and effects replicated via RPC

#### Server Authority

- Player movement is server-authoritative with client prediction
- Combat (damage, kills/deaths) is server-only
- Projectiles spawn via RPC, clients predict visually

#### Lag Compensation

- **RTT estimation** → Ping requests every 0.75s
- **Input history** → Server keeps 800ms of historic inputs
- **Visual advance** → Projectiles adjusted by ping/lag

### 4. Player Spawn/Despawn Cycle

**Server Spawn:**

```
Client: _rpc_request_spawn()
  ↓ (runs on server)
Server: Validate lobby/spawn point
Server: Call _server_spawn_peer_if_needed(peer_id, lobby_id)
Server: RPC _rpc_spawn_player(peer_id, position, name, weapon, character)
  ↓ (all clients)
Clients: _spawn_player_local() - spawns NetPlayer scene
```

**Server Despawn:**

```
Player dies / leaves
Server: RPC _rpc_despawn_player(peer_id)
Clients: _remove_player_local(peer_id)
```

### 5. Combat System Flow

**Attack Sequence:**

```
Client: Hold shoot button → _rpc_submit_input(shoot_held=true)
Server: Check fire cooldown, has ammo
Server: Spawn projectile, RPC _rpc_spawn_projectile()
All: Draw projectile, predict movement
Server: Check collision each frame via hit_damage_resolver.server_projectile_world_hit()
Server: On hit → RPC _rpc_projectile_impact() + apply damage
Server: If kill → _rpc_despawn_player()
```

**Skills (Abilities):**

- **Outrage Bomb** - Creates explosive projectile
- **Erebus Immunity** - Temporary invulnerability

Managed by `SkillsService`, triggered via RPC.

### 6. Lobby System

**Flow:**

```
Lobby Scene loads (lobby.tscn with main.gd script)
Select weapon/character
Create/Join lobby (peer list tracked in LobbyService)
Once 2+ players → Start game (load actual game map)
```

**Key Classes:**

- `LobbyConfig` - Max players, default settings
- `LobbyService` - Tracks lobbies & members
- `LobbyFlowController` - Manages lobby state machine

## Important Constants

Located in `runtime_shared.gd`:

```gdscript
const DEFAULT_PORT := 8080
const SNAPSHOT_RATE := 45.0      # Server broadcast frequency
const INPUT_SEND_RATE := 90.0    # Client input frequency
const PING_INTERVAL := 0.75 sec  # Ping request frequency
const PLAYER_HISTORY_MS := 800   # Client prediction history

const WEAPON_ID_AK47 := "ak47"
const WEAPON_ID_UZI := "uzi"
const CHARACTER_ID_OUTRAGE := "outrage"
const CHARACTER_ID_EREBUS := "erebus"
const MAP_ID_CLASSIC := "classic"
```

⚠️ **Issue:** Constants scattered across files. Should be centralized.

## Player Entity (NetPlayer)

**Script:** `scripts/entities/player.gd`
**Components:**

- `player_movement.gd` - Velocity, jumping, gravity
- `player_weapon_visual.gd` - Gun sprite positioning
- `player_modular_visual.gd` - Body parts (head, torso, legs) rendering
- `player_walk_animation.gd` - Step animations
- `player_fov.gd` - Field of view detection
- `player_vitals_hud.gd` - Health bar display

## Weapon System

**Base Class:** `WeaponProfile` (refcounted)
**Implementations:**

- `AK47` - High damage, slow firing
- `Uzi` - Low damage, fast firing

**Methods:**

- `fire_interval()` - Shot cooldown
- `base_damage()` / `boost_damage()` - Damage values
- `magazine_size()` / `reload_duration()` - Magazine mechanics
- `projectile_visual_config()` - Trail/head visuals
- `clamp_aim_world()` - Aim constraints per weapon

## Projectile System

**Lifecycle:**

```
Spawn: _rpc_spawn_projectile() → ProjectileSystem.spawn_projectile()
Movement: Predicted on client, validated on server
Impact: Hit detection via HitDamageResolver
Despawn: _rpc_despawn_projectile() removed from scene
```

**Data per projectile:**

- Owner peer ID
- Spawn position & velocity
- Lag compensation offset
- Trail visual origin
- Weapon ID (for visual config)

## Configuration & Customization

### Startup Arguments

```bash
godot --mode=server --host=0.0.0.0 --port=8080
godot --mode=client --host=127.0.0.1 --port=8080 --no-autostart
```

### Launcher Configuration

`launcher/launcher_config.json`:

```json
{
  "game_exe": "kw.exe",
  "server_endpoint": "localhost:8080",
  "update_manifest_url": "..."
}
```

## Known Issues & Technical Debt

1. **Deep Inheritance Chain** - 7 levels of extends makes code hard to follow
2. **Callback Pattern** - Error-prone, no type safety for dependencies
3. **Magic IDs** - Weapon/character/map IDs scattered as strings
4. **No DTOs** - Network messages are loose dictionaries
5. **RPC Documentation** - 40+ RPC methods without clear spec
6. **Player Components** - Unclear relationship between files
7. **No Error Handling** - Silent failures on network issues
8. **Build Artifacts** - `/build/` and `.godot/` should be .gitignore'd

## Testing & Debugging

### Local Development

- **Single-window testing:**
  ```bash
  godot --mode=server  # Terminal 1
  godot --mode=client  # Terminal 2
  ```

### Diagnostics

- Run `tools/diag_map_catalog.gd` to list available maps
- Check `server_headless.log` for server errors
- Logs sent to `%StatusLabel` in-game

## Build & Deployment

**Export:** `tools/export_windows.ps1`
**Launcher:** C# WinForms app in `launcher/`
**Update System:** Manifest-based auto-update via `update_manifest.json`

---

**Last Updated:** February 2026
