extends Node2D
class_name MadamAuraVfx

var caster_peer_id := 0
var duration_sec := 5.0
var radius := 138.0
var color := Color(0.86, 0.48, 0.42, 0.88)
var players: Dictionary = {}

var _remaining := 0.0
var _ring_outer: Sprite2D
var _ring_inner: Sprite2D
var _pulse_time := 0.0

func _ready() -> void:
	_remaining = maxf(0.05, duration_sec)
	_build_visual()
	_update_follow_position()

func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	_pulse_time += delta
	_update_follow_position()
	_update_visual()
	if _remaining <= 0.0:
		queue_free()

func _build_visual() -> void:
	_ring_outer = Sprite2D.new()
	_ring_outer.centered = true
	_ring_outer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ring_outer.z_index = 38
	_ring_outer.texture = _ring_texture(0.72, 0.82, color)
	add_child(_ring_outer)

	_ring_inner = Sprite2D.new()
	_ring_inner.centered = true
	_ring_inner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ring_inner.z_index = 37
	_ring_inner.texture = _ring_texture(0.0, 0.46, Color(color.r, color.g, color.b, 0.22))
	add_child(_ring_inner)

	_update_visual()

func _update_follow_position() -> void:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		queue_free()
		return
	global_position = caster.global_position + Vector2(0.0, -8.0)

func _update_visual() -> void:
	var pulse := 1.0 + sin(_pulse_time * 5.8) * 0.05
	var fade := clampf(_remaining / maxf(0.05, duration_sec), 0.0, 1.0)
	var outer_scale := (radius / 32.0) * pulse
	var inner_scale := (radius / 32.0) * (0.86 + sin(_pulse_time * 4.2) * 0.03)
	if _ring_outer != null:
		_ring_outer.scale = Vector2.ONE * outer_scale
		_ring_outer.modulate = Color(1.0, 1.0, 1.0, 0.72 + fade * 0.18)
	if _ring_inner != null:
		_ring_inner.scale = Vector2.ONE * inner_scale
		_ring_inner.modulate = Color(1.0, 1.0, 1.0, 0.32 + fade * 0.12)

func _ring_texture(inner_offset: float, outer_offset: float, tint: Color) -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, inner_offset, outer_offset, 1.0])
	gradient.colors = PackedColorArray([
		Color(tint.r, tint.g, tint.b, 0.0),
		Color(tint.r, tint.g, tint.b, 0.0),
		Color(tint.r, tint.g, tint.b, tint.a),
		Color(tint.r, tint.g, tint.b, 0.0)
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture
