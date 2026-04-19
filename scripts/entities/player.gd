extends CharacterBody2D
class_name NetPlayer

const MINIMAP_HIDDEN_VISIBILITY_LAYER := 1 << 1

const PLAYER_DEATH_CHUNKS_SCRIPT := preload("res://scripts/entities/player_components/player_death_chunks.gd")
const PLAYER_STATUS_VISUALS_SCRIPT := preload("res://scripts/entities/player_components/player_status_visuals.gd")
const PLAYER_DAMAGE_FEEDBACK_SCRIPT := preload("res://scripts/entities/player_components/player_damage_feedback.gd")
const PLAYER_MOTION_SYNC_SCRIPT := preload("res://scripts/entities/player_components/player_motion_sync.gd")
const PLAYER_PRESENCE_STATE_SCRIPT := preload("res://scripts/entities/player_components/player_presence_state.gd")
const PLAYER_WEAPON_FACADE_SCRIPT := preload("res://scripts/entities/player_components/player_weapon_facade.gd")
const PLAYER_COMBAT_STATE_SCRIPT := preload("res://scripts/entities/player_components/player_combat_state.gd")
const PLAYER_CHARACTER_VISUALS_SCRIPT := preload("res://scripts/entities/player_components/player_character_visuals.gd")
const PLAYER_LIFECYCLE_STATE_SCRIPT := preload("res://scripts/entities/player_components/player_lifecycle_state.gd")
const PLAYER_PRESENTATION_FACADE_SCRIPT := preload("res://scripts/entities/player_components/player_presentation_facade.gd")

const MAX_HEALTH := 100
const DEFAULT_MAX_HEALTH := MAX_HEALTH
const HIT_RADIUS := 12.0
const HIT_HEIGHT := 34.0
const DAMAGE_FLASH_JOLT_X := 5.0
const DAMAGE_FLASH_JOLT_Y := -2.5
const RESPAWN_DAMAGE_IMMUNITY_SEC := 0.3
const JUICE_SHRINK_DEFAULT_SCALE := 0.46

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
var status_visuals_component: PlayerStatusVisuals
var damage_feedback_component: PlayerDamageFeedback
var motion_sync_component: PlayerMotionSync
var presence_state_component: PlayerPresenceState
var weapon_facade_component: PlayerWeaponFacade
var combat_state_component: PlayerCombatState
var character_visuals_component: PlayerCharacterVisuals
var lifecycle_state_component: PlayerLifecycleState
var presentation_facade_component: PlayerPresentationFacade
var peer_id: int = 0
var use_network_smoothing := false
var target_position := Vector2.ZERO
var target_velocity := Vector2.ZERO
var target_aim_angle := 0.0
var target_health := MAX_HEALTH
var modular_visual: PlayerModularVisual
var gun_base_modulate := Color.WHITE
var target_animation_on_floor := true
var target_respawn_hidden := false
var damage_push_direction := Vector2.ZERO
var target_damage_push_direction := Vector2.ZERO
var target_dummy_mode := false

func _ready() -> void:
	_init_movement_component()
	_init_death_chunks_component()
	_init_vitals_hud_component()
	_init_weapon_visual_component()
	_init_surface_audio_component()
	target_position = global_position
	target_velocity = velocity
	target_aim_angle = 0.0
	target_health = get_health()
	if visual_root != null:
		visual_root.position = Vector2.ZERO
	_init_modular_visual()
	_init_status_visuals_component()
	_init_damage_feedback_component()
	_init_presence_state_component()
	_init_motion_sync_component()
	_init_weapon_facade_component()
	_init_combat_state_component()
	_init_character_visuals_component()
	_init_lifecycle_state_component()
	_init_presentation_facade_component()
	_apply_player_facing_from_angle(target_aim_angle)
	_apply_gun_horizontal_flip_from_angle(target_aim_angle)
	set_skill_cooldown_bars(1.0, 1.0, false)
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
	if lifecycle_state_component != null:
		lifecycle_state_component.spawn_death_chunks_at(world_position, incoming_velocity)

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

