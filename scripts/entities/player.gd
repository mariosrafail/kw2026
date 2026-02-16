extends CharacterBody2D
class_name NetPlayer

const SPEED := 245.0
const JUMP_VELOCITY := -650.0
const GRAVITY := 1450.0
const FALL_GRAVITY_MULTIPLIER := 1.35
const MAX_FALL_SPEED := 1300.0
const JUMP_RELEASE_DAMP := 0.55
const COYOTE_TIME := 0.16
const SNAP_LERP_SPEED_X := 14.0
const SNAP_LERP_SPEED_Y := 10.0
const AIM_LERP_SPEED := 20.0
const REMOTE_SNAP_DISTANCE := 150.0
const REMOTE_VELOCITY_BLEND := 0.45
const MAX_HEALTH := 100
const HIT_RADIUS := 12.0
const GUN_VISUAL_ANGLE_OFFSET := 0.0
const GUN_RECOIL_SCALE_Y := 1.08
const GUN_RECOIL_OUT_TIME := 0.035
const GUN_RECOIL_BACK_TIME := 0.085
const MUZZLE_FALLBACK_DISTANCE := 24.0
const GUN_CENTERING_Y_TWEAK := -3.0

@onready var body: Polygon2D = $Body
@onready var feet: Polygon2D = $Feet
@onready var player_sprite: Node2D = $Sprite2D
@onready var gun_pivot: Node2D = $GunPivot
@onready var gun: Node2D = $GunPivot/Gun
@onready var muzzle: Marker2D = $GunPivot/Muzzle
@onready var shot_audio: AudioStreamPlayer2D = $GunPivot/ShotAudio
@onready var reload_audio: AudioStreamPlayer2D = $GunPivot/ReloadAudio
@onready var death_audio: AudioStreamPlayer2D = $DeathAudio
@onready var health_label: Label = $HealthLabel
@onready var ammo_label: Label = $AmmoLabel

var peer_id: int = 0
var use_network_smoothing := false
var target_position := Vector2.ZERO
var target_velocity := Vector2.ZERO
var target_aim_angle := 0.0
var health := MAX_HEALTH
var target_health := MAX_HEALTH
var ammo_count := 0
var is_reloading := false
var coyote_time_left := 0.0
var gun_recoil_tween: Tween
var gun_base_scale_abs := Vector2.ONE

func _ready() -> void:
	target_position = global_position
	target_velocity = velocity
	target_aim_angle = 0.0
	target_health = health
	_normalize_gun_sprite_anchor()
	if gun != null:
		gun_base_scale_abs = Vector2(absf(gun.scale.x), absf(gun.scale.y))
	_apply_player_facing_from_angle(target_aim_angle)
	_apply_gun_horizontal_flip_from_angle(target_aim_angle)
	_update_health_label()
	_update_ammo_label()

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
		gun.modulate = color.lightened(0.15)
	set_health(MAX_HEALTH)
	set_ammo(0, false)

func set_shot_audio_stream(stream: AudioStream) -> void:
	if shot_audio == null:
		return
	shot_audio.stream = stream

func set_reload_audio_stream(stream: AudioStream) -> void:
	if reload_audio == null:
		return
	reload_audio.stream = stream

func set_health(value: int) -> void:
	var previous_health := health
	health = clampi(value, 0, MAX_HEALTH)
	target_health = health
	if previous_health > 0 and health <= 0:
		_reset_gun_scale()
		_play_death_audio()
	_update_health_label()

func get_health() -> int:
	return health

func set_ammo(value: int, reloading: bool = false) -> void:
	ammo_count = maxi(0, value)
	is_reloading = reloading
	_update_ammo_label()

func play_reload_audio() -> void:
	if reload_audio == null or reload_audio.stream == null:
		return
	reload_audio.pitch_scale = randf_range(0.98, 1.03)
	reload_audio.stop()
	reload_audio.play()

func apply_damage(amount: int) -> int:
	set_health(health - max(0, amount))
	return health

func _play_death_audio() -> void:
	if death_audio == null or death_audio.stream == null:
		return
	death_audio.pitch_scale = randf_range(0.96, 1.04)
	death_audio.stop()
	death_audio.play()

func get_hit_radius() -> float:
	return HIT_RADIUS

func _update_health_label() -> void:
	if health_label != null:
		health_label.text = str(health)

func _update_ammo_label() -> void:
	if ammo_label == null:
		return
	ammo_label.text = "R" if is_reloading else str(ammo_count)

