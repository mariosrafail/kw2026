extends Node2D
class_name CrashOutBubbleVfx

var duration_sec := 4.5
var radius := 116.0
var color := Color(0.33, 0.93, 1.0, 0.92)
var follow_target: Node2D

var _remaining := 0.0
var _pulse_time := 0.0
var _outer_ring: Sprite2D
var _inner_ring: Sprite2D
var _fill: Sprite2D
var _sheen: Sprite2D

func _ready() -> void:
	_remaining = maxf(0.05, duration_sec)
	_build_visual()
	_update_visual()

func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	_pulse_time += delta
	if follow_target != null and is_instance_valid(follow_target):
		global_position = follow_target.global_position
	_update_visual()
	if _remaining <= 0.0:
		queue_free()

func _build_visual() -> void:
	_fill = Sprite2D.new()
	_fill.centered = true
	_fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fill.z_index = 34
	_fill.texture = _ring_texture(0.0, 0.98, Color(color.r, color.g, color.b, 0.12))
	add_child(_fill)

	_inner_ring = Sprite2D.new()
	_inner_ring.centered = true
	_inner_ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_inner_ring.z_index = 35
	_inner_ring.texture = _ring_texture(0.58, 0.74, Color(color.r, color.g, color.b, 0.44))
	add_child(_inner_ring)

	_outer_ring = Sprite2D.new()
	_outer_ring.centered = true
	_outer_ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_outer_ring.z_index = 36
	_outer_ring.texture = _ring_texture(0.82, 0.92, Color(color.r, color.g, color.b, 0.84))
	add_child(_outer_ring)

	_sheen = Sprite2D.new()
	_sheen.centered = true
	_sheen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sheen.z_index = 37
	_sheen.texture = _ring_texture(0.22, 0.42, Color(1.0, 1.0, 1.0, 0.24))
	add_child(_sheen)

func _update_visual() -> void:
	var fade := clampf(_remaining / maxf(0.05, duration_sec), 0.0, 1.0)
	var pulse_a := 1.0 + sin(_pulse_time * 4.6) * 0.045
	var pulse_b := 1.0 + sin(_pulse_time * 3.5 + 0.9) * 0.06
	var base_scale := radius / 32.0
	if _fill != null:
		_fill.scale = Vector2.ONE * (base_scale * 1.01 * pulse_b)
		_fill.modulate = Color(1.0, 1.0, 1.0, 0.24 + fade * 0.18)
	if _inner_ring != null:
		_inner_ring.scale = Vector2.ONE * (base_scale * 0.98 * pulse_a)
		_inner_ring.modulate = Color(1.0, 1.0, 1.0, 0.48 + fade * 0.12)
	if _outer_ring != null:
		_outer_ring.scale = Vector2.ONE * (base_scale * 1.05 * pulse_b)
		_outer_ring.modulate = Color(1.0, 1.0, 1.0, 0.66 + fade * 0.2)
	if _sheen != null:
		_sheen.scale = Vector2(0.84, 0.66) * (base_scale * (1.0 + sin(_pulse_time * 2.7) * 0.04))
		_sheen.position = Vector2(radius * -0.14, radius * -0.24)
		_sheen.modulate = Color(1.0, 1.0, 1.0, 0.16 + fade * 0.12)

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
