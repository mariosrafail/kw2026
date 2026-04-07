extends RefCounted

class_name PlayerDamageFeedback

const BLOOD_SCREEN_TEXTURES := [
	preload("res://assets/textures/effects/blood1.png"),
	preload("res://assets/textures/effects/blood2.png"),
	preload("res://assets/textures/effects/blood3.png"),
	preload("res://assets/textures/effects/blood4.png"),
	preload("res://assets/textures/effects/blood5.png"),
]
const DAMAGE_FLASH_WHITE_SHADER := preload("res://assets/shaders/damage_flash_white.gdshader")
const DAMAGE_FLASH_MIX_SHADER := preload("res://assets/shaders/damage_flash_mix.gdshader")
const DAMAGE_NUMBER_FONT := preload("res://assets/fonts/kwfont.ttf")
const DAMAGE_FLASH_DURATION_SEC := 0.38
const DAMAGE_FLASH_ALPHA := 1.0
const DAMAGE_FLASH_POP_IN_SEC := 0.015
const DAMAGE_FLASH_HOLD_SEC := 0.16
const DAMAGE_SCREEN_BLOOD_MAX_ALPHA := 0.2
const DAMAGE_SCREEN_BLOOD_FADE_IN_SEC := 0.03
const DAMAGE_SCREEN_BLOOD_HOLD_SEC := 0.04
const DAMAGE_SCREEN_BLOOD_FADE_OUT_SEC := 0.08
const DAMAGE_NUMBER_POP_SEC := 0.12
const DAMAGE_NUMBER_HOLD_SEC := 0.06
const DAMAGE_NUMBER_FADE_SEC := 0.24
const DAMAGE_NUMBER_START_SCALE := 0.46
const DAMAGE_NUMBER_PEAK_SCALE := 1.28
const DAMAGE_NUMBER_END_SCALE := 0.72
const DAMAGE_NUMBER_RISE_DISTANCE := 38.0
const DAMAGE_PART_SCRAMBLE_DURATION_SEC := 0.2

var _player: CharacterBody2D
var _visual_root: Node2D
var _head_sprite: Sprite2D
var _torso_sprite: Sprite2D
var _leg1_sprite: Sprite2D
var _leg2_sprite: Sprite2D
var _peer_id_cb: Callable = Callable()
var _local_peer_id_cb: Callable = Callable()
var _part_base_material_cb: Callable = Callable()
var _visibility_layer_cb: Callable = Callable()

var damage_flash_tween: Tween
var damage_flash_overlay_pairs: Array = []
var damage_flash_part_materials: Array = []
var damage_screen_blood_layer: CanvasLayer
var damage_screen_blood_rect: TextureRect
var damage_screen_blood_tween: Tween
var damage_numbers_root: Node2D
var damage_part_scramble_remaining_sec := 0.0
var damage_part_scramble_offsets: Dictionary = {}
var damage_part_scramble_rotations: Dictionary = {}

func configure(
	player: CharacterBody2D,
	visual_root: Node2D,
	head_sprite: Sprite2D,
	torso_sprite: Sprite2D,
	leg1_sprite: Sprite2D,
	leg2_sprite: Sprite2D,
	peer_id_cb: Callable,
	local_peer_id_cb: Callable,
	part_base_material_cb: Callable,
	visibility_layer_cb: Callable
) -> void:
	_player = player
	_visual_root = visual_root
	_head_sprite = head_sprite
	_torso_sprite = torso_sprite
	_leg1_sprite = leg1_sprite
	_leg2_sprite = leg2_sprite
	_peer_id_cb = peer_id_cb
	_local_peer_id_cb = local_peer_id_cb
	_part_base_material_cb = part_base_material_cb
	_visibility_layer_cb = visibility_layer_cb

func initialize() -> void:
	_init_damage_numbers_root()
	_init_damage_flash_overlays()

func tick(delta: float) -> void:
	_apply_damage_part_scramble(delta)
	if not damage_flash_overlay_pairs.is_empty():
		_sync_damage_flash_overlays()

func reset_for_respawn() -> void:
	damage_part_scramble_remaining_sec = 0.0
	damage_part_scramble_offsets.clear()
	damage_part_scramble_rotations.clear()
	if damage_flash_tween != null:
		damage_flash_tween.kill()
		_clear_damage_flash_tween()
	if damage_screen_blood_tween != null:
		damage_screen_blood_tween.kill()
		_clear_screen_damage_blood()

