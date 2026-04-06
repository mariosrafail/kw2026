extends CharacterBody2D
class_name NetPlayer

const MINIMAP_HIDDEN_VISIBILITY_LAYER := 1 << 1

const BLOOD_SCREEN_TEXTURES := [
	preload("res://assets/textures/effects/blood1.png"),
	preload("res://assets/textures/effects/blood2.png"),
	preload("res://assets/textures/effects/blood3.png"),
	preload("res://assets/textures/effects/blood4.png"),
	preload("res://assets/textures/effects/blood5.png"),
]
const DAMAGE_FLASH_WHITE_SHADER := preload("res://assets/shaders/damage_flash_white.gdshader")
const DAMAGE_FLASH_MIX_SHADER := preload("res://assets/shaders/damage_flash_mix.gdshader")
const OUTRAGE_BOOST_FIRE_SHADER := preload("res://assets/shaders/outrage_boost_fire.gdshader")
const EREBUS_IMMUNE_SHIMMER_SHADER := preload("res://assets/shaders/erebus_immune_shimmer.gdshader")
const DAMAGE_NUMBER_FONT := preload("res://assets/fonts/kwfont.ttf")
const PLAYER_DEATH_CHUNKS_SCRIPT := preload("res://scripts/entities/player_components/player_death_chunks.gd")

const SNAP_LERP_SPEED_X := 14.0
const SNAP_LERP_SPEED_Y := 10.0
const AIM_LERP_SPEED := 20.0
const REMOTE_SNAP_DISTANCE := 150.0
const REMOTE_VELOCITY_BLEND := 0.45
const VISUAL_CORRECTION_DECAY := 9.0
const MAX_HEALTH := 100
const DEFAULT_MAX_HEALTH := MAX_HEALTH
const HIT_RADIUS := 12.0
const HIT_HEIGHT := 34.0
const DAMAGE_FLASH_DURATION_SEC := 0.38
const DAMAGE_FLASH_ALPHA := 1.0
const DAMAGE_FLASH_POP_IN_SEC := 0.015
const DAMAGE_FLASH_HOLD_SEC := 0.16
const DAMAGE_SCREEN_BLOOD_MAX_ALPHA := 0.2
const DAMAGE_SCREEN_BLOOD_FADE_IN_SEC := 0.03
const DAMAGE_SCREEN_BLOOD_HOLD_SEC := 0.04
const DAMAGE_SCREEN_BLOOD_FADE_OUT_SEC := 0.08
const DAMAGE_FLASH_JOLT_X := 5.0
const DAMAGE_FLASH_JOLT_Y := -2.5
const DAMAGE_KNOCKBACK_X := 42.0
const DAMAGE_KNOCKBACK_Y := -36.0
const DAMAGE_SLOW_DURATION_SEC := DAMAGE_FLASH_DURATION_SEC
const DAMAGE_SLOW_MULTIPLIER := 0.58
const DAMAGE_PART_SCRAMBLE_DURATION_SEC := 0.2
const DAMAGE_NUMBER_POP_SEC := 0.12
const DAMAGE_NUMBER_HOLD_SEC := 0.06
const DAMAGE_NUMBER_FADE_SEC := 0.24
const DAMAGE_NUMBER_START_SCALE := 0.46
const DAMAGE_NUMBER_PEAK_SCALE := 1.28
const DAMAGE_NUMBER_END_SCALE := 0.72
const DAMAGE_NUMBER_RISE_DISTANCE := 38.0
const ANIMATION_AIR_VELOCITY_THRESHOLD := 24.0
const ANIMATION_FLOOR_GRACE_SEC := 0.09
const JUMP_TAKEOFF_FORCE_AIR_SEC := 0.11
const STAIR_DESCEND_MIN_FALL_SPEED := 28.0
const STAIR_DESCEND_MAX_FALL_SPEED := 210.0
const STAIR_DESCEND_MIN_HORIZONTAL_SPEED := 10.0
const RESPAWN_DAMAGE_IMMUNITY_SEC := 0.3
const EREBUS_IMMUNE_SIZE_SCALE := 1.2
const EREBUS_IMMUNE_HITBOX_SCALE := 1.28
const EREBUS_IMMUNE_HEAD_SCALE := 1.18
const EREBUS_IMMUNE_TORSO_SCALE := 1.16
const EREBUS_IMMUNE_HEAD_Y_OFFSET := -3.5
const EREBUS_IMMUNE_TORSO_Y_OFFSET := -2.0
const EREBUS_IMMUNE_SPEED_MULTIPLIER := 0.72
const EREBUS_IMMUNE_JUMP_MULTIPLIER := 0.74
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
@onready var footstep_audio: AudioStreamPlayer2D = $FootstepAudio
@onready var death_audio: AudioStreamPlayer2D = $DeathAudio
@onready var health_label: Label = $VisualRoot/HealthLabel
@onready var health_bar_green: Sprite2D = $VisualRoot/HpBackground/HpGreen
@onready var health_bar_damage_lag: Sprite2D = get_node_or_null("VisualRoot/HpBackground/HpDamageLag") as Sprite2D
@onready var ammo_label: Label = $VisualRoot/AmmoLabel
@onready var name_label: Label = $VisualRoot/NameLabel
@onready var skill_label: Label = get_node_or_null("VisualRoot/SkillLabel") as Label
@onready var skill_duration_bar_bg: Sprite2D = get_node_or_null("VisualRoot/SkillBarBackground") as Sprite2D
@onready var skill_duration_bar: Sprite2D = get_node_or_null("VisualRoot/SkillBar") as Sprite2D
@onready var skill_bars_root: Node2D = get_node_or_null("VisualRoot/SkillBars") as Node2D
@onready var skill_q_fill: ColorRect = get_node_or_null("VisualRoot/SkillBars/QDial") as ColorRect
@onready var skill_e_fill: ColorRect = get_node_or_null("VisualRoot/SkillBars/EDial") as ColorRect
@onready var body_collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

