extends RefCounted

class_name PlayerStatusVisuals

const OUTRAGE_BOOST_FIRE_SHADER := preload("res://assets/shaders/outrage_boost_fire.gdshader")
const EREBUS_IMMUNE_SHIMMER_SHADER := preload("res://assets/shaders/erebus_immune_shimmer.gdshader")
const JUICE_SHRINK_DEFAULT_SCALE := 0.46
const JUICE_SHRINK_ENTER_POP_SCALE := 1.08
const JUICE_SHRINK_EXIT_POP_SCALE := 1.1
const JUICE_SHRINK_ENTER_POP_SEC := 0.06
const JUICE_SHRINK_ENTER_SETTLE_SEC := 0.15
const JUICE_SHRINK_EXIT_POP_SEC := 0.09
const JUICE_SHRINK_EXIT_SETTLE_SEC := 0.12
const JUICE_SHRINK_FOOT_ANCHOR_HEIGHT := 36.0
const ULTI_DURATION_BAR_SIZE := Vector2(56.0, 4.0)
const ULTI_DURATION_BAR_OFFSET := Vector2(-28.0, -72.0)
const ULTI_DURATION_BAR_BG_COLOR := Color(0.04, 0.08, 0.12, 0.86)
const ULTI_DURATION_BAR_FILL_COLOR := Color(0.24, 0.8, 0.94, 0.97)
const ULTI_STATUS_LABEL_OFFSET := Vector2(-32.0, -88.0)
const ULTI_STATUS_LABEL_SIZE := Vector2(64.0, 12.0)
const ULTI_STATUS_LABEL_COLOR := Color(1.0, 0.97, 0.88, 1.0)
const ULTI_STATUS_LABEL_OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 1.0)
const HIT_HEIGHT := 34.0
const EREBUS_IMMUNE_HITBOX_SCALE := 1.28
const EREBUS_IMMUNE_HEAD_SCALE := 1.18
const EREBUS_IMMUNE_TORSO_SCALE := 1.16
const EREBUS_IMMUNE_HEAD_Y_OFFSET := -3.5
const EREBUS_IMMUNE_TORSO_Y_OFFSET := -2.0
const EREBUS_IMMUNE_SPEED_MULTIPLIER := 0.72
const EREBUS_IMMUNE_JUMP_MULTIPLIER := 0.74
const VISUAL_CORRECTION_DECAY := 9.0
const SKILL_BAR_DEFAULT_REGION := Rect2(0, 0, 61, 2)

var _player: CharacterBody2D
var _visual_root: Node2D
var _body_collision_shape: CollisionShape2D
var _head_sprite: Sprite2D
var _torso_sprite: Sprite2D
var _leg1_sprite: Sprite2D
var _leg2_sprite: Sprite2D
var _skill_label: Label
var _skill_duration_bar_bg: Sprite2D
var _skill_duration_bar: Sprite2D
var _peer_id_cb: Callable = Callable()
var _local_peer_id_cb: Callable = Callable()
var _torso_ui_color_cb: Callable = Callable()
var _visibility_layer_cb: Callable = Callable()

var visual_correction_offset := Vector2.ZERO
var outrage_boost_remaining_sec := 0.0
var outrage_boost_materials: Dictionary = {}
var outrage_boost_base_modulates: Dictionary = {}
var outrage_boost_overlay_pairs: Array = []
var erebus_immune_visual_remaining_sec := 0.0
var erebus_immune_materials: Dictionary = {}
var _erebus_immune_base_collision_scale := Vector2.ONE
var _erebus_immune_base_collision_position := Vector2.ZERO
var _erebus_immune_base_head_scale := Vector2.ONE
var _erebus_immune_base_torso_scale := Vector2.ONE
var _erebus_immune_base_head_position := Vector2.ZERO
var _erebus_immune_base_torso_position := Vector2.ZERO
var _erebus_immune_size_captured := false
var juice_shrink_remaining_sec := 0.0
var juice_shrink_scale := JUICE_SHRINK_DEFAULT_SCALE
var _juice_shrink_base_visual_scale := Vector2.ONE
var _juice_shrink_base_visual_position := Vector2.ZERO
var _juice_shrink_base_collision_scale := Vector2.ONE
var _juice_shrink_base_collision_position := Vector2.ZERO
var _juice_shrink_base_captured := false
var _juice_shrink_current_visual_scale := 1.0
var _juice_shrink_visual_offset := Vector2.ZERO
var _juice_shrink_tween: Tween
var outrage_boost_screen_fire_layer: CanvasLayer
var outrage_boost_screen_fire_root: Control
var outrage_boost_screen_fire_nodes: Array = []
var outrage_boost_screen_fire_base_alpha := 0.0
var ulti_duration_bar_root: Node2D
var ulti_duration_bar_fill: Sprite2D
var ulti_duration_total_sec := 0.0
var ulti_duration_remaining_sec := 0.0
var ulti_status_label: Label
var ulti_status_text := ""
var _skill_duration_bar_base_region: Rect2 = SKILL_BAR_DEFAULT_REGION
var _skill_duration_bar_base_scale: Vector2 = Vector2.ONE
var _skill_duration_bar_base_modulate: Color = Color.WHITE
var _skill_duration_bar_base_captured := false

