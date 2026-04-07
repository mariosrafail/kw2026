extends RefCounted

class_name PlayerWeaponFacade

var _player: Node2D
var _weapon_visual_component_cb: Callable = Callable()
var _motion_sync_component_cb: Callable = Callable()
var _local_peer_id_cb: Callable = Callable()
var _shot_feedback_cb: Callable = Callable()
var _apply_player_facing_cb: Callable = Callable()
var _apply_gun_horizontal_flip_cb: Callable = Callable()

func configure(
	player: Node2D,
	weapon_visual_component_cb: Callable,
	motion_sync_component_cb: Callable,
	local_peer_id_cb: Callable,
	shot_feedback_cb: Callable,
	apply_player_facing_cb: Callable,
	apply_gun_horizontal_flip_cb: Callable
) -> void:
	_player = player
	_weapon_visual_component_cb = weapon_visual_component_cb
	_motion_sync_component_cb = motion_sync_component_cb
	_local_peer_id_cb = local_peer_id_cb
	_shot_feedback_cb = shot_feedback_cb
	_apply_player_facing_cb = apply_player_facing_cb
	_apply_gun_horizontal_flip_cb = apply_gun_horizontal_flip_cb

func set_shot_audio_stream(stream: AudioStream, fallback_audio: AudioStreamPlayer2D = null) -> void:
	var weapon_visual_component: Variant = _weapon_visual_component()
	if weapon_visual_component != null:
		weapon_visual_component.set_shot_audio_stream(stream)
		return
	if fallback_audio == null:
		return
	fallback_audio.stream = stream

func set_reload_audio_stream(stream: AudioStream, fallback_audio: AudioStreamPlayer2D = null) -> void:
	var weapon_visual_component: Variant = _weapon_visual_component()
	if weapon_visual_component != null:
		weapon_visual_component.set_reload_audio_stream(stream)
		return
	if fallback_audio == null:
		return
	fallback_audio.stream = stream

func set_weapon_visual(visual_config: Dictionary, aim_angle: float) -> void:
	var weapon_visual_component: Variant = _weapon_visual_component()
	if weapon_visual_component != null:
		weapon_visual_component.set_weapon_visual(visual_config, aim_angle)

func get_current_weapon_visual_id() -> String:
	var weapon_visual_component: Variant = _weapon_visual_component()
	if weapon_visual_component != null:
		return str(weapon_visual_component.get_current_weapon_visual_id())
	return ""

func set_aim_world(target_world: Vector2) -> void:
	set_aim_angle((target_world - _player.global_position).angle(), bool(_player.use_network_smoothing))

func set_aim_angle(angle: float, use_network_smoothing: bool) -> void:
	var motion_sync_component: Variant = _motion_sync_component()
	if motion_sync_component != null:
		motion_sync_component.set_aim_angle(angle)
		return
	_player.target_aim_angle = angle
	var weapon_visual_component: Variant = _weapon_visual_component()
	if weapon_visual_component != null:
		weapon_visual_component.set_aim_angle(angle, use_network_smoothing)
	if _apply_player_facing_cb.is_valid():
		_apply_player_facing_cb.call(angle)
	if _apply_gun_horizontal_flip_cb.is_valid():
		_apply_gun_horizontal_flip_cb.call(angle)

func get_aim_angle(default_angle: float) -> float:
	var motion_sync_component: Variant = _motion_sync_component()
	if motion_sync_component != null:
		return float(motion_sync_component.get_aim_angle())
	return default_angle

func get_muzzle_world_position(global_position: Vector2, aim_angle: float) -> Vector2:
	var weapon_visual_component: Variant = _weapon_visual_component()
	if weapon_visual_component != null:
		return weapon_visual_component.get_muzzle_world_position(global_position, aim_angle)
	return global_position

func play_shot_recoil(peer_id: int, aim_angle: float) -> void:
	var weapon_visual_component: Variant = _weapon_visual_component()
	if weapon_visual_component != null:
		weapon_visual_component.play_shot_recoil(aim_angle)
		var local_peer_id := _local_peer_id()
		if peer_id > 0 and peer_id == local_peer_id and _shot_feedback_cb.is_valid():
			_shot_feedback_cb.call()

func apply_gun_horizontal_flip_from_angle(angle: float) -> void:
	var weapon_visual_component: Variant = _weapon_visual_component()
	if weapon_visual_component != null:
		weapon_visual_component.apply_horizontal_flip_from_angle(angle)

func _weapon_visual_component():
	if _weapon_visual_component_cb.is_valid():
		return _weapon_visual_component_cb.call()
	return null

func _motion_sync_component():
	if _motion_sync_component_cb.is_valid():
		return _motion_sync_component_cb.call()
	return null

func _local_peer_id() -> int:
	if _local_peer_id_cb.is_valid():
		return int(_local_peer_id_cb.call())
	return 0