var movement_component: PlayerMovement
var vitals_hud_component: PlayerVitalsHud
var weapon_visual_component: PlayerWeaponVisual
var surface_audio_component: PlayerSurfaceAudio
var death_chunks_component: PlayerDeathChunks
var peer_id: int = 0
var use_network_smoothing := false
var target_position := Vector2.ZERO
var target_velocity := Vector2.ZERO
var target_aim_angle := 0.0
var target_health := MAX_HEALTH
var damage_immune_remaining_sec := 0.0
var shield_health := 0
var shield_remaining_sec := 0.0
var visual_correction_offset := Vector2.ZERO
var modular_visual: PlayerModularVisual
var sfx_suppressed := false
var forced_hidden_reasons: Dictionary = {}
var forced_sfx_suppressed_reasons: Dictionary = {}
var damage_flash_tween: Tween
var gun_base_modulate := Color.WHITE
var damage_flash_overlay_pairs: Array = []
var damage_flash_part_materials: Array = []
var damage_flash_source_materials: Dictionary = {}
var outrage_boost_overlay_pairs: Array = []
var target_animation_on_floor := true
var target_respawn_hidden := false
var damage_push_direction := Vector2.ZERO
var target_damage_push_direction := Vector2.ZERO
var damage_slow_remaining_sec := 0.0
var external_movement_speed_multiplier := 1.0
var external_status_movement_speed_multiplier := 1.0
var external_fire_rate_multiplier := 1.0
var damage_part_scramble_remaining_sec := 0.0
var damage_part_scramble_offsets: Dictionary = {}
var damage_part_scramble_rotations: Dictionary = {}
var damage_screen_blood_layer: CanvasLayer
var damage_screen_blood_rect: TextureRect
var damage_screen_blood_tween: Tween
var outrage_boost_remaining_sec := 0.0
var outrage_boost_materials: Dictionary = {}
var outrage_boost_base_modulates: Dictionary = {}
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
var target_dummy_mode := false
var _screen_fire_edge_h_tex_cache: Texture2D
var _screen_fire_edge_v_tex_cache: Texture2D
var damage_numbers_root: Node2D
var ulti_duration_bar_root: Node2D
var ulti_duration_bar_bg: ColorRect
var ulti_duration_bar_fill: Sprite2D
var ulti_duration_total_sec := 0.0
var ulti_duration_remaining_sec := 0.0
var ulti_status_label: Label
var ulti_status_text := ""
var _skill_duration_bar_base_region: Rect2 = Rect2(0, 0, 61, 2)
var _skill_duration_bar_base_scale: Vector2 = Vector2.ONE
var _skill_duration_bar_base_modulate: Color = Color.WHITE
var _skill_duration_bar_base_captured := false
var _last_input_jump_held := false
var _animation_floor_grace_remaining_sec := 0.0
var _jump_takeoff_force_air_remaining_sec := 0.0
var _respawn_collision_override_active := false
var _respawn_saved_collision_layer := 0
var _respawn_saved_collision_mask := 0

func _ready() -> void:
	_init_movement_component()
	_init_death_chunks_component()
	_init_vitals_hud_component()
	_init_weapon_visual_component()
	_init_surface_audio_component()
	_init_damage_numbers_root()
	target_position = global_position
	target_velocity = velocity
	target_aim_angle = 0.0
	target_health = get_health()
	if visual_root != null:
		visual_root.position = Vector2.ZERO
	_init_modular_visual()
	_capture_erebus_immune_base_size()
	_capture_juice_shrink_base_size()
	_refresh_visual_root_offset()
	_init_damage_flash_overlays()
	_init_outrage_boost_overlays()
	_apply_player_facing_from_angle(target_aim_angle)
	_apply_gun_horizontal_flip_from_angle(target_aim_angle)
	set_skill_cooldown_bars(1.0, 1.0, false)
	_ensure_ulti_duration_bar()
	clear_ulti_duration_bar()
	set_minimap_hidden(true)

func set_minimap_hidden(hidden: bool) -> void:
	var layer := MINIMAP_HIDDEN_VISIBILITY_LAYER if hidden else 1
	_set_canvas_item_visibility_layer_recursive(self, layer)

func _init_movement_component() -> void:
	movement_component = PlayerMovement.new()
	movement_component.configure(self)
	movement_component.configure_floor_movement()

func _init_vitals_hud_component() -> void:
	vitals_hud_component = PlayerVitalsHud.new()
	vitals_hud_component.configure(
		health_label,
		health_bar_green,
		health_bar_damage_lag,
		ammo_label,
		death_audio,
		Callable(self, "_play_damage_visual_feedback"),
		Callable(self, "_handle_before_death"),
		Callable(self, "_is_sfx_suppressed")
	)

func _init_death_chunks_component() -> void:
	death_chunks_component = PLAYER_DEATH_CHUNKS_SCRIPT.new()
	death_chunks_component.configure(self, _part_sprites())

func _handle_before_death() -> void:
	pass

func spawn_death_chunks_at(world_position: Vector2, incoming_velocity: Vector2 = Vector2.ZERO) -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		return
	if death_chunks_component == null:
		return
	var impulse := incoming_velocity
	if impulse.length_squared() <= 0.0001:
		impulse = _resolved_damage_push_direction() * 130.0
	death_chunks_component.clear_active_chunks()
	death_chunks_component.spawn_chunks_at(world_position, impulse, visibility_layer)

func _init_weapon_visual_component() -> void:
	weapon_visual_component = PlayerWeaponVisual.new()
	weapon_visual_component.configure(
		self,
		gun_pivot,
		gun,
		muzzle,
		shot_audio,
		reload_audio,
		Callable(self, "_is_sfx_suppressed"),
		Callable(self, "_trigger_weapon_shot_jolt")
	)

