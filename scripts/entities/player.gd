extends CharacterBody2D
class_name NetPlayer

const BLOOD_SCREEN_TEXTURES := [
	preload("res://assets/textures/effects/blood1.png"),
	preload("res://assets/textures/effects/blood2.png"),
	preload("res://assets/textures/effects/blood3.png"),
	preload("res://assets/textures/effects/blood4.png"),
	preload("res://assets/textures/effects/blood5.png"),
]

const SPEED := 245.0
const JUMP_VELOCITY := -650.0
const GRAVITY := 1450.0
const FALL_GRAVITY_MULTIPLIER := 1.35
const MAX_FALL_SPEED := 1300.0
const JUMP_RELEASE_DAMP := 0.55
const COYOTE_TIME := 0.16
const JUMP_BUFFER_TIME := 0.1
const SNAP_LERP_SPEED_X := 14.0
const SNAP_LERP_SPEED_Y := 10.0
const AIM_LERP_SPEED := 20.0
const REMOTE_SNAP_DISTANCE := 150.0
const REMOTE_VELOCITY_BLEND := 0.45
const VISUAL_CORRECTION_DECAY := 9.0
const MAX_HEALTH := 100
const HIT_RADIUS := 12.0
const GUN_VISUAL_ANGLE_OFFSET := 0.0
const GUN_RECOIL_SCALE_Y := 1.11
const GUN_RECOIL_SCALE_X := 0.95
const GUN_RECOIL_DISTANCE := 4.8
const GUN_RECOIL_OUT_TIME := 0.028
const GUN_RECOIL_BACK_TIME := 0.12
const GUN_RECOIL_ROTATION := 0.0
const MUZZLE_FALLBACK_DISTANCE := 24.0
const GUN_CENTERING_Y_TWEAK := 0.0
const DEFAULT_GUN_POSITION := Vector2(6.0, 2.0)
const DEFAULT_MUZZLE_POSITION := Vector2(27.0, -1.0)
const DEFAULT_SHOT_FRAME_DURATION_SEC := 0.03
const DEFAULT_RELOAD_FRAME_DURATION_SEC := 0.065
const MIN_SHOT_FRAME_DURATION_SEC := 0.01
const GUN_RELOAD_SCALE_MULTIPLIER := 1.12
const GUN_RELOAD_SCALE_UP_TIME := 0.08
const GUN_RELOAD_SCALE_DOWN_TIME := 0.1
const GUN_RELOAD_SPIN_RADIANS := TAU
const GUN_RELOAD_SPIN_UP_TIME := 0.08
const MAX_WALKABLE_SLOPE_DEGREES := 45.0
const FLOOR_SLOPE_TOLERANCE_DEGREES := 0.5
const FLOOR_SNAP_LENGTH := 14.0
const PLAYER_SAFE_MARGIN := 0.08
const PLAYER_MAX_SLIDES := 8
const HEALTH_BAR_MAX_WIDTH := 73.0
const HEALTH_BAR_HEIGHT := 11.0
const DAMAGE_FLASH_DURATION_SEC := 0.3
const DAMAGE_FLASH_ALPHA := 1.0
const DAMAGE_FLASH_POP_IN_SEC := 0.015
const DAMAGE_FLASH_HOLD_SEC := 0.11
const DAMAGE_SCREEN_BLOOD_MAX_ALPHA := 0.2
const DAMAGE_SCREEN_BLOOD_FADE_IN_SEC := 0.03
const DAMAGE_SCREEN_BLOOD_HOLD_SEC := 0.04
const DAMAGE_SCREEN_BLOOD_FADE_OUT_SEC := 0.08
const DAMAGE_FLASH_JOLT_X := 5.0
const DAMAGE_FLASH_JOLT_Y := -2.5
const DAMAGE_KNOCKBACK_X := 42.0
const DAMAGE_KNOCKBACK_Y := -36.0
const DAMAGE_PART_SCRAMBLE_DURATION_SEC := 0.2
const ANIMATION_AIR_VELOCITY_THRESHOLD := 24.0

@onready var body: Polygon2D = get_node_or_null("Body") as Polygon2D
@onready var feet: Polygon2D = get_node_or_null("Feet") as Polygon2D
@onready var visual_root: Node2D = $VisualRoot
@onready var player_sprite: Node2D = $VisualRoot/Sprite2D
@onready var head_sprite: Sprite2D = $VisualRoot/head
@onready var torso_sprite: Sprite2D = $VisualRoot/torso
@onready var leg1_sprite: Sprite2D = $VisualRoot/leg1
@onready var leg2_sprite: Sprite2D = $VisualRoot/leg2
@onready var gun_pivot: Node2D = $VisualRoot/GunPivot
@onready var gun: Node2D = $VisualRoot/GunPivot/Gun
@onready var muzzle: Marker2D = $VisualRoot/GunPivot/Muzzle
@onready var shot_audio: AudioStreamPlayer2D = $VisualRoot/GunPivot/ShotAudio
@onready var reload_audio: AudioStreamPlayer2D = $VisualRoot/GunPivot/ReloadAudio
@onready var death_audio: AudioStreamPlayer2D = $DeathAudio
@onready var health_label: Label = $VisualRoot/HealthLabel
@onready var health_bar_green: Sprite2D = $VisualRoot/HpBackground/HpGreen
@onready var ammo_label: Label = $VisualRoot/AmmoLabel
@onready var name_label: Label = $VisualRoot/NameLabel
@onready var skill_bars_root: Node2D = $VisualRoot/SkillBars
@onready var skill_q_fill: ColorRect = $VisualRoot/SkillBars/QDial
@onready var skill_e_fill: ColorRect = $VisualRoot/SkillBars/EDial