func _init_modular_visual() -> void:
	modular_visual = PlayerModularVisual.new()
	modular_visual.configure(self, visual_root, leg1_sprite, leg2_sprite, torso_sprite, head_sprite)
	if player_sprite != null:
		player_sprite.visible = false
	modular_visual.set_character_visual("outrage")

func _init_status_visuals_component() -> void:
	status_visuals_component = PLAYER_STATUS_VISUALS_SCRIPT.new()
	status_visuals_component.configure(
		self,
		visual_root,
		body_collision_shape,
		head_sprite,
		torso_sprite,
		leg1_sprite,
		leg2_sprite,
		gun_pivot,
		skill_label,
		skill_duration_bar_bg,
		skill_duration_bar,
		Callable(self, "_get_peer_id"),
		Callable(self, "_local_peer_id_safe"),
		Callable(self, "get_main_torso_ui_color"),
		Callable(self, "_set_canvas_item_visibility_layer_recursive")
	)
	status_visuals_component.initialize()

func _init_damage_feedback_component() -> void:
	damage_feedback_component = PLAYER_DAMAGE_FEEDBACK_SCRIPT.new()
	damage_feedback_component.configure(
		self,
		visual_root,
		head_sprite,
		torso_sprite,
		leg1_sprite,
		leg2_sprite,
		Callable(self, "_get_peer_id"),
		Callable(self, "_local_peer_id_safe"),
		Callable(self, "_part_base_material"),
		Callable(self, "_set_canvas_item_visibility_layer_recursive")
	)
	damage_feedback_component.initialize()

func _init_motion_sync_component() -> void:
	motion_sync_component = PLAYER_MOTION_SYNC_SCRIPT.new()
	motion_sync_component.configure(
		self,
		Callable(self, "_get_movement_component"),
		Callable(self, "_get_weapon_visual_component"),
		Callable(self, "_get_modular_visual"),
		Callable(self, "_get_surface_audio_component"),
		Callable(self, "set_forced_hidden"),
		Callable(self, "set_forced_sfx_suppressed"),
		Callable(self, "is_respawn_hidden"),
		Callable(self, "_apply_player_facing_from_angle"),
		Callable(self, "_apply_gun_horizontal_flip_from_angle"),
		Callable(self, "set_health")
	)

func _init_presence_state_component() -> void:
	presence_state_component = PLAYER_PRESENCE_STATE_SCRIPT.new()
	presence_state_component.configure(self, visual_root, body_collision_shape)

func _init_weapon_facade_component() -> void:
	weapon_facade_component = PLAYER_WEAPON_FACADE_SCRIPT.new()
	weapon_facade_component.configure(
		self,
		Callable(self, "_get_weapon_visual_component"),
		Callable(self, "_get_motion_sync_component"),
		Callable(self, "_local_peer_id_safe"),
		Callable(self, "_trigger_local_shot_feedback"),
		Callable(self, "_apply_player_facing_from_angle"),
		Callable(self, "_apply_gun_horizontal_flip_from_angle")
	)

func _init_combat_state_component() -> void:
	combat_state_component = PLAYER_COMBAT_STATE_SCRIPT.new()
	combat_state_component.configure(
		self,
		Callable(self, "_get_vitals_hud_component"),
		Callable(self, "_get_status_visuals_component"),
		Callable(self, "_get_weapon_visual_component"),
		Callable(self, "_show_damage_number"),
		Callable(self, "_resolved_damage_push_direction"),
		Callable(self, "_play_damage_visual_feedback")
	)
	combat_state_component.initialize_defaults()

func _init_character_visuals_component() -> void:
	character_visuals_component = PLAYER_CHARACTER_VISUALS_SCRIPT.new()
	character_visuals_component.configure(
		Callable(self, "_get_modular_visual"),
		player_sprite,
		torso_sprite,
		body
	)

func _init_lifecycle_state_component() -> void:
	lifecycle_state_component = PLAYER_LIFECYCLE_STATE_SCRIPT.new()
	lifecycle_state_component.configure(
		self,
		Callable(self, "_get_death_chunks_component"),
		Callable(self, "_get_movement_component"),
		Callable(self, "_get_surface_audio_component"),
		Callable(self, "_get_status_visuals_component"),
		Callable(self, "_get_damage_feedback_component"),
		Callable(self, "_get_combat_state_component"),
		Callable(self, "_get_presence_state_component"),
		Callable(self, "_get_motion_sync_component"),
		Callable(self, "_get_weapon_visual_component"),
		Callable(self, "_resolved_damage_push_direction"),
		Callable(self, "set_health"),
		Callable(self, "get_max_health")
	)