func configure(
	player: CharacterBody2D,
	visual_root: Node2D,
	body_collision_shape: CollisionShape2D,
	head_sprite: Sprite2D,
	torso_sprite: Sprite2D,
	leg1_sprite: Sprite2D,
	leg2_sprite: Sprite2D,
	skill_label: Label,
	skill_duration_bar_bg: Sprite2D,
	skill_duration_bar: Sprite2D,
	peer_id_cb: Callable,
	local_peer_id_cb: Callable,
	torso_ui_color_cb: Callable,
	visibility_layer_cb: Callable
) -> void:
	_player = player
	_visual_root = visual_root
	_body_collision_shape = body_collision_shape
	_head_sprite = head_sprite
	_torso_sprite = torso_sprite
	_leg1_sprite = leg1_sprite
	_leg2_sprite = leg2_sprite
	_skill_label = skill_label
	_skill_duration_bar_bg = skill_duration_bar_bg
	_skill_duration_bar = skill_duration_bar
	_peer_id_cb = peer_id_cb
	_local_peer_id_cb = local_peer_id_cb
	_torso_ui_color_cb = torso_ui_color_cb
	_visibility_layer_cb = visibility_layer_cb

func initialize() -> void:
	_capture_erebus_immune_base_size()
	_capture_juice_shrink_base_size()
	_refresh_visual_root_offset()
	_init_outrage_boost_overlays()
	_ensure_ulti_duration_bar()
	clear_ulti_duration_bar()

func tick(delta: float) -> void:
	_tick_visual_correction(delta)
	if outrage_boost_remaining_sec > 0.0:
		outrage_boost_remaining_sec = maxf(0.0, outrage_boost_remaining_sec - delta)
		_tick_outrage_boost_part_colors()
		_tick_outrage_boost_screen_fire(delta)
		if outrage_boost_remaining_sec <= 0.0:
			_apply_part_base_materials()
			_set_outrage_boost_overlay_alpha(0.0)
			_set_outrage_boost_screen_fire_alpha(0.0)
			_restore_outrage_boost_base_modulates()
	if erebus_immune_visual_remaining_sec > 0.0:
		erebus_immune_visual_remaining_sec = maxf(0.0, erebus_immune_visual_remaining_sec - delta)
		_tick_erebus_immune_visual()
		if erebus_immune_visual_remaining_sec <= 0.0:
			clear_erebus_immune_visual()
	if juice_shrink_remaining_sec > 0.0:
		juice_shrink_remaining_sec = maxf(0.0, juice_shrink_remaining_sec - delta)
		if juice_shrink_remaining_sec <= 0.0:
			clear_juice_shrink_visual()
	if ulti_duration_remaining_sec > 0.0:
		ulti_duration_remaining_sec = maxf(0.0, ulti_duration_remaining_sec - delta)
		_update_ulti_duration_bar_visual()
	if not outrage_boost_overlay_pairs.is_empty():
		_sync_outrage_boost_overlays()