var peer_id: int = 0
var use_network_smoothing := false
var target_position := Vector2.ZERO
var target_velocity := Vector2.ZERO
var target_aim_angle := 0.0
var health := MAX_HEALTH
var target_health := MAX_HEALTH
var damage_immune_remaining_sec := 0.0
var shield_health := 0
var shield_remaining_sec := 0.0
var ammo_count := 0
var is_reloading := false
var coyote_time_left := 0.0
var jump_buffer_time_left := 0.0
var gun_recoil_tween: Tween
var gun_reload_scale_tween: Tween
var gun_reload_rotation_tween: Tween
var gun_base_scale_abs := Vector2.ONE
var gun_reload_scale_multiplier := 1.0
var gun_recoil_scale_x := GUN_RECOIL_SCALE_X
var gun_recoil_scale_y := GUN_RECOIL_SCALE_Y
var gun_recoil_distance := GUN_RECOIL_DISTANCE
var gun_recoil_out_time := GUN_RECOIL_OUT_TIME
var gun_recoil_back_time := GUN_RECOIL_BACK_TIME
var gun_recoil_rotation := GUN_RECOIL_ROTATION
var configured_gun_position := DEFAULT_GUN_POSITION
var configured_muzzle_position := DEFAULT_MUZZLE_POSITION
var current_weapon_visual_id := ""
var gun_idle_region_rect := Rect2()
var gun_idle_texture: Texture2D
var gun_shot_region_frames: Array = []
var gun_shot_texture_frames: Array = []
var gun_shot_frame_duration_sec := DEFAULT_SHOT_FRAME_DURATION_SEC
var gun_shot_animation_tween: Tween
var gun_shot_animation_nonce := 0
var gun_reload_texture_frames: Array = []
var gun_reload_frame_duration_sec := DEFAULT_RELOAD_FRAME_DURATION_SEC
var gun_reload_animation_tween: Tween
var gun_reload_animation_nonce := 0
var visual_correction_offset := Vector2.ZERO
var modular_visual: PlayerModularVisual
var sfx_suppressed := false
var damage_flash_tween: Tween
var gun_base_modulate := Color.WHITE
var damage_flash_overlay_pairs: Array = []
var target_animation_on_floor := true
var damage_push_direction := Vector2.ZERO
var target_damage_push_direction := Vector2.ZERO
var damage_part_scramble_remaining_sec := 0.0
var damage_part_scramble_offsets: Dictionary = {}
var damage_part_scramble_rotations: Dictionary = {}
var damage_screen_blood_layer: CanvasLayer
var damage_screen_blood_rect: TextureRect
var damage_screen_blood_tween: Tween

func _ready() -> void:
	_configure_floor_movement()
	target_position = global_position
	target_velocity = velocity
	target_aim_angle = 0.0
	target_health = health
	if visual_root != null:
		visual_root.position = Vector2.ZERO
	_init_modular_visual()
	_init_damage_flash_overlays()
	_normalize_gun_sprite_anchor()
	if gun != null:
		gun_base_scale_abs = Vector2(absf(gun.scale.x), absf(gun.scale.y))
	_apply_player_facing_from_angle(target_aim_angle)
	_apply_gun_horizontal_flip_from_angle(target_aim_angle)
	_update_health_label()
	_update_ammo_label()
	set_skill_cooldown_bars(1.0, 1.0, false)

func _configure_floor_movement() -> void:
	# Small tolerance keeps exact 45deg ramps classified as floor.
	floor_max_angle = deg_to_rad(MAX_WALKABLE_SLOPE_DEGREES + FLOOR_SLOPE_TOLERANCE_DEGREES)
	floor_snap_length = FLOOR_SNAP_LENGTH
	floor_constant_speed = true
	floor_block_on_wall = true
	safe_margin = PLAYER_SAFE_MARGIN
	max_slides = PLAYER_MAX_SLIDES
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED

func _normalize_gun_sprite_anchor() -> void:
	if gun == null or not (gun is Sprite2D):
		return
	var gun_sprite := gun as Sprite2D
	if gun_sprite.centered:
		return

	var draw_size := Vector2.ZERO
	if gun_sprite.region_enabled and gun_sprite.region_rect.size.x > 0.0 and gun_sprite.region_rect.size.y > 0.0:
		draw_size = gun_sprite.region_rect.size
	elif gun_sprite.texture != null:
		draw_size = gun_sprite.texture.get_size()
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return

	# Preserve visual placement while switching to center-based anchoring for stable flipping.
	gun_sprite.position += draw_size * 0.5
	gun_sprite.position.y += GUN_CENTERING_Y_TWEAK
	gun_sprite.centered = true

func _init_modular_visual() -> void:
	modular_visual = PlayerModularVisual.new()
	modular_visual.configure(self, visual_root, leg1_sprite, leg2_sprite, torso_sprite, head_sprite)
	if player_sprite != null:
		player_sprite.visible = false
	modular_visual.set_character_visual("outrage")

func _init_damage_flash_overlays() -> void:
	damage_flash_overlay_pairs.clear()
	for source in [head_sprite, torso_sprite, leg1_sprite, leg2_sprite]:
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
		var overlay_material := CanvasItemMaterial.new()
		overlay_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		overlay.material = overlay_material
		overlay.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		overlay.visible = false
		source_sprite.get_parent().add_child(overlay)
		damage_flash_overlay_pairs.append({
			"source": source_sprite,
			"overlay": overlay,
		})
	_sync_damage_flash_overlays()

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

func configure(new_peer_id: int, color: Color) -> void:
	peer_id = new_peer_id
	if body == null:
		body = get_node_or_null("Body") as Polygon2D
	if feet == null:
		feet = get_node_or_null("Feet") as Polygon2D

	if body != null:
		body.color = color
	if feet != null:
		feet.color = color.darkened(0.25)
	if gun != null:
		gun_base_modulate = color.lightened(0.15)
		gun.modulate = gun_base_modulate
	set_health(MAX_HEALTH)
	set_ammo(0, false)

func set_display_name(display_name: String) -> void:
	if name_label == null:
		return
	var trimmed := display_name.strip_edges()
	name_label.text = trimmed
	name_label.visible = not trimmed.is_empty()

