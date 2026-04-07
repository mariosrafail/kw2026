extends Skill

const KOTRO_BOMB_VFX := preload("res://scripts/warriors/vfx/kotro_bomb_vfx.gd")
const KOTRO_BOMB_TEXTURE := preload("res://assets/textures/kotroBomb.png")

const CHARACTER_ID_KOTRO := "kotro"
const BOMB_DURATION_SEC := 5.0
const BOMB_SPEED := 420.0
const BOMB_TURN_SPEED := 8.5
const BOMB_HIT_RADIUS_PX := 30.0
const BOMB_DIRECT_HIT_DAMAGE := 50
const BOMB_SPAWN_OFFSET := Vector2(0.0, -22.0)
const STATUS_TEXT := "Bomb Control"

var character_id_for_peer_cb: Callable = Callable()
var _active_bombs_by_peer: Dictionary = {}

func _init() -> void:
	super._init("kotro_remote_bomb", "Remote Bomb", 0.0, "Guide a bomb with the mouse while Kotro is locked in place")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable

func _execute_cast(caster_peer_id: int, target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_KOTRO:
		return
	var player := players.get(caster_peer_id, null) as NetPlayer
	if player == null:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	var spawn_position := player.global_position + BOMB_SPAWN_OFFSET
	_active_bombs_by_peer[caster_peer_id] = {
		"remaining": BOMB_DURATION_SEC,
		"lobby_id": lobby_id,
		"world_position": spawn_position,
		"velocity": Vector2.ZERO,
		"target_world": target_world,
		"detonated": false
	}
	_lock_caster_input(caster_peer_id, target_world)
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, target_world)

func _execute_client_visual(caster_peer_id: int, target_world: Vector2) -> void:
	_spawn_bomb_vfx(caster_peer_id, target_world)
	var player := players.get(caster_peer_id, null) as NetPlayer
	if player != null and player.has_method("start_ulti_duration_bar"):
		player.call("start_ulti_duration_bar", BOMB_DURATION_SEC, STATUS_TEXT)

func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if _active_bombs_by_peer.is_empty():
		return

	var finished_peers: Array[int] = []
	for peer_value in _active_bombs_by_peer.keys():
		var caster_peer_id := int(peer_value)
		var bomb_data := _active_bombs_by_peer.get(caster_peer_id, {}) as Dictionary
		var player := players.get(caster_peer_id, null) as NetPlayer
		if player == null or player.get_health() <= 0:
			finished_peers.append(caster_peer_id)
			continue
		var remaining := maxf(0.0, float(bomb_data.get("remaining", 0.0)) - delta)
		bomb_data["remaining"] = remaining
		_lock_caster_input(caster_peer_id, bomb_data.get("target_world", player.global_position) as Vector2)
		bomb_data = _tick_bomb_motion(caster_peer_id, bomb_data, delta)
		var hit_peer_id := _bomb_contact_peer(caster_peer_id, bomb_data)
		if hit_peer_id > 0:
			_detonate_bomb(caster_peer_id, bomb_data, hit_peer_id)
			finished_peers.append(caster_peer_id)
			continue
		_active_bombs_by_peer[caster_peer_id] = bomb_data
		if remaining <= 0.0:
			_detonate_bomb(caster_peer_id, bomb_data)
			finished_peers.append(caster_peer_id)

	for caster_peer_id in finished_peers:
		_active_bombs_by_peer.erase(caster_peer_id)

func is_action_locked(peer_id: int) -> bool:
	return _active_bombs_by_peer.has(peer_id)

func override_input_state(peer_id: int, base_state: Dictionary) -> Dictionary:
	if not _active_bombs_by_peer.has(peer_id):
		return base_state
	var out := base_state.duplicate(true)
	out["shoot_held"] = false
	out["boost_damage"] = false
	return out

func camera_focus_state(peer_id: int) -> Dictionary:
	if not _active_bombs_by_peer.has(peer_id):
		return {}
	var bomb := _bomb_vfx_for_peer(peer_id)
	if bomb == null:
		return {}
	return {
		"active": true,
		"position": bomb.global_position
	}

