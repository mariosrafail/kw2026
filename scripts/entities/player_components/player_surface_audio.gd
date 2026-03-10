extends RefCounted

class_name PlayerSurfaceAudio

const SURFACE_WOOD := "wood"
const SURFACE_GRASS := "grass"
const DEFAULT_SURFACE := SURFACE_WOOD
const MOVE_THRESHOLD := 18.0
const STEP_INTERVAL_MIN := 0.18
const STEP_INTERVAL_MAX := 0.34
const STEP_SPEED_REFERENCE := 245.0
const JUMP_TRIGGER_VELOCITY := -120.0
const LAND_TRIGGER_VELOCITY := 180.0
const STEP_VOLUME_DB := -5.5
const JUMP_VOLUME_DB := -8.5
const LAND_VOLUME_DB := -7.0

const STEP_STREAMS := {
	SURFACE_GRASS: [
		preload("res://assets/sounds/sfx/ground/grass/grass_step_1.wav"),
		preload("res://assets/sounds/sfx/ground/grass/grass_step_2.wav"),
		preload("res://assets/sounds/sfx/ground/grass/grass_step_3.wav"),
	],
	SURFACE_WOOD: [
		preload("res://assets/sounds/sfx/ground/wood/wood_step_1.wav"),
		preload("res://assets/sounds/sfx/ground/wood/wood_step_2.wav"),
		preload("res://assets/sounds/sfx/ground/wood/wood_step_3.wav"),
		preload("res://assets/sounds/sfx/ground/wood/wood_step_4.wav"),
		preload("res://assets/sounds/sfx/ground/wood/wood_step_5.wav"),
		preload("res://assets/sounds/sfx/ground/wood/wood_step_6.wav"),
		preload("res://assets/sounds/sfx/ground/wood/wood_step_7.wav"),
	],
}

const JUMP_STREAMS := {
	SURFACE_GRASS: [preload("res://assets/sounds/sfx/ground/grass/grass_jump.wav")],
	SURFACE_WOOD: [preload("res://assets/sounds/sfx/ground/wood/wood_jump.wav")],
}

const LAND_STREAMS := {
	SURFACE_GRASS: [preload("res://assets/sounds/sfx/ground/grass/grass_land.wav")],
	SURFACE_WOOD: [preload("res://assets/sounds/sfx/ground/wood/wood_land.wav")],
}

var _player: CharacterBody2D
var _audio: AudioStreamPlayer2D
var _is_sfx_suppressed_cb: Callable = Callable()
var _active_zones: Dictionary = {}
var _current_surface := DEFAULT_SURFACE
var _step_timer := 0.0
var _was_on_floor := false
var _previous_vertical_velocity := 0.0

func configure(player: CharacterBody2D, audio: AudioStreamPlayer2D, is_sfx_suppressed_cb: Callable = Callable()) -> void:
	_player = player
	_audio = audio
	_is_sfx_suppressed_cb = is_sfx_suppressed_cb
	if _player != null:
		_was_on_floor = _player.is_on_floor()
		_previous_vertical_velocity = _player.velocity.y

func reset_state() -> void:
	_step_timer = 0.0
	_was_on_floor = false
	_previous_vertical_velocity = 0.0
	_active_zones.clear()
	_current_surface = DEFAULT_SURFACE

func register_surface_zone(zone: Area2D) -> void:
	if zone == null:
		return
	_active_zones[zone.get_instance_id()] = zone
	_resolve_surface()

func unregister_surface_zone(zone: Area2D) -> void:
	if zone == null:
		return
	_active_zones.erase(zone.get_instance_id())
	_resolve_surface()

func tick(delta: float, current_velocity: Vector2, on_floor: bool) -> void:
	if _audio == null:
		return
	if not on_floor and _was_on_floor and current_velocity.y <= JUMP_TRIGGER_VELOCITY:
		_play_jump()
		_step_timer = STEP_INTERVAL_MAX * 0.65
	elif on_floor and not _was_on_floor and _previous_vertical_velocity >= LAND_TRIGGER_VELOCITY:
		_play_land()
		_step_timer = STEP_INTERVAL_MAX * 0.45

	var horizontal_speed := absf(current_velocity.x)
	var walking := on_floor and horizontal_speed >= MOVE_THRESHOLD
	if walking:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_play_step()
			_step_timer = _step_interval_for_speed(horizontal_speed)
	else:
		_step_timer = minf(_step_timer, 0.06)

	_was_on_floor = on_floor
	_previous_vertical_velocity = current_velocity.y

func _resolve_surface() -> void:
	var best_zone: Area2D = null
	var best_priority := -2147483648
	for zone_value in _active_zones.values():
		var zone := zone_value as Area2D
		if zone == null or not is_instance_valid(zone):
			continue
		var zone_priority := 0
		if zone.has_method("get_surface_priority"):
			zone_priority = int(zone.call("get_surface_priority"))
		if best_zone == null or zone_priority > best_priority:
			best_zone = zone
			best_priority = zone_priority
	if best_zone != null and best_zone.has_method("get_surface_id"):
		_current_surface = _normalize_surface_id(str(best_zone.call("get_surface_id")))
	else:
		_current_surface = DEFAULT_SURFACE

func _normalize_surface_id(surface_id: String) -> String:
	var normalized := str(surface_id).strip_edges().to_lower()
	if STEP_STREAMS.has(normalized):
		return normalized
	return DEFAULT_SURFACE

func _step_interval_for_speed(horizontal_speed: float) -> float:
	var speed_t := clampf(horizontal_speed / STEP_SPEED_REFERENCE, 0.0, 1.0)
	return lerpf(STEP_INTERVAL_MAX, STEP_INTERVAL_MIN, speed_t)

func _play_step() -> void:
	_play_surface_stream(STEP_STREAMS.get(_current_surface, STEP_STREAMS[DEFAULT_SURFACE]), STEP_VOLUME_DB, 0.96, 1.05)

func _play_jump() -> void:
	_play_surface_stream(JUMP_STREAMS.get(_current_surface, JUMP_STREAMS[DEFAULT_SURFACE]), JUMP_VOLUME_DB, 0.98, 1.03)

func _play_land() -> void:
	_play_surface_stream(LAND_STREAMS.get(_current_surface, LAND_STREAMS[DEFAULT_SURFACE]), LAND_VOLUME_DB, 0.98, 1.04)

func _play_surface_stream(streams_value: Variant, volume_db: float, pitch_min: float, pitch_max: float) -> void:
	if _audio == null:
		return
	if _is_sfx_suppressed_cb.is_valid() and bool(_is_sfx_suppressed_cb.call()):
		return
	if not (streams_value is Array):
		return
	var streams = streams_value as Array
	if streams.is_empty():
		return
	var chosen_stream = streams[randi() % streams.size()]
	if not (chosen_stream is AudioStream):
		return
	_audio.stream = chosen_stream as AudioStream
	_audio.volume_db = volume_db
	_audio.pitch_scale = randf_range(pitch_min, pitch_max)
	_audio.play()