func force_respawn(spawn_position: Vector2) -> void:
	global_position = spawn_position
	target_position = spawn_position
	velocity = Vector2.ZERO
	target_velocity = Vector2.ZERO
	coyote_time_left = 0.0
	_reset_gun_scale()

func set_aim_world(target_world: Vector2) -> void:
	set_aim_angle((target_world - global_position).angle())

func set_aim_angle(angle: float) -> void:
	target_aim_angle = angle
	if not use_network_smoothing and gun_pivot != null:
		gun_pivot.rotation = angle + GUN_VISUAL_ANGLE_OFFSET
	_apply_player_facing_from_angle(angle)
	_apply_gun_horizontal_flip_from_angle(angle)

func _apply_player_facing_from_angle(angle: float) -> void:
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
	gun.scale = Vector2(
		absf(gun_base_scale_abs.x),
		-absf(gun_base_scale_abs.y) if looking_left else absf(gun_base_scale_abs.y)
	)

func play_shot_recoil() -> void:
	if gun == null:
		return
	if shot_audio != null and shot_audio.stream != null:
		shot_audio.pitch_scale = randf_range(0.95, 1.08)
		shot_audio.stop()
		shot_audio.play()
	if gun_recoil_tween != null:
		gun_recoil_tween.kill()

	var sign_x := 1.0
	var sign_y := -1.0 if gun.scale.y < 0.0 else 1.0
	var base_scale := gun_base_scale_abs
	var recoil_scale := Vector2(base_scale.x, base_scale.y * GUN_RECOIL_SCALE_Y)

	gun_recoil_tween = create_tween()
	gun_recoil_tween.tween_property(gun, "scale", Vector2(sign_x * recoil_scale.x, sign_y * recoil_scale.y), GUN_RECOIL_OUT_TIME)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	gun_recoil_tween.tween_property(gun, "scale", Vector2(sign_x * base_scale.x, sign_y * base_scale.y), GUN_RECOIL_BACK_TIME)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _reset_gun_scale() -> void:
	if gun_recoil_tween != null:
		gun_recoil_tween.kill()
		gun_recoil_tween = null
	_apply_gun_horizontal_flip_from_angle(target_aim_angle)

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

	var tweak_offset_world := _get_gun_centering_tweak_world_offset()
	var fallback_position := global_position + Vector2.RIGHT.rotated(aim_angle) * fallback_distance + tweak_offset_world
	if muzzle == null:
		return fallback_position

	var marker_position := muzzle.global_position + tweak_offset_world
	# If marker is still near the player's center, use an auto-calculated barrel tip.
	if marker_position.distance_squared_to(global_position) <= 36.0:
		return fallback_position
	return marker_position

func _get_gun_centering_tweak_world_offset() -> Vector2:
	if gun_pivot == null or is_zero_approx(GUN_CENTERING_Y_TWEAK):
		return Vector2.ZERO
	var local_tweak := Vector2(0.0, GUN_CENTERING_Y_TWEAK)
	return gun_pivot.to_global(local_tweak) - gun_pivot.global_position

func simulate_authoritative(delta: float, axis: float, jump_pressed: bool, jump_held: bool) -> void:
	axis = clamp(axis, -1.0, 1.0)
	var on_floor := is_on_floor()
	if on_floor:
		coyote_time_left = COYOTE_TIME
	else:
		coyote_time_left = maxf(coyote_time_left - delta, 0.0)

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

	if jump_pressed and (on_floor or coyote_time_left > 0.0):
		velocity.y = JUMP_VELOCITY
		coyote_time_left = 0.0

	if not jump_held and velocity.y < 0.0:
		velocity.y *= JUMP_RELEASE_DAMP

	move_and_slide()
	if is_on_floor():
		coyote_time_left = COYOTE_TIME
	target_position = global_position
	target_velocity = velocity
	target_aim_angle = get_aim_angle()

func apply_snapshot(new_position: Vector2, new_velocity: Vector2, new_aim_angle: float, new_health: int) -> void:
	target_position = new_position
	target_velocity = new_velocity
	target_aim_angle = new_aim_angle
	target_health = clampi(new_health, 0, MAX_HEALTH)

	if not use_network_smoothing:
		global_position = target_position
		velocity = target_velocity
		if gun_pivot != null:
			gun_pivot.rotation = target_aim_angle + GUN_VISUAL_ANGLE_OFFSET
		_apply_player_facing_from_angle(target_aim_angle)
		_apply_gun_horizontal_flip_from_angle(target_aim_angle)
		set_health(target_health)

func _physics_process(delta: float) -> void:
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