func reset_for_respawn() -> void:
	visual_correction_offset = Vector2.ZERO
	outrage_boost_remaining_sec = 0.0
	erebus_immune_visual_remaining_sec = 0.0
	juice_shrink_remaining_sec = 0.0
	juice_shrink_scale = JUICE_SHRINK_DEFAULT_SCALE
	clear_ulti_duration_bar()
	clear_erebus_immune_visual()
	clear_juice_shrink_visual(false)
	clear_outrage_boost_visual()
	_refresh_visual_root_offset()

func get_part_base_material(sprite: Sprite2D) -> Material:
	if sprite == null:
		return null
	if erebus_immune_visual_remaining_sec > 0.0:
		return erebus_immune_materials.get(sprite, null) as Material
	if outrage_boost_remaining_sec > 0.0:
		return outrage_boost_materials.get(sprite, null) as Material
	return null

func get_movement_speed_multiplier() -> float:
	if erebus_immune_visual_remaining_sec > 0.0:
		return EREBUS_IMMUNE_SPEED_MULTIPLIER
	return 1.0

func get_jump_velocity_multiplier() -> float:
	if erebus_immune_visual_remaining_sec > 0.0:
		return EREBUS_IMMUNE_JUMP_MULTIPLIER
	return 1.0

func get_hit_radius(base_radius: float) -> float:
	var radius := base_radius
	if erebus_immune_visual_remaining_sec > 0.0:
		radius *= EREBUS_IMMUNE_HITBOX_SCALE
	if juice_shrink_remaining_sec > 0.0:
		radius *= clampf(juice_shrink_scale, 0.2, 1.0)
	return radius

func get_hit_height(base_height: float) -> float:
	var height := base_height
	if erebus_immune_visual_remaining_sec > 0.0:
		height *= EREBUS_IMMUNE_HITBOX_SCALE
	if juice_shrink_remaining_sec > 0.0:
		height *= clampf(juice_shrink_scale, 0.2, 1.0)
	return height

func set_outrage_boost_visual(duration_sec: float) -> void:
	var was_inactive := outrage_boost_remaining_sec <= 0.0
	outrage_boost_remaining_sec = maxf(outrage_boost_remaining_sec, maxf(0.0, duration_sec))
	if outrage_boost_remaining_sec <= 0.0:
		_apply_part_base_materials()
		_set_outrage_boost_overlay_alpha(0.0)
		_set_outrage_boost_screen_fire_alpha(0.0)
		_restore_outrage_boost_base_modulates()
		return
	if was_inactive:
		_capture_outrage_boost_base_modulates()
	_ensure_outrage_boost_materials()
	_apply_part_base_materials()
	_sync_outrage_boost_overlays()
	_set_outrage_boost_overlay_alpha(0.52)
	_ensure_outrage_boost_screen_fire_overlay()
	_set_outrage_boost_screen_fire_alpha(0.05)
	_tick_outrage_boost_part_colors()

func clear_outrage_boost_visual() -> void:
	outrage_boost_remaining_sec = 0.0
	_apply_part_base_materials()
	_set_outrage_boost_overlay_alpha(0.0)
	_set_outrage_boost_screen_fire_alpha(0.0)
	_restore_outrage_boost_base_modulates()

func set_erebus_immune_visual(duration_sec: float) -> void:
	erebus_immune_visual_remaining_sec = maxf(erebus_immune_visual_remaining_sec, maxf(0.0, duration_sec))
	if erebus_immune_visual_remaining_sec <= 0.0:
		clear_erebus_immune_visual()
		return
	_ensure_erebus_immune_materials()
	_apply_erebus_immune_size()
	_apply_part_base_materials()
	_tick_erebus_immune_visual()

func clear_erebus_immune_visual() -> void:
	erebus_immune_visual_remaining_sec = 0.0
	_restore_erebus_immune_size()
	_apply_part_base_materials()

func set_juice_shrink_visual(duration_sec: float, scale_factor: float = JUICE_SHRINK_DEFAULT_SCALE) -> void:
	var was_inactive := juice_shrink_remaining_sec <= 0.0
	juice_shrink_scale = clampf(scale_factor, 0.2, 1.0)
	juice_shrink_remaining_sec = maxf(juice_shrink_remaining_sec, maxf(0.0, duration_sec))
	if juice_shrink_remaining_sec <= 0.0:
		clear_juice_shrink_visual(false)
		return
	if was_inactive:
		_animate_juice_shrink_enter()
	else:
		_apply_juice_shrink_size()

func clear_juice_shrink_visual(animate: bool = true) -> void:
	juice_shrink_remaining_sec = 0.0
	juice_shrink_scale = JUICE_SHRINK_DEFAULT_SCALE
	if animate:
		_animate_juice_shrink_exit()
	else:
		_kill_juice_shrink_tween()
		_restore_juice_shrink_size()

func start_ulti_duration_bar(duration_sec: float, status_text: String = "") -> void:
	var resolved := maxf(0.0, duration_sec)
	if resolved <= 0.0:
		clear_ulti_duration_bar()
		return
	ulti_duration_total_sec = resolved
	ulti_duration_remaining_sec = resolved
	ulti_status_text = status_text.strip_edges()
	_update_ulti_duration_bar_visual()

func clear_ulti_duration_bar() -> void:
	ulti_duration_total_sec = 0.0
	ulti_duration_remaining_sec = 0.0
	ulti_status_text = ""
	_update_ulti_duration_bar_visual()

func apply_visual_correction(offset: Vector2) -> void:
	if _visual_root == null:
		return
	visual_correction_offset += offset
	_refresh_visual_root_offset()

func _part_sprites() -> Array:
	return [_head_sprite, _torso_sprite, _leg1_sprite, _leg2_sprite]

func _capture_erebus_immune_base_size() -> void:
	if _erebus_immune_size_captured:
		return
	if _body_collision_shape != null:
		_erebus_immune_base_collision_scale = _body_collision_shape.scale
		_erebus_immune_base_collision_position = _body_collision_shape.position
	if _head_sprite != null:
		_erebus_immune_base_head_scale = _head_sprite.scale
		_erebus_immune_base_head_position = _head_sprite.position
	if _torso_sprite != null:
		_erebus_immune_base_torso_scale = _torso_sprite.scale
		_erebus_immune_base_torso_position = _torso_sprite.position
	_erebus_immune_size_captured = true

func _apply_erebus_immune_size() -> void:
	_capture_erebus_immune_base_size()
	if _body_collision_shape != null:
		_body_collision_shape.scale = Vector2(
			_erebus_immune_base_collision_scale.x * EREBUS_IMMUNE_HITBOX_SCALE,
			_erebus_immune_base_collision_scale.y * EREBUS_IMMUNE_HITBOX_SCALE
		)
		var hitbox_growth := HIT_HEIGHT * (EREBUS_IMMUNE_HITBOX_SCALE - 1.0)
		_body_collision_shape.position = _erebus_immune_base_collision_position + Vector2(0.0, -hitbox_growth * 0.5)
	if _head_sprite != null:
		_head_sprite.scale = Vector2(
			_erebus_immune_base_head_scale.x * EREBUS_IMMUNE_HEAD_SCALE,
			_erebus_immune_base_head_scale.y * EREBUS_IMMUNE_HEAD_SCALE
		)
		_head_sprite.position = _erebus_immune_base_head_position + Vector2(0.0, EREBUS_IMMUNE_HEAD_Y_OFFSET)
	if _torso_sprite != null:
		_torso_sprite.scale = Vector2(
			_erebus_immune_base_torso_scale.x * EREBUS_IMMUNE_TORSO_SCALE,
			_erebus_immune_base_torso_scale.y * EREBUS_IMMUNE_TORSO_SCALE
		)
		_torso_sprite.position = _erebus_immune_base_torso_position + Vector2(0.0, EREBUS_IMMUNE_TORSO_Y_OFFSET)

func _restore_erebus_immune_size() -> void:
	if not _erebus_immune_size_captured:
		return
	if _body_collision_shape != null:
		_body_collision_shape.scale = _erebus_immune_base_collision_scale
		_body_collision_shape.position = _erebus_immune_base_collision_position
	if _head_sprite != null:
		_head_sprite.scale = _erebus_immune_base_head_scale
		_head_sprite.position = _erebus_immune_base_head_position
	if _torso_sprite != null:
		_torso_sprite.scale = _erebus_immune_base_torso_scale
		_torso_sprite.position = _erebus_immune_base_torso_position

