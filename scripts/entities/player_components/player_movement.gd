extends RefCounted

class_name PlayerMovement

const SPEED := 245.0
const JUMP_VELOCITY := -650.0
const GRAVITY := 1450.0
const FALL_GRAVITY_MULTIPLIER := 1.35
const MAX_FALL_SPEED := 1300.0
const JUMP_RELEASE_DAMP := 0.55
const COYOTE_TIME := 0.16
const JUMP_BUFFER_TIME := 0.1

const MAX_WALKABLE_SLOPE_DEGREES := 45.0
const FLOOR_SLOPE_TOLERANCE_DEGREES := 0.5
const FLOOR_SNAP_LENGTH := 14.0
const PLAYER_SAFE_MARGIN := 0.08
const PLAYER_MAX_SLIDES := 8

var _player: CharacterBody2D
var coyote_time_left := 0.0
var jump_buffer_time_left := 0.0

func configure(player: CharacterBody2D) -> void:
	_player = player
	_configure_floor_movement()

func reset_jump_state() -> void:
	coyote_time_left = 0.0
	jump_buffer_time_left = 0.0

func simulate_authoritative(delta: float, axis: float, jump_pressed: bool, jump_held: bool) -> void:
	if _player == null:
		return
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

	var target_speed := axis * SPEED
	if absf(axis) > 0.001:
		_player.velocity.x = target_speed
	else:
		_player.velocity.x = 0.0

	if not on_floor:
		var gravity_scale := FALL_GRAVITY_MULTIPLIER if _player.velocity.y > 0.0 else 1.0
		_player.velocity.y = min(_player.velocity.y + GRAVITY * gravity_scale * delta, MAX_FALL_SPEED)
	elif _player.velocity.y > 0.0:
		_player.velocity.y = 0.0

	if jump_buffer_time_left > 0.0 and (on_floor or coyote_time_left > 0.0):
		_player.velocity.y = JUMP_VELOCITY
		coyote_time_left = 0.0
		jump_buffer_time_left = 0.0
		jumped_this_frame = true

	if not jumped_this_frame and not jump_held and _player.velocity.y < 0.0:
		_player.velocity.y *= JUMP_RELEASE_DAMP

	_player.move_and_slide()
	if _player.is_on_floor():
		coyote_time_left = COYOTE_TIME

func _configure_floor_movement() -> void:
	# Small tolerance keeps exact 45deg ramps classified as floor.
	_player.floor_max_angle = deg_to_rad(MAX_WALKABLE_SLOPE_DEGREES + FLOOR_SLOPE_TOLERANCE_DEGREES)
	_player.floor_snap_length = FLOOR_SNAP_LENGTH
	_player.floor_constant_speed = true
	_player.floor_block_on_wall = true
	_player.safe_margin = PLAYER_SAFE_MARGIN
	_player.max_slides = PLAYER_MAX_SLIDES
	_player.motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED

