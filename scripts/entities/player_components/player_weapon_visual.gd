extends RefCounted

class_name PlayerWeaponVisual

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
const GUN_Z_INDEX := 4
const GUN_RELOAD_SCALE_MULTIPLIER := 1.12
const GUN_RELOAD_SCALE_UP_TIME := 0.08
const GUN_RELOAD_SCALE_DOWN_TIME := 0.1
const GUN_RELOAD_SPIN_RADIANS := TAU
const GUN_RELOAD_SPIN_UP_TIME := 0.08

var _player: Node2D
var _gun_pivot: Node2D
var _gun: Node2D
var _muzzle: Marker2D
var _shot_audio: AudioStreamPlayer2D
var _reload_audio: AudioStreamPlayer2D
var _sfx_suppressed_cb: Callable = Callable()
var _shot_jolt_cb: Callable = Callable()

var _gun_recoil_tween: Tween
var _gun_reload_scale_tween: Tween
var _gun_reload_rotation_tween: Tween
var _gun_base_scale_abs := Vector2.ONE
var _gun_reload_scale_multiplier := 1.0
var _gun_recoil_scale_x := GUN_RECOIL_SCALE_X
var _gun_recoil_scale_y := GUN_RECOIL_SCALE_Y
var _gun_recoil_distance := GUN_RECOIL_DISTANCE
var _gun_recoil_out_time := GUN_RECOIL_OUT_TIME
var _gun_recoil_back_time := GUN_RECOIL_BACK_TIME
var _gun_recoil_rotation := GUN_RECOIL_ROTATION
var _configured_gun_position := DEFAULT_GUN_POSITION
var _configured_muzzle_position := DEFAULT_MUZZLE_POSITION
var _current_weapon_visual_id := ""

var _gun_idle_region_rect := Rect2()
var _gun_idle_texture: Texture2D
var _gun_shot_region_frames: Array = []
var _gun_shot_texture_frames: Array = []
var _gun_shot_frame_duration_sec := DEFAULT_SHOT_FRAME_DURATION_SEC
var _gun_shot_animation_tween: Tween
var _gun_shot_animation_nonce := 0
var _gun_reload_texture_frames: Array = []
var _gun_reload_frame_duration_sec := DEFAULT_RELOAD_FRAME_DURATION_SEC
var _gun_reload_animation_tween: Tween
var _gun_reload_animation_nonce := 0

func configure(
	player: Node2D,
	gun_pivot: Node2D,
	gun: Node2D,
	muzzle: Marker2D,
	shot_audio: AudioStreamPlayer2D,
	reload_audio: AudioStreamPlayer2D,
	sfx_suppressed_cb: Callable = Callable(),
	shot_jolt_cb: Callable = Callable()
) -> void:
	_player = player
	_gun_pivot = gun_pivot
	_gun = gun
	_muzzle = muzzle
	_shot_audio = shot_audio
	_reload_audio = reload_audio
	_sfx_suppressed_cb = sfx_suppressed_cb
	_shot_jolt_cb = shot_jolt_cb
	_normalize_gun_sprite_anchor()
	_apply_gun_render_order()
	if _gun != null:
		_gun_base_scale_abs = Vector2(absf(_gun.scale.x), absf(_gun.scale.y))

func set_shot_audio_stream(stream: AudioStream) -> void:
	if _shot_audio == null:
		return
	_shot_audio.stream = stream

func set_reload_audio_stream(stream: AudioStream) -> void:
	if _reload_audio == null:
		return
	_reload_audio.stream = stream

