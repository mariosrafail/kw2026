# Warrior System

## Overview

Each playable character (Outrage, Erebus) is a **Warrior** with 2 unique abilities:

- **Skill 1 (Q key)** - Primary ability
- **Skill 2 (E key)** - Secondary ability

The system uses a **composition pattern** where each warrior contains skill instances.

## Architecture

```
WarriorProfile (base class)
├── OutrageWarrior
│   ├── Skill1: OutrageBombSkill (Q) - Explosive projectile
│   └── Skill2: OutrageDamageBoostSkill (E) - Damage multiplier
│
└── ErebusWarrior
    ├── Skill1: ErebusImmunitySkill (Q) - Invulnerability
    └── Skill2: ErebusShieldSkill (E) - Protective barrier
```

## How Skills Work

### Server-Side (Authoritative)

```gdscript
# Player presses Q/E key
warrior.server_cast_skill(skill_number, peer_id, target_world)
  ↓
# Warrior delegates to skill
skill.server_cast(caster_peer_id, target_world)
  ↓
# Skill applies effects (damage, buffs, etc)
skill._execute_cast(caster_peer_id, target_world)
  ↓
# Broadcast to other clients
send_skill_cast_cb.call(...)
```

### Client-Side (Visual)

```gdscript
# RPC broadcast received
client_receive_skill_cast(skill_number, caster_peer_id, target_world)
  ↓
# Warrior delegates to skill
skill.client_receive_cast(caster_peer_id, target_world)
  ↓
# Skill plays visual effect
skill._execute_client_visual(caster_peer_id, target_world)
```

## File Structure

```
scripts/warriors/
├── warrior_profile.gd              # Base class for all warriors
├── warrior_factory.gd              # Creates warriors by ID
├── outrage_warrior.gd              # Outrage implementation
├── erebus_warrior.gd               # Erebus implementation
└── skills/
    ├── skill.gd                    # Base class for all skills
    ├── outrage_bomb_skill.gd       # Outrage Q ability
    ├── outrage_damage_boost_skill.gd  # Outrage E ability (TODO)
    ├── erebus_immunity_skill.gd    # Erebus Q ability
    └── erebus_shield_skill.gd      # Erebus E ability (TODO)
```

## Creating a New Warrior

### 1. Create Warrior Class

```gdscript
# scripts/warriors/my_warrior.gd
extends WarriorProfile

const MY_SKILL1 := preload("res://scripts/warriors/skills/my_skill1.gd")
const MY_SKILL2 := preload("res://scripts/warriors/skills/my_skill2.gd")

func _init() -> void:
    super._init("my_warrior_id", "My Warrior Name")

func _init_skills() -> void:
    skill1 = MY_SKILL1.new()
    skill2 = MY_SKILL2.new()
```

### 2. Create Skill Classes

```gdscript
# scripts/warriors/skills/my_skill1.gd
extends Skill

func _init() -> void:
    super._init("my_skill1_id", "Skill Name", 5.0, "Description")

func _execute_cast(caster_peer_id: int, target_world: Vector2) -> void:
    # Server-side logic: damage, effects, etc
    pass

func _execute_client_visual(caster_peer_id: int, target_world: Vector2) -> void:
    # Client-side: visual effects only
    pass
```

### 3. Register in WarriorFactory

```gdscript
# scripts/warriors/warrior_factory.gd
const MY_WARRIOR := preload("res://scripts/warriors/my_warrior.gd")

static func create_warrior(warrior_id: String) -> WarriorProfile:
    match warrior_id.to_lower():
        "my_warrior_id":
            return MY_WARRIOR.new()
        # ... other warriors ...
```

## Usage Example

```gdscript
# Create a warrior
var warrior = WarriorFactory.create_warrior("outrage")

# Configure with game state
warrior.configure(state_refs, callbacks)

# Server: Cast skill
warrior.server_cast_skill(1, peer_id, target_position)

# Client: Receive skill
warrior.client_receive_skill_cast(1, caster_peer_id, target_position)

# Tick cooldowns every frame
warrior.server_tick_cooldowns(delta)

# Check cooldown (for UI)
var remaining = warrior.get_skill_cooldown_remaining(1, peer_id)
var max = warrior.get_skill_cooldown_max(1)
```

## Skill Lifecycle

### Cooldown Tracking

- Each skill has a `cooldown_sec` maximum
- Per-player cooldown stored in `skill.skill_cooldown_remaining[peer_id]`
- Decremented by `skill.server_tick_cooldowns(delta)`
- Checked by `skill.can_cast(peer_id)` before allowing cast

### Server-Side Validation

- Check if player is in valid game state
- Check if player has enough resources (mana, ammo, etc)
- Apply cooldown
- Execute skill effects
- Broadcast result to other clients

### Network Synchronization

- Input received on server only
- Server validates & applies effect
- Server broadcasts RPC to all clients
- Clients play visual effect (non-gameplay)

## Current Warriors

### Outrage

| Skill        | Key | Cooldown | Effect                                      |
| ------------ | --- | -------- | ------------------------------------------- |
| Bomb Blast   | Q   | 5s       | Explosive projectile, 50 dmg in 64px radius |
| Damage Boost | E   | 8s       | 50% damage multiplier for 4s (TODO)         |

### Erebus

| Skill    | Key | Cooldown | Effect                          |
| -------- | --- | -------- | ------------------------------- |
| Immunity | Q   | 10s      | Invulnerability for 5s          |
| Shield   | E   | 8s       | 30 HP protective barrier (TODO) |

## TODO / In Progress

- [ ] Outrage Damage Boost - implement damage tracking and multiplier
- [ ] Erebus Shield - implement absorb damage mechanics
- [ ] Visual effects for all skills (animations, particles)
- [ ] Sound effects for all skills
- [ ] UI cooldown timers
- [ ] Skill tooltips in character select
- [ ] Balance pass (cooldowns, damage, duration)

---

**Last Updated:** February 2026
