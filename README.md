# KW - Multiplayer 2D Shooter

A fast-paced multiplayer 2D shooter built with **Godot 4.3** and **C#** launcher/updater.

## Overview

KW is a competitive multiplayer game where players battle in arena maps with guns and special abilities.

**Key Features:**

- 🎮 Client-server multiplayer architecture
- 🔄 Real-time combat with lag compensation
- 🎯 Multiple weapons (AK47, Uzi) with unique mechanics
- ⚡ Character abilities (Outrage Bomb, Erebus Immunity)
- 📍 Lobby system for matchmaking
- 🎨 Modular player visual system
- 📊 Auto-update system via launcher

**Tech Stack:**

- **Engine:** Godot 4.3 (GDScript)
- **Launcher:** C# WinForms with auto-update
- **Network:** Godot MultiplayerAPI (custom RPC protocol)
- **Container:** Docker support for server deployment

---

## Quick Start

### Local Development (Single Machine)

**Terminal 1 - Server:**

```bash
godot --mode=server --host=127.0.0.1 --port=8080
```

**Terminal 2 - Client 1:**

```bash
godot --mode=client --host=127.0.0.1 --port=8080
```

**Terminal 3 - Client 2:**

```bash
godot --mode=client --host=127.0.0.1 --port=8080
```

Then:

1. Client 2 clicks **Start Server** (optional, creates local server)
2. Both clients click **Connect**
3. Select weapon/character and create/join lobby
4. When 2+ players → game starts automatically

---

## Documentation

### 📖 Must-Read

- [ARCHITECTURE.md](ARCHITECTURE.md) - System design, service architecture, RPC flow
- [docs/RPC_PROTOCOL.md](docs/RPC_PROTOCOL.md) - Complete RPC specification
- [REFACTORING_GUIDE.md](REFACTORING_GUIDE.md) - Plan for improving code organization

### 🧩 Component Guides

- [scripts/entities/player_components/README.md](scripts/entities/player_components/README.md) - Player subsystems
- [scripts/constants/game_constants.gd](scripts/constants/game_constants.gd) - Centralized constants

### 🐛 Troubleshooting

- Check `server_headless.log` for server errors
- Use `tools/diag_map_catalog.gd` to validate map system
- Enable logs in UI (check Status label)

---

## Directory Structure

```
scripts/
├── app/                           # Core runtime (needs refactoring)
│   ├── runtime_shared.gd          # Base class, constants
│   ├── runtime_world_logic.gd     # Game state, player tracking
│   ├── runtime_session_logic.gd   # Network session management
│   ├── runtime_setup_logic.gd     # Service initialization
│   ├── runtime_rpc_logic.gd       # RPC handlers
│   ├── runtime_controller.gd      # Main loop
│   └── main_runtime.gd            # Godot entry point
│
├── combat/                        # Combat mechanics
│   ├── combat_flow_service.gd     # Server-side combat sim
│   ├── projectile_system.gd       # Projectile lifecycle
│   └── hit_damage_resolver.gd     # Damage calculation
│
├── entities/                      # Game objects
│   ├── player.gd                  # NetPlayer (main class)
│   ├── bullet.gd                  # Projectile
│   └── player_components/         # Player subsystems
│       ├── player_movement.gd
│       ├── player_weapon_visual.gd
│       ├── player_modular_visual.gd
│       ├── README.md              # Component guide
│       └── ...
│
├── network/                       # Multiplayer
│   ├── session_controller.gd      # Connection management
│   ├── player_replication.gd      # State sync
│   ├── client_rpc_flow_service.gd # Client-side RPC handlers
│   └── connect_retry.gd
│
├── lobby/                         # Matchmaking
│   ├── lobby_service.gd
│   ├── lobby_flow_controller.gd
│   └── lobby_config.gd
│
├── world/                         # Maps & spawning
│   ├── map_catalog.gd             # Map registry
│   ├── map_controller.gd          # Base map class
│   ├── classic_map_controller.gd
│   ├── cyber_map_controller.gd
│   ├── spawn_flow_service.gd
│   └── ...
│
├── weapons/                       # Gun mechanics
│   ├── weapon_profile.gd          # Base class
│   ├── ak47.gd
│   ├── uzi.gd
│
├── skills/                        # Character abilities
│   ├── skills_service.gd
│   ├── outrage_bomb_skill.gd
│   └── erebus_immunity_skill.gd
│
├── effects/                       # Visual & audio
│   ├── camera_shake.gd
│   └── combat_effects.gd
│
├── input/                         # Input handling
│   ├── client_input_controller.gd
│
├── ui/                            # UI
│   ├── ui_controller.gd
│   └── lobby_ui_builder.gd
│
└── constants/                     # Centralized config
    └── game_constants.gd          # All magic numbers/strings

scenes/
├── lobby.tscn                     # Lobby scene (main entry)
├── main.tscn                      # Classic map gameplay
├── main_cyber.tscn                # Cyber map variant
├── main_test.tscn                 # Dev testing playground
├── entities/
│   ├── player.tscn                # Player entity prefab
│   └── bullet.tscn                # Projectile prefab

assets/                            # Art & audio
├── warriors/                      # Character sprites
├── textures/                      # Game textures
├── maps/                          # Map backgrounds
├── sounds/
├── fonts/
└── ...

docs/
├── RPC_PROTOCOL.md                # Network message spec
└── ...

launcher/                          # C# Windows launcher
├── MainForm.cs                    # UI
├── Program.cs
├── launcher_config.json           # Server endpoint config
└── KwLauncher.csproj

tools/
├── export_windows.ps1             # Export game
├── make_release.ps1               # Create release build
├── build_launcher.ps1             # Build C# launcher
└── diag_map_catalog.gd            # Debug tool

build/                             # Output (not tracked)
└── kw.pck, kw.exe
```

