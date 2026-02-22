# RPC Protocol Specification

## Overview

KW uses Godot's MultiplayerAPI for real-time synchronization. All RPC calls are defined in `scripts/main.gd` which extends the base runtime.

**Authority Model:**

- **Server-authoritative** for gameplay state (player positions, damage, kills)
- **Peer-to-peer** for input submission (clients send their own input)
- **Broadcast** for state snapshots (server sends to all clients)

---

## RPC Call Reference

### Player Spawn & Despawn

#### `_rpc_request_spawn()`

- **Direction:** Client → Server
- **Authority:** `any_peer`, `reliable`
- **Frequency:** On-demand (when player ready to spawn)
- **Purpose:** Client requests permission to spawn
- **Handler:** Server validates lobby/game state, may accept or reject
- **Response:** Server calls `_rpc_spawn_player()` if approved

---

#### `_rpc_spawn_player(peer_id, spawn_position, display_name, weapon_id, character_id)`

- **Direction:** Server → All Clients
- **Authority:** `authority`, `reliable`
- **Frequency:** Per player spawn (2 times per game max)
- **Purpose:** Notify all clients that a player has spawned
- **Parameters:**
  - `peer_id: int` - Multiplayer peer ID of spawned player
  - `spawn_position: Vector2` - World position of spawn
  - `display_name: String` - Player's username (optional)
  - `weapon_id: String` - Starting weapon ("ak47" or "uzi")
  - `character_id: String` - Character skin ("outrage" or "erebus")
- **Handler:** Creates NetPlayer scene, positions at spawn_position, configures visuals
- **Note:** Weapon & character ID sent even if player didn't change them (for sync)

---

#### `_rpc_despawn_player(peer_id)`

- **Direction:** Server → All Clients
- **Authority:** `authority`, `reliable`
- **Frequency:** Per player death/disconnect
- **Purpose:** Remove a player from the game
- **Parameters:**
  - `peer_id: int` - Peer ID of removed player
- **Handler:** Deletes NetPlayer node, updates scoreboard

---

### Player Movement & State Sync

#### `_rpc_sync_player_state(peer_id, new_position, new_velocity, aim_angle, health)`

- **Direction:** Server → All Clients
- **Authority:** `authority`, `unreliable_ordered`
- **Frequency:** 45 times per second (SNAPSHOT_RATE)
- **Purpose:** Broadcast remote player's state
- **Parameters:**
  - `peer_id: int` - Owner of this state snapshot
  - `new_position: Vector2` - Current world position
  - `new_velocity: Vector2` - Current velocity
  - `aim_angle: float` - Aim direction in radians
  - `health: int` - Current HP (0-100)
- **Handler:** Client applies state via `player_replication.client_apply_state_snapshot()`
- **Note:** Used for client-side prediction reconciliation. Unreliable = OK to drop packets.
- **Frequency Math:** ~22ms between updates at 45 Hz

---

#### `_rpc_submit_input(axis, jump_pressed, jump_held, aim_world, shoot_held, boost_or_rtt, reported_rtt_ms)`

- **Direction:** Client → Server
- **Authority:** `any_peer`, `unreliable_ordered`
- **Frequency:** 90 times per second (INPUT_SEND_RATE)
- **Purpose:** Client sends input to server for simulation
- **Parameters:**
  - `axis: float` - Left/right movement (-1.0 to 1.0)
  - `jump_pressed: bool` - Jump button just pressed this frame
  - `jump_held: bool` - Jump button currently held
  - `aim_world: Vector2` - World position of aim target
  - `shoot_held: bool` - Fire button held
  - `boost_or_rtt: Variant` - Either boost_damage flag OR reported RTT ms (dual-purpose)
  - `reported_rtt_ms: int` - Round-trip time in milliseconds (server fills this)
- **Handler:** Server processes input, applies to local player sim
- **Note:** Server uses RTT for lag compensation on projectiles
- **Frequency Math:** ~11ms between updates at 90 Hz

---

### Player Stats & Scoring

#### `_rpc_sync_player_stats(peer_id, kills, deaths)`

- **Direction:** Server → All Clients
- **Authority:** `authority`, `reliable`
- **Frequency:** When K/D changes (after kill or death)
- **Purpose:** Update scoreboard with player's stats
- **Parameters:**
  - `peer_id: int` - Owner of these stats
  - `kills: int` - Total kills this match
  - `deaths: int` - Total deaths this match
- **Handler:** Updates `player_stats[peer_id]`, refreshes K/D labels

---

### Networking & Latency

#### `_rpc_ping_request(client_sent_msec)`

- **Direction:** Client → Server
- **Authority:** `any_peer`, `unreliable`
- **Frequency:** ~0.75 second intervals (PING_INTERVAL)
- **Purpose:** Measure round-trip latency
- **Parameters:**
  - `client_sent_msec: int` - Client's timestamp (from OS.get_ticks_msec())
