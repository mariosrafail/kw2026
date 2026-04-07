extends Node2D

var caster_peer_id := 0
var duration_sec := 5.0
var explosion_radius := 124.0
var color := Color(0.68, 0.8, 1.0, 0.96)
var players: Dictionary = {}

var _remaining_sec := 0.0
var _exploding := false
var _explosion_remaining_sec := 0.0
var _last_position := Vector2.ZERO

func _ready() -> void:
	_remaining_sec = maxf(0.05, duration_sec)
	z_index = 48
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	var caster := players.get(caster_peer_id, null) as Node2D
	if caster != null:
		var progress := 1.0 - (_remaining_sec / maxf(0.05, duration_sec))
		var vertical_offset := lerpf(22.0, 54.0, clampf(progress, 0.0, 1.0))
		_last_position = caster.global_position + Vector2(0.0, -vertical_offset)
	global_position = _last_position

	if _exploding:
		_explosion_remaining_sec = maxf(0.0, _explosion_remaining_sec - delta)
		if _explosion_remaining_sec <= 0.0:
			queue_free()
			return
	else:
		_remaining_sec = maxf(0.0, _remaining_sec - delta)
		if _remaining_sec <= 0.0:
			_exploding = true
			_explosion_remaining_sec = 0.32
	queue_redraw()

func _draw() -> void:
	if _exploding:
		_draw_explosion()
		return
	_draw_growing_moon()

func _draw_growing_moon() -> void:
	var progress := 1.0 - (_remaining_sec / maxf(0.05, duration_sec))
	var eased := 1.0 - pow(1.0 - clampf(progress, 0.0, 1.0), 2.0)
	var radius := lerpf(5.5, 22.0, eased)
	var glow_radius := radius + lerpf(5.0, 12.0, eased)
	var ring_alpha := lerpf(0.14, 0.34, eased)
	var halo_color := Color(color.r, color.g, color.b, 0.16)
	var moon_color := Color(color.r, color.g, color.b, 0.92)
	var shadow_color := Color(0.04, 0.08, 0.18, 0.62)

	draw_circle(Vector2.ZERO, glow_radius, halo_color)
	draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 44, Color(color.r, color.g, color.b, ring_alpha), 2.0)
	draw_circle(Vector2.ZERO, radius, moon_color)
	draw_circle(Vector2(radius * 0.34, -radius * 0.08), radius * 0.86, shadow_color)
	draw_circle(Vector2(-radius * 0.24, -radius * 0.2), radius * 0.13, Color(1.0, 1.0, 1.0, 0.16))
	draw_circle(Vector2(-radius * 0.08, radius * 0.28), radius * 0.1, Color(1.0, 1.0, 1.0, 0.1))

func _draw_explosion() -> void:
	var progress := 1.0 - (_explosion_remaining_sec / 0.32)
	var eased := 1.0 - pow(1.0 - clampf(progress, 0.0, 1.0), 3.0)
	var ring_radius := lerpf(8.0, explosion_radius, eased)
	var fill_radius := ring_radius * 0.42
	var alpha := 1.0 - clampf(progress, 0.0, 1.0)
	var ring_color := Color(color.r, color.g, color.b, 0.72 * alpha)
	var fill_color := Color(color.r, color.g, color.b, 0.18 * alpha)
	draw_circle(Vector2.ZERO, fill_radius, fill_color)
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 72, ring_color, 4.0)