---

## Key Systems

### Network Architecture

- **Authority:** Server controls game state, clients predict locally
- **Sync Rate:** Client inputs @90Hz, server broadcasts @45Hz
- **Lag Compensation:** RTT estimation + input history for projectiles
- **Reliability:** Combat events use reliable RPCs, movement uses unreliable

### Player Spawn Cycle

1. Client calls `_rpc_request_spawn()`
2. Server validates lobby/game state
3. Server broadcasts `_rpc_spawn_player()` to all clients
4. Clients instantiate NetPlayer scene at spawn point

### Combat Flow

1. Client holds shoot → sends input with `shoot_held=true`
2. Server checks ammo, fire cooldown, weapon config
3. Server RPC broadcasts `_rpc_spawn_projectile()`
4. All clients predict projectile movement
5. Server raycasts for hits each frame
6. On hit → RPC `_rpc_projectile_impact()` + `_rpc_despawn_player()` if kill

### Lobby System

1. Lobby scene loads with player count/config
2. Players select weapon/character
3. Create or join lobby (tracked in `LobbyService`)
4. When 2+ players → Start game (loads actual map)

---

## Configuration

### Network

**File:** (CLI args or launcher_config.json)

```bash
godot --mode=server --host=0.0.0.0 --port=8080
godot --mode=client --host=my.server.com --port=8080
```

### Gameplay

**File:** [scripts/constants/game_constants.gd](scripts/constants/game_constants.gd)

- Weapon damage, fire rate, magazine size
- Character ability costs/cooldowns
- Player movement speed, jump height
- Network timing constants

### Launcher

**File:** `launcher/launcher_config.json`

```json
{
  "game_exe": "kw.exe",
  "server_endpoint": "localhost:8080",
  "update_manifest_url": "https://example.com/manifest.json"
}
```

---

## Development Workflow

### Running Tests

```bash
godot --headless -s tools/diag_map_catalog.gd  # Validate maps
```

### Building Release

```powershell
.\tools\make_release.ps1        # Creates build/release/
.\tools\export_windows.ps1      # Exports game to kw.exe
.\tools\build_launcher.ps1      # Builds C# launcher
```

### Docker Server

```bash
docker-compose -f docker-compose.server.yml up
```

---

## Known Issues & Tech Debt

⚠️ **High Priority:**

- **Deep Inheritance Chain** in `/scripts/app/` - See [REFACTORING_GUIDE.md](REFACTORING_GUIDE.md)
- **Callback-based DI** in services is error-prone, lacks type safety
- **Magic strings** for IDs scattered across codebase (now centralized in [GameConstants](scripts/constants/game_constants.gd))

⚠️ **Medium Priority:**

- RPC protocol lacks formal specification (now documented in [RPC_PROTOCOL.md](docs/RPC_PROTOCOL.md))
- Player components have unclear relationships
- Limited error handling on network disconnects
- No DTOs for network messages (using loose dictionaries)

⚠️ **Low Priority:**

- Build artifacts tracked in .gitignore (minor)
- Player components could use signals instead of direct calls
- Missing unit tests

---

## Contributing

### Code Style

- Use snake_case for functions/variables
- Use CONSTANT_CASE for constants
- Classes use PascalCase with `class_name` declaration
- Add comments for complex logic, especially RPC handlers

### Adding Features

1. Create feature branch: `git checkout -b feature/my-feature`
2. Implement changes
3. Test locally (server + 2+ clients)
4. Update docs if adding new systems
5. Commit: `git commit -m "Add feature: X"`
6. Push & create PR

### Documentation

- Update [ARCHITECTURE.md](ARCHITECTURE.md) if changing major systems
- Update [docs/RPC_PROTOCOL.md](docs/RPC_PROTOCOL.md) if adding RPC calls
- Add comments to complex code
- Update this README if changing project structure

---

## Deployment

### Windows Build

```powershell
.\tools\export_windows.ps1
# Output: build/kw.exe, build/kw.pck
```

### Server Deployment

```bash
# Docker
docker-compose -f docker-compose.server.yml up -d

# Manual
godot --headless --mode=server --host=0.0.0.0 --port=8080
```

### Update Distribution

- Build → `build/release/kw.exe` + `build/release/kw.pck`
- Create manifest → `build/release/update_manifest.json`
- Upload to CDN
- Launcher auto-detects and prompts for update

---

## Support & Debugging

### Common Issues

**Connection refuses**

```
Check: Is server running?
       Is port open?
       Check launcher_config.json host/port
```

**Physics not syncing**

```
Check: SNAPSHOT_RATE (45 Hz)
       INPUT_SEND_RATE (90 Hz)
       Network latency (high RTT?)
       Player history buffer (800ms)
```

**Projectile hit weirdness**

```
Check: Lag compensation values
       Raycasting in hit_damage_resolver
       Weapon offset/muzzle position
```

### Debug Mode

In-game logs: Check "Status" label in top-left  
Server logs: `server_headless.log`  
Map info: `godot --headless -s tools/diag_map_catalog.gd`

---

## License

(Add your license here)

---

**Last Updated:** February 2026  
**Engine:** Godot 4.3  
**Latest Version:** alpha-0.1.21