func _init_surface_audio_component() -> void:
	surface_audio_component = PlayerSurfaceAudio.new()
	surface_audio_component.configure(
		self,
		footstep_audio,
		Callable(self, "_is_sfx_suppressed")
	)

func _init_damage_numbers_root() -> void:
	if visual_root == null:
		return
	damage_numbers_root = visual_root.get_node_or_null("DamageNumbers") as Node2D
	if damage_numbers_root != null:
		return
	damage_numbers_root = Node2D.new()
	damage_numbers_root.name = "DamageNumbers"
	damage_numbers_root.z_index = 4
	damage_numbers_root.position = Vector2(0.0, -16.0)
	visual_root.add_child(damage_numbers_root)
	_set_canvas_item_visibility_layer_recursive(damage_numbers_root, visibility_layer)

func _init_modular_visual() -> void:
	modular_visual = PlayerModularVisual.new()
	modular_visual.configure(self, visual_root, leg1_sprite, leg2_sprite, torso_sprite, head_sprite)
	if player_sprite != null:
		player_sprite.visible = false
	modular_visual.set_character_visual("outrage")

func _part_sprites() -> Array:
	return [head_sprite, torso_sprite, leg1_sprite, leg2_sprite]

func _capture_erebus_immune_base_size() -> void:
	if _erebus_immune_size_captured:
		return
	if body_collision_shape != null:
		_erebus_immune_base_collision_scale = body_collision_shape.scale
		_erebus_immune_base_collision_position = body_collision_shape.position
	if head_sprite != null:
		_erebus_immune_base_head_scale = head_sprite.scale
		_erebus_immune_base_head_position = head_sprite.position
	if torso_sprite != null:
		_erebus_immune_base_torso_scale = torso_sprite.scale
		_erebus_immune_base_torso_position = torso_sprite.position
	_erebus_immune_size_captured = true

func _apply_erebus_immune_size() -> void:
	_capture_erebus_immune_base_size()
	if body_collision_shape != null:
		body_collision_shape.scale = Vector2(
			_erebus_immune_base_collision_scale.x * EREBUS_IMMUNE_HITBOX_SCALE,
			_erebus_immune_base_collision_scale.y * EREBUS_IMMUNE_HITBOX_SCALE
		)
		var hitbox_growth := HIT_HEIGHT * (EREBUS_IMMUNE_HITBOX_SCALE - 1.0)
		body_collision_shape.position = _erebus_immune_base_collision_position + Vector2(0.0, -hitbox_growth * 0.5)
	if head_sprite != null:
		head_sprite.scale = Vector2(
			_erebus_immune_base_head_scale.x * EREBUS_IMMUNE_HEAD_SCALE,
			_erebus_immune_base_head_scale.y * EREBUS_IMMUNE_HEAD_SCALE
		)
		head_sprite.position = _erebus_immune_base_head_position + Vector2(0.0, EREBUS_IMMUNE_HEAD_Y_OFFSET)
	if torso_sprite != null:
		torso_sprite.scale = Vector2(
			_erebus_immune_base_torso_scale.x * EREBUS_IMMUNE_TORSO_SCALE,
			_erebus_immune_base_torso_scale.y * EREBUS_IMMUNE_TORSO_SCALE
		)
		torso_sprite.position = _erebus_immune_base_torso_position + Vector2(0.0, EREBUS_IMMUNE_TORSO_Y_OFFSET)

func _restore_erebus_immune_size() -> void:
	if not _erebus_immune_size_captured:
		return
	if body_collision_shape != null:
		body_collision_shape.scale = _erebus_immune_base_collision_scale
		body_collision_shape.position = _erebus_immune_base_collision_position
	if head_sprite != null:
		head_sprite.scale = _erebus_immune_base_head_scale
		head_sprite.position = _erebus_immune_base_head_position
	if torso_sprite != null:
		torso_sprite.scale = _erebus_immune_base_torso_scale
		torso_sprite.position = _erebus_immune_base_torso_position

func _capture_juice_shrink_base_size() -> void:
	if _juice_shrink_base_captured:
		return
	if visual_root != null:
		_juice_shrink_base_visual_scale = visual_root.scale
		_juice_shrink_base_visual_position = visual_root.position
	if body_collision_shape != null:
		_juice_shrink_base_collision_scale = body_collision_shape.scale
		_juice_shrink_base_collision_position = body_collision_shape.position
	_juice_shrink_current_visual_scale = 1.0
	_juice_shrink_visual_offset = Vector2.ZERO
	_juice_shrink_base_captured = true

func _kill_juice_shrink_tween() -> void:
	if _juice_shrink_tween != null:
		_juice_shrink_tween.kill()
	_juice_shrink_tween = null

func _refresh_visual_root_offset() -> void:
	if visual_root == null:
		return
	visual_root.position = _juice_shrink_base_visual_position + visual_correction_offset + _juice_shrink_visual_offset

func _apply_juice_shrink_scale_state(scale_factor: float) -> void:
	_capture_juice_shrink_base_size()
	var safe_scale := clampf(scale_factor, 0.2, JUICE_SHRINK_EXIT_POP_SCALE)
	_juice_shrink_current_visual_scale = safe_scale
	if visual_root != null:
		visual_root.scale = _juice_shrink_base_visual_scale * safe_scale
		var foot_anchor_offset := JUICE_SHRINK_FOOT_ANCHOR_HEIGHT * (1.0 - safe_scale)
		_juice_shrink_visual_offset = Vector2(0.0, foot_anchor_offset)
		_refresh_visual_root_offset()
	if body_collision_shape != null:
		body_collision_shape.scale = Vector2(
			_juice_shrink_base_collision_scale.x * safe_scale,
			_juice_shrink_base_collision_scale.y * safe_scale
		)
		var hitbox_delta := HIT_HEIGHT * (safe_scale - 1.0)
		body_collision_shape.position = _juice_shrink_base_collision_position + Vector2(0.0, -hitbox_delta * 0.5)

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
	_juice_shrink_tween = create_tween()
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
	_juice_shrink_tween = create_tween()
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