- **Handler:** Server immediately responds with `_rpc_ping_response()`

---

#### `_rpc_ping_response(client_sent_msec)`

- **Direction:** Server → Client
- **Authority:** `authority`, `unreliable`
- **Frequency:** 1:1 response to ping requests
- **Purpose:** Return ping for RTT calculation
- **Parameters:**
  - `client_sent_msec: int` - Echo of request timestamp
- **Handler:** Client calculates RTT = now - client_sent_msec, updates `last_ping_ms`

---

### Combat & Projectiles

#### `_rpc_spawn_projectile(projectile_id, owner_peer_id, spawn_position, velocity, lag_comp_ms, trail_origin, weapon_id)`

- **Direction:** Server → All Clients
- **Authority:** `authority`, `reliable`
- **Frequency:** Per shot fired
- **Purpose:** Spawn a projectile for all players to see
- **Parameters:**
  - `projectile_id: int` - Unique ID for this projectile (incremental)
  - `owner_peer_id: int` - Who shot it (for damage tracking)
  - `spawn_position: Vector2` - Where it spawned
  - `velocity: Vector2` - Direction & speed (pixels/sec)
  - `lag_comp_ms: int` - How far ahead to draw (lag compensation)
  - `trail_origin: Vector2` - Where particle trail starts
  - `weapon_id: String` - "ak47" or "uzi" (affects visuals)
- **Handler:** ProjectileSystem.spawn_projectile() creates scene
- **Note:** Clients predict movement; server validates hits

---

#### `_rpc_despawn_projectile(projectile_id)`

- **Direction:** Server → All Clients
- **Authority:** `authority`, `reliable`
- **Frequency:** Per projectile life end
- **Purpose:** Remove projectile from scene
- **Parameters:**
  - `projectile_id: int` - ID of projectile to remove
- **Handler:** Deletes projectile node from tree

---

#### `_rpc_projectile_impact(projectile_id, impact_position, _legacy_trail_start_position)`

- **Direction:** Server → All Clients
- **Authority:** `authority`, `reliable`
- **Frequency:** Per hit
- **Purpose:** Notify all players of projectile impact
- **Parameters:**
  - `projectile_id: int` - Which projectile hit
  - `impact_position: Vector2` - Where it hit
  - `_legacy_trail_start_position: Vector2` - (unused, deprecated)
- **Handler:**
  - Despawns projectile at impact_position
  - Plays impact SFX
  - Spawns blood/surface particles
  - Server already applied damage (no RPC for that)

---

### Weapon System

#### `_rpc_player_ammo_update(target_peer_id, ammo_in_mag, ammo_reserve)`

- **Direction:** Server → All Clients
- **Authority:** `authority`, `reliable`
- **Frequency:** When magazine changes
- **Purpose:** Sync weapon ammo state
- **Parameters:**
  - `target_peer_id: int` - Whose ammo changed
  - `ammo_in_mag: int` - Current magazine count
  - `ammo_reserve: int` - Reserve ammo
- **Handler:** Updates UI ammo display

---

#### `_rpc_player_reload(peer_id)`

- **Direction:** Server → All Clients
- **Authority:** `authority`, `reliable`
- **Frequency:** When player starts reload
- **Purpose:** Trigger reload animation on all clients
- **Parameters:**
  - `peer_id: int` - Who is reloading
- **Handler:** Plays reload animation for that player's weapon visual

---

#### `_rpc_weapon_shot_sfx(peer_id, weapon_id)`

- **Direction:** Server → All Clients
- **Authority:** `authority`, `reliable`
- **Frequency:** Per shot
- **Purpose:** Play weapon fire sound for all players
- **Parameters:**
  - `peer_id: int` - Who shot
  - `weapon_id: String` - Which weapon
- **Handler:** Plays weapon-specific SFX from dictionary

---

#### `_rpc_weapon_reload_sfx(peer_id, weapon_id)`

- **Direction:** Server → All Clients
- **Authority:** `authority`, `reliable`
- **Frequency:** Per reload
- **Purpose:** Play reload sound
- **Parameters:**
  - `peer_id: int` - Who is reloading
  - `weapon_id: String` - Which weapon
- **Handler:** Plays reload SFX

---

### Combat Effects & Death

#### `_rpc_play_death_sfx(impact_position)`

- **Direction:** Server → All Clients
- **Authority:** `authority`, `reliable`
- **Frequency:** Per player death
- **Purpose:** Play death sound at impact location
- **Parameters:**
  - `impact_position: Vector2` - Where death occurred
- **Handler:** Plays death sound, emits particles at position

---

