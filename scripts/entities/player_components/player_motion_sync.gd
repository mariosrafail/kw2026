extends RefCounted

class_name PlayerMotionSync

const SNAP_LERP_SPEED_X := 14.0
const SNAP_LERP_SPEED_Y := 10.0
const AIM_LERP_SPEED := 20.0
const REMOTE_SNAP_DISTANCE := 150.0
const REMOTE_VELOCITY_BLEND := 0.45
const ANIMATION_AIR_VELOCITY_THRESHOLD := 24.0
const ANIMATION_FLOOR_GRACE_SEC := 0.09
const JUMP_TAKEOFF_FORCE_AIR_SEC := 0.11
const STAIR_DESCEND_MIN_FALL_SPEED := 28.0
const STAIR_DESCEND_MAX_FALL_SPEED := 210.0
const STAIR_DESCEND_MIN_HORIZONTAL_SPEED := 10.0

var _player: Node
var _movement_component_cb: Callable = Callable()
var _weapon_visual_component_cb: Callable = Callable()
var _modular_visual_cb: Callable = Callable()
var _surface_audio_component_cb: Callable = Callable()
var _set_forced_hidden_cb: Callable = Callable()
var _set_forced_sfx_suppressed_cb: Callable = Callable()
var _is_respawn_hidden_cb: Callable = Callable()
var _apply_player_facing_cb: Callable = Callable()
var _apply_gun_horizontal_flip_cb: Callable = Callable()
var _set_health_cb: Callable = Callable()

var _last_input_jump_held := false
var _animation_floor_grace_remaining_sec := 0.0
var _jump_takeoff_force_air_remaining_sec := 0.0

func configure(
	player: Node,
	movement_component_cb: Callable,
	weapon_visual_component_cb: Callable,
	modular_visual_cb: Callable,
	surface_audio_component_cb: Callable,
	set_forced_hidden_cb: Callable,
	set_forced_sfx_suppressed_cb: Callable,
	is_respawn_hidden_cb: Callable,
	apply_player_facing_cb: Callable,
	apply_gun_horizontal_flip_cb: Callable,
	set_health_cb: Callable
) -> void:
	_player = player
	_movement_component_cb = movement_component_cb
	_weapon_visual_component_cb = weapon_visual_component_cb
	_modular_visual_cb = modular_visual_cb
	_surface_audio_component_cb = surface_audio_component_cb
	_set_forced_hidden_cb = set_forced_hidden_cb
	_set_forced_sfx_suppressed_cb = set_forced_sfx_suppressed_cb
	_is_respawn_hidden_cb = is_respawn_hidden_cb
	_apply_player_facing_cb = apply_player_facing_cb
	_apply_gun_horizontal_flip_cb = apply_gun_horizontal_flip_cb
	_set_health_cb = set_health_cb

func reset_for_target_dummy() -> void:
	_last_input_jump_held = false
	_animation_floor_grace_remaining_sec = 0.0
	_jump_takeoff_force_air_remaining_sec = 0.0
	_player.target_animation_on_floor = true

func reset_for_respawn() -> void:
	_last_input_jump_held = false
	_animation_floor_grace_remaining_sec = 0.0
	_jump_takeoff_force_air_remaining_sec = 0.0
	_player.target_respawn_hidden = false

func set_aim_angle(angle: float) -> void:
	_player.target_aim_angle = angle
	var weapon_visual_component = _weapon_visual_component()
	if weapon_visual_component != null:
		weapon_visual_component.set_aim_angle(angle, _player.use_network_smoothing)
	if _apply_player_facing_cb.is_valid():
		_apply_player_facing_cb.call(angle)
	if _apply_gun_horizontal_flip_cb.is_valid():
		_apply_gun_horizontal_flip_cb.call(angle)

func get_aim_angle() -> float:
	return float(_player.target_aim_angle)

