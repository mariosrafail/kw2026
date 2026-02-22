# Refactoring Guide: Breaking Down scripts/app/

## Current Problem

The `scripts/app/` folder has a 7-level deep inheritance chain:

```
main.gd
  → main_runtime.gd
    → runtime_controller.gd
      → runtime_rpc_logic.gd
        → runtime_setup_logic.gd
          → runtime_session_logic.gd
            → runtime_world_logic.gd
              → runtime_shared.gd (base)
```

This makes it **difficult to understand** what code does what. Proposed refactoring uses **composition over inheritance**.

---

## Target Architecture

```
app/
├── services/              # Service registry & initialization
│   ├── service_registry.gd       (manages all services)
│   └── service_factory.gd        (creates services)
│
├── controllers/           # Business logic controllers
│   ├── game_controller.gd        (main game loop)
│   ├── session_controller.gd     (network session)
│   ├── combat_controller.gd      (combat logic)
│   └── player_controller.gd      (player management)
│
├── handlers/              # RPC & event handlers
│   ├── rpc_handler.gd           (dispatches RPC calls)
│   ├── spawn_handler.gd         (spawn/despawn logic)
│   ├── combat_handler.gd        (projectile/damage RPCs)
│   └── input_handler.gd         (input processing)
│
├── state/                 # Centralized game state
│   ├── game_state.gd            (players, lobbies, world)
│   └── network_state.gd         (peers, connections)
│
└── runtime_main.gd        (entry point, composes controllers)
```

---

## Step-by-Step Refactoring Plan

### Phase 0: Preparation (No Breaking Changes)

#### Step 1: Create Service Registry

**File:** `scripts/app/services/service_registry.gd`

```gdscript
extends RefCounted
class_name ServiceRegistry

var services: Dictionary = {}

func register_service(name: String, service: Object) -> void:
    services[name] = service

func get_service(name: String) -> Variant:
    return services.get(name, null)

# Convenience methods
func get_player_replication() -> PlayerReplication:
    return get_service("player_replication") as PlayerReplication

func get_combat_flow() -> CombatFlowService:
    return get_service("combat_flow") as CombatFlowService

func get_map_catalog() -> MapCatalog:
    return get_service("map_catalog") as MapCatalog

# ... more getters for each service
```

**How to Integrate:**

1. In `runtime_setup_logic._init_services()`, create a `ServiceRegistry` instance
2. Register each service: `service_registry.register_service("combat_flow", combat_flow_service)`
3. Pass `service_registry` to functions instead of individual services
4. Update service configure() calls: `service.configure({...}, callbacks)`

**Benefits:**

- Single point of access for all services
- Easier to test (can mock ServiceRegistry)
- Clearer dependencies

---

#### Step 2: Extract RPC Dispatcher

**File:** `scripts/app/handlers/rpc_handler.gd`

Create a central class that handles all RPC dispatching:

```gdscript
extends RefCounted
class_name RpcHandler

var multiplayer: MultiplayerAPI
var service_registry: ServiceRegistry
var player_replication: PlayerReplication
var combat_flow: CombatFlowService
# ... other dependencies

func _init(multiplayer: MultiplayerAPI, registry: ServiceRegistry) -> void:
    self.multiplayer = multiplayer
    self.service_registry = registry
    self.player_replication = registry.get_player_replication()
    self.combat_flow = registry.get_combat_flow()

# RPC handlers moved from main.gd
func rpc_request_spawn() -> void:
    if not multiplayer.is_server():
        return
    # ... existing logic

func rpc_spawn_player(peer_id: int, spawn_position: Vector2, ...) -> void:
    # ... existing logic

func rpc_submit_input(axis: float, jump_pressed: bool, ...) -> void:
    # ... existing logic

# ... all other RPCs
```

**Integration Steps:**

1. Copy logic from `runtime_rpc_logic.gd` methods
2. Create `RpcHandler` instance in `runtime_controller._ready()`
3. Replace `@rpc` calls:

   ```gdscript
   # OLD:
   @rpc("any_peer", "reliable")
   func _rpc_request_spawn() -> void:
       # ... code

   # NEW:
   # In main.gd:
   @rpc("any_peer", "reliable")
   func _rpc_request_spawn() -> void:
       rpc_handler.rpc_request_spawn()
   ```

This keeps the `@rpc` decorators but delegates to handler class.

---

#### Step 3: Extract Player Management

**File:** `scripts/app/controllers/player_controller.gd`

```gdscript
extends RefCounted
class_name PlayerController

var players: Dictionary = {}
var player_display_names: Dictionary = {}
var peer_weapon_ids: Dictionary = {}
var peer_character_ids: Dictionary = {}
var multiplayer: MultiplayerAPI
var service_registry: ServiceRegistry

func _init(multiplayer, registry) -> void:
    self.multiplayer = multiplayer
    self.service_registry = registry

func spawn_local_player(peer_id: int, spawn_pos: Vector2, weapon_id: String, char_id: String) -> void:
    # Logic from _spawn_player_local()
    pass

func despawn_player(peer_id: int) -> void:
    # Logic from _remove_player_local()
    pass

func get_local_player() -> NetPlayer:
    var local_id = multiplayer.get_unique_id()
    return players.get(local_id)

func get_remote_player(peer_id: int) -> NetPlayer:
    return players.get(peer_id)

func get_all_players() -> Array:
    return players.values()
```