func _init_presentation_facade_component() -> void:
	presentation_facade_component = PLAYER_PRESENTATION_FACADE_SCRIPT.new()
	presentation_facade_component.configure(
		Callable(self, "_get_status_visuals_component"),
		Callable(self, "_get_damage_feedback_component"),
		name_label,
		skill_bars_root,
		skill_q_fill,
		skill_e_fill
	)

func _part_sprites() -> Array:
	return [head_sprite, torso_sprite, leg1_sprite, leg2_sprite]

func _get_peer_id() -> int:
	return peer_id

func _get_movement_component() -> PlayerMovement:
	return movement_component

func _get_weapon_visual_component() -> PlayerWeaponVisual:
	return weapon_visual_component

func _get_modular_visual() -> PlayerModularVisual:
	return modular_visual

func _get_surface_audio_component() -> PlayerSurfaceAudio:
	return surface_audio_component

func _get_motion_sync_component() -> PlayerMotionSync:
	return motion_sync_component

func _get_death_chunks_component() -> PlayerDeathChunks:
	return death_chunks_component

func _get_damage_feedback_component() -> PlayerDamageFeedback:
	return damage_feedback_component

func _get_combat_state_component() -> PlayerCombatState:
	return combat_state_component

func _get_presence_state_component() -> PlayerPresenceState:
	return presence_state_component

func _get_vitals_hud_component() -> PlayerVitalsHud:
	return vitals_hud_component

func _get_status_visuals_component() -> PlayerStatusVisuals:
	return status_visuals_component

func _trigger_local_shot_feedback() -> void:
	var cursor_manager := get_tree().root.get_node_or_null("CursorManager")
	if cursor_manager != null and cursor_manager.has_method("trigger_shot_feedback"):
		cursor_manager.call("trigger_shot_feedback", 1.0)

func _part_base_material(sprite: Sprite2D) -> Material:
	if presentation_facade_component != null:
		return presentation_facade_component.part_base_material(sprite)
	return null

func set_outrage_boost_visual(duration_sec: float) -> void:
	if presentation_facade_component != null:
		presentation_facade_component.set_outrage_boost_visual(duration_sec)

func clear_outrage_boost_visual() -> void:
	if presentation_facade_component != null:
		presentation_facade_component.clear_outrage_boost_visual()

func set_erebus_immune_visual(duration_sec: float) -> void:
	if presentation_facade_component != null:
		presentation_facade_component.set_erebus_immune_visual(duration_sec)

func clear_erebus_immune_visual() -> void:
	if presentation_facade_component != null:
		presentation_facade_component.clear_erebus_immune_visual()

func set_juice_shrink_visual(duration_sec: float, scale_factor: float = JUICE_SHRINK_DEFAULT_SCALE) -> void:
	if presentation_facade_component != null:
		presentation_facade_component.set_juice_shrink_visual(duration_sec, scale_factor)

func clear_juice_shrink_visual(animate: bool = true) -> void:
	if presentation_facade_component != null:
		presentation_facade_component.clear_juice_shrink_visual(animate)

func set_crashout_belly_visual(duration_sec: float) -> void:
	if presentation_facade_component != null:
		presentation_facade_component.set_crashout_belly_visual(duration_sec)

func clear_crashout_belly_visual() -> void:
	if presentation_facade_component != null:
		presentation_facade_component.clear_crashout_belly_visual()

func set_petrified_visual(duration_sec: float) -> void:
	if presentation_facade_component != null:
		presentation_facade_component.set_petrified_visual(duration_sec)

func clear_petrified_visual() -> void:
	if presentation_facade_component != null:
		presentation_facade_component.clear_petrified_visual()

func set_public_debuff_visual(debuff_id: String, duration_sec: float) -> void:
	if presentation_facade_component != null:
		presentation_facade_component.set_public_debuff_visual(debuff_id, duration_sec)