func simulate_authoritative(delta: float, axis: float, jump_pressed: bool, jump_held: bool) -> void:
	_last_input_jump_held = jump_held
	var movement_component: Variant = _movement_component()
	var pre_jump_on_floor: bool = _player.is_on_floor()
	var pre_jump_coyote_ready: bool = movement_component != null and movement_component.coyote_time_left > 0.0
	if movement_component != null:
		movement_component.simulate_authoritative(delta, axis, jump_pressed, jump_held)
	if jump_pressed and (pre_jump_on_floor or pre_jump_coyote_ready) and _player.velocity.y < -ANIMATION_AIR_VELOCITY_THRESHOLD:
		_jump_takeoff_force_air_remaining_sec = JUMP_TAKEOFF_FORCE_AIR_SEC
	_player.target_position = _player.global_position
	_player.target_velocity = _player.velocity
	_player.target_aim_angle = get_aim_angle()

func is_jump_input_held() -> bool:
	return _last_input_jump_held

func apply_snapshot(new_position: Vector2, new_velocity: Vector2, new_aim_angle: float, new_health: int, part_animation_state: Dictionary = {}) -> void:
	_player.target_position = new_position
	_player.target_velocity = new_velocity
	_player.target_aim_angle = new_aim_angle
	_player.target_health = clampi(new_health, 0, _player.get_max_health())
	set_part_animation_state(part_animation_state)
	if not _player.use_network_smoothing:
		_player.global_position = _player.target_position
		_player.velocity = _player.target_velocity
		var weapon_visual_component: Variant = _weapon_visual_component()
		if weapon_visual_component != null:
			weapon_visual_component.set_aim_angle(_player.target_aim_angle, false)
		if _apply_player_facing_cb.is_valid():
			_apply_player_facing_cb.call(_player.target_aim_angle)
		if _apply_gun_horizontal_flip_cb.is_valid():
			_apply_gun_horizontal_flip_cb.call(_player.target_aim_angle)
		if _set_health_cb.is_valid():
			_set_health_cb.call(_player.target_health)

func set_part_animation_state(state: Dictionary) -> void:
	_player.target_animation_on_floor = bool(state.get("on_floor", _player.target_animation_on_floor))
	_player.target_respawn_hidden = bool(state.get("respawn_hidden", _player.target_respawn_hidden))
	var push_direction_value: Variant = state.get("damage_push_direction", Vector2.ZERO)
	if push_direction_value is Vector2:
		_player.target_damage_push_direction = push_direction_value as Vector2

func get_part_animation_state() -> Dictionary:
	return {
		"on_floor": _player.is_on_floor(),
		"respawn_hidden": _is_respawn_hidden(),
		"damage_push_direction": _player.damage_push_direction
	}