func _part_base_material(sprite: Sprite2D) -> Material:
	if sprite == null:
		return null
	if erebus_immune_visual_remaining_sec > 0.0:
		return erebus_immune_materials.get(sprite, null) as Material
	if outrage_boost_remaining_sec > 0.0:
		return outrage_boost_materials.get(sprite, null) as Material
	return null

func _apply_part_base_materials() -> void:
	if not damage_flash_part_materials.is_empty():
		return
	for sprite_value in _part_sprites():
		var sprite := sprite_value as Sprite2D
		if sprite == null:
			continue
		sprite.material = _part_base_material(sprite)

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

func _tick_erebus_immune_visual() -> void:
	if erebus_immune_visual_remaining_sec <= 0.0:
		return
	var tint := get_torso_dominant_color()
	for material_value in erebus_immune_materials.values():
		var material := material_value as ShaderMaterial
		if material == null:
			continue
		material.set_shader_parameter("tint_color", Color(tint.r, tint.g, tint.b, 1.0))

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
		var overlay_material := ShaderMaterial.new()
		overlay_material.shader = DAMAGE_FLASH_WHITE_SHADER
		overlay.material = overlay_material
		overlay.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		overlay.visible = false
		source_sprite.get_parent().add_child(overlay)
		_set_canvas_item_visibility_layer_recursive(overlay, visibility_layer)
		damage_flash_overlay_pairs.append({
			"source": source_sprite,
			"overlay": overlay,
		})
	_sync_damage_flash_overlays()

func _init_outrage_boost_overlays() -> void:
	outrage_boost_overlay_pairs.clear()
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
		overlay.z_index = source_sprite.z_index + 5
		var overlay_material := ShaderMaterial.new()
		overlay_material.shader = OUTRAGE_BOOST_FIRE_SHADER
		overlay_material.set_shader_parameter("fire_strength", 1.0)
		overlay.material = overlay_material
		overlay.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		overlay.visible = false
		source_sprite.get_parent().add_child(overlay)
		_set_canvas_item_visibility_layer_recursive(overlay, visibility_layer)
		outrage_boost_overlay_pairs.append({
			"source": source_sprite,
			"overlay": overlay,
		})
	_sync_outrage_boost_overlays()

func _init_damage_flash_materials() -> void:
	damage_flash_part_materials.clear()
	damage_flash_source_materials.clear()
	for sprite in [head_sprite, torso_sprite, leg1_sprite, leg2_sprite]:
		if sprite == null:
			continue
		damage_flash_source_materials[sprite] = sprite.material
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
	var local_peer_id := _local_peer_id_safe()
	if peer_id <= 0 or peer_id != local_peer_id:
		return
	if outrage_boost_screen_fire_root != null and is_instance_valid(outrage_boost_screen_fire_root):
		return
	var hud_layer := get_tree().current_scene.get_node_or_null("ClientHud") if get_tree().current_scene != null else null
	if hud_layer is CanvasLayer:
		outrage_boost_screen_fire_layer = hud_layer as CanvasLayer
	else:
		var overlay_host: Node = get_tree().current_scene
		if overlay_host == null:
			overlay_host = get_tree().root
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
	var viewport := get_viewport()
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