func set_weapon_visual(visual_config: Dictionary, aim_angle: float) -> void:
	if _gun == null or not (_gun is Sprite2D):
		return
	var visual_weapon_id := str(visual_config.get("weapon_id", "")).strip_edges().to_lower()
	var is_same_weapon_visual := not visual_weapon_id.is_empty() and visual_weapon_id == _current_weapon_visual_id
	_reset_gun_scale(aim_angle)
	var gun_sprite := _gun as Sprite2D

	var texture_value = visual_config.get("texture", null)
	if texture_value is Texture2D:
		gun_sprite.texture = texture_value
	_gun_idle_texture = gun_sprite.texture

	var material_value = visual_config.get("material", null)
	gun_sprite.material = material_value as Material if material_value is Material else null

	var region_enabled := bool(visual_config.get("region_enabled", true))
	gun_sprite.region_enabled = region_enabled
	if region_enabled:
		var region_rect_value = visual_config.get("region_rect", gun_sprite.region_rect)
		if region_rect_value is Rect2:
			gun_sprite.region_rect = region_rect_value
		_gun_idle_region_rect = gun_sprite.region_rect
	else:
		_gun_idle_region_rect = Rect2()

	var target_gun_position := DEFAULT_GUN_POSITION
	var gun_position_value = visual_config.get("gun_position", target_gun_position)
	if gun_position_value is Vector2:
		target_gun_position = gun_position_value
	_configured_gun_position = target_gun_position
	gun_sprite.centered = true

	if _muzzle != null:
		var target_muzzle_position := DEFAULT_MUZZLE_POSITION
		var muzzle_position_value = visual_config.get("muzzle_position", target_muzzle_position)
		if muzzle_position_value is Vector2:
			target_muzzle_position = muzzle_position_value
		_configured_muzzle_position = target_muzzle_position

	_gun_shot_region_frames.clear()
	_gun_shot_texture_frames.clear()
	var shot_frames_value = visual_config.get("shot_region_frames", [])
	if shot_frames_value is Array:
		for frame_value in shot_frames_value:
			if frame_value is Rect2:
				var frame_rect: Rect2 = frame_value
				if frame_rect.size.x > 0.0 and frame_rect.size.y > 0.0:
					_gun_shot_region_frames.append(frame_rect)
	var shot_texture_frames_value = visual_config.get("shot_texture_frames", [])
	if shot_texture_frames_value is Array:
		for frame_value in shot_texture_frames_value:
			if frame_value is Texture2D:
				_gun_shot_texture_frames.append(frame_value)
	if _gun_shot_region_frames.is_empty() and _gun_idle_region_rect.size.x > 0.0 and _gun_idle_region_rect.size.y > 0.0:
		_gun_shot_region_frames.append(_gun_idle_region_rect)
	if _gun_shot_texture_frames.is_empty() and _gun_idle_texture != null:
		_gun_shot_texture_frames.append(_gun_idle_texture)

	var shot_duration_value = visual_config.get("shot_frame_duration_sec", DEFAULT_SHOT_FRAME_DURATION_SEC)
	_gun_shot_frame_duration_sec = maxf(MIN_SHOT_FRAME_DURATION_SEC, float(shot_duration_value))
	if not is_same_weapon_visual:
		_reset_gun_shot_animation()

	_gun_reload_texture_frames.clear()
	var reload_frames_value = visual_config.get("reload_texture_frames", [])
	if reload_frames_value is Array:
		for frame_value in reload_frames_value:
			if frame_value is Texture2D:
				_gun_reload_texture_frames.append(frame_value)
	if _gun_reload_texture_frames.is_empty() and _gun_idle_texture != null:
		_gun_reload_texture_frames.append(_gun_idle_texture)

	var reload_duration_value = visual_config.get("reload_frame_duration_sec", DEFAULT_RELOAD_FRAME_DURATION_SEC)
	_gun_reload_frame_duration_sec = maxf(MIN_SHOT_FRAME_DURATION_SEC, float(reload_duration_value))
	if not is_same_weapon_visual:
		_reset_gun_reload_animation()

	_gun_recoil_scale_x = float(visual_config.get("recoil_scale_x", GUN_RECOIL_SCALE_X))
	_gun_recoil_scale_y = float(visual_config.get("recoil_scale_y", GUN_RECOIL_SCALE_Y))
	_gun_recoil_distance = float(visual_config.get("recoil_distance", GUN_RECOIL_DISTANCE))
	_gun_recoil_out_time = maxf(0.01, float(visual_config.get("recoil_out_time", GUN_RECOIL_OUT_TIME)))
	_gun_recoil_back_time = maxf(0.01, float(visual_config.get("recoil_back_time", GUN_RECOIL_BACK_TIME)))
	_gun_recoil_rotation = float(visual_config.get("recoil_rotation", GUN_RECOIL_ROTATION))

	_gun_base_scale_abs = Vector2(absf(gun_sprite.scale.x), absf(gun_sprite.scale.y))
	if not visual_weapon_id.is_empty():
		_current_weapon_visual_id = visual_weapon_id
	_apply_gun_horizontal_flip_from_angle(aim_angle)