func set_skill_cooldown_bars(q_ratio: float, e_ratio: float, bars_visible: bool) -> void:
	if skill_bars_root != null:
		skill_bars_root.visible = bars_visible
	if skill_q_fill != null:
		var q_material := skill_q_fill.material as ShaderMaterial
		if q_material != null:
			q_material.set_shader_parameter("progress", clampf(q_ratio, 0.0, 1.0))
	if skill_e_fill != null:
		var e_material := skill_e_fill.material as ShaderMaterial
		if e_material != null:
			e_material.set_shader_parameter("progress", clampf(e_ratio, 0.0, 1.0))

func set_shot_audio_stream(stream: AudioStream) -> void:
	if shot_audio == null:
		return
	shot_audio.stream = stream

func set_reload_audio_stream(stream: AudioStream) -> void:
	if reload_audio == null:
		return
	reload_audio.stream = stream

func set_weapon_visual(visual_config: Dictionary) -> void:
	if gun == null or not (gun is Sprite2D):
		return
	var visual_weapon_id := str(visual_config.get("weapon_id", "")).strip_edges().to_lower()
	var is_same_weapon_visual := not visual_weapon_id.is_empty() and visual_weapon_id == current_weapon_visual_id
	_reset_gun_scale()
	var gun_sprite := gun as Sprite2D

	var texture_value = visual_config.get("texture", null)
	if texture_value is Texture2D:
		gun_sprite.texture = texture_value
	gun_idle_texture = gun_sprite.texture
	var material_value = visual_config.get("material", null)
	gun_sprite.material = material_value as Material if material_value is Material else null

	var region_enabled := bool(visual_config.get("region_enabled", true))
	gun_sprite.region_enabled = region_enabled
	if region_enabled:
		var region_rect_value = visual_config.get("region_rect", gun_sprite.region_rect)
		if region_rect_value is Rect2:
			gun_sprite.region_rect = region_rect_value
		gun_idle_region_rect = gun_sprite.region_rect
	else:
		gun_idle_region_rect = Rect2()

	var target_gun_position := DEFAULT_GUN_POSITION
	var gun_position_value = visual_config.get("gun_position", target_gun_position)
	if gun_position_value is Vector2:
		target_gun_position = gun_position_value
	configured_gun_position = target_gun_position
	gun_sprite.centered = true

	if muzzle != null:
		var target_muzzle_position := DEFAULT_MUZZLE_POSITION
		var muzzle_position_value = visual_config.get("muzzle_position", target_muzzle_position)
		if muzzle_position_value is Vector2:
			target_muzzle_position = muzzle_position_value
		configured_muzzle_position = target_muzzle_position

	gun_shot_region_frames.clear()
	gun_shot_texture_frames.clear()
	var shot_frames_value = visual_config.get("shot_region_frames", [])
	if shot_frames_value is Array:
		for frame_value in shot_frames_value:
			if frame_value is Rect2:
				var frame_rect: Rect2 = frame_value
				if frame_rect.size.x > 0.0 and frame_rect.size.y > 0.0:
					gun_shot_region_frames.append(frame_rect)
	var shot_texture_frames_value = visual_config.get("shot_texture_frames", [])
	if shot_texture_frames_value is Array:
		for frame_value in shot_texture_frames_value:
			if frame_value is Texture2D:
				gun_shot_texture_frames.append(frame_value)
	if gun_shot_region_frames.is_empty() and gun_idle_region_rect.size.x > 0.0 and gun_idle_region_rect.size.y > 0.0:
		gun_shot_region_frames.append(gun_idle_region_rect)
	if gun_shot_texture_frames.is_empty() and gun_idle_texture != null:
		gun_shot_texture_frames.append(gun_idle_texture)

	var shot_duration_value = visual_config.get("shot_frame_duration_sec", DEFAULT_SHOT_FRAME_DURATION_SEC)
	gun_shot_frame_duration_sec = maxf(MIN_SHOT_FRAME_DURATION_SEC, float(shot_duration_value))
	if not is_same_weapon_visual:
		_reset_gun_shot_animation()

	gun_reload_texture_frames.clear()
	var reload_frames_value = visual_config.get("reload_texture_frames", [])
	if reload_frames_value is Array:
		for frame_value in reload_frames_value:
			if frame_value is Texture2D:
				gun_reload_texture_frames.append(frame_value)
	if gun_reload_texture_frames.is_empty() and gun_idle_texture != null:
		gun_reload_texture_frames.append(gun_idle_texture)

	var reload_duration_value = visual_config.get("reload_frame_duration_sec", DEFAULT_RELOAD_FRAME_DURATION_SEC)
	gun_reload_frame_duration_sec = maxf(MIN_SHOT_FRAME_DURATION_SEC, float(reload_duration_value))
	if not is_same_weapon_visual:
		_reset_gun_reload_animation()

	gun_recoil_scale_x = float(visual_config.get("recoil_scale_x", GUN_RECOIL_SCALE_X))
	gun_recoil_scale_y = float(visual_config.get("recoil_scale_y", GUN_RECOIL_SCALE_Y))
	gun_recoil_distance = float(visual_config.get("recoil_distance", GUN_RECOIL_DISTANCE))
	gun_recoil_out_time = maxf(0.01, float(visual_config.get("recoil_out_time", GUN_RECOIL_OUT_TIME)))
	gun_recoil_back_time = maxf(0.01, float(visual_config.get("recoil_back_time", GUN_RECOIL_BACK_TIME)))
	gun_recoil_rotation = float(visual_config.get("recoil_rotation", GUN_RECOIL_ROTATION))

	gun_base_scale_abs = Vector2(absf(gun_sprite.scale.x), absf(gun_sprite.scale.y))
	if not visual_weapon_id.is_empty():
		current_weapon_visual_id = visual_weapon_id
	_apply_gun_horizontal_flip_from_angle(target_aim_angle)