func _capture_juice_shrink_base_size() -> void:
	if _juice_shrink_base_captured:
		return
	if _visual_root != null:
		_juice_shrink_base_visual_scale = _visual_root.scale
		_juice_shrink_base_visual_position = _visual_root.position
	if _body_collision_shape != null:
		_juice_shrink_base_collision_scale = _body_collision_shape.scale
		_juice_shrink_base_collision_position = _body_collision_shape.position
	_juice_shrink_current_visual_scale = 1.0
	_juice_shrink_visual_offset = Vector2.ZERO
	_juice_shrink_base_captured = true

func _kill_juice_shrink_tween() -> void:
	if _juice_shrink_tween != null:
		_juice_shrink_tween.kill()
	_juice_shrink_tween = null

func _refresh_visual_root_offset() -> void:
	if _visual_root == null:
		return
	_visual_root.position = _juice_shrink_base_visual_position + visual_correction_offset + _juice_shrink_visual_offset

func _apply_juice_shrink_scale_state(scale_factor: float) -> void:
	_capture_juice_shrink_base_size()
	var safe_scale := clampf(scale_factor, 0.2, JUICE_SHRINK_EXIT_POP_SCALE)
	_juice_shrink_current_visual_scale = safe_scale
	if _visual_root != null:
		_visual_root.scale = _juice_shrink_base_visual_scale * safe_scale
		var foot_anchor_offset := JUICE_SHRINK_FOOT_ANCHOR_HEIGHT * (1.0 - safe_scale)
		_juice_shrink_visual_offset = Vector2(0.0, foot_anchor_offset)
		_refresh_visual_root_offset()
	if _body_collision_shape != null:
		_body_collision_shape.scale = Vector2(
			_juice_shrink_base_collision_scale.x * safe_scale,
			_juice_shrink_base_collision_scale.y * safe_scale
		)
		var hitbox_delta := HIT_HEIGHT * (safe_scale - 1.0)
		_body_collision_shape.position = _juice_shrink_base_collision_position + Vector2(0.0, -hitbox_delta * 0.5)

func _apply_juice_shrink_size() -> void:
	_apply_juice_shrink_scale_state(juice_shrink_scale)

func _restore_juice_shrink_size() -> void:
	if not _juice_shrink_base_captured:
		return
	_apply_juice_shrink_scale_state(1.0)

func _animate_juice_shrink_enter() -> void:
	_kill_juice_shrink_tween()
	var target_scale := clampf(juice_shrink_scale, 0.2, 1.0)
	var start_scale := clampf(_juice_shrink_current_visual_scale, 0.2, JUICE_SHRINK_EXIT_POP_SCALE)
	var pop_scale := maxf(start_scale, JUICE_SHRINK_ENTER_POP_SCALE)
	_juice_shrink_tween = _player.create_tween()
	var pop_track := _juice_shrink_tween.tween_method(Callable(self, "_apply_juice_shrink_scale_state"), start_scale, pop_scale, JUICE_SHRINK_ENTER_POP_SEC)
	pop_track.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var shrink_track := _juice_shrink_tween.tween_method(Callable(self, "_apply_juice_shrink_scale_state"), pop_scale, target_scale, JUICE_SHRINK_ENTER_SETTLE_SEC)
	shrink_track.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_juice_shrink_tween.finished.connect(func() -> void:
		_juice_shrink_tween = null
	)

func _animate_juice_shrink_exit() -> void:
	_kill_juice_shrink_tween()
	var start_scale := clampf(_juice_shrink_current_visual_scale, 0.2, JUICE_SHRINK_EXIT_POP_SCALE)
	_juice_shrink_tween = _player.create_tween()
	var pop_track := _juice_shrink_tween.tween_method(Callable(self, "_apply_juice_shrink_scale_state"), start_scale, JUICE_SHRINK_EXIT_POP_SCALE, JUICE_SHRINK_EXIT_POP_SEC)
	pop_track.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var settle_track := _juice_shrink_tween.tween_method(Callable(self, "_apply_juice_shrink_scale_state"), JUICE_SHRINK_EXIT_POP_SCALE, 1.0, JUICE_SHRINK_EXIT_SETTLE_SEC)
	settle_track.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_juice_shrink_tween.finished.connect(func() -> void:
		_juice_shrink_tween = null
	)