func _tick_bomb_motion(caster_peer_id: int, bomb_data: Dictionary, delta: float) -> Dictionary:
	var world_position := bomb_data.get("world_position", Vector2.ZERO) as Vector2
	var velocity := bomb_data.get("velocity", Vector2.ZERO) as Vector2
	var desired_target := _desired_target_world(caster_peer_id, world_position)
	bomb_data["target_world"] = desired_target
	var to_target := desired_target - world_position
	var desired_velocity := Vector2.ZERO
	if to_target.length_squared() > 4.0:
		desired_velocity = to_target.normalized() * BOMB_SPEED
	velocity = velocity.lerp(desired_velocity, min(1.0, delta * BOMB_TURN_SPEED))
	world_position += velocity * delta
	bomb_data["world_position"] = world_position
	bomb_data["velocity"] = velocity
	return bomb_data

func _desired_target_world(caster_peer_id: int, fallback_position: Vector2) -> Vector2:
	var state := input_states.get(caster_peer_id, {}) as Dictionary
	if state.has("aim_world"):
		return state.get("aim_world", fallback_position) as Vector2
	var player := players.get(caster_peer_id, null) as NetPlayer
	if player != null:
		return player.global_position + Vector2.RIGHT.rotated(player.get_aim_angle()) * 120.0
	return fallback_position

func _lock_caster_input(caster_peer_id: int, target_world: Vector2) -> void:
	var state := input_states.get(caster_peer_id, {}) as Dictionary
	if state.is_empty():
		return
	state["shoot_held"] = false
	state["boost_damage"] = false
	state["aim_world"] = target_world
	input_states[caster_peer_id] = state

func _detonate_bomb(caster_peer_id: int, bomb_data: Dictionary, hit_peer_id: int = 0) -> void:
	var lobby_id := int(bomb_data.get("lobby_id", _get_peer_lobby(caster_peer_id)))
	if lobby_id <= 0:
		return
	if hit_peer_id <= 0:
		return
	var target := players.get(hit_peer_id, null) as NetPlayer
	if target == null or target.get_health() <= 0:
		return
	var explosion_center := bomb_data.get("world_position", Vector2.ZERO) as Vector2
	var offset := target.global_position - explosion_center
	if hit_damage_resolver != null and hit_damage_resolver.has_method("server_apply_direct_damage"):
		hit_damage_resolver.server_apply_direct_damage(caster_peer_id, hit_peer_id, target, BOMB_DIRECT_HIT_DAMAGE, offset)

func _bomb_contact_peer(caster_peer_id: int, bomb_data: Dictionary) -> int:
	var lobby_id := int(bomb_data.get("lobby_id", _get_peer_lobby(caster_peer_id)))
	if lobby_id <= 0:
		return 0
	var bomb_position := bomb_data.get("world_position", Vector2.ZERO) as Vector2
	for peer_value in players.keys():
		var target_peer_id := int(peer_value)
		if target_peer_id == caster_peer_id:
			continue
		if _get_peer_lobby(target_peer_id) != lobby_id:
			continue
		var target := players.get(target_peer_id, null) as NetPlayer
		if target == null or target.get_health() <= 0:
			continue
		if target.global_position.distance_to(bomb_position) <= BOMB_HIT_RADIUS_PX:
			return target_peer_id
	return 0

func _spawn_bomb_vfx(caster_peer_id: int, initial_target_world: Vector2) -> void:
	if projectile_system == null or projectile_system.projectiles_root == null:
		return
	var existing := _bomb_vfx_for_peer(caster_peer_id)
	if existing != null:
		existing.queue_free()
	var vfx := KOTRO_BOMB_VFX.new()
	vfx.name = "KotroBomb_%d" % caster_peer_id
	vfx.caster_peer_id = caster_peer_id
	vfx.players = players
	vfx.multiplayer_api = multiplayer
	vfx.texture = KOTRO_BOMB_TEXTURE
	vfx.duration_sec = BOMB_DURATION_SEC
	vfx.speed = BOMB_SPEED
	vfx.turn_speed = BOMB_TURN_SPEED
	vfx.hit_radius = BOMB_HIT_RADIUS_PX
	vfx.spawn_offset = BOMB_SPAWN_OFFSET
	vfx.initial_target_world = initial_target_world
	projectile_system.projectiles_root.add_child(vfx)

func _bomb_vfx_for_peer(caster_peer_id: int) -> Node2D:
	if projectile_system == null or projectile_system.projectiles_root == null:
		return null
	return projectile_system.projectiles_root.get_node_or_null("KotroBomb_%d" % caster_peer_id) as Node2D

func _character_id_for_peer(peer_id: int) -> String:
	if character_id_for_peer_cb.is_valid():
		return str(character_id_for_peer_cb.call(peer_id)).strip_edges().to_lower()
	return CHARACTER_ID_KOTRO
