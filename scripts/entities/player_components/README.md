# Player Components System

## Overview

The `NetPlayer` entity (player.gd) is composed of several modular components that handle different aspects of player behavior. These are NOT Godot nodes but rather GDScript files that contain functions and state related to their domain.

**Location:** `scripts/entities/player_components/`

## Components

### 1. player_movement.gd

**Purpose:** Handles player physics, velocity, and movement.

**Responsibilities:**

- Jump mechanics (coyote time, jump buffering)
- Gravity and fall speed calculations
- Velocity clamping and movement constraints
- Snap-to-ground behavior for smooth platforming
- Integration with CharacterBody2D physics

**Key Methods:**

- `process_input_movement()` - Apply axis input to velocity
- `apply_gravity()` - Update vertical velocity each frame
- `process_floor_snap()` - Maintain floor contact
- `get_effective_velocity()` - Return clamped velocity for physics

**Called From:** Player `_physics_process()`

---

### 2. player_weapon_visual.gd

**Purpose:** Manages gun sprite positioning and rotation.

**Responsibilities:**

- Position gun relative to player aim direction
- Handle gun recoil animation (kick-back effect after shot)
- Manage reload animation strip playback
- Clamp gun rotation to weapon-specific limits
- Track gun visual state (recoil progress, reload progress)

**Key Methods:**

- `update_gun_aim()` - Rotate gun toward mouse/aim point
- `apply_gun_recoil()` - Animate gun kick-back
- `update_reload_visual()` - Play reload animation strip
- `get_muzzle_world_position()` - Return gun barrel position (for projectiles)

**Visual State:**

- Gun sprites rendered as child of GunPivot node
- Muzzle marker for projectile spawn position

**Called From:** Player `_process()` for visual, `_physics_process()` for mechanics

---

### 3. player_modular_visual.gd

**Purpose:** Renders player body parts (head, torso, legs) independently.

**Responsibilities:**

- Switch between character skins (Outrage, Erebus)
- Render modular sprites (head, torso, legs) from sprite sheet
- Handle character visual configuration
- Manage layer ordering for proper depth

**Key Methods:**

- `set_character_visual()` - Load character sprites & configure regions
- `update_visual_rotation()` - Rotate torso/head toward aim direction
- `update_leg_positions()` - Offset leg sprites for animation

**Data:**

- Character ID determines which texture regions to use from sprite sheets
- `allHeads.png`, `allTorso.png`, `allLegs.png` contain sprite regions

**Called From:** Player setup and `_process()`

---

### 4. player_walk_animation.gd

**Purpose:** Handles step/walking animation.

**Responsibilities:**

- Detect movement changes (acceleration, deceleration, direction)
- Play footstep sound effects on ground contact
- Animate leg bob/stride during movement
- Track play state for efficiency

**Key Methods:**

- `update_walk_animation()` - Check if moving, play step sounds
- `should_play_step_sound()` - Debounce footstep audio

**Called From:** Player `_physics_process()`

---

### 5. player_fov.gd (Field of View)

**Purpose:** Detects enemies and objects within player's vision.

**Responsibilities:**

- Maintain FOV (vision cone) as a physics area
- Detect overlapping enemy players
- Report who is visible to the player
- Support visibility toggles (for UI, debugging)

**Key Methods:**

- `get_visible_players()` - Return list of visible NetPlayer nodes
- `is_player_visible()` - Check if specific peer is in FOV
- `update_fov_direction()` - Rotate FOV cone toward aim angle

**Detection Method:**

- Uses Area2D with cone-shaped collision (or circular approximation)
- Checks overlapping bodies each frame

**Usage:** Could be used for UI (highlight nearby enemies), combat (abilities), or HUD updates

---

### 6. player_vitals_hud.gd

**Purpose:** Displays health bar and vital information above player.

**Responsibilities:**

- Render health bar (visual representation of current/max HP)
- Position HUD above player's head
- Update color based on health status (green → red as damage taken)
- Hide/show based on player state (alive/dead)

**Key Methods:**

- `update_health_display()` - Refresh health bar based on current HP
- `set_target_player()` - Link HUD to a specific NetPlayer
- `on_player_damaged()` - Update visuals during damage

**Visual Elements:**

- ProgressBar or custom drawn rect showing health
- Text label showing numeric health (optional)

**Called From:** Player health changes, remote player sync

---

## Component Initialization

Components are initialized in `player.gd` during `_ready()`:

```gdscript
# Example (not actual code, for illustration):
func _ready() -> void:
    _init_movement()
    _init_weapon_visual()
    _init_modular_visual()
    _init_walk_animation()
    _init_fov()
    _init_vitals_hud()
```

Each component may have its own `_init_*()` or `configure()` method.

## Data Flow

```
PhysicsProcess_Loop:
  Input → player_movement (velocity)
         → player_weapon_visual (gun aim)
         → player_walk_animation (step sfx)

  Physics → CharacterBody2D.move_and_slide()
          (uses velocity from player_movement)

  Update → player_vitals_hud (health bar pos)
         → player_fov (vision detection)

Process_Loop:
  Visuals → player_modular_visual (sprite rotation)
          → player_weapon_visual (recoil, reload)
```

## Adding a New Component

To add a new component (e.g., `player_dash.gd`):

1. **Create file** in `scripts/entities/player_components/player_dash.gd`
2. **Define functions** for initialization and updates
3. **Call from player.gd** in appropriate loop (`_ready()`, `_process()`, `_physics_process()`)
4. **Test** with local player, then remote replication
5. **Document** changes in ARCHITECTURE.md

### Example Template:

```gdscript
# player_dash.gd - Handles dash ability
extends "res://scripts/entities/player.gd"

var dash_enabled := true
var dash_cooldown := 0.0
var dash_speed := 400.0

func _init_dash() -> void:
    # Called during player _ready()
    pass

func _physics_process_dash(delta: float) -> void:
    # Called each physics frame
    dash_cooldown -= delta
    if dash_cooldown < 0:
        dash_cooldown = 0

func can_dash() -> bool:
    return dash_enabled and dash_cooldown <= 0
```

---

## Known Issues

1. **Unclear Separation** - Not obvious which parts are components vs player core logic
2. **No Clear Interface** - Components don't have consistent method signatures
3. **Tight Coupling** - Components directly access player's `@onready` nodes
4. **No Comments** - Most components lack docstrings

## Future Improvements

- Create base `PlayerComponent` class with standard interface
- Use signals instead of direct function calls
- Separate visual-only from gameplay components
- Add validation for network replication of component state
