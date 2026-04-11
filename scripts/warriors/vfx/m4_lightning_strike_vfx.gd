extends Node2D
class_name M4LightningStrikeVfx

const STRIKE_LIFE_SEC := 0.14
const SEGMENT_COUNT := 9
const THICKNESS := 2.4
const IMPACT_RING_MAX_RADIUS := 18.0

var from_world := Vector2.ZERO
var to_world := Vector2.ZERO
var strike_color := Color(0.40, 0.92, 1.0, 1.0)

var _age := 0.0
var _points: PackedVector2Array = PackedVector2Array()
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = 86
	_rng.seed = int(Time.get_ticks_usec()) ^ int(get_instance_id())
	_rebuild_points()
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_age += maxf(0.0, delta)
	if _age >= STRIKE_LIFE_SEC:
		queue_free()
		return
	if _rng.randf() < 0.35:
		_rebuild_points()
	queue_redraw()

func _draw() -> void:
	if _points.size() < 2:
		return
	var ratio := clampf(_age / STRIKE_LIFE_SEC, 0.0, 1.0)
	var alpha := clampf(1.0 - ratio, 0.0, 1.0)
	draw_polyline(_points, Color(strike_color.r, strike_color.g, strike_color.b, alpha), THICKNESS, true)
	draw_circle(_points[_points.size() - 1], lerpf(4.0, IMPACT_RING_MAX_RADIUS, ratio), Color(strike_color.r, strike_color.g, strike_color.b, alpha * 0.22))

func _rebuild_points() -> void:
	_points.clear()
	var local_start := to_local(from_world)
	var local_end := to_local(to_world)
	var travel := local_end - local_start
	var perp := Vector2(-travel.y, travel.x).normalized()
	if perp == Vector2.ZERO:
		perp = Vector2.UP
	for index in range(SEGMENT_COUNT):
		var t := float(index) / float(maxi(1, SEGMENT_COUNT - 1))
		var point := local_start.lerp(local_end, t)
		if index > 0 and index < SEGMENT_COUNT - 1:
			var jitter := _rng.randf_range(-1.0, 1.0) * (1.0 - absf(t - 0.5) * 1.4)
			point += perp * jitter * 16.0
		_points.append(point)
