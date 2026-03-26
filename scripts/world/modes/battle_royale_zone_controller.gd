extends Node2D
class_name BattleRoyaleZoneController

const OUTLINE_COLOR := Color(1.0, 0.14, 0.14, 0.95)
const OUTLINE_WIDTH := 10.0
const OUTLINE_POINT_COUNT := 192

@export var zone_center := Vector2(1024.0, 1024.0)
@export var start_radius := 1320.0
@export var end_radius := 260.0
@export var shrink_delay_sec := 12.0
@export var shrink_duration_sec := 50.0

var _elapsed_sec := 0.0
var _current_radius := start_radius

func _ready() -> void:
	position = zone_center
	_current_radius = start_radius
	queue_redraw()

func reset_match() -> void:
	_elapsed_sec = 0.0
	_current_radius = start_radius
	position = zone_center
	queue_redraw()

func server_tick(delta: float) -> void:
	_elapsed_sec = maxf(0.0, _elapsed_sec + delta)
	_set_radius(_radius_for_elapsed(_elapsed_sec))

func apply_synced_state(center: Vector2, radius: float) -> void:
	zone_center = center
	position = center
	_set_radius(radius)

func current_center() -> Vector2:
	return zone_center

func current_radius() -> float:
	return _current_radius

func is_outside(point: Vector2) -> bool:
	return point.distance_to(zone_center) > _current_radius

func _radius_for_elapsed(elapsed_sec: float) -> float:
	if elapsed_sec <= shrink_delay_sec:
		return start_radius
	var shrink_t := clampf(
		(elapsed_sec - shrink_delay_sec) / maxf(0.001, shrink_duration_sec),
		0.0,
		1.0
	)
	return lerpf(start_radius, end_radius, shrink_t)

func _set_radius(radius: float) -> void:
	var clamped := maxf(end_radius, radius)
	if absf(_current_radius - clamped) <= 0.05:
		return
	_current_radius = clamped
	queue_redraw()

func _draw() -> void:
	draw_arc(
		Vector2.ZERO,
		_current_radius,
		0.0,
		TAU,
		OUTLINE_POINT_COUNT,
		OUTLINE_COLOR,
		OUTLINE_WIDTH,
		true
	)
