## GameConstants
## Centralized game configuration and constants
## Replaces magic strings scattered across the codebase

extends RefCounted
class_name GameConstants

# ============================================================================
# NETWORK
# ============================================================================

const DEFAULT_PORT := 8080
const MAX_CLIENTS := 8
const DEFAULT_HOST := "127.0.0.1"

# RPC & Synchronization Rates
const SNAPSHOT_RATE := 45.0        # Server broadcast frequency (Hz)
const INPUT_SEND_RATE := 90.0      # Client input frequency (Hz)
const PING_INTERVAL := 0.75        # Ping request interval (seconds)
const PLAYER_HISTORY_MS := 800     # Client prediction history (ms)
const MAX_INPUT_PACKETS_PER_SEC := 120
const MAX_REPORTED_RTT_MS := 300   # Maximum RTT for lag compensation
const MAX_INPUT_STALE_MS := 120    # Max input age before ignoring

# Client-side Prediction (Reconciliation)
const LOCAL_RECONCILE_SNAP_DISTANCE := 96.0      # Distance snap threshold (pixels)
const LOCAL_RECONCILE_VERTICAL_SNAP_DISTANCE := 6.0
const LOCAL_RECONCILE_POS_BLEND := 0.08          # Position smoothing factor
const LOCAL_RECONCILE_VEL_BLEND := 0.12          # Velocity smoothing factor

# ============================================================================
# WEAPONS
# ============================================================================

const WEAPON_ID_AK47 := "ak47"
const WEAPON_ID_UZI := "uzi"

const WEAPONS := {
	WEAPON_ID_AK47: {
		"name": "AK47",
		"projectile_speed": 5000,
		"base_damage": 5,
		"boost_damage": 100,
		"fire_interval": 0.10,
		"magazine_size": 25,
		"reload_duration": 1.0,
		"max_aim_distance": 2600.0,
		"max_spread_degrees": 1.2,
		"camera_shake": 20.0
	},
	WEAPON_ID_UZI: {
		"name": "Uzi",
		"projectile_speed": 8000,
		"base_damage": 3,
		"boost_damage": 65,
		"fire_interval": 0.055,
		"magazine_size": 60,
		"reload_duration": 1.0,
		"max_aim_distance": 2400.0,
		"max_spread_degrees": 3.2,
		"camera_shake": 5.0
	}
}

# ============================================================================
# CHARACTERS & ABILITIES
# ============================================================================

const CHARACTER_ID_OUTRAGE := "outrage"
const CHARACTER_ID_EREBUS := "erebus"
const CHARACTER_ID_TASKO := "tasko"

const CHARACTERS := {
	CHARACTER_ID_OUTRAGE: {
		"name": "Outrage",
		"ability": "Bomb",
		"description": "Explosive projectile ability"
	},
	CHARACTER_ID_EREBUS: {
		"name": "Erebus",
		"ability": "Immunity",
		"description": "Temporary invulnerability"
	},
	CHARACTER_ID_TASKO: {
		"name": "Tasko",
		"ability": "Invisibility + Mine",
		"description": "Stealth field and persistent mine"
	}
}

# ============================================================================
# MAPS
# ============================================================================

const MAP_ID_CLASSIC := "classic"
const MAP_ID_CYBER := "cyber"
const MAP_ID_TEST := "test"

const MAPS := {
	MAP_ID_CLASSIC: {
		"name": "Classic",
		"scene_path": "res://scenes/main.tscn",
		"max_players": 2,
		"description": "Original warriors arena"
	},
	MAP_ID_CYBER: {
		"name": "Cyber",
		"scene_path": "res://scenes/main_cyber.tscn",
		"max_players": 2,
		"description": "Futuristic variant"
	},
	MAP_ID_TEST: {
		"name": "Test",
		"scene_path": "res://scenes/main_test.tscn",
		"max_players": 2,
		"description": "Development map"
	}
}

# ============================================================================
# PLAYER & GAMEPLAY
# ============================================================================

const MAX_HEALTH := 100
const PLAYER_HIT_RADIUS := 12.0

# Movement constants
const PLAYER_SPEED := 245.0
const PLAYER_JUMP_VELOCITY := -650.0
const PLAYER_GRAVITY := 1450.0
const PLAYER_FALL_GRAVITY_MULTIPLIER := 1.35
const PLAYER_MAX_FALL_SPEED := 1300.0
const PLAYER_JUMP_RELEASE_DAMP := 0.55
const PLAYER_COYOTE_TIME := 0.16
const PLAYER_JUMP_BUFFER_TIME := 0.1

# ============================================================================
# ENVIRONMENT
# ============================================================================

const CAMERA_VIEWPORT_WIDTH := 640
const CAMERA_VIEWPORT_HEIGHT := 180
const WINDOW_WIDTH_OVERRIDE := 1280
const WINDOW_HEIGHT_OVERRIDE := 720

# ============================================================================
# COMMAND-LINE ARGUMENTS
# ============================================================================

const ARG_MODE_PREFIX := "--mode="
const ARG_HOST_PREFIX := "--host="
const ARG_PORT_PREFIX := "--port="
const ARG_NO_AUTOSTART := "--no-autostart"

# ============================================================================
# UTILITY METHODS
# ============================================================================

static func is_valid_weapon_id(weapon_id: String) -> bool:
	return WEAPONS.has(weapon_id.to_lower())

static func is_valid_character_id(character_id: String) -> bool:
	return CHARACTERS.has(character_id.to_lower())

static func is_valid_map_id(map_id: String) -> bool:
	return MAPS.has(map_id.to_lower())

static func normalize_weapon_id(weapon_id: String) -> String:
	var normalized := weapon_id.strip_edges().to_lower()
	if is_valid_weapon_id(normalized):
		return normalized
	return WEAPON_ID_AK47  # Default fallback

static func normalize_character_id(character_id: String) -> String:
	var normalized := character_id.strip_edges().to_lower()
	if is_valid_character_id(normalized):
		return normalized
	return CHARACTER_ID_OUTRAGE  # Default fallback

static func normalize_map_id(map_id: String) -> String:
	var normalized := map_id.strip_edges().to_lower()
	if is_valid_map_id(normalized):
		return normalized
	return MAP_ID_CLASSIC  # Default fallback

static func get_weapon_name(weapon_id: String) -> String:
	if WEAPONS.has(weapon_id):
		return WEAPONS[weapon_id].get("name", "Unknown")
	return "Unknown"

static func get_character_name(character_id: String) -> String:
	if CHARACTERS.has(character_id):
		return CHARACTERS[character_id].get("name", "Unknown")
	return "Unknown"

static func get_map_name(map_id: String) -> String:
	if MAPS.has(map_id):
		return MAPS[map_id].get("name", "Unknown")
	return "Unknown"