func get_current_weapon_visual_id() -> String:
	return _current_weapon_visual_id

func reset_after_respawn(aim_angle: float) -> void:
	_reset_gun_scale(aim_angle)
	_reset_gun_shot_animation()
	_reset_gun_reload_animation()

func set_aim_angle(angle: float, use_network_smoothing: bool) -> void:
	if not use_network_smoothing and _gun_pivot != null:
		_gun_pivot.rotation = angle + GUN_VISUAL_ANGLE_OFFSET
	_apply_gun_horizontal_flip_from_angle(angle)

func tick_aim_smoothing(delta: float, aim_angle: float, aim_lerp_speed: float) -> void:
	if _gun_pivot == null:
		return
	_gun_pivot.rotation = lerp_angle(_gun_pivot.rotation, aim_angle + GUN_VISUAL_ANGLE_OFFSET, min(1.0, delta * aim_lerp_speed))

func get_muzzle_world_position(player_position: Vector2, aim_angle: float) -> Vector2:
	var fallback_distance := MUZZLE_FALLBACK_DISTANCE
	if _gun != null and _gun is Sprite2D:
		var gun_sprite := _gun as Sprite2D
		if gun_sprite.region_enabled and gun_sprite.region_rect.size.x > 0.0:
			fallback_distance = maxf(fallback_distance, gun_sprite.region_rect.size.x * 0.5 + 2.0)
		elif gun_sprite.texture != null:
			fallback_distance = maxf(fallback_distance, gun_sprite.texture.get_size().x * 0.5 + 2.0)

	var fallback_position := player_position + Vector2.RIGHT.rotated(aim_angle) * fallback_distance
	if _muzzle == null:
		return fallback_position
	return _muzzle.global_position

