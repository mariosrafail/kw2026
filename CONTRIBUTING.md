# Contributing to KW

Thank you for contributing! This guide helps maintain code quality and consistency.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Code Style](#code-style)
3. [Architecture](#architecture)
4. [Testing](#testing)
5. [Documentation](#documentation)
6. [Submitting Changes](#submitting-changes)

---

## Getting Started

### Prerequisites

- Godot 4.3+ with C# support (optional, only needed for launcher modifications)
- PowerShell 5.1+ (for build scripts)
- Git

### Development Environment

1. **Clone & Setup**

   ```bash
   git clone <repo>
   cd kw_godot
   godot --mode=client --host=127.0.0.1 --port=8080
   ```

2. **Open Project**
   - Launch Godot 4.3
   - Open `c:\Users\mario\Documents\kw_godot\`
   - Set main scene to `scenes/lobby.tscn`

3. **Test Locally**

   ```bash
   # Terminal 1
   godot --mode=server --host=127.0.0.1 --port=8080

   # Terminal 2
   godot --mode=client --host=127.0.0.1 --port=8080

   # Terminal 3 (optional, second client)
   godot --mode=client --host=127.0.0.1 --port=8080
   ```

---

## Code Style

### GDScript Guidelines

#### Naming Conventions

```gdscript
# Classes (use class_name)
class_name MyService

# Functions & variables (snake_case)
func process_input(delta: float) -> void:
    pass

var player_position := Vector2.ZERO

# Constants (UPPER_SNAKE_CASE)
const MAX_PLAYERS := 8
const RELOAD_DURATION := 1.0

# Private functions (leading underscore)
func _init_services() -> void:
    pass

func _process_local_player(delta: float) -> void:
    pass

# Type hints (always use them)
func spawn_player(peer_id: int, position: Vector2) -> NetPlayer:
    pass
```

#### Formatting

```gdscript
# Line length: max 100 characters (soft), 120 (hard)

# Indentation: tabs (4 spaces)

# Blank lines: 2 between class-level sections
class_name MyClass

const MAX_HEALTH := 100

var players: Dictionary = {}


func _ready() -> void:
    # Ready implementation
    pass


func spawn_player(peer_id: int) -> void:
    # Spawn implementation
    pass
```

#### Comments

```gdscript
# Use comments to explain WHY, not WHAT

# ❌ Bad
var health := 100  # Set health to 100

# ✅ Good
# Start with full health for new players
var health := 100

# For complex logic, add multi-line comments
# This reconciliation formula blends server position with client prediction
# to smooth jittery movement while staying synchronized
var blended_position := server_position.lerp(predicted_position, 0.08)

# For RPC handlers, document authority & frequency
@rpc("authority", "reliable")
func _rpc_spawn_player(peer_id: int, position: Vector2) -> void:
    # Server broadcasts spawn to all clients
    # Called once per player per game
    pass
```

### C# Guidelines (Launcher)

```csharp
// Same as GDScript conventions
public class LauncherConfig
{
    public string GameExe { get; set; }
    public string ServerEndpoint { get; set; }

    // UPPER_SNAKE_CASE for constants
    private const string CONFIG_FILE = "launcher_config.json";
}
```

---

## Architecture

### Design Principles

1. **Single Responsibility** - Each class does one thing well
2. **Dependency Injection** - Pass dependencies, don't create them
3. **Composition over Inheritance** - Prefer services over deep inheritance chains
4. **Signal/Callback Architecture** - Use signals for decoupled communication

### Service Pattern

All major systems are RefCounted services:

```gdscript
extends RefCounted
class_name MyService

var dependency: OtherService

func configure(refs: Dictionary, callbacks: Dictionary) -> void:
    dependency = refs.get("dependency")
    # Register callbacks for events
    spawn_player_cb = callbacks.get("spawn_player", Callable())

func do_something() -> void:
    if spawn_player_cb.is_valid():
        spawn_player_cb.call(peer_id)
```

### RPC Best Practices

```gdscript
# ✅ DO:
# - Use @rpc decorators clearly
# - Document authority level
@rpc("authority", "reliable")
func _rpc_spawn_player(peer_id: int, pos: Vector2) -> void:
    pass

# - Use "_rpc_" prefix for remote procedures
# - Type all parameters
# - Handle authority checks

# ❌ DON'T:
# - Mix game logic with RPC handlers
# - Use loose dictionaries for complex data
# - Forget authority checks (if not multiplayer.is_server(): return)
# - Assume reliable delivery without @rpc("authority", "reliable")

# Correct pattern:
@rpc("any_peer", "reliable")
func _rpc_request_spawn() -> void:
    if not multiplayer.is_server():
        return
    # Logic here...
```

### Player Components

When adding player functionality:

```gdscript
# Use modular components in scripts/entities/player_components/
# Each component handles one aspect:
# - player_movement.gd = physics & velocity
# - player_weapon_visual.gd = gun rendering
# - player_modular_visual.gd = body sprites
# - player_fov.gd = vision detection
# - player_vitals_hud.gd = health display

# DON'T add everything to player.gd!
```

---

## Testing

### Local Testing

**Single Device (Multiple Clients):**

```bash
# Terminal 1: Headless server
godot --headless --mode=server --host=127.0.0.1 --port=8080 2>server.log

# Terminal 2-N: Clients
godot --mode=client --host=127.0.0.1 --port=8080
```

**Testing Checklist:**

- [ ] Lobby create/join works
- [ ] Both clients see each other
- [ ] Weapon swap updates for both
- [ ] Firing projectiles syncs
- [ ] Hit detection works
- [ ] Respawning works
- [ ] Disconnect/reconnect handled

### Critical Paths to Test Before Submitting

1. **Spawn/Despawn** - Create player → Check both clients see them
2. **Movement** - Move locally → Remote player follows smoothly
3. **Combat** - Fire → Projectile hits → Damage syncs → Kill triggers respawn
4. **Abilities** - Use ability → Effect visible to both players
5. **Network** - High ping/packet loss → Game stays playable

### Debugging Tools

```bash
# Check available maps
godot --headless -s tools/diag_map_catalog.gd

# Export test build
.\tools\export_windows.ps1

# Check launcher config
cat launcher/launcher_config.json
```

---

## Documentation

### When to Document

- ✅ Adding new service class
- ✅ Changing network protocol (RPC changes)
- ✅ Making architectural decisions
- ✅ Adding complex features (abilities, maps)
- ❌ Comment on obvious code (e.g., `health = 100` needs no comment)

### What to Update

**For new features:**

1. Add comments to code explaining WHY
2. Update [ARCHITECTURE.md](ARCHITECTURE.md) if system-level
3. Update [docs/RPC_PROTOCOL.md](docs/RPC_PROTOCOL.md) if adding RPC
4. Update this [CONTRIBUTING.md](CONTRIBUTING.md) if changing dev workflow

**For major refactoring:**

1. Create design doc (e.g., [REFACTORING_GUIDE.md](REFACTORING_GUIDE.md))
2. Update architecture overview
3. Add migration guide if breaking changes

### Documentation Template

```gdscript
# MyNewService.gd
## Service handling X functionality
##
## This service manages X, providing:
## - Method A: Does X
## - Method B: Does Y
##
## Configuration:
##   var refs = {"dependency": obj}
##   var cbs = {"callback_name": Callable()}
##   service.configure(refs, cbs)
##
## Usage:
##   my_service.do_thing()  # Returns result

extends RefCounted
class_name MyNewService
```

---

## Submitting Changes

### Before Submitting

```bash
# 1. Update your branch
git fetch origin
git rebase origin/main

# 2. Test locally (see Testing section)
godot --mode=server &
godot --mode=client &
# ... play test ...

# 3. Check for obvious issues
# - No hardcoded IPs/passwords
# - No debug code left in
# - Type hints on all functions
# - Comments on complex logic

# 4. Build & export
.\tools\export_windows.ps1
# Verify kw.exe runs without errors
```

### Creating a Pull Request

**Branch Naming:**

```
feature/add-shield-ability
bugfix/projectile-sync-delay
docs/add-network-guide
refactor/app-folder-structure
```

**Commit Messages:**

```
# Good
Add shield ability with cooldown tracking
Fix projectile spawn position offset
Update RPC protocol docs for new skill system

# Avoid
fix bug
update stuff
changes
```

**PR Description Template:**

```markdown
## Description

What does this PR do?

## Changes

- List of changes
- More changes

## Testing

How to verify this works?

## Related Issues

Fixes #123

## Checklist

- [ ] Tested locally with 2+ clients
- [ ] Updated ARCHITECTURE.md if applicable
- [ ] Updated docs/RPC_PROTOCOL.md if adding RPC
- [ ] Added comments to complex code
- [ ] All functions have type hints
```

### Code Review Expectations

Reviewers will check:

- ✅ Code style matches guidelines
- ✅ No obvious bugs
- ✅ Network sync is correct
- ✅ Documentation updated
- ✅ No breaking changes (or justified)

**Be prepared to:**

- Explain design decisions
- Add tests or debug steps
- Make requested changes
- Discuss alternatives

---

## Common Pitfalls

### ❌ Don't

```gdscript
# 1. Global state
var global_player_ref  # ❌ Hard to debug

# 2. No type hints
func process(data) -> void:  # ❌ What type is data?

# 3. Mixed concerns
func calculate_damage_and_spawn_ui() -> void:  # ❌ Do one thing!

# 4. Silent failures
hit_damage_resolver.apply_damage(peer_id, 50)
# ❌ What if peer_id doesn't exist?

# 5. Magic numbers
velocity.y += 1450.0 * delta  # ❌ What is 1450?

# 6. RPC without authority check
@rpc("any_peer", "reliable")
func _rpc_award_kill(peer_id: int) -> void:
    # ❌ Any client can call this!
    player_stats[peer_id]["kills"] += 1
```

### ✅ Do

```gdscript
# 1. Service injection
var hit_resolver: HitDamageResolver  # Passed in configure()

# 2. Strong typing
func process(data: Dictionary) -> void:

# 3. Single responsibility
func calculate_damage() -> int:
var spawn_impact_visuals(pos: Vector2) -> void:

# 4. Validation
var target_player = players.get(peer_id)
if target_player == null:
    push_error("Invalid peer_id: %d" % peer_id)
    return

# 5. Named constants
const GRAVITY := 1450.0
velocity.y += GRAVITY * delta

# 6. RPC with authority & error handling
@rpc("authority", "reliable")
func _rpc_award_kill(peer_id: int) -> void:
    if not "kills" in player_stats.get(peer_id, {}):
        player_stats[peer_id] = {"kills": 0, "deaths": 0}
    player_stats[peer_id]["kills"] += 1
```

---

## Health Checks

### Before Merging PR

Run these to ensure quality:

```bash
# 1. Lint check (look for obvious issues)
# (Godot has built-in GDScript LSP, use editor)

# 2. Export test
.\tools\export_windows.ps1
# Verify build succeeds

# 3. Launch test
kw.exe --mode=client

# 4. Documentation
# Verify related docs updated
```

---

## Questions?

**Documentation Issues:**

- Add comments to code clarifying confusion
- Update [README.md](README.md) or [ARCHITECTURE.md](ARCHITECTURE.md)

**Design Questions:**

- Open an issue
- Discuss approach before implementing
- Reference architecture decisions

**Communication:**

- Check [ARCHITECTURE.md](ARCHITECTURE.md#network-architecture)
- Check [docs/RPC_PROTOCOL.md](docs/RPC_PROTOCOL.md)
- Ask in PR / GitHub Issues

---

**Last Updated:** February 2026  
**Godot Version:** 4.3+