func clear_public_debuff_visual(debuff_id: String = "") -> void:
	if presentation_facade_component != null:
		presentation_facade_component.clear_public_debuff_visual(debuff_id)

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
	if combat_state_component != null:
		combat_state_component.initialize_defaults()

func set_display_name(display_name: String) -> void:
	if presentation_facade_component != null:
		presentation_facade_component.set_display_name(display_name)

func set_target_dummy_mode(enabled: bool) -> void:
	if lifecycle_state_component != null:
		lifecycle_state_component.set_target_dummy_mode(enabled, DEFAULT_MAX_HEALTH)
		return
	target_dummy_mode = enabled

func is_target_dummy() -> bool:
	if lifecycle_state_component != null:
		return lifecycle_state_component.is_target_dummy()
	return target_dummy_mode

func set_skill_cooldown_bars(q_ratio: float, e_ratio: float, bars_visible: bool) -> void:
	if presentation_facade_component != null:
		presentation_facade_component.set_skill_cooldown_bars(q_ratio, e_ratio, bars_visible)

func start_ulti_duration_bar(duration_sec: float, status_text: String = "") -> void:
	if presentation_facade_component != null:
		presentation_facade_component.start_ulti_duration_bar(duration_sec, status_text)

func clear_ulti_duration_bar() -> void:
	if presentation_facade_component != null:
		presentation_facade_component.clear_ulti_duration_bar()

func set_shot_audio_stream(stream: AudioStream) -> void:
	if weapon_facade_component != null:
		weapon_facade_component.set_shot_audio_stream(stream, shot_audio)

func set_reload_audio_stream(stream: AudioStream) -> void:
	if weapon_facade_component != null:
		weapon_facade_component.set_reload_audio_stream(stream, reload_audio)

func set_weapon_visual(visual_config: Dictionary) -> void:
	if weapon_facade_component != null:
		weapon_facade_component.set_weapon_visual(visual_config, target_aim_angle)

func get_current_weapon_visual_id() -> String:
	if weapon_facade_component != null:
		return weapon_facade_component.get_current_weapon_visual_id()
	return ""

func set_character_visual(character_id: String) -> void:
	if character_visuals_component != null:
		character_visuals_component.set_character_visual(character_id)

func set_skin_index(skin_index: int) -> void:
	if character_visuals_component != null:
		character_visuals_component.set_skin_index(skin_index)

func set_health(value: int) -> void:
	if combat_state_component != null:
		combat_state_component.set_health(value)

func get_health() -> int:
	if combat_state_component != null:
		return combat_state_component.get_health()
	return MAX_HEALTH

func set_max_health(value: int, clamp_current: bool = true) -> void:
	if combat_state_component != null:
		combat_state_component.set_max_health(value, clamp_current)

func get_max_health() -> int:
	if combat_state_component != null:
		return combat_state_component.get_max_health()
	return DEFAULT_MAX_HEALTH

func _show_damage_number(amount: int) -> void:
	if presentation_facade_component != null:
		presentation_facade_component.show_damage_number(amount)

func get_torso_dominant_color() -> Color:
	if character_visuals_component != null:
		return character_visuals_component.get_torso_dominant_color()
	return Color(0.98, 0.02, 0.07, 1.0)

func set_ammo(value: int, reloading: bool = false) -> void:
	if combat_state_component != null:
		combat_state_component.set_ammo(value, reloading)

func play_reload_audio() -> void:
	if combat_state_component != null:
		combat_state_component.play_reload_audio(_is_sfx_suppressed(), reload_audio)

func apply_damage(amount: int, incoming_velocity: Vector2 = Vector2.ZERO) -> int:
	if combat_state_component != null:
		return combat_state_component.apply_damage(amount, incoming_velocity)
	return get_health()

func _apply_damage_feedback() -> void:
	if combat_state_component != null:
		combat_state_component._apply_damage_feedback()

func get_movement_speed_multiplier() -> float:
	if combat_state_component != null:
		return combat_state_component.get_movement_speed_multiplier()
	return 1.0

