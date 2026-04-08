extends RefCounted

class_name PlayerCombatState

const MAX_HEALTH := 100
const DEFAULT_MAX_HEALTH := MAX_HEALTH
const DAMAGE_SLOW_DURATION_SEC := 0.38
const DAMAGE_SLOW_MULTIPLIER := 0.58
const DAMAGE_KNOCKBACK_X := 42.0
const DAMAGE_KNOCKBACK_Y := -36.0

var _player: CharacterBody2D
var _vitals_hud_component_cb: Callable = Callable()
var _status_visuals_component_cb: Callable = Callable()
var _weapon_visual_component_cb: Callable = Callable()
var _show_damage_number_cb: Callable = Callable()
var _resolved_damage_push_direction_cb: Callable = Callable()
var _play_damage_visual_feedback_cb: Callable = Callable()

var damage_immune_remaining_sec := 0.0
var shield_health := 0
var shield_remaining_sec := 0.0
var damage_slow_remaining_sec := 0.0
var external_movement_speed_multiplier := 1.0
var external_status_movement_speed_multiplier := 1.0
var external_status_jump_velocity_multiplier := 1.0
var external_fire_rate_multiplier := 1.0
var external_reload_speed_multiplier := 1.0
var reload_animation_speed_multiplier := 1.0

func configure(
	player: CharacterBody2D,
	vitals_hud_component_cb: Callable,
	status_visuals_component_cb: Callable,
	weapon_visual_component_cb: Callable,
	show_damage_number_cb: Callable,
	resolved_damage_push_direction_cb: Callable,
	play_damage_visual_feedback_cb: Callable
) -> void:
	_player = player
	_vitals_hud_component_cb = vitals_hud_component_cb
	_status_visuals_component_cb = status_visuals_component_cb
	_weapon_visual_component_cb = weapon_visual_component_cb
	_show_damage_number_cb = show_damage_number_cb
	_resolved_damage_push_direction_cb = resolved_damage_push_direction_cb
	_play_damage_visual_feedback_cb = play_damage_visual_feedback_cb

func tick(delta: float) -> void:
	if damage_immune_remaining_sec > 0.0:
		damage_immune_remaining_sec = maxf(0.0, damage_immune_remaining_sec - delta)
	if damage_slow_remaining_sec > 0.0:
		damage_slow_remaining_sec = maxf(0.0, damage_slow_remaining_sec - delta)
	if shield_remaining_sec > 0.0:
		shield_remaining_sec = maxf(0.0, shield_remaining_sec - delta)
		if shield_remaining_sec <= 0.0:
			shield_health = 0

func reset_for_respawn() -> void:
	damage_immune_remaining_sec = 0.0
	shield_health = 0
	shield_remaining_sec = 0.0
	damage_slow_remaining_sec = 0.0
	external_movement_speed_multiplier = 1.0
	external_status_movement_speed_multiplier = 1.0
	external_status_jump_velocity_multiplier = 1.0
	external_fire_rate_multiplier = 1.0
	external_reload_speed_multiplier = 1.0
	reload_animation_speed_multiplier = 1.0

func initialize_defaults() -> void:
	set_health(MAX_HEALTH)
	set_ammo(0, false)

func set_health(value: int) -> void:
	var vitals_hud_component: Variant = _vitals_hud_component()
	if vitals_hud_component == null:
		return
	var previous_health: int = int(vitals_hud_component.get_health())
	vitals_hud_component.set_health(value)
	_player.target_health = int(vitals_hud_component.get_health())
	var damage_taken: int = previous_health - int(_player.target_health)
	if damage_taken > 0 and _show_damage_number_cb.is_valid():
		_show_damage_number_cb.call(damage_taken)

func get_health() -> int:
	var vitals_hud_component: Variant = _vitals_hud_component()
	if vitals_hud_component == null:
		return MAX_HEALTH
	return int(vitals_hud_component.get_health())

func set_max_health(value: int, clamp_current: bool = true) -> void:
	var vitals_hud_component: Variant = _vitals_hud_component()
	if vitals_hud_component == null:
		return
	vitals_hud_component.set_max_health(value, clamp_current)
	_player.target_health = clampi(_player.target_health, 0, get_max_health())

func get_max_health() -> int:
	var vitals_hud_component: Variant = _vitals_hud_component()
	if vitals_hud_component == null:
		return DEFAULT_MAX_HEALTH
	return int(vitals_hud_component.get_max_health())

func set_ammo(value: int, reloading: bool = false) -> void:
	var vitals_hud_component: Variant = _vitals_hud_component()
	if vitals_hud_component == null:
		return
	vitals_hud_component.set_ammo(value, reloading)