func _ensure_outrage_boost_materials() -> void:
	if not outrage_boost_materials.is_empty():
		return
	for sprite_value in _part_sprites():
		var sprite := sprite_value as Sprite2D
		if sprite == null:
			continue
		var material := ShaderMaterial.new()
		material.shader = OUTRAGE_BOOST_FIRE_SHADER
		material.set_shader_parameter("fire_strength", 0.48)
		outrage_boost_materials[sprite] = material

func _ensure_erebus_immune_materials() -> void:
	if not erebus_immune_materials.is_empty():
		return
	for sprite_value in _part_sprites():
		var sprite := sprite_value as Sprite2D
		if sprite == null:
			continue
		var material := ShaderMaterial.new()
		material.shader = EREBUS_IMMUNE_SHIMMER_SHADER
		material.set_shader_parameter("shimmer_speed", 0.34)
		material.set_shader_parameter("shimmer_width", 0.28)
		material.set_shader_parameter("shimmer_softness", 0.16)
		material.set_shader_parameter("shimmer_strength", 0.24)
		material.set_shader_parameter("shimmer_color", Color(1.0, 1.0, 1.0, 1.0))
		erebus_immune_materials[sprite] = material

func _apply_part_base_materials() -> void:
	for sprite_value in _part_sprites():
		var sprite := sprite_value as Sprite2D
		if sprite == null:
			continue
		sprite.material = get_part_base_material(sprite)

func _capture_outrage_boost_base_modulates() -> void:
	outrage_boost_base_modulates.clear()
	for sprite_value in _part_sprites():
		var sprite := sprite_value as Sprite2D
		if sprite == null:
			continue
		outrage_boost_base_modulates[sprite] = sprite.modulate

func _restore_outrage_boost_base_modulates() -> void:
	for sprite_value in _part_sprites():
		var sprite := sprite_value as Sprite2D
		if sprite == null:
			continue
		var base_modulate_value: Variant = outrage_boost_base_modulates.get(sprite, Color.WHITE)
		if base_modulate_value is Color:
			sprite.modulate = base_modulate_value as Color

func _tick_outrage_boost_part_colors() -> void:
	var time_sec := float(Time.get_ticks_msec()) / 1000.0
	for index in range(_part_sprites().size()):
		var sprite := _part_sprites()[index] as Sprite2D
		if sprite == null:
			continue
		var base_modulate_value: Variant = outrage_boost_base_modulates.get(sprite, Color.WHITE)
		var base_modulate: Color = base_modulate_value as Color if base_modulate_value is Color else Color.WHITE
		var phase := time_sec * (9.5 + float(index) * 1.35) + randf_range(-0.35, 0.35)
		var mix_amount := 0.5 + 0.5 * sin(phase)
		var fire_color := Color(1.0, 0.94, 0.24, 1.0).lerp(Color(0.95, 0.16, 0.02, 1.0), mix_amount)
		var boosted: Color = base_modulate.lerp(fire_color, 0.34)
		sprite.modulate = Color(boosted.r, boosted.g, boosted.b, base_modulate.a)

func _tick_erebus_immune_visual() -> void:
	if erebus_immune_visual_remaining_sec <= 0.0:
		return
	var tint := _torso_ui_color()
	for material_value in erebus_immune_materials.values():
		var material := material_value as ShaderMaterial
		if material == null:
			continue
		material.set_shader_parameter("tint_color", Color(tint.r, tint.g, tint.b, 1.0))

func _init_outrage_boost_overlays() -> void:
	outrage_boost_overlay_pairs.clear()
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
		overlay.z_index = source_sprite.z_index + 5
		var overlay_material := ShaderMaterial.new()
		overlay_material.shader = OUTRAGE_BOOST_FIRE_SHADER
		overlay_material.set_shader_parameter("fire_strength", 1.0)
		overlay.material = overlay_material
		overlay.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		overlay.visible = false
		source_sprite.get_parent().add_child(overlay)
		if _visibility_layer_cb.is_valid():
			_visibility_layer_cb.call(overlay, source_sprite.visibility_layer)
		outrage_boost_overlay_pairs.append({
			"source": source_sprite,
			"overlay": overlay,
		})
	_sync_outrage_boost_overlays()

