extends RefCounted
class_name ClientInputController

var players: Dictionary = {}
var multiplayer: MultiplayerAPI
var main_camera: Camera2D
var camera_shake: CameraShake

var submit_input_cb: Callable = Callable()
var is_gameplay_locked_cb: Callable = Callable()
var override_input_state_cb: Callable = Callable()
var camera_focus_state_cb: Callable = Callable()
var weapon_id_for_peer_cb: Callable = Callable()
var input_send_rate := 60.0
var idle_input_send_rate := 12.0

var _input_send_accumulator := 0.0
var _cached_local_input_state: Dictionary = {}
var _local_last_non_zero_move_axis := 1.0
var _last_sent_axis := 0.0
var _last_sent_jump_held := false
var _last_sent_shoot_held := false
var _camera_follow_position := Vector2.ZERO
var _camera_mouse_look_offset := Vector2.ZERO
var _base_camera_zoom := Vector2.ONE
var _camera_zoom_initialized := false

const CAMERA_FOLLOW_LERP_SPEED := 8.0
const CAMERA_MOUSE_LOOK_LERP_SPEED := 10.0
const CAMERA_MOUSE_LOOK_MAX_OFFSET := Vector2(80.0, 50.0)
const CAMERA_MOUSE_LOOK_SHIFT_MULTIPLIER := 2.65
const CAMERA_MOUSE_LOOK_DEADZONE := 0.24
const CAMERA_MOUSE_LOOK_CURVE := 1.35
const WEAPON_ID_KAR := "kar"
const KAR_CAMERA_ZOOM := Vector2(0.84, 0.84)
const CAMERA_ZOOM_LERP_SPEED := 7.0

func configure(refs: Dictionary, callbacks: Dictionary, config: Dictionary = {}) -> void:
	players = refs.get("players", {}) as Dictionary
	multiplayer = refs.get("multiplayer", null) as MultiplayerAPI
	main_camera = refs.get("main_camera", null) as Camera2D
	camera_shake = refs.get("camera_shake", null) as CameraShake

	submit_input_cb = callbacks.get("submit_input", Callable()) as Callable
	is_gameplay_locked_cb = callbacks.get("is_gameplay_locked", Callable()) as Callable
	override_input_state_cb = callbacks.get("override_input_state", Callable()) as Callable
	camera_focus_state_cb = callbacks.get("camera_focus_state", Callable()) as Callable
	weapon_id_for_peer_cb = callbacks.get("weapon_id_for_peer", Callable()) as Callable
	input_send_rate = float(config.get("input_send_rate", input_send_rate))
	idle_input_send_rate = float(config.get("idle_input_send_rate", idle_input_send_rate))
	if main_camera != null:
		_base_camera_zoom = main_camera.zoom
		_camera_zoom_initialized = true

func reset() -> void:
	_input_send_accumulator = 0.0
	_cached_local_input_state.clear()
	_local_last_non_zero_move_axis = 1.0
	_last_sent_axis = 0.0
	_last_sent_jump_held = false
	_last_sent_shoot_held = false
	_camera_follow_position = Vector2.ZERO
	_camera_mouse_look_offset = Vector2.ZERO
	if main_camera != null:
		main_camera.zoom = _resolved_base_camera_zoom()

func client_send_input(delta: float, last_ping_ms: int, damage_boost_enabled: bool) -> void:
	if multiplayer == null:
		return
	var local_id := multiplayer.get_unique_id()
	if not players.has(local_id):
		return

	var state: Dictionary = _cached_local_input_state if not _cached_local_input_state.is_empty() else _read_local_input_state(damage_boost_enabled)
	state = _apply_input_override(local_id, state)
	var axis := float(state.get("axis", 0.0))
	var jump_pressed := bool(state.get("jump_pressed", false))
	var jump_held := bool(state.get("jump_held", false))
	var shoot_held := bool(state.get("shoot_held", false))
	var changed := (
		absf(axis - _last_sent_axis) > 0.001
		or jump_pressed
		or jump_held != _last_sent_jump_held
		or shoot_held != _last_sent_shoot_held
	)
	var local_player := players[local_id] as NetPlayer
	if local_player != null:
		local_player.set_aim_world(state.get("aim_world", local_player.global_position + Vector2.RIGHT * 120.0) as Vector2)

	_input_send_accumulator += delta
	var send_rate := input_send_rate if changed else idle_input_send_rate
	send_rate = maxf(1.0, send_rate)
	if _input_send_accumulator < 1.0 / send_rate:
		return
	_input_send_accumulator = 0.0
	if not submit_input_cb.is_valid():
		return

	submit_input_cb.call(
		axis,
		jump_pressed,
		jump_held,
		state.get("aim_world", Vector2.ZERO) as Vector2,
		shoot_held,
		bool(state.get("boost_damage", false)),
		last_ping_ms
	)
	_last_sent_axis = axis
	_last_sent_jump_held = jump_held
	_last_sent_shoot_held = shoot_held