func get_current_weapon_visual_id() -> String:
	return current_weapon_visual_id

func set_character_visual(character_id: String) -> void:
	print("[DBG PLAYER %d] set_character_visual called with %s, modular_visual=%s" % [peer_id, character_id, "valid" if modular_visual != null else "NULL"])
	if modular_visual != null:
		modular_visual.set_character_visual(character_id)
	else:
		print("[DBG PLAYER %d] modular_visual is null!" % peer_id)
	if player_sprite == null or not (player_sprite is Sprite2D):
		return
	var sprite := player_sprite as Sprite2D
	var normalized := str(character_id).strip_edges().to_lower()
	print("[DBG PLAYER %d] Applying tint for %s" % [peer_id, normalized])
	match normalized:
		"erebus":
			sprite.modulate = Color(0.72, 0.78, 1.0, 1.0)
		"tasko":
			sprite.modulate = Color(1.0, 0.65, 0.92, 1.0)
		"outrage":
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_:
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

func set_skin_index(skin_index: int) -> void:
	if modular_visual == null:
		return
	var idx := maxi(0, skin_index) + 1
	modular_visual.set_modular_part_indices(idx, idx, idx)

func set_health(value: int) -> void:
	var previous_health := health
	health = clampi(value, 0, MAX_HEALTH)
	target_health = health
	if health < previous_health and health > 0:
		_play_damage_visual_feedback()
	if previous_health > 0 and health <= 0:
		_reset_gun_scale()
		_play_death_audio()
	_update_health_label()

func get_health() -> int:
	return health

func get_torso_dominant_color() -> Color:
	if torso_sprite == null:
		return Color(0.98, 0.02, 0.07, 1.0)
	var torso_texture := torso_sprite.texture
	if torso_texture == null:
		return torso_sprite.modulate
	var image := torso_texture.get_image()
	if image == null or image.is_empty():
		return torso_sprite.modulate

	var region := Rect2i(0, 0, image.get_width(), image.get_height())
	if torso_sprite.region_enabled and torso_sprite.region_rect.size.x > 0.0 and torso_sprite.region_rect.size.y > 0.0:
		region = Rect2i(
			int(torso_sprite.region_rect.position.x),
			int(torso_sprite.region_rect.position.y),
			int(torso_sprite.region_rect.size.x),
			int(torso_sprite.region_rect.size.y)
		)

	var buckets: Dictionary = {}
	var best_key := ""
	var best_weight := -1.0
	var tint := torso_sprite.modulate
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
		return torso_sprite.modulate
	var parts := best_key.split(":")
	if parts.size() != 3:
		return torso_sprite.modulate
	return Color(
		float(parts[0].to_int()) / 7.0,
		float(parts[1].to_int()) / 7.0,
		float(parts[2].to_int()) / 7.0,
		1.0
	)

func set_ammo(value: int, reloading: bool = false) -> void:
	ammo_count = maxi(0, value)
	is_reloading = reloading
	_update_ammo_label()

func play_reload_audio() -> void:
	_start_gun_reload_scale_animation()
	_start_gun_reload_rotation_animation()
	_play_gun_reload_animation()
	if sfx_suppressed:
		return
	if reload_audio == null or reload_audio.stream == null:
		return
	reload_audio.pitch_scale = randf_range(0.98, 1.03)
	reload_audio.stop()
	reload_audio.play()

func apply_damage(amount: int, incoming_velocity: Vector2 = Vector2.ZERO) -> int:
	if damage_immune_remaining_sec > 0.0:
		return health
	var remaining: int = maxi(0, amount)
	if shield_remaining_sec > 0.0 and shield_health > 0 and remaining > 0:
		var absorbed: int = mini(shield_health, remaining)
		shield_health = maxi(0, shield_health - absorbed)
		remaining = maxi(0, remaining - absorbed)
		if shield_health <= 0:
			shield_remaining_sec = 0.0
	if remaining <= 0:
		return health
	if incoming_velocity.length_squared() > 0.0001:
		damage_push_direction = incoming_velocity.normalized()
		target_damage_push_direction = damage_push_direction
	_apply_damage_feedback()
	set_health(health - remaining)
	return health

func _apply_damage_feedback() -> void:
	var push_direction := _resolved_damage_push_direction()
	velocity.x += DAMAGE_KNOCKBACK_X * push_direction.x
	velocity.y = minf(velocity.y, DAMAGE_KNOCKBACK_Y)
	target_velocity = velocity
	_play_damage_visual_feedback(push_direction)

func _play_damage_visual_feedback(push_direction := Vector2.ZERO) -> void:
	if push_direction.length_squared() <= 0.0001:
		push_direction = _resolved_damage_push_direction()
	apply_visual_correction(Vector2(DAMAGE_FLASH_JOLT_X * push_direction.x, DAMAGE_FLASH_JOLT_Y))
	_trigger_damage_part_scramble()
	_play_screen_damage_blood()
	_play_damage_flash()

func _resolved_damage_push_direction() -> Vector2:
	if damage_push_direction.length_squared() > 0.0001:
		return damage_push_direction.normalized()
	if target_damage_push_direction.length_squared() > 0.0001:
		return target_damage_push_direction.normalized()
	var fallback_x := -1.0 if cos(target_aim_angle) >= 0.0 else 1.0
	if absf(velocity.x) > 1.0:
		fallback_x = -signf(velocity.x)
	return Vector2(fallback_x, 0.0)

func _play_damage_flash() -> void:
	if damage_flash_tween != null:
		damage_flash_tween.kill()
		_hide_damage_flash_overlays()
	if damage_flash_overlay_pairs.is_empty():
		return
	_sync_damage_flash_overlays()
	damage_flash_tween = create_tween()
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
	for pair_value in damage_flash_overlay_pairs:
		if not (pair_value is Dictionary):
			continue
		var pair := pair_value as Dictionary
		var overlay := pair.get("overlay", null) as Sprite2D
		if overlay == null:
			continue
		var fade_track := damage_flash_tween.parallel().tween_property(overlay, "self_modulate:a", 0.0, 0.01)
		fade_track.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	damage_flash_tween.tween_callback(Callable(self, "_clear_damage_flash_tween"))

