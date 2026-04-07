extends RefCounted

class_name PlayerLifecycleState

const DEATH_CHUNK_IMPULSE_MULTIPLIER := 130.0

var _player: CharacterBody2D
var _death_chunks_component_cb: Callable = Callable()
var _movement_component_cb: Callable = Callable()
var _surface_audio_component_cb: Callable = Callable()
var _status_visuals_component_cb: Callable = Callable()
var _damage_feedback_component_cb: Callable = Callable()
var _combat_state_component_cb: Callable = Callable()
var _presence_state_component_cb: Callable = Callable()
var _motion_sync_component_cb: Callable = Callable()
var _weapon_visual_component_cb: Callable = Callable()
var _resolved_damage_push_direction_cb: Callable = Callable()
var _set_health_cb: Callable = Callable()
var _get_max_health_cb: Callable = Callable()

func configure(
	player: CharacterBody2D,
	death_chunks_component_cb: Callable,
	movement_component_cb: Callable,
	surface_audio_component_cb: Callable,
	status_visuals_component_cb: Callable,
	damage_feedback_component_cb: Callable,
	combat_state_component_cb: Callable,
	presence_state_component_cb: Callable,
	motion_sync_component_cb: Callable,
	weapon_visual_component_cb: Callable,
	resolved_damage_push_direction_cb: Callable,
	set_health_cb: Callable,
	get_max_health_cb: Callable
) -> void:
	_player = player
	_death_chunks_component_cb = death_chunks_component_cb
	_movement_component_cb = movement_component_cb
	_surface_audio_component_cb = surface_audio_component_cb
	_status_visuals_component_cb = status_visuals_component_cb
	_damage_feedback_component_cb = damage_feedback_component_cb
	_combat_state_component_cb = combat_state_component_cb
	_presence_state_component_cb = presence_state_component_cb
	_motion_sync_component_cb = motion_sync_component_cb
	_weapon_visual_component_cb = weapon_visual_component_cb
	_resolved_damage_push_direction_cb = resolved_damage_push_direction_cb
	_set_health_cb = set_health_cb
	_get_max_health_cb = get_max_health_cb

func spawn_death_chunks_at(world_position: Vector2, incoming_velocity: Vector2 = Vector2.ZERO) -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		return
	var death_chunks_component: Variant = _death_chunks_component()
	if death_chunks_component == null:
		return
	var impulse: Vector2 = incoming_velocity
	if impulse.length_squared() <= 0.0001:
		impulse = _resolved_damage_push_direction() * DEATH_CHUNK_IMPULSE_MULTIPLIER
	death_chunks_component.clear_active_chunks()
	death_chunks_component.spawn_chunks_at(world_position, impulse, _player.visibility_layer)

func set_target_dummy_mode(enabled: bool, default_max_health: int) -> void:
	_player.set("target_dummy_mode", enabled)
	if not enabled:
		set_max_health(default_max_health)
		_player.target_health = clampi(int(_player.target_health), 0, default_max_health)
	_player.velocity = Vector2.ZERO
	_player.target_velocity = Vector2.ZERO
	_player.target_animation_on_floor = true
	var motion_sync_component: Variant = _motion_sync_component()
	if motion_sync_component != null:
		motion_sync_component.reset_for_target_dummy()

func is_target_dummy() -> bool:
	return bool(_player.get("target_dummy_mode"))

func force_respawn(spawn_position: Vector2, respawn_damage_immunity_sec: float) -> void:
	_player.global_position = spawn_position
	_player.target_position = spawn_position
	_player.velocity = Vector2.ZERO
	_player.target_velocity = Vector2.ZERO
	set_health(get_max_health())
	_player.target_health = get_max_health()
	_player.damage_push_direction = Vector2.ZERO
	_player.target_damage_push_direction = Vector2.ZERO
	_player.target_respawn_hidden = false

	var movement_component: Variant = _movement_component()
	if movement_component != null:
		movement_component.reset_jump_state()
	var surface_audio_component: Variant = _surface_audio_component()
	if surface_audio_component != null:
		surface_audio_component.reset_state()
	var status_visuals_component: Variant = _status_visuals_component()
	if status_visuals_component != null:
		status_visuals_component.reset_for_respawn()
	var damage_feedback_component: Variant = _damage_feedback_component()
	if damage_feedback_component != null:
		damage_feedback_component.reset_for_respawn()
	var combat_state_component: Variant = _combat_state_component()
	if combat_state_component != null:
		combat_state_component.reset_for_respawn()
		combat_state_component.set_damage_immune(respawn_damage_immunity_sec)
	var presence_state_component: Variant = _presence_state_component()
	if presence_state_component != null:
		presence_state_component.reset_for_respawn()
	var motion_sync_component: Variant = _motion_sync_component()
	if motion_sync_component != null:
		motion_sync_component.reset_for_respawn()
	var weapon_visual_component: Variant = _weapon_visual_component()
	if weapon_visual_component != null:
		weapon_visual_component.reset_after_respawn(float(_player.target_aim_angle))

func _resolved_damage_push_direction() -> Vector2:
	if _resolved_damage_push_direction_cb.is_valid():
		var value: Variant = _resolved_damage_push_direction_cb.call()
		if value is Vector2:
			return value as Vector2
	return Vector2.LEFT

func set_health(value: int) -> void:
	if _set_health_cb.is_valid():
		_set_health_cb.call(value)

func get_max_health() -> int:
	if _get_max_health_cb.is_valid():
		return int(_get_max_health_cb.call())
	return 0

func set_max_health(value: int) -> void:
	if _player.has_method("set_max_health"):
		_player.call("set_max_health", value)

func _death_chunks_component() -> Variant:
	if _death_chunks_component_cb.is_valid():
		return _death_chunks_component_cb.call()
	return null

func _movement_component() -> Variant:
	if _movement_component_cb.is_valid():
		return _movement_component_cb.call()
	return null

func _surface_audio_component() -> Variant:
	if _surface_audio_component_cb.is_valid():
		return _surface_audio_component_cb.call()
	return null

func _status_visuals_component() -> Variant:
	if _status_visuals_component_cb.is_valid():
		return _status_visuals_component_cb.call()
	return null

func _damage_feedback_component() -> Variant:
	if _damage_feedback_component_cb.is_valid():
		return _damage_feedback_component_cb.call()
	return null

func _combat_state_component() -> Variant:
	if _combat_state_component_cb.is_valid():
		return _combat_state_component_cb.call()
	return null

func _presence_state_component() -> Variant:
	if _presence_state_component_cb.is_valid():
		return _presence_state_component_cb.call()
	return null

func _motion_sync_component() -> Variant:
	if _motion_sync_component_cb.is_valid():
		return _motion_sync_component_cb.call()
	return null

func _weapon_visual_component() -> Variant:
	if _weapon_visual_component_cb.is_valid():
		return _weapon_visual_component_cb.call()
	return null