func show_damage_number(amount: int) -> void:
	if amount <= 0:
		return
	if damage_numbers_root == null:
		_init_damage_numbers_root()
	if damage_numbers_root == null:
		return
	var label := Label.new()
	var popup_size := Vector2(72.0, 24.0)
	var start_offset := Vector2(randf_range(-10.0, 10.0), randf_range(-4.0, 2.0))
	var end_offset := start_offset + Vector2(randf_range(-4.0, 4.0), -DAMAGE_NUMBER_RISE_DISTANCE)
	label.text = "-%d" % amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = start_offset - (popup_size * 0.5)
	label.size = popup_size
	label.pivot_offset = popup_size * 0.5
	label.scale = Vector2.ONE * DAMAGE_NUMBER_START_SCALE
	label.add_theme_font_override("font", DAMAGE_NUMBER_FONT)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.18, 0.18, 1.0))
	damage_numbers_root.add_child(label)

	var move_tween := _player.create_tween()
	move_tween.bind_node(label)
	var move_track := move_tween.tween_property(label, "position", end_offset - (popup_size * 0.5), DAMAGE_NUMBER_POP_SEC + DAMAGE_NUMBER_HOLD_SEC + DAMAGE_NUMBER_FADE_SEC)
	move_track.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var scale_tween := _player.create_tween()
	scale_tween.bind_node(label)
	var grow_track := scale_tween.tween_property(label, "scale", Vector2.ONE * DAMAGE_NUMBER_PEAK_SCALE, DAMAGE_NUMBER_POP_SEC)
	grow_track.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var shrink_track := scale_tween.tween_property(label, "scale", Vector2.ONE * DAMAGE_NUMBER_END_SCALE, DAMAGE_NUMBER_HOLD_SEC + DAMAGE_NUMBER_FADE_SEC)
	shrink_track.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var fade_tween := _player.create_tween()
	fade_tween.bind_node(label)
	fade_tween.tween_interval(DAMAGE_NUMBER_HOLD_SEC)
	var fade_track := fade_tween.tween_property(label, "modulate:a", 0.0, DAMAGE_NUMBER_FADE_SEC)
	fade_track.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade_tween.finished.connect(label.queue_free)

func play_damage_visual_feedback(push_direction: Vector2) -> void:
	_trigger_damage_part_scramble(push_direction)
	_play_screen_damage_blood()
	_play_damage_flash()

func _part_sprites() -> Array:
	return [_head_sprite, _torso_sprite, _leg1_sprite, _leg2_sprite]

func _init_damage_numbers_root() -> void:
	if _visual_root == null:
		return
	damage_numbers_root = _visual_root.get_node_or_null("DamageNumbers") as Node2D
	if damage_numbers_root != null:
		return
	damage_numbers_root = Node2D.new()
	damage_numbers_root.name = "DamageNumbers"
	damage_numbers_root.z_index = 4
	damage_numbers_root.position = Vector2(0.0, -16.0)
	_visual_root.add_child(damage_numbers_root)
	if _visibility_layer_cb.is_valid():
		_visibility_layer_cb.call(damage_numbers_root, _visual_root.visibility_layer)

func _init_damage_flash_overlays() -> void:
	damage_flash_overlay_pairs.clear()
	for source in _part_sprites():
		if not (source is Sprite2D):
			continue
		var source_sprite := source as Sprite2D
		var overlay := Sprite2D.new()
		overlay.texture_filter = source_sprite.texture_filter
		overlay.centered = source_sprite.centered
		overlay.offset = source_sprite.offset
		overlay.texture = source_sprite.texture
		overlay.region_enabled = source_sprite.region_enabled
		overlay.region_rect = source_sprite.region_rect
		overlay.hframes = source_sprite.hframes
		overlay.vframes = source_sprite.vframes
		overlay.frame = source_sprite.frame
		overlay.frame_coords = source_sprite.frame_coords
		overlay.z_index = source_sprite.z_index + 20
		var overlay_material := ShaderMaterial.new()
		overlay_material.shader = DAMAGE_FLASH_WHITE_SHADER
		overlay.material = overlay_material
		overlay.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		overlay.visible = false
		source_sprite.get_parent().add_child(overlay)
		if _visibility_layer_cb.is_valid():
			_visibility_layer_cb.call(overlay, source_sprite.visibility_layer)
		damage_flash_overlay_pairs.append({
			"source": source_sprite,
			"overlay": overlay,
		})
	_sync_damage_flash_overlays()

func _init_damage_flash_materials() -> void:
	damage_flash_part_materials.clear()
	for sprite in _part_sprites():
		if sprite == null:
			continue
		var material := ShaderMaterial.new()
		material.shader = DAMAGE_FLASH_MIX_SHADER
		material.set_shader_parameter("flash_strength", 0.0)
		sprite.material = material
		damage_flash_part_materials.append({
			"sprite": sprite,
			"material": material,
		})

