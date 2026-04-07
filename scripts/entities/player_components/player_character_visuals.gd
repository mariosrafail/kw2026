extends RefCounted

class_name PlayerCharacterVisuals

const DEFAULT_TORSO_UI_COLOR := Color(0.98, 0.02, 0.07, 1.0)
const DEFAULT_CHARACTER_TINT := Color(1.0, 1.0, 1.0, 1.0)
const EREBUS_CHARACTER_TINT := Color(0.72, 0.78, 1.0, 1.0)
const TASKO_CHARACTER_TINT := Color(1.0, 0.65, 0.92, 1.0)

var _modular_visual_cb: Callable = Callable()
var _player_sprite: Node2D
var _torso_sprite: Sprite2D
var _body: Polygon2D

func configure(
	modular_visual_cb: Callable,
	player_sprite: Node2D,
	torso_sprite: Sprite2D,
	body: Polygon2D
) -> void:
	_modular_visual_cb = modular_visual_cb
	_player_sprite = player_sprite
	_torso_sprite = torso_sprite
	_body = body

func set_character_visual(character_id: String) -> void:
	var modular_visual: Variant = _modular_visual()
	if modular_visual != null:
		modular_visual.set_character_visual(character_id)
	if _player_sprite == null or not (_player_sprite is Sprite2D):
		return
	var sprite := _player_sprite as Sprite2D
	sprite.modulate = _character_tint(character_id)

func set_skin_index(skin_index: int) -> void:
	var modular_visual: Variant = _modular_visual()
	if modular_visual == null:
		return
	var idx: int = maxi(0, skin_index) + 1
	modular_visual.set_modular_part_indices(idx, idx, idx)

func get_torso_dominant_color() -> Color:
	if _torso_sprite == null:
		return DEFAULT_TORSO_UI_COLOR
	var torso_texture := _torso_sprite.texture
	if torso_texture == null:
		return _torso_sprite.modulate
	var image := torso_texture.get_image()
	if image == null or image.is_empty():
		return _torso_sprite.modulate

	var region := Rect2i(0, 0, image.get_width(), image.get_height())
	if _torso_sprite.region_enabled and _torso_sprite.region_rect.size.x > 0.0 and _torso_sprite.region_rect.size.y > 0.0:
		region = Rect2i(
			int(_torso_sprite.region_rect.position.x),
			int(_torso_sprite.region_rect.position.y),
			int(_torso_sprite.region_rect.size.x),
			int(_torso_sprite.region_rect.size.y)
		)

	var buckets: Dictionary = {}
	var best_key := ""
	var best_weight := -1.0
	var tint := _torso_sprite.modulate
	for y in range(region.position.y, region.position.y + region.size.y):
		for x in range(region.position.x, region.position.x + region.size.x):
			var pixel := image.get_pixel(x, y)
			var alpha := float(pixel.a) * float(tint.a)
			if alpha <= 0.1:
				continue
			var tinted := Color(pixel.r * tint.r, pixel.g * tint.g, pixel.b * tint.b, 1.0)
			var r := int(round(clampf(tinted.r, 0.0, 1.0) * 7.0))
			var g := int(round(clampf(tinted.g, 0.0, 1.0) * 7.0))
			var b := int(round(clampf(tinted.b, 0.0, 1.0) * 7.0))
			var bucket_key := "%d:%d:%d" % [r, g, b]
			var weight := float(buckets.get(bucket_key, 0.0)) + alpha
			buckets[bucket_key] = weight
			if weight > best_weight:
				best_weight = weight
				best_key = bucket_key

	if best_key.is_empty():
		return _torso_sprite.modulate
	var parts := best_key.split(":")
	if parts.size() != 3:
		return _torso_sprite.modulate
	return Color(
		float(parts[0].to_int()) / 7.0,
		float(parts[1].to_int()) / 7.0,
		float(parts[2].to_int()) / 7.0,
		1.0
	)

func get_main_torso_ui_color() -> Color:
	if _body != null:
		return Color(_body.color.r, _body.color.g, _body.color.b, 1.0)
	return get_torso_dominant_color()

func _character_tint(character_id: String) -> Color:
	var normalized := str(character_id).strip_edges().to_lower()
	match normalized:
		"erebus":
			return EREBUS_CHARACTER_TINT
		"tasko":
			return TASKO_CHARACTER_TINT
		_:
			return DEFAULT_CHARACTER_TINT

func _modular_visual() -> Variant:
	if _modular_visual_cb.is_valid():
		return _modular_visual_cb.call()
	return null