### Skills & Abilities

#### `_rpc_spawn_outrage_bomb(world_position, fuse_sec)`

- **Direction:** Server → All Clients
- **Authority:** `authority`, `reliable`
- **Frequency:** Per ability use
- **Purpose:** Spawn Outrage character's bomb ability
- **Parameters:**
  - `world_position: Vector2` - Center of explosion area
  - `fuse_sec: float` - Time until detonation
- **Handler:** Creates visual bomb, applies damage radius on timer

---

#### `_rpc_spawn_erebus_immunity(peer_id, duration_sec)`

- **Direction:** Server → All Clients
- **Authority:** `authority`, `reliable`
- **Frequency:** Per ability use
- **Purpose:** Apply Erebus immunity bubble
- **Parameters:**
  - `peer_id: int` - Who is protected
  - `duration_sec: float` - How long immunity lasts
- **Handler:** Renders visual effect, blocks damage on server-side

---

### Lobby Management

#### `_rpc_request_lobby_list()`

- **Direction:** Client → Server
- **Authority:** `any_peer`, `reliable`
- **Frequency:** When lobby list opened
- **Purpose:** Request current lobbies
- **Handler:** Server responds with lobby data via RPC

---

#### `_rpc_lobby_create(requested_name, payload)`

- **Direction:** Client → Server
- **Authority:** `any_peer`, `reliable`
- **Frequency:** Once per game session
- **Purpose:** Create a new lobby
- **Parameters:**
  - `requested_name: String` - Lobby name (user input)
  - `payload: String` - Additional JSON metadata
- **Handler:** Server validates, creates LobbyService entry, returns lobby_id

---

#### `_rpc_lobby_join(lobby_id, weapon_id, character_id)`

- **Direction:** Client → Server
- **Authority:** `any_peer`, `reliable`
- **Frequency:** When joining a lobby
- **Purpose:** Join an existing lobby
- **Parameters:**
  - `lobby_id: int` - ID of target lobby
  - `weapon_id: String` - Player's weapon choice
  - `character_id: String` - Player's character choice
- **Handler:** Server adds player to lobby, checks if game should start

---

#### `_rpc_lobby_leave(_legacy_a, _legacy_b)`

- **Direction:** Client → Server
- **Authority:** `any_peer`, `reliable`
- **Frequency:** When exiting lobby
- **Purpose:** Remove player from lobby
- **Parameters:** (deprecated, empty)
- **Handler:** Removes from LobbyService, updates member list

---

#### `_rpc_lobby_set_weapon(peer_or_weapon, weapon_id)`

- **Direction:** Client → Server
- **Authority:** `any_peer`, `reliable`
- **Frequency:** When player changes weapon selection
- **Purpose:** Update weapon choice in lobby
- **Parameters:** (two-signature method for backward compat)
- **Handler:** Updates lobby player data, broadcasts to lobby members

---

## Flow Diagrams

### Typical Game Loop

```
CLIENT                          SERVER                          CLIENTS
  │                               │                               │
  ├─────(InputFrame @90Hz)───────→│                               │
  │                               ├─(Simulate Player)             │
  │                               ├─(Projectile Raycasts)         │
  │                               ├─(Apply Damage)                │
  │                               ├─(Broadcast State @45Hz)──────→│
  │                               │                               ├─(Reconcile Pos)
  │                               │                               ├─(Predict Movement)
  │◄──────(StateSnapshot)─────────┤                               │
  │                               │                               │
  ├─────(PingRequest @0.75Hz)────→│                               │
  │◄────(PingResponse)────────────┤                               │
```

### Spawn Sequence

```
CLIENT                              SERVER
  │                                   │
  ├──(_rpc_request_spawn)────────────→│
  │                                   ├─(Validate Lobby)
  │                                   ├─(Pick Spawn Point)
  │◄───(_rpc_spawn_player)────────────┤ → ALL CLIENTS
  │                                   │
  ├─(Create NetPlayer Scene)          │
  ├─(Position at spawn_position)      │
  ├─(Set Weapon/Character Visuals)    │
```

---

## Important Notes

### Unreliable vs Reliable

- **Unreliable** = OK to drop, for frequent updates (input, movement)
- **Reliable** = Guaranteed delivery, for critical events (spawn, kills, items)

### Performance Considerations

- Input sent at 90 Hz (11ms intervals) - don't change without testing
- State broadcast at 45 Hz to balance latency vs bandwidth
- Projectile spawns are always reliable (critical for combat)
- Audio/SFX are reliable (no dropped gunshots!)

### Network Order

- Most projectile-adjacent RPCs use `unreliable_ordered` for chronological consistency
- Movement can use unreliable because we reconcile regularly
- Combat events always reliable

---

**Last Updated:** February 2026
