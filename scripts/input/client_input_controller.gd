extends RefCounted
class_name ClientInputController

var players: Dictionary = {}
var multiplayer: MultiplayerAPI
var main_camera: Camera2D
var camera_shake: CameraShake

var submit_input_cb: Callable = Callable()
var input_send_rate := 60.0

var _input_send_accumulator := 0.0
var _cached_local_input_state: Dictionary = {}
var _local_last_non_zero_move_axis := 1.0
var _last_sent_axis := 0.0
var _last_sent_jump_held := false
var _last_sent_shoot_held := false

func configure(refs: Dictionary, callbacks: Dictionary, config: Dictionary = {}) -> void:
	players = refs.get("players", {}) as Dictionary
	multiplayer = refs.get("multiplayer", null) as MultiplayerAPI
	main_camera = refs.get("main_camera", null) as Camera2D
	camera_shake = refs.get("camera_shake", null) as CameraShake

	submit_input_cb = callbacks.get("submit_input", Callable()) as Callable
	input_send_rate = float(config.get("input_send_rate", input_send_rate))

func reset() -> void:
	_input_send_accumulator = 0.0
	_cached_local_input_state.clear()
	_local_last_non_zero_move_axis = 1.0
	_last_sent_axis = 0.0
	_last_sent_jump_held = false
	_last_sent_shoot_held = false

func client_send_input(delta: float, last_ping_ms: int, damage_boost_enabled: bool) -> void:
	if multiplayer == null:
		return
	var local_id := multiplayer.get_unique_id()
	if not players.has(local_id):
		return

	var state: Dictionary = _cached_local_input_state if not _cached_local_input_state.is_empty() else _read_local_input_state(damage_boost_enabled)
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
	if not changed and _input_send_accumulator < 1.0 / input_send_rate:
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
	_cached_local_input_state = state
	local_player.set_aim_world(state.get("aim_world", local_player.global_position + Vector2.RIGHT * 120.0) as Vector2)
	local_player.simulate_authoritative(
		delta,
		float(state.get("axis", 0.0)),
		bool(state.get("jump_pressed", false)),
		bool(state.get("jump_held", false))
	)

func follow_local_player_camera(delta: float) -> void:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	if main_camera == null:
		return
	var local_player := players.get(multiplayer.get_unique_id(), null) as NetPlayer
	if local_player == null:
		return
	var target_position := main_camera.global_position.lerp(local_player.global_position, min(1.0, delta * 8.0))
	if camera_shake == null:
		main_camera.global_position = target_position
	else:
		main_camera.global_position = target_position + camera_shake.step_offset(delta)

func _read_local_input_state(damage_boost_enabled: bool) -> Dictionary:
	var mouse_world := main_camera.get_global_mouse_position() if main_camera != null else Vector2.ZERO
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
