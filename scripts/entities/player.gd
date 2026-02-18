extends CharacterBody2D
class_name NetPlayer

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
const GUN_RECOIL_SCALE_Y := 1.08
const GUN_RECOIL_OUT_TIME := 0.035
const GUN_RECOIL_BACK_TIME := 0.085
const MUZZLE_FALLBACK_DISTANCE := 24.0
const GUN_CENTERING_Y_TWEAK := 0.0
const DEFAULT_GUN_POSITION := Vector2(6.0, 2.0)
const DEFAULT_MUZZLE_POSITION := Vector2(27.0, -1.0)
const DEFAULT_SHOT_FRAME_DURATION_SEC := 0.03
const DEFAULT_RELOAD_FRAME_DURATION_SEC := 0.065
const MIN_SHOT_FRAME_DURATION_SEC := 0.01
const MAX_WALKABLE_SLOPE_DEGREES := 45.0
const FLOOR_SLOPE_TOLERANCE_DEGREES := 0.5
const FLOOR_SNAP_LENGTH := 14.0
const PLAYER_SAFE_MARGIN := 0.08
const PLAYER_MAX_SLIDES := 8

@onready var body: Polygon2D = get_node_or_null("Body") as Polygon2D
@onready var feet: Polygon2D = get_node_or_null("Feet") as Polygon2D
@onready var visual_root: Node2D = $VisualRoot
@onready var player_sprite: Node2D = $VisualRoot/Sprite2D
@onready var gun_pivot: Node2D = $VisualRoot/GunPivot
@onready var gun: Node2D = $VisualRoot/GunPivot/Gun
@onready var muzzle: Marker2D = $VisualRoot/GunPivot/Muzzle
@onready var shot_audio: AudioStreamPlayer2D = $VisualRoot/GunPivot/ShotAudio
@onready var reload_audio: AudioStreamPlayer2D = $VisualRoot/GunPivot/ReloadAudio
@onready var death_audio: AudioStreamPlayer2D = $DeathAudio
@onready var health_label: Label = $VisualRoot/HealthLabel
@onready var ammo_label: Label = $VisualRoot/AmmoLabel

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
var jump_buffer_time_left := 0.0
var gun_recoil_tween: Tween
var gun_base_scale_abs := Vector2.ONE
var configured_gun_position := DEFAULT_GUN_POSITION
var configured_muzzle_position := DEFAULT_MUZZLE_POSITION
var gun_idle_region_rect := Rect2()
var gun_idle_texture: Texture2D
var gun_shot_region_frames: Array = []
var gun_shot_frame_duration_sec := DEFAULT_SHOT_FRAME_DURATION_SEC
var gun_shot_animation_tween: Tween
var gun_shot_animation_nonce := 0
var gun_reload_texture_frames: Array = []
var gun_reload_frame_duration_sec := DEFAULT_RELOAD_FRAME_DURATION_SEC
var gun_reload_animation_tween: Tween
var gun_reload_animation_nonce := 0
var visual_correction_offset := Vector2.ZERO

func _ready() -> void:
	_configure_floor_movement()
	target_position = global_position
	target_velocity = velocity
	target_aim_angle = 0.0
	target_health = health
	if visual_root != null:
		visual_root.position = Vector2.ZERO
	_normalize_gun_sprite_anchor()
	if gun != null:
		gun_base_scale_abs = Vector2(absf(gun.scale.x), absf(gun.scale.y))
	_apply_player_facing_from_angle(target_aim_angle)
	_apply_gun_horizontal_flip_from_angle(target_aim_angle)
	_update_health_label()
	_update_ammo_label()

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

func set_weapon_visual(visual_config: Dictionary) -> void:
	if gun == null or not (gun is Sprite2D):
		return
	var gun_sprite := gun as Sprite2D

	var texture_value = visual_config.get("texture", null)
	if texture_value is Texture2D:
		gun_sprite.texture = texture_value
	gun_idle_texture = gun_sprite.texture

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
	var shot_frames_value = visual_config.get("shot_region_frames", [])
	if shot_frames_value is Array:
		for frame_value in shot_frames_value:
			if frame_value is Rect2:
				var frame_rect: Rect2 = frame_value
				if frame_rect.size.x > 0.0 and frame_rect.size.y > 0.0:
					gun_shot_region_frames.append(frame_rect)
	if gun_shot_region_frames.is_empty() and gun_idle_region_rect.size.x > 0.0 and gun_idle_region_rect.size.y > 0.0:
		gun_shot_region_frames.append(gun_idle_region_rect)

	var shot_duration_value = visual_config.get("shot_frame_duration_sec", DEFAULT_SHOT_FRAME_DURATION_SEC)
	gun_shot_frame_duration_sec = maxf(MIN_SHOT_FRAME_DURATION_SEC, float(shot_duration_value))
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
	_reset_gun_reload_animation()

	gun_base_scale_abs = Vector2(absf(gun_sprite.scale.x), absf(gun_sprite.scale.y))
	_apply_gun_horizontal_flip_from_angle(target_aim_angle)

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
	_play_gun_reload_animation()
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
	_apply_weapon_mount_offsets_from_angle(angle)

func _apply_weapon_mount_offsets_from_angle(angle: float) -> void:
	var looking_left := cos(angle) < 0.0
	var gun_position := configured_gun_position
	var muzzle_position := configured_muzzle_position
	if looking_left:
		gun_position.y = -gun_position.y
	if gun != null:
		gun.position = gun_position
	if muzzle != null:
		muzzle.position = muzzle_position

func play_shot_recoil() -> void:
	if gun == null:
		return
	if shot_audio != null and shot_audio.stream != null:
		shot_audio.pitch_scale = randf_range(0.95, 1.08)
		shot_audio.stop()
		shot_audio.play()
	_play_gun_shot_animation()
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

func _play_gun_shot_animation() -> void:
	if gun == null or not (gun is Sprite2D):
		return
	var gun_sprite := gun as Sprite2D
	if not gun_sprite.region_enabled:
		return
	if gun_shot_region_frames.is_empty():
		return

	gun_shot_animation_nonce += 1
	var nonce := gun_shot_animation_nonce
	if gun_shot_animation_tween != null:
		gun_shot_animation_tween.kill()

	gun_shot_animation_tween = create_tween()
	for frame_value in gun_shot_region_frames:
		if not (frame_value is Rect2):
			continue
		var frame_rect: Rect2 = frame_value
		gun_shot_animation_tween.tween_callback(Callable(self, "_apply_gun_shot_frame").bind(nonce, frame_rect))
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
	_apply_gun_idle_frame()
	gun_reload_animation_tween = null

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
	if visual_root != null:
		_tick_visual_correction(delta)
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