func _screen_fire_edge_h_tex(flip_vertical: bool) -> Texture2D:
	if not flip_vertical and _screen_fire_edge_h_tex_cache != null:
		return _screen_fire_edge_h_tex_cache
	var img := Image.create(96, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(img.get_width()):
		var wave := 0.55 + 0.45 * sin(float(x) * 0.22)
		var flame_height := int(4 + wave * 14.0)
		for y in range(flame_height):
			var py := y if not flip_vertical else img.get_height() - 1 - y
			var alpha := 1.0 - (float(y) / maxf(1.0, float(flame_height)))
			img.set_pixel(x, py, Color(1.0, 1.0, 1.0, alpha))
	var tex := ImageTexture.create_from_image(img)
	if not flip_vertical:
		_screen_fire_edge_h_tex_cache = tex
	return tex

func _screen_fire_edge_v_tex(flip_horizontal: bool) -> Texture2D:
	if not flip_horizontal and _screen_fire_edge_v_tex_cache != null:
		return _screen_fire_edge_v_tex_cache
	var img := Image.create(20, 96, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(img.get_height()):
		var wave := 0.55 + 0.45 * sin(float(y) * 0.24 + 0.7)
		var flame_width := int(4 + wave * 10.0)
		for x in range(flame_width):
			var px := x if not flip_horizontal else img.get_width() - 1 - x
			var alpha := 1.0 - (float(x) / maxf(1.0, float(flame_width)))
			img.set_pixel(px, y, Color(1.0, 1.0, 1.0, alpha))
	var tex := ImageTexture.create_from_image(img)
	if not flip_horizontal:
		_screen_fire_edge_v_tex_cache = tex
	return tex

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

func set_target_dummy_mode(enabled: bool) -> void:
	target_dummy_mode = enabled
	if not enabled:
		set_max_health(DEFAULT_MAX_HEALTH)
		target_health = clampi(target_health, 0, DEFAULT_MAX_HEALTH)
	velocity = Vector2.ZERO
	target_velocity = Vector2.ZERO
	target_animation_on_floor = true

func is_target_dummy() -> bool:
	return target_dummy_mode

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

func set_shot_audio_stream(stream: AudioStream) -> void:
	if weapon_visual_component != null:
		weapon_visual_component.set_shot_audio_stream(stream)
		return
	if shot_audio == null:
		return
	shot_audio.stream = stream

func set_reload_audio_stream(stream: AudioStream) -> void:
	if weapon_visual_component != null:
		weapon_visual_component.set_reload_audio_stream(stream)
		return
	if reload_audio == null:
		return
	reload_audio.stream = stream

func set_weapon_visual(visual_config: Dictionary) -> void:
	if weapon_visual_component != null:
		weapon_visual_component.set_weapon_visual(visual_config, target_aim_angle)
		return

func get_current_weapon_visual_id() -> String:
	if weapon_visual_component != null:
		return weapon_visual_component.get_current_weapon_visual_id()
	return ""

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
		"juice":
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		"madam":
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
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
	if vitals_hud_component == null:
		return
	var previous_health := vitals_hud_component.get_health()
	vitals_hud_component.set_health(value)
	target_health = vitals_hud_component.get_health()
	var damage_taken := previous_health - target_health
	if damage_taken > 0:
		_show_damage_number(damage_taken)

func get_health() -> int:
	if vitals_hud_component == null:
		return MAX_HEALTH
	return vitals_hud_component.get_health()

func set_max_health(value: int, clamp_current: bool = true) -> void:
	if vitals_hud_component == null:
		return
	vitals_hud_component.set_max_health(value, clamp_current)
	target_health = clampi(target_health, 0, get_max_health())

func get_max_health() -> int:
	if vitals_hud_component == null:
		return DEFAULT_MAX_HEALTH
	return vitals_hud_component.get_max_health()

func _show_damage_number(amount: int) -> void:
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

	var move_tween := create_tween()
	move_tween.bind_node(label)
	var move_track := move_tween.tween_property(label, "position", end_offset - (popup_size * 0.5), DAMAGE_NUMBER_POP_SEC + DAMAGE_NUMBER_HOLD_SEC + DAMAGE_NUMBER_FADE_SEC)
	move_track.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var scale_tween := create_tween()
	scale_tween.bind_node(label)
	var grow_track := scale_tween.tween_property(label, "scale", Vector2.ONE * DAMAGE_NUMBER_PEAK_SCALE, DAMAGE_NUMBER_POP_SEC)
	grow_track.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var shrink_track := scale_tween.tween_property(label, "scale", Vector2.ONE * DAMAGE_NUMBER_END_SCALE, DAMAGE_NUMBER_HOLD_SEC + DAMAGE_NUMBER_FADE_SEC)
	shrink_track.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var fade_tween := create_tween()
	fade_tween.bind_node(label)
	fade_tween.tween_interval(DAMAGE_NUMBER_HOLD_SEC)
	var fade_track := fade_tween.tween_property(label, "modulate:a", 0.0, DAMAGE_NUMBER_FADE_SEC)
	fade_track.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade_tween.finished.connect(label.queue_free)

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
	if vitals_hud_component == null:
		return
	vitals_hud_component.set_ammo(value, reloading)

func play_reload_audio() -> void:
	if weapon_visual_component != null:
		weapon_visual_component.play_reload_audio()
		return
	if _is_sfx_suppressed():
		return
	if reload_audio == null or reload_audio.stream == null:
		return
	reload_audio.pitch_scale = randf_range(0.98, 1.03)
	reload_audio.stop()
	reload_audio.play()

func apply_damage(amount: int, incoming_velocity: Vector2 = Vector2.ZERO) -> int:
	if damage_immune_remaining_sec > 0.0:
		return get_health()
	var remaining: int = maxi(0, amount)
	if shield_remaining_sec > 0.0 and shield_health > 0 and remaining > 0:
		var absorbed: int = mini(shield_health, remaining)
		shield_health = maxi(0, shield_health - absorbed)
		remaining = maxi(0, remaining - absorbed)
		if shield_health <= 0:
			shield_remaining_sec = 0.0
	if remaining <= 0:
		return get_health()
	if incoming_velocity.length_squared() > 0.0001:
		damage_push_direction = incoming_velocity.normalized()
		target_damage_push_direction = damage_push_direction
	_apply_damage_feedback()
	set_health(get_health() - remaining)
	return get_health()

func _apply_damage_feedback() -> void:
	var push_direction := _resolved_damage_push_direction()
	damage_slow_remaining_sec = maxf(damage_slow_remaining_sec, DAMAGE_SLOW_DURATION_SEC)
	velocity.x += DAMAGE_KNOCKBACK_X * push_direction.x
	velocity.y = minf(velocity.y, DAMAGE_KNOCKBACK_Y)
	target_velocity = velocity
	_play_damage_visual_feedback(push_direction)

func get_movement_speed_multiplier() -> float:
	var multiplier := clampf(external_movement_speed_multiplier, 0.0, 1.0)
	multiplier *= clampf(external_status_movement_speed_multiplier, 0.0, 1.0)
	if damage_slow_remaining_sec > 0.0:
		multiplier *= DAMAGE_SLOW_MULTIPLIER
	if erebus_immune_visual_remaining_sec > 0.0:
		multiplier *= EREBUS_IMMUNE_SPEED_MULTIPLIER
	return multiplier

func get_jump_velocity_multiplier() -> float:
	if erebus_immune_visual_remaining_sec > 0.0:
		return EREBUS_IMMUNE_JUMP_MULTIPLIER
	return 1.0

func set_external_movement_speed_multiplier(value: float) -> void:
	external_movement_speed_multiplier = clampf(value, 0.0, 1.0)

func set_external_status_movement_speed_multiplier(value: float) -> void:
	external_status_movement_speed_multiplier = clampf(value, 0.0, 1.0)

func set_external_fire_rate_multiplier(value: float) -> void:
	external_fire_rate_multiplier = clampf(value, 0.05, 4.0)

func get_external_fire_rate_multiplier() -> float:
	return clampf(external_fire_rate_multiplier, 0.05, 4.0)

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
	_init_damage_flash_materials()
	if damage_flash_overlay_pairs.is_empty():
		_set_damage_flash_strength(0.0)
	else:
		_sync_damage_flash_overlays()
	_sync_damage_flash_overlays()
	_set_damage_flash_strength(0.0)
	damage_flash_tween = create_tween()
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
		sprite.material = _part_base_material(sprite)
	damage_flash_part_materials.clear()
	damage_flash_source_materials.clear()
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
	var local_peer_id := _local_peer_id_safe()
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

func _set_canvas_item_visibility_layer_recursive(node: Node, layer: int) -> void:
	if node is CanvasItem:
		(node as CanvasItem).visibility_layer = layer
	for child in node.get_children():
		var child_node := child as Node
		if child_node != null:
			_set_canvas_item_visibility_layer_recursive(child_node, layer)

func set_damage_immune(duration_sec: float) -> void:
	damage_immune_remaining_sec = maxf(damage_immune_remaining_sec, maxf(0.0, duration_sec))

func clear_damage_immune() -> void:
	damage_immune_remaining_sec = 0.0

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

func _is_sfx_suppressed() -> bool:
	return sfx_suppressed or not forced_sfx_suppressed_reasons.is_empty()

func set_sfx_suppressed(value: bool) -> void:
	sfx_suppressed = value
	_refresh_forced_visibility_state()

func set_forced_hidden(reason: String, enabled: bool) -> void:
	var key := reason.strip_edges()
	if key.is_empty():
		key = "default"
	if enabled:
		forced_hidden_reasons[key] = true
	else:
		forced_hidden_reasons.erase(key)
	_refresh_forced_visibility_state()

func set_forced_sfx_suppressed(reason: String, enabled: bool) -> void:
	var key := reason.strip_edges()
	if key.is_empty():
		key = "default"
	if enabled:
		forced_sfx_suppressed_reasons[key] = true
	else:
		forced_sfx_suppressed_reasons.erase(key)
	_refresh_forced_visibility_state()

func _refresh_forced_visibility_state() -> void:
	var forced_visible := forced_hidden_reasons.is_empty()
	visible = forced_visible
	if visual_root != null:
		visual_root.visible = forced_visible
	var respawn_hidden := bool(forced_hidden_reasons.get("respawn_wait", false))
	if body_collision_shape != null:
		body_collision_shape.set_deferred("disabled", respawn_hidden)
	if respawn_hidden:
		if not _respawn_collision_override_active:
			_respawn_saved_collision_layer = collision_layer
			_respawn_saved_collision_mask = collision_mask
			_respawn_collision_override_active = true
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
	elif _respawn_collision_override_active:
		set_deferred("collision_layer", _respawn_saved_collision_layer)
		set_deferred("collision_mask", _respawn_saved_collision_mask)
		_respawn_collision_override_active = false

func is_respawn_hidden() -> bool:
	return bool(forced_hidden_reasons.get("respawn_wait", false))

func get_hit_radius() -> float:
	var radius := HIT_RADIUS
	if erebus_immune_visual_remaining_sec > 0.0:
		radius *= EREBUS_IMMUNE_HITBOX_SCALE
	if juice_shrink_remaining_sec > 0.0:
		radius *= clampf(juice_shrink_scale, 0.2, 1.0)
	return radius

func get_hit_height() -> float:
	var height := HIT_HEIGHT
	if erebus_immune_visual_remaining_sec > 0.0:
		height *= EREBUS_IMMUNE_HITBOX_SCALE
	if juice_shrink_remaining_sec > 0.0:
		height *= clampf(juice_shrink_scale, 0.2, 1.0)
	return height

func force_respawn(spawn_position: Vector2) -> void:
	global_position = spawn_position
	target_position = spawn_position
	velocity = Vector2.ZERO
	target_velocity = Vector2.ZERO
	set_health(get_max_health())
	target_health = get_max_health()
	damage_immune_remaining_sec = RESPAWN_DAMAGE_IMMUNITY_SEC
	shield_health = 0
	shield_remaining_sec = 0.0
	damage_slow_remaining_sec = 0.0
	external_movement_speed_multiplier = 1.0
	external_status_movement_speed_multiplier = 1.0
	external_fire_rate_multiplier = 1.0
	damage_push_direction = Vector2.ZERO
	target_damage_push_direction = Vector2.ZERO
	damage_part_scramble_remaining_sec = 0.0
	damage_part_scramble_offsets.clear()
	damage_part_scramble_rotations.clear()
	clear_ulti_duration_bar()
	clear_erebus_immune_visual()
	clear_juice_shrink_visual(false)
	forced_hidden_reasons.clear()
	forced_sfx_suppressed_reasons.clear()
	target_respawn_hidden = false
	_refresh_forced_visibility_state()
	if movement_component != null:
		movement_component.reset_jump_state()
	if surface_audio_component != null:
		surface_audio_component.reset_state()
	if damage_flash_tween != null:
		damage_flash_tween.kill()
		_clear_damage_flash_tween()
	if damage_screen_blood_tween != null:
		damage_screen_blood_tween.kill()
		_clear_screen_damage_blood()
	clear_outrage_boost_visual()
	if weapon_visual_component != null:
		weapon_visual_component.reset_after_respawn(target_aim_angle)

func set_aim_world(target_world: Vector2) -> void:
	set_aim_angle((target_world - global_position).angle())

func register_ground_audio_zone(zone: Area2D) -> void:
	if surface_audio_component != null:
		surface_audio_component.register_surface_zone(zone)

func unregister_ground_audio_zone(zone: Area2D) -> void:
	if surface_audio_component != null:
		surface_audio_component.unregister_surface_zone(zone)

func set_aim_angle(angle: float) -> void:
	target_aim_angle = angle
	if weapon_visual_component != null:
		weapon_visual_component.set_aim_angle(angle, use_network_smoothing)
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
	if weapon_visual_component != null:
		weapon_visual_component.apply_horizontal_flip_from_angle(angle)
		return

func play_shot_recoil() -> void:
	if weapon_visual_component != null:
		weapon_visual_component.play_shot_recoil(target_aim_angle)
		var local_peer_id := _local_peer_id_safe()
		if peer_id > 0 and peer_id == local_peer_id:
			var cursor_manager := get_tree().root.get_node_or_null("CursorManager")
			if cursor_manager != null and cursor_manager.has_method("trigger_shot_feedback"):
				cursor_manager.call("trigger_shot_feedback", 1.0)
		return

func get_aim_angle() -> float:
	return target_aim_angle

func get_muzzle_world_position() -> Vector2:
	if weapon_visual_component != null:
		return weapon_visual_component.get_muzzle_world_position(global_position, get_aim_angle())
	return global_position

func simulate_authoritative(delta: float, axis: float, jump_pressed: bool, jump_held: bool) -> void:
	_last_input_jump_held = jump_held
	var pre_jump_on_floor := is_on_floor()
	var pre_jump_coyote_ready := movement_component != null and movement_component.coyote_time_left > 0.0
	if movement_component != null:
		movement_component.simulate_authoritative(delta, axis, jump_pressed, jump_held)
	if jump_pressed and (pre_jump_on_floor or pre_jump_coyote_ready) and velocity.y < -ANIMATION_AIR_VELOCITY_THRESHOLD:
		_jump_takeoff_force_air_remaining_sec = JUMP_TAKEOFF_FORCE_AIR_SEC
	target_position = global_position
	target_velocity = velocity
	target_aim_angle = get_aim_angle()

func apply_external_jump_hold(duration_sec: float) -> void:
	if movement_component == null:
		return
	movement_component.set_external_jump_hold(duration_sec)

func is_jump_input_held() -> bool:
	return _last_input_jump_held

func apply_snapshot(new_position: Vector2, new_velocity: Vector2, new_aim_angle: float, new_health: int, part_animation_state: Dictionary = {}) -> void:
	target_position = new_position
	target_velocity = new_velocity
	target_aim_angle = new_aim_angle
	target_health = clampi(new_health, 0, get_max_health())
	set_part_animation_state(part_animation_state)

	if not use_network_smoothing:
		global_position = target_position
		velocity = target_velocity
		if weapon_visual_component != null:
			weapon_visual_component.set_aim_angle(target_aim_angle, false)
		_apply_player_facing_from_angle(target_aim_angle)
		_apply_gun_horizontal_flip_from_angle(target_aim_angle)
		set_health(target_health)

func set_part_animation_state(state: Dictionary) -> void:
	target_animation_on_floor = bool(state.get("on_floor", target_animation_on_floor))
	target_respawn_hidden = bool(state.get("respawn_hidden", target_respawn_hidden))
	var push_direction_value: Variant = state.get("damage_push_direction", Vector2.ZERO)
	if push_direction_value is Vector2:
		target_damage_push_direction = push_direction_value as Vector2

func get_part_animation_state() -> Dictionary:
	return {
		"on_floor": is_on_floor(),
		"respawn_hidden": bool(forced_hidden_reasons.get("respawn_wait", false)),
		"damage_push_direction": damage_push_direction
	}

func _physics_process(delta: float) -> void:
	if vitals_hud_component != null:
		vitals_hud_component.tick(delta)
	if damage_immune_remaining_sec > 0.0:
		damage_immune_remaining_sec = maxf(0.0, damage_immune_remaining_sec - delta)
	if damage_slow_remaining_sec > 0.0:
		damage_slow_remaining_sec = maxf(0.0, damage_slow_remaining_sec - delta)
	if outrage_boost_remaining_sec > 0.0:
		outrage_boost_remaining_sec = maxf(0.0, outrage_boost_remaining_sec - delta)
		_tick_outrage_boost_part_colors()
		_tick_outrage_boost_screen_fire(delta)
		if outrage_boost_remaining_sec <= 0.0:
			_apply_part_base_materials()
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
	if shield_remaining_sec > 0.0:
		shield_remaining_sec = maxf(0.0, shield_remaining_sec - delta)
		if shield_remaining_sec <= 0.0:
			shield_health = 0
	if ulti_duration_remaining_sec > 0.0:
		ulti_duration_remaining_sec = maxf(0.0, ulti_duration_remaining_sec - delta)
		_update_ulti_duration_bar_visual()
	if visual_root != null:
		_tick_visual_correction(delta)
	if _jump_takeoff_force_air_remaining_sec > 0.0:
		_jump_takeoff_force_air_remaining_sec = maxf(0.0, _jump_takeoff_force_air_remaining_sec - delta)
	var floor_contact := is_on_floor()
	if floor_contact:
		_animation_floor_grace_remaining_sec = ANIMATION_FLOOR_GRACE_SEC
	elif _animation_floor_grace_remaining_sec > 0.0:
		_animation_floor_grace_remaining_sec = maxf(0.0, _animation_floor_grace_remaining_sec - delta)
	var local_animation_floor := floor_contact or _animation_floor_grace_remaining_sec > 0.0
	if _jump_takeoff_force_air_remaining_sec > 0.0:
		local_animation_floor = false
	var local_stair_descend_blend := 0.0
	if (
		not floor_contact
		and _jump_takeoff_force_air_remaining_sec <= 0.0
		and _animation_floor_grace_remaining_sec > 0.0
		and absf(velocity.x) >= STAIR_DESCEND_MIN_HORIZONTAL_SPEED
		and velocity.y >= STAIR_DESCEND_MIN_FALL_SPEED
	):
		var speed_t := clampf(
			(velocity.y - STAIR_DESCEND_MIN_FALL_SPEED) / (STAIR_DESCEND_MAX_FALL_SPEED - STAIR_DESCEND_MIN_FALL_SPEED),
			0.0,
			1.0
		)
		var grace_t := clampf(_animation_floor_grace_remaining_sec / ANIMATION_FLOOR_GRACE_SEC, 0.0, 1.0)
		local_stair_descend_blend = speed_t * grace_t
	if modular_visual != null:
		var animation_on_floor := local_animation_floor
		var animation_stair_descend_blend := local_stair_descend_blend
		if use_network_smoothing:
			animation_on_floor = target_animation_on_floor and absf(target_velocity.y) < ANIMATION_AIR_VELOCITY_THRESHOLD
			animation_stair_descend_blend = 0.0
		modular_visual.update_walk_animation(
			delta,
			velocity if not use_network_smoothing else target_velocity,
			animation_on_floor,
			animation_stair_descend_blend
		)
	if surface_audio_component != null:
		var audio_on_floor := local_animation_floor
		var audio_velocity := velocity
		if use_network_smoothing:
			audio_on_floor = target_animation_on_floor and absf(target_velocity.y) < ANIMATION_AIR_VELOCITY_THRESHOLD
			audio_velocity = target_velocity
		surface_audio_component.tick(delta, audio_velocity, audio_on_floor)
	_apply_damage_part_scramble(delta)
	if use_network_smoothing:
		set_forced_hidden("respawn_wait", target_respawn_hidden)
		set_forced_sfx_suppressed("respawn_wait", target_respawn_hidden)
	if not damage_flash_overlay_pairs.is_empty():
		_sync_damage_flash_overlays()
	if not outrage_boost_overlay_pairs.is_empty():
		_sync_outrage_boost_overlays()
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
	if weapon_visual_component != null:
		weapon_visual_component.tick_aim_smoothing(delta, target_aim_angle, AIM_LERP_SPEED)
	_apply_player_facing_from_angle(target_aim_angle)
	_apply_gun_horizontal_flip_from_angle(target_aim_angle)
	if get_health() != target_health:
		set_health(target_health)

func apply_visual_correction(offset: Vector2) -> void:
	if visual_root == null:
		return
	visual_correction_offset += offset
	_refresh_visual_root_offset()

func _trigger_weapon_shot_jolt(aim_angle: float) -> void:
	if modular_visual != null:
		modular_visual.trigger_shot_jolt(aim_angle)

func _tick_visual_correction(delta: float) -> void:
	if visual_correction_offset.length_squared() <= 0.0001:
		visual_correction_offset = Vector2.ZERO
		_refresh_visual_root_offset()
		return
	visual_correction_offset = visual_correction_offset.lerp(Vector2.ZERO, min(1.0, delta * VISUAL_CORRECTION_DECAY))
	_refresh_visual_root_offset()

func _ensure_ulti_duration_bar() -> void:
	if visual_root == null:
		return
	ulti_status_label = skill_label
	ulti_duration_bar_root = skill_duration_bar
	ulti_duration_bar_fill = skill_duration_bar
	if skill_duration_bar != null:
		skill_duration_bar.region_enabled = true
		skill_duration_bar.centered = false
		if not _skill_duration_bar_base_captured:
			_skill_duration_bar_base_region = skill_duration_bar.region_rect
			_skill_duration_bar_base_scale = skill_duration_bar.scale
			_skill_duration_bar_base_modulate = skill_duration_bar.modulate
			_skill_duration_bar_base_captured = true
	if ulti_status_label != null:
		ulti_status_label.visible = false
	if skill_duration_bar_bg != null:
		skill_duration_bar_bg.visible = false
	if skill_duration_bar != null:
		skill_duration_bar.visible = false

func _update_ulti_duration_bar_visual() -> void:
	_ensure_ulti_duration_bar()
	if skill_duration_bar == null:
		return
	var local_peer_id := _local_peer_id_safe()
	var is_local_player := local_peer_id > 0 and peer_id > 0 and peer_id == local_peer_id
	var show := is_local_player and ulti_duration_total_sec > 0.0 and ulti_duration_remaining_sec > 0.0
	skill_duration_bar.visible = show
	if skill_duration_bar_bg != null:
		skill_duration_bar_bg.visible = show
	if ulti_status_label != null:
		ulti_status_label.visible = show and not ulti_status_text.is_empty()
		ulti_status_label.text = ulti_status_text if show else ""
	if not show:
		if _skill_duration_bar_base_captured:
			skill_duration_bar.scale = _skill_duration_bar_base_scale
			skill_duration_bar.modulate = _skill_duration_bar_base_modulate
		return
	var ratio := clampf(ulti_duration_remaining_sec / maxf(0.001, ulti_duration_total_sec), 0.0, 1.0)
	skill_duration_bar.region_rect = _skill_duration_bar_base_region
	skill_duration_bar.scale = Vector2(_skill_duration_bar_base_scale.x * ratio, _skill_duration_bar_base_scale.y)
	var tint := get_main_torso_ui_color()
	skill_duration_bar.modulate = Color(clampf(tint.r, 0.0, 1.0), clampf(tint.g, 0.0, 1.0), clampf(tint.b, 0.0, 1.0), 0.96)

func get_main_torso_ui_color() -> Color:
	if body != null:
		return Color(body.color.r, body.color.g, body.color.b, 1.0)
	return get_torso_dominant_color()

func _local_peer_id_safe() -> int:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return 0
	return multiplayer.get_unique_id()