func get_jump_velocity_multiplier() -> float:
	if combat_state_component != null:
		return combat_state_component.get_jump_velocity_multiplier()
	return 1.0

func set_external_movement_speed_multiplier(value: float) -> void:
	if combat_state_component != null:
		combat_state_component.set_external_movement_speed_multiplier(value)

func set_external_status_movement_speed_multiplier(value: float) -> void:
	if combat_state_component != null:
		combat_state_component.set_external_status_movement_speed_multiplier(value)

func set_external_status_jump_velocity_multiplier(value: float) -> void:
	if combat_state_component != null:
		combat_state_component.set_external_status_jump_velocity_multiplier(value)

func set_external_fire_rate_multiplier(value: float) -> void:
	if combat_state_component != null:
		combat_state_component.set_external_fire_rate_multiplier(value)

func get_external_fire_rate_multiplier() -> float:
	if combat_state_component != null:
		return combat_state_component.get_external_fire_rate_multiplier()
	return 1.0

func set_external_reload_speed_multiplier(value: float) -> void:
	if combat_state_component != null:
		combat_state_component.set_external_reload_speed_multiplier(value)

func get_external_reload_speed_multiplier() -> float:
	if combat_state_component != null:
		return combat_state_component.get_external_reload_speed_multiplier()
	return 1.0

func set_reload_animation_speed_multiplier(value: float) -> void:
	if combat_state_component != null:
		combat_state_component.set_reload_animation_speed_multiplier(value)

func get_reload_animation_speed_multiplier() -> float:
	if combat_state_component != null:
		return combat_state_component.get_reload_animation_speed_multiplier()
	return 1.0

func _play_damage_visual_feedback(push_direction := Vector2.ZERO) -> void:
	if push_direction.length_squared() <= 0.0001:
		push_direction = _resolved_damage_push_direction()
	apply_visual_correction(Vector2(DAMAGE_FLASH_JOLT_X * push_direction.x, DAMAGE_FLASH_JOLT_Y))
	if damage_feedback_component != null:
		damage_feedback_component.play_damage_visual_feedback(push_direction)

func _resolved_damage_push_direction() -> Vector2:
	if damage_push_direction.length_squared() > 0.0001:
		return damage_push_direction.normalized()
	if target_damage_push_direction.length_squared() > 0.0001:
		return target_damage_push_direction.normalized()
	var fallback_x := -1.0 if cos(target_aim_angle) >= 0.0 else 1.0
	if absf(velocity.x) > 1.0:
		fallback_x = -signf(velocity.x)
	return Vector2(fallback_x, 0.0)

func _set_canvas_item_visibility_layer_recursive(node: Node, layer: int) -> void:
	if node is CanvasItem:
		(node as CanvasItem).visibility_layer = layer
	for child in node.get_children():
		var child_node := child as Node
		if child_node != null:
			_set_canvas_item_visibility_layer_recursive(child_node, layer)

func set_damage_immune(duration_sec: float) -> void:
	if combat_state_component != null:
		combat_state_component.set_damage_immune(duration_sec)

func clear_damage_immune() -> void:
	if combat_state_component != null:
		combat_state_component.clear_damage_immune()

func is_damage_immune() -> bool:
	if combat_state_component != null:
		return combat_state_component.is_damage_immune()
	return false

func set_shield(amount: int, duration_sec: float) -> void:
	if combat_state_component != null:
		combat_state_component.set_shield(amount, duration_sec)

func _is_sfx_suppressed() -> bool:
	if presence_state_component != null:
		return presence_state_component.is_sfx_suppressed()
	return false

func set_sfx_suppressed(value: bool) -> void:
	if presence_state_component != null:
		presence_state_component.set_sfx_suppressed(value)

func set_forced_hidden(reason: String, enabled: bool) -> void:
	if presence_state_component != null:
		presence_state_component.set_forced_hidden(reason, enabled)

func set_forced_sfx_suppressed(reason: String, enabled: bool) -> void:
	if presence_state_component != null:
		presence_state_component.set_forced_sfx_suppressed(reason, enabled)

func is_respawn_hidden() -> bool:
	if presence_state_component != null:
		return presence_state_component.is_respawn_hidden()
	return false