func _sync_outrage_boost_overlays() -> void:
	for pair_value in outrage_boost_overlay_pairs:
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

func _set_outrage_boost_overlay_alpha(alpha: float) -> void:
	for pair_value in outrage_boost_overlay_pairs:
		if not (pair_value is Dictionary):
			continue
		var pair := pair_value as Dictionary
		var overlay := pair.get("overlay", null) as Sprite2D
		if overlay == null:
			continue
		overlay.visible = alpha > 0.001
		overlay.self_modulate = Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))

func _ensure_outrage_boost_screen_fire_overlay() -> void:
	var local_peer_id := _local_peer_id()
	var peer_id := _peer_id()
	if peer_id <= 0 or peer_id != local_peer_id:
		return
	if outrage_boost_screen_fire_root != null and is_instance_valid(outrage_boost_screen_fire_root):
		return
	var tree := _player.get_tree()
	if tree == null:
		return
	var hud_layer := tree.current_scene.get_node_or_null("ClientHud") if tree.current_scene != null else null
	if hud_layer is CanvasLayer:
		outrage_boost_screen_fire_layer = hud_layer as CanvasLayer
	else:
		var overlay_host: Node = tree.current_scene
		if overlay_host == null:
			overlay_host = tree.root
		outrage_boost_screen_fire_layer = CanvasLayer.new()
		outrage_boost_screen_fire_layer.name = "OutrageBoostScreenFire"
		outrage_boost_screen_fire_layer.layer = 210
		outrage_boost_screen_fire_layer.follow_viewport_enabled = true
		overlay_host.add_child(outrage_boost_screen_fire_layer)
	outrage_boost_screen_fire_root = Control.new()
	outrage_boost_screen_fire_root.name = "ScreenFireRoot"
	outrage_boost_screen_fire_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	outrage_boost_screen_fire_root.offset_left = 0.0
	outrage_boost_screen_fire_root.offset_top = 0.0
	outrage_boost_screen_fire_root.offset_right = 0.0
	outrage_boost_screen_fire_root.offset_bottom = 0.0
	outrage_boost_screen_fire_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outrage_boost_screen_fire_root.z_index = 1100
	outrage_boost_screen_fire_root.visible = false
	outrage_boost_screen_fire_layer.add_child(outrage_boost_screen_fire_root)
	_layout_outrage_boost_screen_fire_overlay()
	outrage_boost_screen_fire_nodes.clear()
	var screen_tint := ColorRect.new()
	screen_tint.name = "BoostScreenTint"
	screen_tint.color = Color(1.0, 0.0, 0.0, 0.0)
	screen_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_tint.offset_left = 0.0
	screen_tint.offset_top = 0.0
	screen_tint.offset_right = 0.0
	screen_tint.offset_bottom = 0.0
	screen_tint.z_index = 1101
	outrage_boost_screen_fire_root.add_child(screen_tint)
	outrage_boost_screen_fire_nodes.append(screen_tint)
	_set_outrage_boost_screen_fire_alpha(0.0)

func _layout_outrage_boost_screen_fire_overlay() -> void:
	if outrage_boost_screen_fire_root == null or not is_instance_valid(outrage_boost_screen_fire_root):
		return
	var viewport := _player.get_viewport()
	if viewport == null:
		return
	outrage_boost_screen_fire_root.position = Vector2.ZERO
	outrage_boost_screen_fire_root.size = viewport.get_visible_rect().size

func _set_outrage_boost_screen_fire_alpha(alpha: float) -> void:
	outrage_boost_screen_fire_base_alpha = clampf(alpha, 0.0, 1.0)
	var visible := outrage_boost_screen_fire_base_alpha > 0.001
	if outrage_boost_screen_fire_root != null and is_instance_valid(outrage_boost_screen_fire_root):
		_layout_outrage_boost_screen_fire_overlay()
		outrage_boost_screen_fire_root.visible = visible
	for node_value in outrage_boost_screen_fire_nodes:
		if node_value is ColorRect:
			var glow := node_value as ColorRect
			glow.visible = visible
			glow.color = Color(1.0, 0.0, 0.0, outrage_boost_screen_fire_base_alpha)

