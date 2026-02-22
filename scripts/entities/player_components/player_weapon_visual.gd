extends RefCounted

class_name PlayerWeaponVisual

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
const MIN_FRAME_DURATION_SEC := 0.01

var _player: Node2D
var _gun_pivot: Node2D
var _gun: Node2D
var _muzzle: Marker2D
var _shot_audio: AudioStreamPlayer2D
var _reload_audio: AudioStreamPlayer2D

var _gun_recoil_tween: Tween
var _gun_base_scale_abs := Vector2.ONE
var _configured_gun_position := DEFAULT_GUN_POSITION
var _configured_muzzle_position := DEFAULT_MUZZLE_POSITION

var _gun_idle_region_rect := Rect2()
var _gun_idle_texture: Texture2D

var _gun_shot_region_frames: Array = []
var _gun_shot_frame_duration_sec := DEFAULT_SHOT_FRAME_DURATION_SEC
var _gun_shot_animation_tween: Tween
var _gun_shot_animation_nonce := 0

var _gun_reload_texture_frames: Array = []
var _gun_reload_frame_duration_sec := DEFAULT_RELOAD_FRAME_DURATION_SEC
var _gun_reload_animation_tween: Tween
var _gun_reload_animation_nonce := 0

func configure(player: Node2D, gun_pivot: Node2D, gun: Node2D, muzzle: Marker2D, shot_audio: AudioStreamPlayer2D, reload_audio: AudioStreamPlayer2D) -> void:
	_player = player
	_gun_pivot = gun_pivot
	_gun = gun
	_muzzle = muzzle
	_shot_audio = shot_audio
	_reload_audio = reload_audio
	_normalize_gun_sprite_anchor()
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
	var gun_sprite := _gun as Sprite2D

	var texture_value = visual_config.get("texture", null)
	if texture_value is Texture2D:
		gun_sprite.texture = texture_value
	_gun_idle_texture = gun_sprite.texture

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
	var shot_frames_value = visual_config.get("shot_region_frames", [])
	if shot_frames_value is Array:
		for frame_value in shot_frames_value:
			if frame_value is Rect2:
				var frame_rect: Rect2 = frame_value
				if frame_rect.size.x > 0.0 and frame_rect.size.y > 0.0:
					_gun_shot_region_frames.append(frame_rect)
	if _gun_shot_region_frames.is_empty() and _gun_idle_region_rect.size.x > 0.0 and _gun_idle_region_rect.size.y > 0.0:
		_gun_shot_region_frames.append(_gun_idle_region_rect)

	var shot_duration_value = visual_config.get("shot_frame_duration_sec", DEFAULT_SHOT_FRAME_DURATION_SEC)
	_gun_shot_frame_duration_sec = maxf(MIN_FRAME_DURATION_SEC, float(shot_duration_value))
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
	_gun_reload_frame_duration_sec = maxf(MIN_FRAME_DURATION_SEC, float(reload_duration_value))
	_reset_gun_reload_animation()

	_gun_base_scale_abs = Vector2(absf(gun_sprite.scale.x), absf(gun_sprite.scale.y))
	_apply_gun_horizontal_flip_from_angle(aim_angle)

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
	if _shot_audio != null and _shot_audio.stream != null:
		_shot_audio.pitch_scale = randf_range(0.95, 1.08)
		_shot_audio.stop()
		_shot_audio.play()
	_play_gun_shot_animation()
	if _gun_recoil_tween != null:
		_gun_recoil_tween.kill()

	var sign_x := 1.0
	var sign_y := -1.0 if _gun.scale.y < 0.0 else 1.0
	var base_scale := _gun_base_scale_abs
	var recoil_scale := Vector2(base_scale.x, base_scale.y * GUN_RECOIL_SCALE_Y)

	_gun_recoil_tween = _player.create_tween()
	_gun_recoil_tween.tween_property(_gun, "scale", Vector2(sign_x * recoil_scale.x, sign_y * recoil_scale.y), GUN_RECOIL_OUT_TIME)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_gun_recoil_tween.tween_property(_gun, "scale", Vector2(sign_x * base_scale.x, sign_y * base_scale.y), GUN_RECOIL_BACK_TIME)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_apply_gun_horizontal_flip_from_angle(aim_angle)

func play_reload_audio() -> void:
	_play_gun_reload_animation()
	if _reload_audio == null or _reload_audio.stream == null:
		return
	_reload_audio.pitch_scale = randf_range(0.98, 1.03)
	_reload_audio.stop()
	_reload_audio.play()

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

func _apply_gun_horizontal_flip_from_angle(angle: float) -> void:
	if _gun == null:
		return
	var looking_left := cos(angle) < 0.0
	_gun.scale = Vector2(
		absf(_gun_base_scale_abs.x),
		-absf(_gun_base_scale_abs.y) if looking_left else absf(_gun_base_scale_abs.y)
	)
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
	_apply_gun_horizontal_flip_from_angle(aim_angle)

func _play_gun_shot_animation() -> void:
	if _gun == null or not (_gun is Sprite2D):
		return
	var gun_sprite := _gun as Sprite2D
	if not gun_sprite.region_enabled:
		return
	if _gun_shot_region_frames.is_empty():
		return

	_gun_shot_animation_nonce += 1
	var nonce := _gun_shot_animation_nonce
	if _gun_shot_animation_tween != null:
		_gun_shot_animation_tween.kill()

	_gun_shot_animation_tween = _player.create_tween()
	for frame_value in _gun_shot_region_frames:
		if not (frame_value is Rect2):
			continue
		var frame_rect: Rect2 = frame_value
		_gun_shot_animation_tween.tween_callback(Callable(self, "_apply_gun_shot_frame").bind(nonce, frame_rect))
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
	_apply_gun_idle_frame()
	_gun_reload_animation_tween = null

