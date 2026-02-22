extends Node2D
class_name HardLight2D

@export var enabled := true
@export var range_px := 520.0
@export var cone_angle_deg := 85.0
@export_range(0.0, 0.25, 0.005) var cone_edge_softness := 0.04
@export_range(0.05, 3.0, 0.05) var radial_falloff_pow := 0.45
@export var texture_size := 512
@export var color := Color(0.75, 0.9, 1.0, 1.0)
@export var energy := 1.2
@export var origin_offset := Vector2(0.0, -10.0)

@export var shadow_enabled := true
@export var shadow_color := Color(0.0, 0.0, 0.0, 1.0)
@export var shadow_filter := 0 # 0 = hard
@export var item_cull_mask := 1
@export var blend_mode := Light2D.BLEND_MODE_MIX

var _light: PointLight2D
var _texture: Texture2D

func _ready() -> void:
	_ensure_light()
	set_enabled(enabled)

func set_enabled(value: bool) -> void:
	enabled = value
	if _light != null:
		_light.visible = value

func _process(_delta: float) -> void:
	if not enabled:
		return
	_ensure_light()
	if _light == null:
		return
	_light.global_position = global_position + origin_offset.rotated(global_rotation)
	_light.global_rotation = _aim_rotation()

func _aim_rotation() -> float:
	var parent := get_parent()
	if parent != null and parent.has_method("get_aim_angle"):
		return float(parent.call("get_aim_angle"))
	return global_rotation

func _ensure_light() -> void:
	if _light != null and is_instance_valid(_light):
		_apply_light_settings()
		return
	_light = get_node_or_null("Light") as PointLight2D
	if _light == null:
		_light = PointLight2D.new()
		_light.name = "Light"
		add_child(_light)
	_apply_light_settings()

func _apply_light_settings() -> void:
	if _light == null:
		return
	if _texture == null:
		_texture = _build_cone_texture(maxi(64, texture_size))
	_light.texture = _texture
	_light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_light.energy = energy
	_light.color = color
	_light.shadow_enabled = shadow_enabled
	_light.shadow_color = shadow_color
	_light.shadow_filter = shadow_filter
	_apply_cull_masks()
	_light.blend_mode = blend_mode
	_light.texture_scale = maxf(0.2, range_px / 128.0)

func _apply_cull_masks() -> void:
	if _light == null:
		return

	# Godot versions/templates can expose different property names for 2D light cull masks.
	# Prefer the most specific names if present.
	var has_item_cull := _has_property(_light, &"item_cull_mask")
	var has_range_cull := _has_property(_light, &"range_item_cull_mask")
	var has_shadow_cull := _has_property(_light, &"shadow_item_cull_mask")

	if has_item_cull:
		_light.set("item_cull_mask", item_cull_mask)
	if has_range_cull:
		_light.set("range_item_cull_mask", item_cull_mask)
	if has_shadow_cull:
		_light.set("shadow_item_cull_mask", item_cull_mask)

func _has_property(obj: Object, prop_name: StringName) -> bool:
	if obj == null:
		return false
	for p in obj.get_property_list():
		var pd := p as Dictionary
		if pd.get("name", "") == String(prop_name):
			return true
	return false

func _build_cone_texture(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))

	var center := Vector2(float(size) * 0.5, float(size) * 0.5)
	var max_r := float(size) * 0.5
	var half_angle := deg_to_rad(cone_angle_deg) * 0.5
	var edge_soft := clampf(cone_edge_softness, 0.0, 0.25)
	var inv_edge_soft := 1.0 / maxf(0.0001, edge_soft)

	for y in range(size):
		for x in range(size):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5) - center
			var r := p.length()
			if r <= 0.001 or r > max_r:
				continue
			var ang := absf(atan2(p.y, p.x))
			if ang > half_angle:
				continue

			var t := r / max_r

			# Radial falloff: strong near the player, fades out at range.
			var radial := pow(maxf(0.0, 1.0 - t), radial_falloff_pow)

			# Mostly hard cone edge, but with a tiny softness so it doesn't look jaggy.
			var edge := 1.0
			if edge_soft > 0.0:
				var a_t := ang / half_angle
				if a_t > 1.0 - edge_soft:
					edge = clampf((1.0 - a_t) * inv_edge_soft, 0.0, 1.0)

			# Brighter in the center line, dimmer toward the sides.
			var side := 1.0 - clampf(ang / half_angle, 0.0, 1.0)
			var center_boost := 0.6 + 0.4 * side * side

			var a := clampf(radial * edge * center_boost, 0.0, 1.0)
			if a <= 0.001:
				continue
			img.set_pixel(x, y, Color(1, 1, 1, a))

	return ImageTexture.create_from_image(img)