**Integration:**
Move player tracking logic from `runtime_world_logic.gd` → `PlayerController`

---

#### Step 4: Extract Combat Management

**File:** `scripts/app/controllers/combat_controller.gd`

```gdscript
extends RefCounted
class_name CombatController

var service_registry: ServiceRegistry
var multiplayer: MultiplayerAPI

func _init(multiplayer, registry) -> void:
    self.multiplayer = multiplayer
    self.service_registry = registry

func server_simulate_combat(delta: float) -> void:
    var combat = service_registry.get_combat_flow()
    # Logic from _physics_process() combat section

func apply_damage(victim_peer_id: int, damage: int, killer_peer_id: int) -> void:
    # Server-side damage application

func respawn_player(peer_id: int) -> void:
    # Server respawn logic
```

---

### Phase 1: Gradual Migration (Keep Existing Code Running)

**Key:** Never break the existing inheritance chain. Instead, gradually move logic OUT of it.

#### Week 1-2: Run Both Systems in Parallel

```gdscript
# runtime_controller.gd setup
func _ready() -> void:
    randomize()

    # Existing initialization
    _ensure_input_actions()
    _init_services()
    # ... etc ...

    # NEW: Create modern components in parallel
    service_registry = ServiceRegistry.new()
    _register_services_in_registry()  # New function

    rpc_handler = RpcHandler.new(multiplayer, service_registry)
    player_controller = PlayerController.new(multiplayer, service_registry)
    combat_controller = CombatController.new(multiplayer, service_registry)

    # OLD code still runs
    _setup_ui_defaults()
    # ... etc ...
```

#### Week 2-3: Start Delegating to New Controllers

In existing methods, call new controllers:

```gdscript
# runtime_rpc_logic._rpc_spawn_player()
@rpc("authority", "reliable")
func _rpc_spawn_player(peer_id, spawn_position, display_name, weapon_id, character_id) -> void:
    # Store in both old and new systems temporarily
    player_display_names[peer_id] = display_name

    # Delegate to new system
    player_controller.spawn_local_player(peer_id, spawn_position, weapon_id, character_id)

    # OLD system still runs for compat
    _spawn_player_local(peer_id, spawn_position)
```

#### Week 3-4: Cut Over to New System

Remove old implementations, point to new ones:

```gdscript
# OLD method now just delegates
func _spawn_player_local(peer_id: int, spawn_position: Vector2) -> void:
    player_controller.spawn_local_player(peer_id, spawn_position, "", "")
```

---

### Phase 2: Complete Migration

Once stable, remove old files:

- Delete `runtime_world_logic.gd`
- Delete `runtime_session_logic.gd`
- Delete `runtime_setup_logic.gd`
- Delete `runtime_rpc_logic.gd`
- Merge `runtime_controller.gd` and `runtime_shared.gd` into single `runtime_main.gd`

Final inheritance:

```
main.gd
  → runtime_main.gd (contains: initialization, _ready, _physics_process, UI refs)
  → components (ServiceRegistry, RpcHandler, PlayerController, etc.)
```

---

## Benefits of This Refactoring

✅ **Clarity** - Each class has single responsibility  
✅ **Testability** - Can unit test controllers without full game  
✅ **Maintainability** - Adding features doesn't require editing 5 files  
✅ **Extensibility** - Easy to add new controllers (e.g., `EnvironmentController`)  
✅ **Navigation** - Jump to specific controller instead of scrolling 500+ lines

---

## Alternative: Minimal Refactoring

If full refactoring is too risky, consider:

1. **Add comments to each file explaining what it does:**

   ```gdscript
   # runtime_world_logic.gd
   # Handles: Player tracking, lobby queries, state accessors
   # Dependencies: multiplayer, lobby_service, player_replication
   ```

2. **Create a "Router" class that redirects calls:**

   ```gdscript
   class_name AppRouter

   static func instance() -> RuntimeController:
       return get_tree().root.get_child(0)

   static func get_local_player() -> NetPlayer:
       return instance().get_local_player()
   ```

3. **Split files by domain (not inheritance):**
   ```
   app/
   ├── runtime_main.gd         (entry point)
   ├── world/
   │   ├── player_manager.gd
   │   └── lobby_manager.gd
   └── network/
       ├── session.gd
       └── replication.gd
   ```

---

## Risk Mitigation

**Before any changes:**

1. ✅ Version control all work (`git checkout -b refactor/app-structure`)
2. ✅ Run game and verify baseline works
3. ✅ Add tests for critical paths (spawn, combat, sync)
4. ✅ Make changes in small commits (1 controller at a time)
5. ✅ Test after each commit

**Fallback:**

- If something breaks, `git revert` last commit
- Red-green-refactor cycle: test BEFORE refactoring

---

## Recommended Approach

Given the risk, I recommend **Phase 0 + Comment-based approach**:

1. ✅ Add detailed comments to scripts/app/ files explaining what they do (1-2 hours)
2. ✅ Create ServiceRegistry and wire it in (safe, additive, 2-3 hours)
3. ⏳ Extract first small controller (PlayerController) and test thoroughly
4. 🎯 Complete controller extraction one-by-one as time permits

This gives immediate documentation benefit while reducing risk.

---

**Last Updated:** February 2026