func client_predict_local_player(delta: float, damage_boost_enabled: bool) -> void:
	if multiplayer == null:
		return
	var local_id := multiplayer.get_unique_id()
	if local_id <= 0 or not players.has(local_id):
		return

	var local_player := players[local_id] as NetPlayer
	if local_player == null:
		return

	var state: Dictionary = _read_local_input_state(damage_boost_enabled)
	state = _apply_input_override(local_id, state)
	_cached_local_input_state = state
	local_player.set_aim_world(state.get("aim_world", local_player.global_position + Vector2.RIGHT * 120.0) as Vector2)
	local_player.simulate_authoritative(
		delta,
		float(state.get("axis", 0.0)),
		bool(state.get("jump_pressed", false)),
		bool(state.get("jump_held", false))
	)

func local_host_apply_input(delta: float, damage_boost_enabled: bool, input_states: Dictionary) -> void:
	if multiplayer == null:
		return
	var local_id := multiplayer.get_unique_id()
	if local_id <= 0 or not players.has(local_id):
		return
	var local_player := players.get(local_id, null) as NetPlayer
	if local_player == null:
		return
	var state: Dictionary = _read_local_input_state(damage_boost_enabled)
	state = _apply_input_override(local_id, state)
	_cached_local_input_state = state
	local_player.set_aim_world(state.get("aim_world", local_player.global_position + Vector2.RIGHT * 120.0) as Vector2)
	var authoritative_state := state.duplicate(true)
	authoritative_state["reported_rtt_ms"] = 0
	authoritative_state["last_packet_msec"] = Time.get_ticks_msec()
	input_states[local_id] = authoritative_state

func follow_local_player_camera(delta: float) -> void:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	if main_camera == null:
		return
	_ensure_camera_zoom_initialized()
	var local_player := players.get(multiplayer.get_unique_id(), null) as NetPlayer
	if local_player == null:
		return
	var focus_state := _camera_focus_state(multiplayer.get_unique_id())
	if bool(focus_state.get("active", false)):
		var focus_position := focus_state.get("position", local_player.global_position) as Vector2
		if _camera_follow_position == Vector2.ZERO:
			_camera_follow_position = main_camera.global_position
		_camera_mouse_look_offset = Vector2.ZERO
		_camera_follow_position = _camera_follow_position.lerp(focus_position, min(1.0, delta * CAMERA_FOLLOW_LERP_SPEED))
		if camera_shake == null:
			main_camera.global_position = _camera_follow_position
		else:
			main_camera.global_position = _camera_follow_position + camera_shake.step_offset(delta)
		_apply_weapon_camera_zoom(multiplayer.get_unique_id(), delta)
		return
	if _camera_follow_position == Vector2.ZERO:
		_camera_follow_position = main_camera.global_position
	var look_target := _camera_mouse_look_target()
	_camera_mouse_look_offset = _camera_mouse_look_offset.lerp(look_target, min(1.0, delta * CAMERA_MOUSE_LOOK_LERP_SPEED))
	var desired_position := local_player.global_position + _camera_mouse_look_offset
	_camera_follow_position = _camera_follow_position.lerp(desired_position, min(1.0, delta * CAMERA_FOLLOW_LERP_SPEED))
	if camera_shake == null:
		main_camera.global_position = _camera_follow_position
	else:
		main_camera.global_position = _camera_follow_position + camera_shake.step_offset(delta)
	_apply_weapon_camera_zoom(multiplayer.get_unique_id(), delta)

func snap_camera_to_local_player(reset_mouse_look: bool = true) -> void:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	if main_camera == null:
		return
	var local_player := players.get(multiplayer.get_unique_id(), null) as NetPlayer
	if local_player == null:
		return
	if reset_mouse_look:
		_camera_mouse_look_offset = Vector2.ZERO
	_camera_follow_position = local_player.global_position + _camera_mouse_look_offset
	main_camera.global_position = _camera_follow_position
	main_camera.zoom = _target_camera_zoom_for_peer(multiplayer.get_unique_id())

