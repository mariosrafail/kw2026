## Base class for all character skills (Q and E abilities)
##
## Each warrior has 2 skills: skill1 (Q key) and skill2 (E key)
## This base class defines the interface all skills must implement

extends RefCounted
class_name Skill

## Skill metadata
var skill_id: String = ""
var skill_name: String = ""
var cooldown_sec: float = 0.0
var description: String = ""

## Dependencies (shared between all skills)
var players: Dictionary = {}
var input_states: Dictionary = {}
var multiplayer: MultiplayerAPI
var projectile_system: ProjectileSystem
var hit_damage_resolver: HitDamageResolver
var camera_shake: CameraShake

## Callbacks for networking
var get_peer_lobby_cb: Callable = Callable()
var get_lobby_members_cb: Callable = Callable()
var send_skill_cast_cb: Callable = Callable()  # For custom skill RPC

# Per-player cooldown tracking
var skill_cooldown_remaining: Dictionary = {}

func _init(id: String, name: String, cooldown: float, desc: String = "") -> void:
	skill_id = id
	skill_name = name
	cooldown_sec = cooldown
	description = desc

## Configure shared dependencies
func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	players = state_refs.get("players", {})
	input_states = state_refs.get("input_states", {}) as Dictionary
	multiplayer = state_refs.get("multiplayer", null)
	projectile_system = state_refs.get("projectile_system", null)
	hit_damage_resolver = state_refs.get("hit_damage_resolver", null)
	camera_shake = state_refs.get("camera_shake", null)
	
	get_peer_lobby_cb = callbacks.get("get_peer_lobby", Callable())
	get_lobby_members_cb = callbacks.get("get_lobby_members", Callable())
	send_skill_cast_cb = callbacks.get("send_skill_cast", Callable())

## Check if player can cast (not on cooldown)
func can_cast(caster_peer_id: int) -> bool:
	var remaining = skill_cooldown_remaining.get(caster_peer_id, 0.0)
	return remaining <= 0.0

## Server-side skill cast
## Called when player presses Q (skill1) or E (skill2)
func server_cast(caster_peer_id: int, target_world: Vector2) -> void:
	if not multiplayer.is_server():
		return
	
	if not can_cast(caster_peer_id):
		return
	
	# Start cooldown
	skill_cooldown_remaining[caster_peer_id] = cooldown_sec
	
	# Subclasses override this for actual logic
	_execute_cast(caster_peer_id, target_world)

## Client-side visual effect
## Called when RPC broadcasts skill to all clients
func client_receive_cast(caster_peer_id: int, target_world: Vector2) -> void:
	_execute_client_visual(caster_peer_id, target_world)

## Tick cooldowns (called each frame on server)
func server_tick_cooldowns(delta: float) -> void:
	for peer_id in skill_cooldown_remaining.keys():
		skill_cooldown_remaining[peer_id] -= delta
		if skill_cooldown_remaining[peer_id] < 0:
			skill_cooldown_remaining[peer_id] = 0.0

# ============================================================================
# Virtual Methods - Subclasses Override These
# ============================================================================

## Server-side damage/effect application
## Subclasses should override
func _execute_cast(caster_peer_id: int, target_world: Vector2) -> void:
	push_error("Skill %s must implement _execute_cast()" % skill_id)

## Client-side visual effect
## Subclasses should override
func _execute_client_visual(caster_peer_id: int, target_world: Vector2) -> void:
	pass  # Optional override

# ============================================================================
# Utility Methods
# ============================================================================

func _get_peer_lobby(peer_id: int) -> int:
	if get_peer_lobby_cb.is_valid():
		return get_peer_lobby_cb.call(peer_id)
	return 0

func _get_lobby_members(lobby_id: int) -> Array:
	if get_lobby_members_cb.is_valid():
		return get_lobby_members_cb.call(lobby_id)
	return []

func _broadcast_to_lobby(lobby_id: int, callback_name: String, args: Array) -> void:
	"""Broadcast skill cast to all lobby members"""
	var members = _get_lobby_members(lobby_id)
	for member_value in members:
		var member_id = int(member_value)
		if send_skill_cast_cb.is_valid():
			var full_args = [member_id, callback_name] + args
			send_skill_cast_cb.callv(full_args)
