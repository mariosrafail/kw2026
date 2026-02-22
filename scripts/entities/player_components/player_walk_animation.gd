extends RefCounted

class_name PlayerWalkAnimation

const ANIM_IDLE := "idle"
const ANIM_WALK := "walk"

const MOVE_THRESHOLD := 3.0
const BLEND_TIME := 0.12

const WALK_SPEED_BASE := 1.0
const WALK_SPEED_SCALE := 0.012
const WALK_SPEED_MIN := 0.75
const WALK_SPEED_MAX := 2.25

var _player: CharacterBody2D
var _anim_player: AnimationPlayer
var _current_anim := ""

func configure(player: CharacterBody2D, anim_player: AnimationPlayer) -> void:
	_player = player
	_anim_player = anim_player
	_current_anim = ""

func tick(_delta: float) -> void:
	if _player == null or _anim_player == null:
		return

	var horizontal_speed := absf(_player.velocity.x)
	var walking := _player.is_on_floor() and horizontal_speed > MOVE_THRESHOLD
	if walking:
		_play_walk(horizontal_speed)
	else:
		_play_idle()

func _play_idle() -> void:
	if _current_anim == ANIM_IDLE and _anim_player.is_playing():
		return
	_current_anim = ANIM_IDLE
	_anim_player.speed_scale = 1.0
	_anim_player.play(ANIM_IDLE, BLEND_TIME)

func _play_walk(horizontal_speed: float) -> void:
	var speed := clampf(WALK_SPEED_BASE + horizontal_speed * WALK_SPEED_SCALE, WALK_SPEED_MIN, WALK_SPEED_MAX)
	if _current_anim != ANIM_WALK:
		_current_anim = ANIM_WALK
		_anim_player.play(ANIM_WALK, BLEND_TIME)
	_anim_player.speed_scale = speed

