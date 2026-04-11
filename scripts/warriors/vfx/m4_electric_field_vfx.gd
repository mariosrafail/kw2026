extends Node2D
class_name M4ElectricFieldVfx

const ARC_COUNT := 20
const ARC_MIN_LIFE := 0.05
const ARC_MAX_LIFE := 0.14
const ARC_MIN_LEN := 12.0
const ARC_MAX_LEN := 48.0

var caster_peer_id := 0
var duration_sec := 5.0
var radius_px := 268.0
var players: Dictionary = {}
var electric_color := Color(0.40, 0.92, 1.0, 1.0)

var _remaining := 0.0
var _pulse_time := 0.0
var _rng := RandomNumberGenerator.new()
var _arcs: Array = []

func _ready() -> void:
	z_index = 64
	_rng.seed = int(Time.get_ticks_usec()) ^ int(get_instance_id())
	_remaining = maxf(0.05, duration_sec)
	_update_follow_position()
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	_pulse_time += maxf(0.0, delta)
	_update_follow_position()
	_tick_arcs(delta)
	if _remaining <= 0.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	for arc_value in _arcs:
		if not (arc_value is Dictionary):
			continue
		var arc := arc_value as Dictionary
		var age := float(arc.get("age", 0.0))
		var life := maxf(0.01, float(arc.get("life", 0.1)))
		var ratio := clampf(age / life, 0.0, 1.0)
		var alpha := (1.0 - ratio) * 0.9
		var start_pos := arc.get("start", Vector2.ZERO) as Vector2
		var end_pos := arc.get("end", Vector2.ZERO) as Vector2
		var mid := (start_pos + end_pos) * 0.5
		var jitter := arc.get("jitter", Vector2.ZERO) as Vector2
		draw_polyline(
			PackedVector2Array([start_pos, mid + jitter, end_pos]),
			Color(electric_color.r, electric_color.g, electric_color.b, alpha),
			2.0,
			true
		)

func _update_follow_position() -> void:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null or not is_instance_valid(caster):
		queue_free()
		return
	global_position = caster.global_position + Vector2(0.0, -10.0)

func _tick_arcs(delta: float) -> void:
	var keep: Array = []
	for arc_value in _arcs:
		if not (arc_value is Dictionary):
			continue
		var arc := arc_value as Dictionary
		var life := float(arc.get("life", 0.1))
		var age := float(arc.get("age", 0.0)) + delta
		if age >= life:
			continue
		arc["age"] = age
		keep.append(arc)
	_arcs = keep
	while _arcs.size() < ARC_COUNT:
		_arcs.append(_spawn_arc())

func _spawn_arc() -> Dictionary:
	var angle := _rng.randf_range(0.0, TAU)
	var arc_len := _rng.randf_range(ARC_MIN_LEN, ARC_MAX_LEN)
	var center := Vector2.RIGHT.rotated(angle) * _rng.randf_range(radius_px * 0.18, radius_px * 0.92)
	var tangent := Vector2.RIGHT.rotated(angle + PI * 0.5)
	return {
		"start": center - tangent * arc_len * 0.5,
		"end": center + tangent * arc_len * 0.5,
		"jitter": Vector2.RIGHT.rotated(angle + _rng.randf_range(-0.4, 0.4)) * _rng.randf_range(4.0, 11.0),
		"life": _rng.randf_range(ARC_MIN_LIFE, ARC_MAX_LIFE),
		"age": 0.0,
	}