func _hide_damage_flash_overlays() -> void:
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

func _trigger_damage_part_scramble() -> void:
	damage_part_scramble_remaining_sec = DAMAGE_PART_SCRAMBLE_DURATION_SEC
	damage_part_scramble_offsets.clear()
	damage_part_scramble_rotations.clear()
	var push_direction := _resolved_damage_push_direction()
	var push_offset := Vector2(push_direction.x * 11.0, push_direction.y * 5.5 - 1.5)
	for sprite in [head_sprite, torso_sprite, leg1_sprite, leg2_sprite]:
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
	for sprite in [head_sprite, torso_sprite, leg1_sprite, leg2_sprite]:
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
	if peer_id <= 0 or peer_id != multiplayer.get_unique_id():
		return
	_ensure_screen_damage_blood_overlay()
	if damage_screen_blood_rect == null:
		return
	if damage_screen_blood_tween != null:
		damage_screen_blood_tween.kill()
	damage_screen_blood_rect.texture = BLOOD_SCREEN_TEXTURES[randi() % BLOOD_SCREEN_TEXTURES.size()]
	damage_screen_blood_rect.visible = true
	damage_screen_blood_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	damage_screen_blood_tween = create_tween()
	var fade_in := damage_screen_blood_tween.tween_property(damage_screen_blood_rect, "modulate:a", DAMAGE_SCREEN_BLOOD_MAX_ALPHA, DAMAGE_SCREEN_BLOOD_FADE_IN_SEC)
	fade_in.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	damage_screen_blood_tween.tween_interval(DAMAGE_SCREEN_BLOOD_HOLD_SEC)
	var fade_out := damage_screen_blood_tween.tween_property(damage_screen_blood_rect, "modulate:a", 0.0, DAMAGE_SCREEN_BLOOD_FADE_OUT_SEC)
	fade_out.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	damage_screen_blood_tween.tween_callback(Callable(self, "_clear_screen_damage_blood"))

func _ensure_screen_damage_blood_overlay() -> void:
	if damage_screen_blood_rect != null and is_instance_valid(damage_screen_blood_rect):
		return
	var hud_layer := get_tree().current_scene.get_node_or_null("ClientHud") if get_tree().current_scene != null else null
	if hud_layer is CanvasLayer:
		damage_screen_blood_layer = hud_layer as CanvasLayer
	else:
		var overlay_host: Node = get_tree().current_scene
		if overlay_host == null:
			overlay_host = get_tree().root
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

func set_damage_immune(duration_sec: float) -> void:
	damage_immune_remaining_sec = maxf(damage_immune_remaining_sec, maxf(0.0, duration_sec))

func is_damage_immune() -> bool:
	return damage_immune_remaining_sec > 0.0

func set_shield(amount: int, duration_sec: float) -> void:
	var normalized_amount := maxi(0, amount)
	var normalized_duration := maxf(0.0, duration_sec)
	if normalized_amount <= 0 or normalized_duration <= 0.0:
		shield_health = 0
		shield_remaining_sec = 0.0
		return
	shield_health = maxi(shield_health, normalized_amount)
	shield_remaining_sec = maxf(shield_remaining_sec, normalized_duration)

func _play_death_audio() -> void:
	if sfx_suppressed:
		return
	if death_audio == null or death_audio.stream == null:
		return
	death_audio.pitch_scale = randf_range(0.96, 1.04)
	death_audio.stop()
	death_audio.play()

func set_sfx_suppressed(value: bool) -> void:
	sfx_suppressed = value

func get_hit_radius() -> float:
	return HIT_RADIUS

func _update_health_label() -> void:
	if health_label != null:
		health_label.visible = false
	if health_bar_green == null:
		return
	var health_ratio := clampf(float(health) / float(MAX_HEALTH), 0.0, 1.0)
	var width := HEALTH_BAR_MAX_WIDTH * health_ratio
	health_bar_green.visible = width > 0.0
	health_bar_green.region_enabled = true
	health_bar_green.region_rect = Rect2(0.0, 0.0, width, HEALTH_BAR_HEIGHT)

func _update_ammo_label() -> void:
	if ammo_label == null:
		return
	ammo_label.text = "R" if is_reloading else str(ammo_count)

func force_respawn(spawn_position: Vector2) -> void:
	global_position = spawn_position
	target_position = spawn_position
	velocity = Vector2.ZERO
	target_velocity = Vector2.ZERO
	damage_push_direction = Vector2.ZERO
	target_damage_push_direction = Vector2.ZERO
	coyote_time_left = 0.0
	jump_buffer_time_left = 0.0
	_reset_gun_scale()
	_reset_gun_shot_animation()
	_reset_gun_reload_animation()

func set_aim_world(target_world: Vector2) -> void:
	set_aim_angle((target_world - global_position).angle())

func set_aim_angle(angle: float) -> void:
	target_aim_angle = angle
	if not use_network_smoothing and gun_pivot != null:
		gun_pivot.rotation = angle + GUN_VISUAL_ANGLE_OFFSET
	_apply_player_facing_from_angle(angle)
	_apply_gun_horizontal_flip_from_angle(angle)

func _apply_player_facing_from_angle(angle: float) -> void:
	if modular_visual != null:
		modular_visual.apply_player_facing_from_angle(angle)
	if player_sprite == null:
		return
	var looking_left := cos(angle) < 0.0
	var current_scale := player_sprite.scale
	current_scale.x = -absf(current_scale.x) if looking_left else absf(current_scale.x)
	player_sprite.scale = current_scale