func _set_damage_flash_strength(value: float) -> void:
	for material_value in damage_flash_part_materials:
		if not (material_value is Dictionary):
			continue
		var material_entry := material_value as Dictionary
		var material := material_entry.get("material", null) as ShaderMaterial
		if material == null:
			continue
		material.set_shader_parameter("flash_strength", clampf(value, 0.0, 1.0))

func _sync_damage_flash_overlays() -> void:
	for pair_value in damage_flash_overlay_pairs:
		if not (pair_value is Dictionary):
			continue
		var pair := pair_value as Dictionary
		var source := pair.get("source", null) as Sprite2D
		var overlay := pair.get("overlay", null) as Sprite2D
		if source == null or overlay == null:
			continue
		overlay.position = source.position
		overlay.rotation = source.rotation
		overlay.scale = source.scale
		overlay.skew = source.skew
		overlay.flip_h = source.flip_h
		overlay.flip_v = source.flip_v
		overlay.texture = source.texture
		overlay.region_enabled = source.region_enabled
		overlay.region_rect = source.region_rect
		overlay.hframes = source.hframes
		overlay.vframes = source.vframes
		overlay.frame = source.frame
		overlay.frame_coords = source.frame_coords

func _play_damage_flash() -> void:
	if damage_flash_tween != null:
		damage_flash_tween.kill()
		_hide_damage_flash_overlays()
	_init_damage_flash_materials()
	if damage_flash_overlay_pairs.is_empty():
		_set_damage_flash_strength(0.0)
	else:
		_sync_damage_flash_overlays()
		_set_damage_flash_strength(0.0)
	damage_flash_tween = _player.create_tween()
	var shader_pop := damage_flash_tween.parallel().tween_method(Callable(self, "_set_damage_flash_strength"), 0.0, DAMAGE_FLASH_ALPHA, DAMAGE_FLASH_POP_IN_SEC)
	shader_pop.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	for pair_value in damage_flash_overlay_pairs:
		if not (pair_value is Dictionary):
			continue
		var pair := pair_value as Dictionary
		var overlay := pair.get("overlay", null) as Sprite2D
		if overlay == null:
			continue
		overlay.visible = true
		overlay.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		var pop_track := damage_flash_tween.parallel().tween_property(overlay, "self_modulate:a", DAMAGE_FLASH_ALPHA, DAMAGE_FLASH_POP_IN_SEC)
		pop_track.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	damage_flash_tween.tween_interval(DAMAGE_FLASH_HOLD_SEC)
	var shader_fade_duration := maxf(0.01, DAMAGE_FLASH_DURATION_SEC - DAMAGE_FLASH_POP_IN_SEC - DAMAGE_FLASH_HOLD_SEC)
	var shader_fade := damage_flash_tween.parallel().tween_method(Callable(self, "_set_damage_flash_strength"), DAMAGE_FLASH_ALPHA, 0.0, shader_fade_duration)
	shader_fade.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	for pair_value in damage_flash_overlay_pairs:
		if not (pair_value is Dictionary):
			continue
		var pair := pair_value as Dictionary
		var overlay := pair.get("overlay", null) as Sprite2D
		if overlay == null:
			continue
		var fade_track := damage_flash_tween.parallel().tween_property(overlay, "self_modulate:a", 0.0, shader_fade_duration)
		fade_track.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	damage_flash_tween.tween_callback(Callable(self, "_clear_damage_flash_tween"))

func _hide_damage_flash_overlays() -> void:
	_set_damage_flash_strength(0.0)
	for material_value in damage_flash_part_materials:
		if not (material_value is Dictionary):
			continue
		var material_entry := material_value as Dictionary
		var sprite := material_entry.get("sprite", null) as Sprite2D
		if sprite == null:
			continue
		if _part_base_material_cb.is_valid():
			sprite.material = _part_base_material_cb.call(sprite) as Material
	damage_flash_part_materials.clear()
	for pair_value in damage_flash_overlay_pairs:
		if not (pair_value is Dictionary):
			continue
		var pair := pair_value as Dictionary
		var overlay := pair.get("overlay", null) as Sprite2D
		if overlay == null:
			continue
		overlay.visible = false
		overlay.self_modulate = Color(1.0, 1.0, 1.0, 0.0)

func _clear_damage_flash_tween() -> void:
	_hide_damage_flash_overlays()
	damage_flash_tween = null