func _camera_mouse_look_target() -> Vector2:
	if main_camera == null:
		return Vector2.ZERO
	var viewport := main_camera.get_viewport()
	if viewport == null:
		return Vector2.ZERO
	var viewport_size := viewport.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2.ZERO
	var half_size := viewport_size * 0.5
	var mouse_pos := viewport.get_mouse_position()
	var normalized := Vector2(
		clampf((mouse_pos.x - half_size.x) / maxf(1.0, half_size.x), -1.0, 1.0),
		clampf((mouse_pos.y - half_size.y) / maxf(1.0, half_size.y), -1.0, 1.0)
	)
	var look_offset_max := CAMERA_MOUSE_LOOK_MAX_OFFSET
	if Input.is_key_pressed(KEY_SHIFT):
		look_offset_max *= CAMERA_MOUSE_LOOK_SHIFT_MULTIPLIER
	return Vector2(
		_camera_mouse_look_axis(normalized.x) * look_offset_max.x,
		_camera_mouse_look_axis(normalized.y) * look_offset_max.y
	)

func _camera_mouse_look_axis(value: float) -> float:
	var distance := absf(value)
	if distance <= CAMERA_MOUSE_LOOK_DEADZONE:
		return 0.0
	var adjusted := (distance - CAMERA_MOUSE_LOOK_DEADZONE) / (1.0 - CAMERA_MOUSE_LOOK_DEADZONE)
	return signf(value) * pow(clampf(adjusted, 0.0, 1.0), CAMERA_MOUSE_LOOK_CURVE)

func _read_local_input_state(damage_boost_enabled: bool) -> Dictionary:
	var mouse_world := main_camera.get_global_mouse_position() if main_camera != null else Vector2.ZERO
	if is_gameplay_locked_cb.is_valid() and is_gameplay_locked_cb.call() == true:
		return {
			"axis": 0.0,
			"jump_pressed": false,
			"jump_held": false,
			"aim_world": mouse_world,
			"shoot_held": false,
			"boost_damage": false
		}
	var left_pressed := Input.is_action_pressed("move_left")
	var right_pressed := Input.is_action_pressed("move_right")
	if Input.is_action_just_pressed("move_left"):
		_local_last_non_zero_move_axis = -1.0
	elif Input.is_action_just_pressed("move_right"):
		_local_last_non_zero_move_axis = 1.0

	var move_axis := 0.0
	if left_pressed and not right_pressed:
		move_axis = -1.0
	elif right_pressed and not left_pressed:
		move_axis = 1.0
	elif left_pressed and right_pressed:
		move_axis = _local_last_non_zero_move_axis
	else:
		move_axis = 0.0

	if absf(move_axis) > 0.001:
		_local_last_non_zero_move_axis = move_axis

	return {
		"axis": move_axis,
		"jump_pressed": Input.is_action_just_pressed("jump"),
		"jump_held": Input.is_action_pressed("jump"),
		"aim_world": mouse_world,
		"shoot_held": Input.is_action_pressed("shoot"),
		"boost_damage": damage_boost_enabled
	}

func _apply_input_override(peer_id: int, base_state: Dictionary) -> Dictionary:
	if not override_input_state_cb.is_valid():
		return base_state
	var override_value: Variant = override_input_state_cb.call(peer_id, base_state)
	if override_value is Dictionary:
		return override_value as Dictionary
	return base_state

func _camera_focus_state(peer_id: int) -> Dictionary:
	if not camera_focus_state_cb.is_valid():
		return {}
	var focus_value: Variant = camera_focus_state_cb.call(peer_id)
	if focus_value is Dictionary:
		return focus_value as Dictionary
	return {}

func _apply_weapon_camera_zoom(peer_id: int, delta: float) -> void:
	if main_camera == null:
		return
	var target_zoom := _target_camera_zoom_for_peer(peer_id)
	main_camera.zoom = main_camera.zoom.lerp(target_zoom, min(1.0, delta * CAMERA_ZOOM_LERP_SPEED))

func _target_camera_zoom_for_peer(peer_id: int) -> Vector2:
	var weapon_id := _weapon_id_for_peer(peer_id)
	if weapon_id == WEAPON_ID_KAR:
		return KAR_CAMERA_ZOOM
	return _resolved_base_camera_zoom()

func _weapon_id_for_peer(peer_id: int) -> String:
	if weapon_id_for_peer_cb.is_valid():
		return str(weapon_id_for_peer_cb.call(peer_id)).strip_edges().to_lower()
	return ""

func _ensure_camera_zoom_initialized() -> void:
	if _camera_zoom_initialized or main_camera == null:
		return
	_base_camera_zoom = main_camera.zoom
	_camera_zoom_initialized = true

func _resolved_base_camera_zoom() -> Vector2:
	return _base_camera_zoom if _base_camera_zoom != Vector2.ZERO else Vector2.ONE