func _apply_gun_horizontal_flip_from_angle(angle: float) -> void:
	if gun == null:
		return
	var looking_left := cos(angle) < 0.0
	var base_scale := _current_gun_base_scale_abs()
	gun.scale = Vector2(
		absf(base_scale.x),
		-absf(base_scale.y) if looking_left else absf(base_scale.y)
	)
	_apply_weapon_mount_offsets_from_angle(angle)

func _apply_weapon_mount_offsets_from_angle(angle: float) -> void:
	var looking_left := cos(angle) < 0.0
	var gun_position := configured_gun_position
	var muzzle_position := configured_muzzle_position
	if looking_left:
		gun_position.y = -gun_position.y
		muzzle_position.y = -muzzle_position.y
	if gun != null:
		gun.position = gun_position
	if muzzle != null:
		muzzle.position = muzzle_position

func play_shot_recoil() -> void:
	if gun == null:
		return
	if gun_reload_scale_tween != null:
		gun_reload_scale_tween.kill()
		gun_reload_scale_tween = null
		gun_reload_scale_multiplier = 1.0
	if gun_reload_rotation_tween != null:
		gun_reload_rotation_tween.kill()
		gun_reload_rotation_tween = null
		gun.rotation = 0.0
	_apply_gun_horizontal_flip_from_angle(target_aim_angle)
	if modular_visual != null:
		modular_visual.trigger_shot_jolt(target_aim_angle)
	if not sfx_suppressed and shot_audio != null and shot_audio.stream != null:
		shot_audio.pitch_scale = randf_range(0.95, 1.08)
		shot_audio.stop()
		shot_audio.play()
	_play_gun_shot_animation()
	if gun_recoil_tween != null:
		gun_recoil_tween.kill()

	var sign_x := 1.0
	var sign_y := -1.0 if gun.scale.y < 0.0 else 1.0
	var base_scale := _current_gun_base_scale_abs()
	var recoil_scale := Vector2(base_scale.x * gun_recoil_scale_x, base_scale.y * gun_recoil_scale_y)
	var base_position := gun.position
	var recoil_offset := Vector2.LEFT.rotated(target_aim_angle) * gun_recoil_distance
	var recoil_position := base_position + recoil_offset
	var recoil_rotation := gun_recoil_rotation if gun.scale.y >= 0.0 else -gun_recoil_rotation

	gun_recoil_tween = create_tween()
	gun_recoil_tween.parallel().tween_property(gun, "position", recoil_position, gun_recoil_out_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	gun_recoil_tween.tween_property(gun, "scale", Vector2(sign_x * recoil_scale.x, sign_y * recoil_scale.y), gun_recoil_out_time)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	gun_recoil_tween.parallel().tween_property(gun, "rotation", recoil_rotation, gun_recoil_out_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	gun_recoil_tween.parallel().tween_property(gun, "position", base_position, gun_recoil_back_time)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	gun_recoil_tween.tween_property(gun, "scale", Vector2(sign_x * base_scale.x, sign_y * base_scale.y), gun_recoil_back_time)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	gun_recoil_tween.parallel().tween_property(gun, "rotation", 0.0, gun_recoil_back_time)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _reset_gun_scale() -> void:
	if gun_recoil_tween != null:
		gun_recoil_tween.kill()
		gun_recoil_tween = null
	if gun_reload_scale_tween != null:
		gun_reload_scale_tween.kill()
		gun_reload_scale_tween = null
	if gun_reload_rotation_tween != null:
		gun_reload_rotation_tween.kill()
		gun_reload_rotation_tween = null
	gun_reload_scale_multiplier = 1.0
	if gun != null:
		gun.rotation = 0.0
	_apply_gun_horizontal_flip_from_angle(target_aim_angle)

func _play_gun_shot_animation() -> void:
	if gun == null or not (gun is Sprite2D):
		return
	var gun_sprite := gun as Sprite2D
	var use_region_frames := gun_sprite.region_enabled and not gun_shot_region_frames.is_empty()
	var use_texture_frames := not gun_sprite.region_enabled and not gun_shot_texture_frames.is_empty()
	if not use_region_frames and not use_texture_frames:
		return

	gun_shot_animation_nonce += 1
	var nonce := gun_shot_animation_nonce
	if gun_shot_animation_tween != null:
		gun_shot_animation_tween.kill()

	gun_shot_animation_tween = create_tween()
	if use_region_frames:
		for frame_value in gun_shot_region_frames:
			if not (frame_value is Rect2):
				continue
			var frame_rect: Rect2 = frame_value
			gun_shot_animation_tween.tween_callback(Callable(self, "_apply_gun_shot_frame").bind(nonce, frame_rect))
			gun_shot_animation_tween.tween_interval(gun_shot_frame_duration_sec)
	else:
		for frame_value in gun_shot_texture_frames:
			if not (frame_value is Texture2D):
				continue
			var frame_texture := frame_value as Texture2D
			gun_shot_animation_tween.tween_callback(Callable(self, "_apply_gun_shot_texture_frame").bind(nonce, frame_texture))
			gun_shot_animation_tween.tween_interval(gun_shot_frame_duration_sec)
	gun_shot_animation_tween.tween_callback(Callable(self, "_finish_gun_shot_animation").bind(nonce))

func _reset_gun_shot_animation() -> void:
	gun_shot_animation_nonce += 1
	if gun_shot_animation_tween != null:
		gun_shot_animation_tween.kill()
		gun_shot_animation_tween = null
	_apply_gun_idle_frame()

func _apply_gun_idle_frame() -> void:
	if gun == null or not (gun is Sprite2D):
		return
	var gun_sprite := gun as Sprite2D
	if gun_sprite.region_enabled:
		if gun_idle_region_rect.size.x <= 0.0 or gun_idle_region_rect.size.y <= 0.0:
			return
		gun_sprite.region_rect = gun_idle_region_rect
		return
	if gun_idle_texture == null:
		return
	gun_sprite.texture = gun_idle_texture

func _apply_gun_shot_frame(nonce: int, frame_rect: Rect2) -> void:
	if nonce != gun_shot_animation_nonce:
		return
	if gun == null or not (gun is Sprite2D):
		return
	var gun_sprite := gun as Sprite2D
	if not gun_sprite.region_enabled:
		return
	gun_sprite.region_rect = frame_rect

func _apply_gun_shot_texture_frame(nonce: int, frame_texture: Texture2D) -> void:
	if nonce != gun_shot_animation_nonce:
		return
	if gun == null or not (gun is Sprite2D):
		return
	var gun_sprite := gun as Sprite2D
	if gun_sprite.region_enabled:
		return
	gun_sprite.texture = frame_texture

func _finish_gun_shot_animation(nonce: int) -> void:
	if nonce != gun_shot_animation_nonce:
		return
	_apply_gun_idle_frame()
	gun_shot_animation_tween = null

func _play_gun_reload_animation() -> void:
	if gun == null or not (gun is Sprite2D):
		return
	if gun_reload_texture_frames.is_empty():
		return

	gun_reload_animation_nonce += 1
	var nonce := gun_reload_animation_nonce
	if gun_reload_animation_tween != null:
		gun_reload_animation_tween.kill()

	gun_reload_animation_tween = create_tween()
	for frame_value in gun_reload_texture_frames:
		if not (frame_value is Texture2D):
			continue
		var frame_texture: Texture2D = frame_value
		gun_reload_animation_tween.tween_callback(Callable(self, "_apply_gun_reload_frame").bind(nonce, frame_texture))
		gun_reload_animation_tween.tween_interval(gun_reload_frame_duration_sec)
	gun_reload_animation_tween.tween_callback(Callable(self, "_finish_gun_reload_animation").bind(nonce))

func _reset_gun_reload_animation() -> void:
	gun_reload_animation_nonce += 1
	if gun_reload_animation_tween != null:
		gun_reload_animation_tween.kill()
		gun_reload_animation_tween = null
	_reset_gun_reload_scale_animation()
	_reset_gun_reload_rotation_animation(true)
	_apply_gun_idle_frame()

func _apply_gun_reload_frame(nonce: int, frame_texture: Texture2D) -> void:
	if nonce != gun_reload_animation_nonce:
		return
	if gun == null or not (gun is Sprite2D):
		return
	var gun_sprite := gun as Sprite2D
	gun_sprite.region_enabled = false
	gun_sprite.texture = frame_texture

func _finish_gun_reload_animation(nonce: int) -> void:
	if nonce != gun_reload_animation_nonce:
		return
	_reset_gun_reload_scale_animation()
	_reset_gun_reload_rotation_animation(true)
	_apply_gun_idle_frame()
	gun_reload_animation_tween = null

func _current_gun_base_scale_abs() -> Vector2:
	return gun_base_scale_abs * gun_reload_scale_multiplier

func _start_gun_reload_scale_animation() -> void:
	if gun == null:
		return
	if gun_reload_scale_tween != null:
		gun_reload_scale_tween.kill()
	var sign_y := -1.0 if gun.scale.y < 0.0 else 1.0
	var target_scale := Vector2(gun_base_scale_abs.x * GUN_RELOAD_SCALE_MULTIPLIER, gun_base_scale_abs.y * GUN_RELOAD_SCALE_MULTIPLIER)
	gun_reload_scale_tween = create_tween()
	gun_reload_scale_tween.tween_property(gun, "scale", Vector2(target_scale.x, sign_y * target_scale.y), GUN_RELOAD_SCALE_UP_TIME)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	gun_reload_scale_multiplier = GUN_RELOAD_SCALE_MULTIPLIER

func _reset_gun_reload_scale_animation() -> void:
	if gun == null:
		gun_reload_scale_multiplier = 1.0
		return
	if is_equal_approx(gun_reload_scale_multiplier, 1.0) and gun_reload_scale_tween == null:
		return
	if gun_reload_scale_tween != null:
		gun_reload_scale_tween.kill()
	var sign_y := -1.0 if gun.scale.y < 0.0 else 1.0
	gun_reload_scale_tween = create_tween()
	gun_reload_scale_tween.tween_property(gun, "scale", Vector2(gun_base_scale_abs.x, sign_y * gun_base_scale_abs.y), GUN_RELOAD_SCALE_DOWN_TIME)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	gun_reload_scale_tween.finished.connect(Callable(self, "_clear_gun_reload_scale_tween"), CONNECT_ONE_SHOT)
	gun_reload_scale_multiplier = 1.0

func _clear_gun_reload_scale_tween() -> void:
	gun_reload_scale_tween = null

func _start_gun_reload_rotation_animation() -> void:
	if gun == null:
		return
	if gun_reload_rotation_tween != null:
		gun_reload_rotation_tween.kill()
	gun.rotation = 0.0
	var total_duration := maxf(
		GUN_RELOAD_SPIN_UP_TIME,
		float(gun_reload_texture_frames.size()) * gun_reload_frame_duration_sec
	)
	gun_reload_rotation_tween = create_tween()
	gun_reload_rotation_tween.tween_property(gun, "rotation", GUN_RELOAD_SPIN_RADIANS, total_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _reset_gun_reload_rotation_animation(immediate: bool = false) -> void:
	if gun == null:
		return
	if gun_reload_rotation_tween != null:
		gun_reload_rotation_tween.kill()
	gun_reload_rotation_tween = null
	if immediate or absf(gun.rotation) >= PI:
		gun.rotation = 0.0
		return
	gun.rotation = 0.0

func _clear_gun_reload_rotation_tween() -> void:
	if gun != null:
		gun.rotation = 0.0
	gun_reload_rotation_tween = null

func get_aim_angle() -> float:
	return target_aim_angle

func get_muzzle_world_position() -> Vector2:
	var aim_angle := get_aim_angle()
	var fallback_distance := MUZZLE_FALLBACK_DISTANCE
	if gun != null and gun is Sprite2D:
		var gun_sprite := gun as Sprite2D
		if gun_sprite.region_enabled and gun_sprite.region_rect.size.x > 0.0:
			fallback_distance = maxf(fallback_distance, gun_sprite.region_rect.size.x * 0.5 + 2.0)
		elif gun_sprite.texture != null:
			fallback_distance = maxf(fallback_distance, gun_sprite.texture.get_size().x * 0.5 + 2.0)

	var fallback_position := global_position + Vector2.RIGHT.rotated(aim_angle) * fallback_distance
	if muzzle == null:
		return fallback_position

	# Temporarily disable extra corrective offsets and always trust marker position.
	return muzzle.global_position

func simulate_authoritative(delta: float, axis: float, jump_pressed: bool, jump_held: bool) -> void:
	axis = clamp(axis, -1.0, 1.0)
	var on_floor := is_on_floor()
	var jumped_this_frame := false
	if on_floor:
		coyote_time_left = COYOTE_TIME
	else:
		coyote_time_left = maxf(coyote_time_left - delta, 0.0)

	if jump_pressed:
		jump_buffer_time_left = JUMP_BUFFER_TIME
	else:
		jump_buffer_time_left = maxf(jump_buffer_time_left - delta, 0.0)

	var target_speed := axis * SPEED
	if absf(axis) > 0.001:
		velocity.x = target_speed
	else:
		velocity.x = 0.0

	if not on_floor:
		var gravity_scale := FALL_GRAVITY_MULTIPLIER if velocity.y > 0.0 else 1.0
		velocity.y = min(velocity.y + GRAVITY * gravity_scale * delta, MAX_FALL_SPEED)
	elif velocity.y > 0.0:
		velocity.y = 0.0

	if jump_buffer_time_left > 0.0 and (on_floor or coyote_time_left > 0.0):
		velocity.y = JUMP_VELOCITY
		coyote_time_left = 0.0
		jump_buffer_time_left = 0.0
		jumped_this_frame = true

	if not jumped_this_frame and not jump_held and velocity.y < 0.0:
		velocity.y *= JUMP_RELEASE_DAMP

	move_and_slide()
	if is_on_floor():
		coyote_time_left = COYOTE_TIME
	target_position = global_position
	target_velocity = velocity
	target_aim_angle = get_aim_angle()

func apply_snapshot(new_position: Vector2, new_velocity: Vector2, new_aim_angle: float, new_health: int, part_animation_state: Dictionary = {}) -> void:
	target_position = new_position
	target_velocity = new_velocity
	target_aim_angle = new_aim_angle
	target_health = clampi(new_health, 0, MAX_HEALTH)
	set_part_animation_state(part_animation_state)

	if not use_network_smoothing:
		global_position = target_position
		velocity = target_velocity
		if gun_pivot != null:
			gun_pivot.rotation = target_aim_angle + GUN_VISUAL_ANGLE_OFFSET
		_apply_player_facing_from_angle(target_aim_angle)
		_apply_gun_horizontal_flip_from_angle(target_aim_angle)
		set_health(target_health)

func set_part_animation_state(state: Dictionary) -> void:
	target_animation_on_floor = bool(state.get("on_floor", target_animation_on_floor))
	var push_direction_value: Variant = state.get("damage_push_direction", Vector2.ZERO)
	if push_direction_value is Vector2:
		target_damage_push_direction = push_direction_value as Vector2

func get_part_animation_state() -> Dictionary:
	return {
		"on_floor": is_on_floor(),
		"damage_push_direction": damage_push_direction
	}

func _physics_process(delta: float) -> void:
	if damage_immune_remaining_sec > 0.0:
		damage_immune_remaining_sec = maxf(0.0, damage_immune_remaining_sec - delta)
	if shield_remaining_sec > 0.0:
		shield_remaining_sec = maxf(0.0, shield_remaining_sec - delta)
		if shield_remaining_sec <= 0.0:
			shield_health = 0
	if visual_root != null:
		_tick_visual_correction(delta)
	if modular_visual != null:
		var animation_on_floor := is_on_floor()
		if use_network_smoothing:
			animation_on_floor = target_animation_on_floor and absf(target_velocity.y) < ANIMATION_AIR_VELOCITY_THRESHOLD
		modular_visual.update_walk_animation(delta, velocity if not use_network_smoothing else target_velocity, animation_on_floor)
	_apply_damage_part_scramble(delta)
	if not damage_flash_overlay_pairs.is_empty():
		_sync_damage_flash_overlays()
	if not use_network_smoothing:
		return

	var position_error := target_position - global_position
	if position_error.length() > REMOTE_SNAP_DISTANCE:
		global_position = target_position
		velocity = target_velocity
	else:
		global_position.x = lerpf(global_position.x, target_position.x, min(1.0, delta * SNAP_LERP_SPEED_X))
		global_position.y = lerpf(global_position.y, target_position.y, min(1.0, delta * SNAP_LERP_SPEED_Y))
		velocity = velocity.lerp(target_velocity, REMOTE_VELOCITY_BLEND)
	if gun_pivot != null:
		gun_pivot.rotation = lerp_angle(gun_pivot.rotation, target_aim_angle + GUN_VISUAL_ANGLE_OFFSET, min(1.0, delta * AIM_LERP_SPEED))
	_apply_player_facing_from_angle(target_aim_angle)
	_apply_gun_horizontal_flip_from_angle(target_aim_angle)
	if health != target_health:
		set_health(target_health)

func apply_visual_correction(offset: Vector2) -> void:
	if visual_root == null:
		return
	visual_correction_offset += offset
	visual_root.position = visual_correction_offset

func _tick_visual_correction(delta: float) -> void:
	if visual_correction_offset.length_squared() <= 0.0001:
		visual_correction_offset = Vector2.ZERO
		visual_root.position = Vector2.ZERO
		return
	visual_correction_offset = visual_correction_offset.lerp(Vector2.ZERO, min(1.0, delta * VISUAL_CORRECTION_DECAY))
	visual_root.position = visual_correction_offset