func tick(delta: float) -> void:
	if _jump_takeoff_force_air_remaining_sec > 0.0:
		_jump_takeoff_force_air_remaining_sec = maxf(0.0, _jump_takeoff_force_air_remaining_sec - delta)
	var floor_contact: bool = _player.is_on_floor()
	if floor_contact:
		_animation_floor_grace_remaining_sec = ANIMATION_FLOOR_GRACE_SEC
	elif _animation_floor_grace_remaining_sec > 0.0:
		_animation_floor_grace_remaining_sec = maxf(0.0, _animation_floor_grace_remaining_sec - delta)
	var local_animation_floor: bool = floor_contact or _animation_floor_grace_remaining_sec > 0.0
	if _jump_takeoff_force_air_remaining_sec > 0.0:
		local_animation_floor = false
	var local_stair_descend_blend := 0.0
	if (
		not floor_contact
		and _jump_takeoff_force_air_remaining_sec <= 0.0
		and _animation_floor_grace_remaining_sec > 0.0
		and absf(_player.velocity.x) >= STAIR_DESCEND_MIN_HORIZONTAL_SPEED
		and _player.velocity.y >= STAIR_DESCEND_MIN_FALL_SPEED
	):
		var speed_t := clampf(
			(_player.velocity.y - STAIR_DESCEND_MIN_FALL_SPEED) / (STAIR_DESCEND_MAX_FALL_SPEED - STAIR_DESCEND_MIN_FALL_SPEED),
			0.0,
			1.0
		)
		var grace_t := clampf(_animation_floor_grace_remaining_sec / ANIMATION_FLOOR_GRACE_SEC, 0.0, 1.0)
		local_stair_descend_blend = speed_t * grace_t
	var modular_visual: Variant = _modular_visual()
	if modular_visual != null:
		var animation_on_floor: bool = local_animation_floor
		var animation_stair_descend_blend := local_stair_descend_blend
		if _player.use_network_smoothing:
			animation_on_floor = _player.target_animation_on_floor and absf(_player.target_velocity.y) < ANIMATION_AIR_VELOCITY_THRESHOLD
			animation_stair_descend_blend = 0.0
		modular_visual.update_walk_animation(
			delta,
			_player.velocity if not _player.use_network_smoothing else _player.target_velocity,
			animation_on_floor,
			animation_stair_descend_blend
		)
	var surface_audio_component: Variant = _surface_audio_component()
	if surface_audio_component != null:
		var audio_on_floor: bool = local_animation_floor
		var audio_velocity: Vector2 = _player.velocity
		if _player.use_network_smoothing:
			audio_on_floor = _player.target_animation_on_floor and absf(_player.target_velocity.y) < ANIMATION_AIR_VELOCITY_THRESHOLD
			audio_velocity = _player.target_velocity
		surface_audio_component.tick(delta, audio_velocity, audio_on_floor)
	if _player.use_network_smoothing:
		if _set_forced_hidden_cb.is_valid():
			_set_forced_hidden_cb.call("respawn_wait", _player.target_respawn_hidden)
		if _set_forced_sfx_suppressed_cb.is_valid():
			_set_forced_sfx_suppressed_cb.call("respawn_wait", _player.target_respawn_hidden)
	else:
		return
	var position_error: Vector2 = _player.target_position - _player.global_position
	if position_error.length() > REMOTE_SNAP_DISTANCE:
		_player.global_position = _player.target_position
		_player.velocity = _player.target_velocity
	else:
		_player.global_position.x = lerpf(_player.global_position.x, _player.target_position.x, min(1.0, delta * SNAP_LERP_SPEED_X))
		_player.global_position.y = lerpf(_player.global_position.y, _player.target_position.y, min(1.0, delta * SNAP_LERP_SPEED_Y))
		_player.velocity = _player.velocity.lerp(_player.target_velocity, REMOTE_VELOCITY_BLEND)
	var weapon_visual_component: Variant = _weapon_visual_component()
	if weapon_visual_component != null:
		weapon_visual_component.tick_aim_smoothing(delta, _player.target_aim_angle, AIM_LERP_SPEED)
	if _apply_player_facing_cb.is_valid():
		_apply_player_facing_cb.call(_player.target_aim_angle)
	if _apply_gun_horizontal_flip_cb.is_valid():
		_apply_gun_horizontal_flip_cb.call(_player.target_aim_angle)
	if _player.get_health() != _player.target_health and _set_health_cb.is_valid():
		_set_health_cb.call(_player.target_health)

func _movement_component():
	if _movement_component_cb.is_valid():
		return _movement_component_cb.call()
	return null

func _weapon_visual_component():
	if _weapon_visual_component_cb.is_valid():
		return _weapon_visual_component_cb.call()
	return null

func _modular_visual():
	if _modular_visual_cb.is_valid():
		return _modular_visual_cb.call()
	return null

func _surface_audio_component():
	if _surface_audio_component_cb.is_valid():
		return _surface_audio_component_cb.call()
	return null

func _is_respawn_hidden() -> bool:
	if _is_respawn_hidden_cb.is_valid():
		return bool(_is_respawn_hidden_cb.call())
	return false