func _trigger_damage_part_scramble(push_direction: Vector2) -> void:
	damage_part_scramble_remaining_sec = DAMAGE_PART_SCRAMBLE_DURATION_SEC
	damage_part_scramble_offsets.clear()
	damage_part_scramble_rotations.clear()
	var push_offset := Vector2(push_direction.x * 11.0, push_direction.y * 5.5 - 1.5)
	for sprite in _part_sprites():
		if sprite == null:
			continue
		damage_part_scramble_offsets[sprite] = push_offset + Vector2(
			randf_range(-2.0, 2.0),
			randf_range(-3.0, 3.0)
		)
		damage_part_scramble_rotations[sprite] = push_direction.x * randf_range(0.35, 0.8) + randf_range(-0.12, 0.12)

func _apply_damage_part_scramble(delta: float) -> void:
	if damage_part_scramble_remaining_sec <= 0.0:
		return
	damage_part_scramble_remaining_sec = maxf(0.0, damage_part_scramble_remaining_sec - delta)
	var weight := clampf(damage_part_scramble_remaining_sec / DAMAGE_PART_SCRAMBLE_DURATION_SEC, 0.0, 1.0)
	for sprite in _part_sprites():
		if sprite == null:
			continue
		var offset := damage_part_scramble_offsets.get(sprite, Vector2.ZERO) as Vector2
		var rotation_offset := float(damage_part_scramble_rotations.get(sprite, 0.0))
		sprite.position += offset * weight
		sprite.rotation += rotation_offset * weight
	if damage_part_scramble_remaining_sec <= 0.0:
		damage_part_scramble_offsets.clear()
		damage_part_scramble_rotations.clear()

func _play_screen_damage_blood() -> void:
	var local_peer_id := _local_peer_id()
	var peer_id := _peer_id()
	if peer_id <= 0 or peer_id != local_peer_id:
		return
	_ensure_screen_damage_blood_overlay()
	if damage_screen_blood_rect == null:
		return
	if damage_screen_blood_tween != null:
		damage_screen_blood_tween.kill()
	damage_screen_blood_rect.texture = BLOOD_SCREEN_TEXTURES[randi() % BLOOD_SCREEN_TEXTURES.size()]
	damage_screen_blood_rect.visible = true
	damage_screen_blood_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	damage_screen_blood_tween = _player.create_tween()
	var fade_in := damage_screen_blood_tween.tween_property(damage_screen_blood_rect, "modulate:a", DAMAGE_SCREEN_BLOOD_MAX_ALPHA, DAMAGE_SCREEN_BLOOD_FADE_IN_SEC)
	fade_in.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	damage_screen_blood_tween.tween_interval(DAMAGE_SCREEN_BLOOD_HOLD_SEC)
	var fade_out := damage_screen_blood_tween.tween_property(damage_screen_blood_rect, "modulate:a", 0.0, DAMAGE_SCREEN_BLOOD_FADE_OUT_SEC)
	fade_out.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	damage_screen_blood_tween.tween_callback(Callable(self, "_clear_screen_damage_blood"))

func _ensure_screen_damage_blood_overlay() -> void:
	if damage_screen_blood_rect != null and is_instance_valid(damage_screen_blood_rect):
		return
	var tree := _player.get_tree()
	if tree == null:
		return
	var hud_layer := tree.current_scene.get_node_or_null("ClientHud") if tree.current_scene != null else null
	if hud_layer is CanvasLayer:
		damage_screen_blood_layer = hud_layer as CanvasLayer
	else:
		var overlay_host: Node = tree.current_scene
		if overlay_host == null:
			overlay_host = tree.root
		damage_screen_blood_layer = CanvasLayer.new()
		damage_screen_blood_layer.layer = 200
		damage_screen_blood_layer.follow_viewport_enabled = true
		overlay_host.add_child(damage_screen_blood_layer)
	damage_screen_blood_rect = TextureRect.new()
	damage_screen_blood_rect.name = "DamageScreenBlood"
	damage_screen_blood_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_screen_blood_rect.offset_left = 0.0
	damage_screen_blood_rect.offset_top = 0.0
	damage_screen_blood_rect.offset_right = 0.0
	damage_screen_blood_rect.offset_bottom = 0.0
	damage_screen_blood_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_screen_blood_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	damage_screen_blood_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	damage_screen_blood_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	damage_screen_blood_rect.z_index = 1000
	damage_screen_blood_rect.visible = false
	damage_screen_blood_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	damage_screen_blood_layer.add_child(damage_screen_blood_rect)

func _clear_screen_damage_blood() -> void:
	if damage_screen_blood_rect != null:
		damage_screen_blood_rect.visible = false
		damage_screen_blood_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	damage_screen_blood_tween = null

func _peer_id() -> int:
	if _peer_id_cb.is_valid():
		return int(_peer_id_cb.call())
	return 0

func _local_peer_id() -> int:
	if _local_peer_id_cb.is_valid():
		return int(_local_peer_id_cb.call())
	return 0
