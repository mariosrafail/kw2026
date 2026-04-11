extends Node2D
class_name RPRainVfx

const DROP_COUNT := 140
const DROP_MIN_SPEED := 320.0
const DROP_MAX_SPEED := 760.0
const DROP_MIN_LENGTH := 8.0
const DROP_MAX_LENGTH := 22.0
const SPLASH_CHANCE := 0.16
const SPLASH_LIFE_SEC := 0.16

var duration_sec := 5.0
var rain_color := Color(0.32, 0.68, 1.0, 1.0)

var _remaining_sec := 0.0
var _rng := RandomNumberGenerator.new()
var _drops: Array = []
var _splashes: Array = []
var _rain_area_size := Vector2(640.0, 360.0)

func _ready() -> void:
	z_index = 90
	_rng.seed = int(Time.get_ticks_usec()) ^ int(get_instance_id())
	_remaining_sec = maxf(0.05, duration_sec)
	_resolve_global_rain_area()
	_rebuild_drops()
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_remaining_sec = maxf(0.0, _remaining_sec - maxf(0.0, delta))
	_tick_drops(delta)
	_tick_splashes(delta)
	queue_redraw()
	if _remaining_sec <= 0.0 and _splashes.is_empty():
		queue_free()

func _draw() -> void:
	var base := rain_color
	for drop_value in _drops:
		if not (drop_value is Dictionary):
			continue
		var drop := drop_value as Dictionary
		var pos := drop.get("pos", Vector2.ZERO) as Vector2
		var length := float(drop.get("length", 10.0))
		var alpha := clampf(float(drop.get("alpha", 0.8)), 0.1, 1.0)
		draw_line(
			pos,
			pos + Vector2(0.0, length),
			Color(base.r, base.g, base.b, alpha),
			1.4
		)
	for splash_value in _splashes:
		if not (splash_value is Dictionary):
			continue
		var splash := splash_value as Dictionary
		var age := float(splash.get("age", 0.0))
		var life := maxf(0.01, float(splash.get("life", SPLASH_LIFE_SEC)))
		var ratio := clampf(age / life, 0.0, 1.0)
		var alpha := clampf(1.0 - ratio, 0.0, 1.0)
		var radius := lerpf(1.0, 5.0, ratio)
		var pos := splash.get("pos", Vector2.ZERO) as Vector2
		draw_arc(pos, radius, 0.0, TAU, 10, Color(base.r, base.g, base.b, alpha * 0.55), 1.2, true)

func _resolve_global_rain_area() -> void:
	var area_size := _rain_area_size
	var center := Vector2.ZERO
	var root := get_tree().current_scene if get_tree() != null else null
	if root != null and root.has_method("_play_bounds_rect"):
		var bounds_value: Variant = root.call("_play_bounds_rect")
		if bounds_value is Rect2i:
			var bounds := bounds_value as Rect2i
			if bounds.size.x > 8 and bounds.size.y > 8:
				area_size = Vector2(bounds.size)
				center = Vector2(bounds.position) + Vector2(bounds.size) * 0.5
	if area_size.x <= 8.0 or area_size.y <= 8.0:
		var viewport := get_viewport()
		if viewport != null:
			area_size = viewport.get_visible_rect().size
			center = area_size * 0.5
	_rain_area_size = area_size
	global_position = center

func _rebuild_drops() -> void:
	_drops.clear()
	for _i in range(DROP_COUNT):
		_drops.append(_spawn_drop(_rng.randf_range(-_rain_area_size.y * 0.5, _rain_area_size.y * 0.5)))

func _spawn_drop(y_value: float = -10000.0) -> Dictionary:
	var half_w := _rain_area_size.x * 0.5
	var half_h := _rain_area_size.y * 0.5
	var resolved_y := y_value
	if resolved_y < -9999.0:
		resolved_y = _rng.randf_range(-half_h - 24.0, half_h + 8.0)
	return {
		"pos": Vector2(_rng.randf_range(-half_w - 16.0, half_w + 16.0), resolved_y),
		"speed": _rng.randf_range(DROP_MIN_SPEED, DROP_MAX_SPEED),
		"length": _rng.randf_range(DROP_MIN_LENGTH, DROP_MAX_LENGTH),
		"alpha": _rng.randf_range(0.35, 0.92),
	}

func _tick_drops(delta: float) -> void:
	var half_h := _rain_area_size.y * 0.5
	var half_w := _rain_area_size.x * 0.5
	for index in range(_drops.size()):
		var drop := _drops[index] as Dictionary
		var pos := drop.get("pos", Vector2.ZERO) as Vector2
		var speed := float(drop.get("speed", DROP_MIN_SPEED))
		pos.y += speed * maxf(0.0, delta)
		pos.x += -speed * 0.08 * maxf(0.0, delta)
		if pos.y > half_h + 20.0:
			if _rng.randf() < SPLASH_CHANCE:
				_splashes.append({
					"pos": Vector2(clampf(pos.x, -half_w, half_w), half_h - _rng.randf_range(0.0, 6.0)),
					"age": 0.0,
					"life": SPLASH_LIFE_SEC
				})
			drop = _spawn_drop(-half_h - _rng.randf_range(8.0, 42.0))
		else:
			drop["pos"] = pos
		_drops[index] = drop

func _tick_splashes(delta: float) -> void:
	if _splashes.is_empty():
		return
	var keep: Array = []
	for splash_value in _splashes:
		if not (splash_value is Dictionary):
			continue
		var splash := splash_value as Dictionary
		var age := float(splash.get("age", 0.0)) + maxf(0.0, delta)
		var life := float(splash.get("life", SPLASH_LIFE_SEC))
		if age >= life:
			continue
		splash["age"] = age
		keep.append(splash)
	_splashes = keep