func get_hit_radius() -> float:
	if presentation_facade_component != null:
		return presentation_facade_component.get_hit_radius(HIT_RADIUS)
	return HIT_RADIUS

func get_hit_height() -> float:
	if presentation_facade_component != null:
		return presentation_facade_component.get_hit_height(HIT_HEIGHT)
	return HIT_HEIGHT

func force_respawn(spawn_position: Vector2) -> void:
	if lifecycle_state_component != null:
		lifecycle_state_component.force_respawn(spawn_position, RESPAWN_DAMAGE_IMMUNITY_SEC)

func set_aim_world(target_world: Vector2) -> void:
	if weapon_facade_component != null:
		weapon_facade_component.set_aim_world(target_world)
		return
	set_aim_angle((target_world - global_position).angle())

func register_ground_audio_zone(zone: Area2D) -> void:
	if surface_audio_component != null:
		surface_audio_component.register_surface_zone(zone)

func unregister_ground_audio_zone(zone: Area2D) -> void:
	if surface_audio_component != null:
		surface_audio_component.unregister_surface_zone(zone)

func set_aim_angle(angle: float) -> void:
	if weapon_facade_component != null:
		weapon_facade_component.set_aim_angle(angle, use_network_smoothing)
		return
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
	if weapon_facade_component != null:
		weapon_facade_component.apply_gun_horizontal_flip_from_angle(angle)

func play_shot_recoil() -> void:
	if weapon_facade_component != null:
		weapon_facade_component.play_shot_recoil(peer_id, target_aim_angle)
		return
	if weapon_visual_component != null:
		weapon_visual_component.play_shot_recoil(target_aim_angle)
		_trigger_local_shot_feedback()

func get_aim_angle() -> float:
	if weapon_facade_component != null:
		return weapon_facade_component.get_aim_angle(target_aim_angle)
	return target_aim_angle

func get_muzzle_world_position() -> Vector2:
	if weapon_facade_component != null:
		return weapon_facade_component.get_muzzle_world_position(global_position, get_aim_angle())
	return global_position

func simulate_authoritative(delta: float, axis: float, jump_pressed: bool, jump_held: bool) -> void:
	if motion_sync_component != null:
		motion_sync_component.simulate_authoritative(delta, axis, jump_pressed, jump_held)

func apply_external_jump_hold(duration_sec: float) -> void:
	if movement_component == null:
		return
	movement_component.set_external_jump_hold(duration_sec)

func is_jump_input_held() -> bool:
	if motion_sync_component != null:
		return motion_sync_component.is_jump_input_held()
	return false

func apply_snapshot(new_position: Vector2, new_velocity: Vector2, new_aim_angle: float, new_health: int, part_animation_state: Dictionary = {}) -> void:
	if motion_sync_component != null:
		motion_sync_component.apply_snapshot(new_position, new_velocity, new_aim_angle, new_health, part_animation_state)

func set_part_animation_state(state: Dictionary) -> void:
	if motion_sync_component != null:
		motion_sync_component.set_part_animation_state(state)

func get_part_animation_state() -> Dictionary:
	if motion_sync_component != null:
		return motion_sync_component.get_part_animation_state()
	return {}

func _physics_process(delta: float) -> void:
	if vitals_hud_component != null:
		vitals_hud_component.tick(delta)
	if combat_state_component != null:
		combat_state_component.tick(delta)
	if status_visuals_component != null:
		status_visuals_component.tick(delta)
	if damage_feedback_component != null:
		damage_feedback_component.tick(delta)
	if motion_sync_component != null:
		motion_sync_component.tick(delta)

func apply_visual_correction(offset: Vector2) -> void:
	if presentation_facade_component != null:
		presentation_facade_component.apply_visual_correction(offset)

func _trigger_weapon_shot_jolt(aim_angle: float) -> void:
	if modular_visual != null:
		modular_visual.trigger_shot_jolt(aim_angle)

func get_main_torso_ui_color() -> Color:
	if character_visuals_component != null:
		return character_visuals_component.get_main_torso_ui_color()
	return get_torso_dominant_color()

func _local_peer_id_safe() -> int:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return 0
	return multiplayer.get_unique_id()
