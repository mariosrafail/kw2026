extends RefCounted

class_name PlayerMovement

const SPEED := 245.0
const JUMP_VELOCITY := -650.0
const GRAVITY := 1450.0
const FALL_GRAVITY_MULTIPLIER := 1.35
const MAX_FALL_SPEED := 1300.0
const JUMP_RELEASE_DAMP := 0.55
const EXTERNAL_HOLD_INPUT_SUPPRESS_EXTENSION := 0.12
const COYOTE_TIME := 0.16
const JUMP_BUFFER_TIME := 0.1
const GROUND_ACCEL := 3200.0
const GROUND_DECEL := 1850.0
const AIR_ACCEL := 1700.0

const MAX_WALKABLE_SLOPE_DEGREES := 45.0
const FLOOR_SLOPE_TOLERANCE_DEGREES := 2.0
const FLOOR_SNAP_LENGTH := 18.0
const STAIR_STEP_HEIGHT := 8.0
const STAIR_FORWARD_MIN := 2.0
const STAIR_FORWARD_PADDING := 2.0
const PLAYER_SAFE_MARGIN := 0.08
const PLAYER_MAX_SLIDES := 8

var _player: CharacterBody2D
var coyote_time_left := 0.0
var jump_buffer_time_left := 0.0
var external_jump_hold_time_left := 0.0
var external_jump_hold_input_suppress_time_left := 0.0

func configure(player: CharacterBody2D) -> void:
	_player = player
	_configure_floor_movement()

func reset_jump_state() -> void:
	coyote_time_left = 0.0
	jump_buffer_time_left = 0.0
	external_jump_hold_time_left = 0.0
	external_jump_hold_input_suppress_time_left = 0.0

func set_external_jump_hold(duration_sec: float) -> void:
	var normalized_duration := maxf(0.0, duration_sec)
	external_jump_hold_time_left = maxf(external_jump_hold_time_left, normalized_duration)
	external_jump_hold_input_suppress_time_left = maxf(
		external_jump_hold_input_suppress_time_left,
		normalized_duration + EXTERNAL_HOLD_INPUT_SUPPRESS_EXTENSION
	)

func configure_floor_movement() -> void:
	if _player == null:
		return
	_configure_floor_movement()

func simulate_authoritative(delta: float, axis: float, jump_pressed: bool, jump_held: bool) -> void:
	if _player == null:
		return
	if external_jump_hold_time_left > 0.0:
		external_jump_hold_time_left = maxf(external_jump_hold_time_left - delta, 0.0)
	if external_jump_hold_input_suppress_time_left > 0.0:
		external_jump_hold_input_suppress_time_left = maxf(external_jump_hold_input_suppress_time_left - delta, 0.0)
	var input_jump_held := jump_held
	if external_jump_hold_input_suppress_time_left > 0.0 and _player.velocity.y < 0.0:
		input_jump_held = false
	var effective_jump_held := input_jump_held or external_jump_hold_time_left > 0.0
	axis = clamp(axis, -1.0, 1.0)
	var on_floor := _player.is_on_floor()
	var jumped_this_frame := false
	if on_floor:
		coyote_time_left = COYOTE_TIME
	else:
		coyote_time_left = maxf(coyote_time_left - delta, 0.0)

	if jump_pressed:
		jump_buffer_time_left = JUMP_BUFFER_TIME
	else:
		jump_buffer_time_left = maxf(jump_buffer_time_left - delta, 0.0)

	var speed_multiplier := 1.0
	if _player != null and _player.has_method("get_movement_speed_multiplier"):
		speed_multiplier = float(_player.call("get_movement_speed_multiplier"))
	var target_speed := axis * SPEED * clampf(speed_multiplier, 0.0, 1.0)
	var horizontal_accel := AIR_ACCEL
	var horizontal_decel := AIR_ACCEL
	if on_floor:
		horizontal_accel = GROUND_ACCEL
		horizontal_decel = GROUND_DECEL
	if absf(axis) > 0.001:
		_player.velocity.x = move_toward(_player.velocity.x, target_speed, horizontal_accel * delta)
	else:
		# Keep a little glide on ground instead of hard-stopping (felt like sticky friction on slopes).
		_player.velocity.x = move_toward(_player.velocity.x, 0.0, horizontal_decel * delta)

	if not on_floor:
		var gravity_scale := FALL_GRAVITY_MULTIPLIER if _player.velocity.y > 0.0 else 1.0
		_player.velocity.y = min(_player.velocity.y + GRAVITY * gravity_scale * delta, MAX_FALL_SPEED)
	elif _player.velocity.y > 0.0:
		_player.velocity.y = 0.0

	if jump_buffer_time_left > 0.0 and (on_floor or coyote_time_left > 0.0):
		var jump_velocity := JUMP_VELOCITY
		if _player.has_method("get_jump_velocity_multiplier"):
			var jump_mul := clampf(float(_player.call("get_jump_velocity_multiplier")), 0.25, 2.0)
			jump_velocity *= jump_mul
		_player.velocity.y = jump_velocity
		coyote_time_left = 0.0
		jump_buffer_time_left = 0.0
		jumped_this_frame = true

	if not jumped_this_frame and not effective_jump_held and _player.velocity.y < 0.0:
		_player.velocity.y *= JUMP_RELEASE_DAMP

	_try_step_up(delta, axis, on_floor, jumped_this_frame)
	_player.move_and_slide()
	if _player.is_on_floor():
		coyote_time_left = COYOTE_TIME

func _configure_floor_movement() -> void:
	# Small tolerance keeps exact 45deg ramps classified as floor.
	_player.floor_max_angle = deg_to_rad(MAX_WALKABLE_SLOPE_DEGREES + FLOOR_SLOPE_TOLERANCE_DEGREES)
	_player.floor_snap_length = FLOOR_SNAP_LENGTH
	_player.floor_constant_speed = true
	# Allows smoother transitions on 45deg slope seams instead of wall-like catches.
	_player.floor_block_on_wall = false
	_player.safe_margin = PLAYER_SAFE_MARGIN
	_player.max_slides = PLAYER_MAX_SLIDES
	_player.motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED

func _try_step_up(delta: float, axis: float, was_on_floor: bool, jumped_this_frame: bool) -> bool:
	if _player == null:
		return false
	if not was_on_floor or jumped_this_frame:
		return false
	if absf(axis) <= 0.001:
		return false
	# Only attempt step-up when a forward move is actually blocked.
	var dir := signf(axis)
	var forward_dist := maxf(STAIR_FORWARD_MIN, absf(_player.velocity.x) * delta + STAIR_FORWARD_PADDING)
	var forward := Vector2(dir * forward_dist, 0.0)
	var base_xform: Transform2D = _player.global_transform
	if not _player.test_move(base_xform, forward):
		return false

	var step_heights := PackedFloat32Array([
		STAIR_STEP_HEIGHT,
		STAIR_STEP_HEIGHT * 0.75,
		STAIR_STEP_HEIGHT * 0.5
	])
	for step_h_value in step_heights:
		var step_h := float(step_h_value)
		var up := Vector2(0.0, -step_h)
		if _player.test_move(base_xform, up):
			continue
		var raised_xform := base_xform.translated(up)
		if _player.test_move(raised_xform, forward):
			continue
		var raised_forward_xform := raised_xform.translated(forward)
		# Require floor under the stepped position, so we don't "climb" vertical walls.
		if not _player.test_move(raised_forward_xform, Vector2(0.0, step_h + FLOOR_SNAP_LENGTH)):
			continue
		_player.global_position += up
		if _player.velocity.y > 0.0:
			_player.velocity.y = 0.0
		return true
	return false