func play_shot_recoil(aim_angle: float) -> void:
	if _gun == null:
		return
	if _gun_reload_scale_tween != null:
		_gun_reload_scale_tween.kill()
		_gun_reload_scale_tween = null
		_gun_reload_scale_multiplier = 1.0
	if _gun_reload_rotation_tween != null:
		_gun_reload_rotation_tween.kill()
		_gun_reload_rotation_tween = null
		_gun.rotation = 0.0
	_apply_gun_horizontal_flip_from_angle(aim_angle)
	if _shot_jolt_cb.is_valid():
		_shot_jolt_cb.call(aim_angle)
	if not _is_sfx_suppressed() and _shot_audio != null and _shot_audio.stream != null:
		_shot_audio.pitch_scale = randf_range(0.95, 1.08)
		_shot_audio.stop()
		_shot_audio.play()
	_play_gun_shot_animation()
	if _gun_recoil_tween != null:
		_gun_recoil_tween.kill()

	var sign_x := 1.0
	var sign_y := -1.0 if _gun.scale.y < 0.0 else 1.0
	var base_scale := _get_current_base_scale_abs()
	var recoil_scale := Vector2(base_scale.x * _gun_recoil_scale_x, base_scale.y * _gun_recoil_scale_y)
	var base_position := _gun.position
	var recoil_offset := Vector2.LEFT.rotated(aim_angle) * _gun_recoil_distance
	var recoil_position := base_position + recoil_offset
	var recoil_rotation := _gun_recoil_rotation if _gun.scale.y >= 0.0 else -_gun_recoil_rotation

	_gun_recoil_tween = _player.create_tween()
	_gun_recoil_tween.parallel().tween_property(_gun, "position", recoil_position, _gun_recoil_out_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_gun_recoil_tween.tween_property(_gun, "scale", Vector2(sign_x * recoil_scale.x, sign_y * recoil_scale.y), _gun_recoil_out_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_gun_recoil_tween.parallel().tween_property(_gun, "rotation", recoil_rotation, _gun_recoil_out_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_gun_recoil_tween.parallel().tween_property(_gun, "position", base_position, _gun_recoil_back_time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_gun_recoil_tween.tween_property(_gun, "scale", Vector2(sign_x * base_scale.x, sign_y * base_scale.y), _gun_recoil_back_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_gun_recoil_tween.parallel().tween_property(_gun, "rotation", 0.0, _gun_recoil_back_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func play_reload_audio() -> void:
	_start_gun_reload_scale_animation()
	_start_gun_reload_rotation_animation()
	_play_gun_reload_animation()
	if _is_sfx_suppressed() or _reload_audio == null or _reload_audio.stream == null:
		return
	_reload_audio.pitch_scale = randf_range(0.98, 1.03)
	_reload_audio.stop()
	_reload_audio.play()

func apply_horizontal_flip_from_angle(angle: float) -> void:
	_apply_gun_horizontal_flip_from_angle(angle)

func _normalize_gun_sprite_anchor() -> void:
	if _gun == null or not (_gun is Sprite2D):
		return
	var gun_sprite := _gun as Sprite2D
	if gun_sprite.centered:
		return

	var draw_size := Vector2.ZERO
	if gun_sprite.region_enabled and gun_sprite.region_rect.size.x > 0.0 and gun_sprite.region_rect.size.y > 0.0:
		draw_size = gun_sprite.region_rect.size
	elif gun_sprite.texture != null:
		draw_size = gun_sprite.texture.get_size()
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return

	gun_sprite.position += draw_size * 0.5
	gun_sprite.position.y += GUN_CENTERING_Y_TWEAK
	gun_sprite.centered = true

func _apply_gun_render_order() -> void:
	if _gun != null and _gun is CanvasItem:
		(_gun as CanvasItem).z_index = GUN_Z_INDEX

func _apply_gun_horizontal_flip_from_angle(angle: float) -> void:
	if _gun == null:
		return
	var looking_left := cos(angle) < 0.0
	var base_scale := _get_current_base_scale_abs()
	_gun.scale = Vector2(absf(base_scale.x), -absf(base_scale.y) if looking_left else absf(base_scale.y))
	_apply_weapon_mount_offsets_from_angle(angle)

func _apply_weapon_mount_offsets_from_angle(angle: float) -> void:
	var looking_left := cos(angle) < 0.0
	var gun_position := _configured_gun_position
	var muzzle_position := _configured_muzzle_position
	if looking_left:
		gun_position.y = -gun_position.y
		muzzle_position.y = -muzzle_position.y
	if _gun != null:
		_gun.position = gun_position
	if _muzzle != null:
		_muzzle.position = muzzle_position

func _reset_gun_scale(aim_angle: float) -> void:
	if _gun_recoil_tween != null:
		_gun_recoil_tween.kill()
		_gun_recoil_tween = null
	if _gun_reload_scale_tween != null:
		_gun_reload_scale_tween.kill()
		_gun_reload_scale_tween = null
	if _gun_reload_rotation_tween != null:
		_gun_reload_rotation_tween.kill()
		_gun_reload_rotation_tween = null
	_gun_reload_scale_multiplier = 1.0
	if _gun != null:
		_gun.rotation = 0.0
	_apply_gun_horizontal_flip_from_angle(aim_angle)

func _play_gun_shot_animation() -> void:
	if _gun == null or not (_gun is Sprite2D):
		return
	var gun_sprite := _gun as Sprite2D
	var use_region_frames := gun_sprite.region_enabled and not _gun_shot_region_frames.is_empty()
	var use_texture_frames := not gun_sprite.region_enabled and not _gun_shot_texture_frames.is_empty()
	if not use_region_frames and not use_texture_frames:
		return

	_gun_shot_animation_nonce += 1
	var nonce := _gun_shot_animation_nonce
	if _gun_shot_animation_tween != null:
		_gun_shot_animation_tween.kill()

	_gun_shot_animation_tween = _player.create_tween()
	if use_region_frames:
		for frame_value in _gun_shot_region_frames:
			if not (frame_value is Rect2):
				continue
			var frame_rect: Rect2 = frame_value
			_gun_shot_animation_tween.tween_callback(Callable(self, "_apply_gun_shot_frame").bind(nonce, frame_rect))
			_gun_shot_animation_tween.tween_interval(_gun_shot_frame_duration_sec)
	else:
		for frame_value in _gun_shot_texture_frames:
			if not (frame_value is Texture2D):
				continue
			var frame_texture := frame_value as Texture2D
			_gun_shot_animation_tween.tween_callback(Callable(self, "_apply_gun_shot_texture_frame").bind(nonce, frame_texture))
			_gun_shot_animation_tween.tween_interval(_gun_shot_frame_duration_sec)
	_gun_shot_animation_tween.tween_callback(Callable(self, "_finish_gun_shot_animation").bind(nonce))

func _reset_gun_shot_animation() -> void:
	_gun_shot_animation_nonce += 1
	if _gun_shot_animation_tween != null:
		_gun_shot_animation_tween.kill()
		_gun_shot_animation_tween = null
	_apply_gun_idle_frame()

func _apply_gun_idle_frame() -> void:
	if _gun == null or not (_gun is Sprite2D):
		return
	var gun_sprite := _gun as Sprite2D
	if gun_sprite.region_enabled:
		if _gun_idle_region_rect.size.x <= 0.0 or _gun_idle_region_rect.size.y <= 0.0:
			return
		gun_sprite.region_rect = _gun_idle_region_rect
		return
	if _gun_idle_texture == null:
		return
	gun_sprite.texture = _gun_idle_texture

func _apply_gun_shot_frame(nonce: int, frame_rect: Rect2) -> void:
	if nonce != _gun_shot_animation_nonce:
		return
	if _gun == null or not (_gun is Sprite2D):
		return
	var gun_sprite := _gun as Sprite2D
	if not gun_sprite.region_enabled:
		return
	gun_sprite.region_rect = frame_rect

func _apply_gun_shot_texture_frame(nonce: int, frame_texture: Texture2D) -> void:
	if nonce != _gun_shot_animation_nonce:
		return
	if _gun == null or not (_gun is Sprite2D):
		return
	var gun_sprite := _gun as Sprite2D
	if gun_sprite.region_enabled:
		return
	gun_sprite.texture = frame_texture

func _finish_gun_shot_animation(nonce: int) -> void:
	if nonce != _gun_shot_animation_nonce:
		return
	_apply_gun_idle_frame()
	_gun_shot_animation_tween = null

func _play_gun_reload_animation() -> void:
	if _gun == null or not (_gun is Sprite2D):
		return
	if _gun_reload_texture_frames.is_empty():
		return

	_gun_reload_animation_nonce += 1
	var nonce := _gun_reload_animation_nonce
	if _gun_reload_animation_tween != null:
		_gun_reload_animation_tween.kill()

	_gun_reload_animation_tween = _player.create_tween()
	for frame_value in _gun_reload_texture_frames:
		if not (frame_value is Texture2D):
			continue
		var frame_texture: Texture2D = frame_value
		_gun_reload_animation_tween.tween_callback(Callable(self, "_apply_gun_reload_frame").bind(nonce, frame_texture))
		_gun_reload_animation_tween.tween_interval(_gun_reload_frame_duration_sec)
	_gun_reload_animation_tween.tween_callback(Callable(self, "_finish_gun_reload_animation").bind(nonce))

func _reset_gun_reload_animation() -> void:
	_gun_reload_animation_nonce += 1
	if _gun_reload_animation_tween != null:
		_gun_reload_animation_tween.kill()
		_gun_reload_animation_tween = null
	_reset_gun_reload_scale_animation()
	_reset_gun_reload_rotation_animation(true)
	_apply_gun_idle_frame()

func _apply_gun_reload_frame(nonce: int, frame_texture: Texture2D) -> void:
	if nonce != _gun_reload_animation_nonce:
		return
	if _gun == null or not (_gun is Sprite2D):
		return
	var gun_sprite := _gun as Sprite2D
	gun_sprite.region_enabled = false
	gun_sprite.texture = frame_texture

func _finish_gun_reload_animation(nonce: int) -> void:
	if nonce != _gun_reload_animation_nonce:
		return
	_reset_gun_reload_scale_animation()
	_reset_gun_reload_rotation_animation(true)
	_apply_gun_idle_frame()
	_gun_reload_animation_tween = null

func _get_current_base_scale_abs() -> Vector2:
	return _gun_base_scale_abs * _gun_reload_scale_multiplier

func _start_gun_reload_scale_animation() -> void:
	if _gun == null:
		return
	if _gun_reload_scale_tween != null:
		_gun_reload_scale_tween.kill()
	var sign_y := -1.0 if _gun.scale.y < 0.0 else 1.0
	var target_scale := Vector2(_gun_base_scale_abs.x * GUN_RELOAD_SCALE_MULTIPLIER, _gun_base_scale_abs.y * GUN_RELOAD_SCALE_MULTIPLIER)
	_gun_reload_scale_tween = _player.create_tween()
	_gun_reload_scale_tween.tween_property(_gun, "scale", Vector2(target_scale.x, sign_y * target_scale.y), GUN_RELOAD_SCALE_UP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_gun_reload_scale_multiplier = GUN_RELOAD_SCALE_MULTIPLIER

func _reset_gun_reload_scale_animation() -> void:
	if _gun == null:
		_gun_reload_scale_multiplier = 1.0
		return
	if is_equal_approx(_gun_reload_scale_multiplier, 1.0) and _gun_reload_scale_tween == null:
		return
	if _gun_reload_scale_tween != null:
		_gun_reload_scale_tween.kill()
	var sign_y := -1.0 if _gun.scale.y < 0.0 else 1.0
	_gun_reload_scale_tween = _player.create_tween()
	_gun_reload_scale_tween.tween_property(_gun, "scale", Vector2(_gun_base_scale_abs.x, sign_y * _gun_base_scale_abs.y), GUN_RELOAD_SCALE_DOWN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_gun_reload_scale_tween.finished.connect(Callable(self, "_clear_gun_reload_scale_tween"), CONNECT_ONE_SHOT)
	_gun_reload_scale_multiplier = 1.0

func _clear_gun_reload_scale_tween() -> void:
	_gun_reload_scale_tween = null

func _start_gun_reload_rotation_animation() -> void:
	if _gun == null:
		return
	if _gun_reload_rotation_tween != null:
		_gun_reload_rotation_tween.kill()
	_gun.rotation = 0.0
	var total_duration := maxf(GUN_RELOAD_SPIN_UP_TIME, float(_gun_reload_texture_frames.size()) * _gun_reload_frame_duration_sec)
	_gun_reload_rotation_tween = _player.create_tween()
	_gun_reload_rotation_tween.tween_property(_gun, "rotation", GUN_RELOAD_SPIN_RADIANS, total_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _reset_gun_reload_rotation_animation(immediate: bool = false) -> void:
	if _gun == null:
		return
	if _gun_reload_rotation_tween != null:
		_gun_reload_rotation_tween.kill()
	_gun_reload_rotation_tween = null
	if immediate or absf(_gun.rotation) >= PI:
		_gun.rotation = 0.0
		return
	_gun.rotation = 0.0

func _is_sfx_suppressed() -> bool:
	return _sfx_suppressed_cb.is_valid() and bool(_sfx_suppressed_cb.call())
