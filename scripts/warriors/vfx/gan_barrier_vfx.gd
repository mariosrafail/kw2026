extends Node2D
class_name GanBarrierVfx

var duration_sec := 5.0
var radius := 210.0
var color := Color(0.38, 0.86, 1.0, 0.9)

var _remaining := 0.0
var _pulse_time := 0.0
var _ring_outer: Sprite2D
var _ring_inner: Sprite2D
var _fill: Sprite2D

func _ready() -> void:
	_remaining = maxf(0.05, duration_sec)
	_build_visual()
	_update_visual()

func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	_pulse_time += delta
	_update_visual()
	if _remaining <= 0.0:
		queue_free()

func _build_visual() -> void:
	_fill = Sprite2D.new()
	_fill.centered = true
	_fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fill.z_index = 34
	_fill.texture = _ring_texture(0.0, 0.94, Color(color.r, color.g, color.b, 0.1))
	add_child(_fill)

	_ring_inner = Sprite2D.new()
	_ring_inner.centered = true
	_ring_inner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ring_inner.z_index = 35
	_ring_inner.texture = _ring_texture(0.62, 0.78, Color(color.r, color.g, color.b, 0.54))
	add_child(_ring_inner)

	_ring_outer = Sprite2D.new()
	_ring_outer.centered = true
	_ring_outer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ring_outer.z_index = 36
	_ring_outer.texture = _ring_texture(0.8, 0.9, Color(color.r, color.g, color.b, 0.86))
	add_child(_ring_outer)

func _update_visual() -> void:
	var fade := clampf(_remaining / maxf(0.05, duration_sec), 0.0, 1.0)
	var pulse_a := 1.0 + sin(_pulse_time * 5.2) * 0.035
	var pulse_b := 1.0 + sin(_pulse_time * 4.0 + 0.9) * 0.05
	var base_scale := radius / 32.0
	if _fill != null:
		_fill.scale = Vector2.ONE * (base_scale * 0.98 * pulse_b)
		_fill.modulate = Color(1.0, 1.0, 1.0, 0.32 + fade * 0.18)
	if _ring_inner != null:
		_ring_inner.scale = Vector2.ONE * (base_scale * 1.02 * pulse_a)
		_ring_inner.modulate = Color(1.0, 1.0, 1.0, 0.58 + fade * 0.16)
	if _ring_outer != null:
		_ring_outer.scale = Vector2.ONE * (base_scale * 1.05 * pulse_b)
		_ring_outer.modulate = Color(1.0, 1.0, 1.0, 0.72 + fade * 0.18)

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