func _tick_outrage_boost_screen_fire(_delta: float) -> void:
	if outrage_boost_screen_fire_root == null or not is_instance_valid(outrage_boost_screen_fire_root):
		return
	if outrage_boost_screen_fire_base_alpha <= 0.001:
		return
	_layout_outrage_boost_screen_fire_overlay()
	for node_value in outrage_boost_screen_fire_nodes:
		if node_value is ColorRect:
			var glow := node_value as ColorRect
			glow.color = Color(1.0, 0.0, 0.0, outrage_boost_screen_fire_base_alpha)

func _ensure_ulti_duration_bar() -> void:
	if _visual_root == null:
		return
	ulti_status_label = _skill_label
	ulti_duration_bar_root = _skill_duration_bar
	ulti_duration_bar_fill = _skill_duration_bar
	if _skill_duration_bar != null:
		_skill_duration_bar.region_enabled = true
		_skill_duration_bar.centered = false
		if not _skill_duration_bar_base_captured:
			_skill_duration_bar_base_region = _skill_duration_bar.region_rect
			_skill_duration_bar_base_scale = _skill_duration_bar.scale
			_skill_duration_bar_base_modulate = _skill_duration_bar.modulate
			_skill_duration_bar_base_captured = true
	if ulti_status_label != null:
		ulti_status_label.visible = false
	if _skill_duration_bar_bg != null:
		_skill_duration_bar_bg.visible = false
	if _skill_duration_bar != null:
		_skill_duration_bar.visible = false

func _update_ulti_duration_bar_visual() -> void:
	_ensure_ulti_duration_bar()
	if _skill_duration_bar == null:
		return
	var local_peer_id := _local_peer_id()
	var peer_id := _peer_id()
	var is_local_player := local_peer_id > 0 and peer_id > 0 and peer_id == local_peer_id
	var show := is_local_player and ulti_duration_total_sec > 0.0 and ulti_duration_remaining_sec > 0.0
	_skill_duration_bar.visible = show
	if _skill_duration_bar_bg != null:
		_skill_duration_bar_bg.visible = show
	if ulti_status_label != null:
		ulti_status_label.visible = show and not ulti_status_text.is_empty()
		ulti_status_label.text = ulti_status_text if show else ""
	if not show:
		if _skill_duration_bar_base_captured:
			_skill_duration_bar.scale = _skill_duration_bar_base_scale
			_skill_duration_bar.modulate = _skill_duration_bar_base_modulate
		return
	var ratio := clampf(ulti_duration_remaining_sec / maxf(0.001, ulti_duration_total_sec), 0.0, 1.0)
	_skill_duration_bar.region_rect = _skill_duration_bar_base_region
	_skill_duration_bar.scale = Vector2(_skill_duration_bar_base_scale.x * ratio, _skill_duration_bar_base_scale.y)
	var tint := _torso_ui_color()
	_skill_duration_bar.modulate = Color(clampf(tint.r, 0.0, 1.0), clampf(tint.g, 0.0, 1.0), clampf(tint.b, 0.0, 1.0), 0.96)

func _tick_visual_correction(delta: float) -> void:
	if visual_correction_offset.length_squared() <= 0.0001:
		visual_correction_offset = Vector2.ZERO
		_refresh_visual_root_offset()
		return
	visual_correction_offset = visual_correction_offset.lerp(Vector2.ZERO, min(1.0, delta * VISUAL_CORRECTION_DECAY))
	_refresh_visual_root_offset()

func _peer_id() -> int:
	if _peer_id_cb.is_valid():
		return int(_peer_id_cb.call())
	return 0

func _local_peer_id() -> int:
	if _local_peer_id_cb.is_valid():
		return int(_local_peer_id_cb.call())
	return 0

func _torso_ui_color() -> Color:
	if _torso_ui_color_cb.is_valid():
		var value: Variant = _torso_ui_color_cb.call()
		if value is Color:
			return value as Color
	return Color.WHITE