func play_reload_audio(is_sfx_suppressed: bool, fallback_audio: AudioStreamPlayer2D = null) -> void:
	var weapon_visual_component: Variant = _weapon_visual_component()
	if weapon_visual_component != null:
		weapon_visual_component.play_reload_audio(get_reload_animation_speed_multiplier())
		return
	if is_sfx_suppressed:
		return
	if fallback_audio == null or fallback_audio.stream == null:
		return
	fallback_audio.pitch_scale = randf_range(0.98, 1.03)
	fallback_audio.stop()
	fallback_audio.play()

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
		_player.damage_push_direction = incoming_velocity.normalized()
		_player.target_damage_push_direction = _player.damage_push_direction
	_apply_damage_feedback()
	set_health(get_health() - remaining)
	return get_health()

func get_movement_speed_multiplier() -> float:
	var multiplier: float = clampf(external_movement_speed_multiplier, 0.0, 1.0)
	multiplier *= clampf(external_status_movement_speed_multiplier, 0.0, 3.0)
	if damage_slow_remaining_sec > 0.0:
		multiplier *= DAMAGE_SLOW_MULTIPLIER
	var status_visuals_component: Variant = _status_visuals_component()
	if status_visuals_component != null:
		multiplier *= float(status_visuals_component.get_movement_speed_multiplier())
	return multiplier

func get_jump_velocity_multiplier() -> float:
	var multiplier := clampf(external_status_jump_velocity_multiplier, 0.25, 3.0)
	var status_visuals_component: Variant = _status_visuals_component()
	if status_visuals_component != null:
		multiplier *= float(status_visuals_component.get_jump_velocity_multiplier())
	return multiplier

func set_external_movement_speed_multiplier(value: float) -> void:
	external_movement_speed_multiplier = clampf(value, 0.0, 1.0)

func set_external_status_movement_speed_multiplier(value: float) -> void:
	external_status_movement_speed_multiplier = clampf(value, 0.0, 3.0)

func set_external_status_jump_velocity_multiplier(value: float) -> void:
	external_status_jump_velocity_multiplier = clampf(value, 0.25, 3.0)

func set_external_fire_rate_multiplier(value: float) -> void:
	external_fire_rate_multiplier = clampf(value, 0.05, 4.0)

func get_external_fire_rate_multiplier() -> float:
	return clampf(external_fire_rate_multiplier, 0.05, 4.0)

func set_external_reload_speed_multiplier(value: float) -> void:
	external_reload_speed_multiplier = clampf(value, 0.05, 4.0)

func get_external_reload_speed_multiplier() -> float:
	return clampf(external_reload_speed_multiplier, 0.05, 4.0)

func set_reload_animation_speed_multiplier(value: float) -> void:
	reload_animation_speed_multiplier = clampf(value, 0.05, 4.0)

func get_reload_animation_speed_multiplier() -> float:
	return clampf(reload_animation_speed_multiplier, 0.05, 4.0)

func set_damage_immune(duration_sec: float) -> void:
	damage_immune_remaining_sec = maxf(damage_immune_remaining_sec, maxf(0.0, duration_sec))

func clear_damage_immune() -> void:
	damage_immune_remaining_sec = 0.0

func is_damage_immune() -> bool:
	return damage_immune_remaining_sec > 0.0

func set_shield(amount: int, duration_sec: float) -> void:
	var normalized_amount: int = maxi(0, amount)
	var normalized_duration: float = maxf(0.0, duration_sec)
	if normalized_amount <= 0 or normalized_duration <= 0.0:
		shield_health = 0
		shield_remaining_sec = 0.0
		return
	shield_health = maxi(shield_health, normalized_amount)
	shield_remaining_sec = maxf(shield_remaining_sec, normalized_duration)

func _apply_damage_feedback() -> void:
	var push_direction := Vector2.ZERO
	if _resolved_damage_push_direction_cb.is_valid():
		var value: Variant = _resolved_damage_push_direction_cb.call()
		if value is Vector2:
			push_direction = value as Vector2
	damage_slow_remaining_sec = maxf(damage_slow_remaining_sec, DAMAGE_SLOW_DURATION_SEC)
	_player.velocity.x += DAMAGE_KNOCKBACK_X * push_direction.x
	_player.velocity.y = minf(_player.velocity.y, DAMAGE_KNOCKBACK_Y)
	_player.target_velocity = _player.velocity
	if _play_damage_visual_feedback_cb.is_valid():
		_play_damage_visual_feedback_cb.call(push_direction)

func _vitals_hud_component() -> Variant:
	if _vitals_hud_component_cb.is_valid():
		return _vitals_hud_component_cb.call()
	return null

func _status_visuals_component() -> Variant:
	if _status_visuals_component_cb.is_valid():
		return _status_visuals_component_cb.call()
	return null

func _weapon_visual_component() -> Variant:
	if _weapon_visual_component_cb.is_valid():
		return _weapon_visual_component_cb.call()
	return null
