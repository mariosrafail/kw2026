extends "res://scripts/app/runtime/runtime_scene_logic.gd"

const GUN_BASE_POSITION := Vector2(6.0, 2.0)
const AK47_GUN_FALLBACK_REGION := Rect2(31, 12, 50, 12)
const GRENADE_GUN_FALLBACK_REGION := Rect2(0, 0, 96, 71)
const KAR_GUN_FALLBACK_REGION := Rect2(31, 12, 50, 12)
const SHOTGUN_GUN_FALLBACK_REGION := Rect2(0, 0, 42, 37)
const UZI_GUN_FALLBACK_REGION := Rect2(161, 85, 25, 21)
const AK47_MUZZLE_POSITION := Vector2(33.0, 2.5)
const GRENADE_MUZZLE_POSITION := Vector2(34.0, 0.0)
const KAR_MUZZLE_POSITION := Vector2(37.0, 2.0)
const SHOTGUN_MUZZLE_POSITION := Vector2(42.0, 2.0)
const UZI_MUZZLE_POSITION := Vector2(35.0, 2.5)
const AK47_RELOAD_STRIP := preload("res://assets/textures/guns/akReload.png")
const GRENADE_RELOAD_STRIP := preload("res://assets/textures/guns/grenadeReload.png")
const KAR_RELOAD_STRIP := preload("res://assets/textures/guns/karReload.png")
const SHOTGUN_RELOAD_STRIP := preload("res://assets/textures/guns/shotgunReload.png")
const UZI_RELOAD_STRIP := preload("res://assets/textures/guns/uziReload.png")
const AK47_RELOAD_FRAME_SIZE := Vector2i(89, 39)
const GRENADE_RELOAD_FRAME_SIZE := Vector2i(96, 71)
const KAR_RELOAD_FRAME_SIZE := Vector2i(123, 60)
const SHOTGUN_RELOAD_FRAME_SIZE := Vector2i(108, 37)
const UZI_RELOAD_FRAME_SIZE := Vector2i(64, 64)
const AK47_RELOAD_FRAME_COUNT := 15
const GRENADE_RELOAD_FRAME_COUNT := 18
const KAR_RELOAD_FRAME_COUNT := 16
const SHOTGUN_RELOAD_FRAME_COUNT := 7
const UZI_RELOAD_FRAME_COUNT := 13
const AK47_RELOAD_FRAME_DURATION_SEC := 1.0 / 15.0
const GRENADE_RELOAD_FRAME_DURATION_SEC := 1.5 / 18.0
const KAR_RELOAD_FRAME_DURATION_SEC := 1.4 / 15.0
const SHOTGUN_RELOAD_FRAME_DURATION_SEC := 1.2 / 7.0
const UZI_RELOAD_FRAME_DURATION_SEC := 1.0 / 13.0

var weapon_idle_texture_by_id: Dictionary = {}
var weapon_reload_frames_by_id: Dictionary = {}

func _weapon_profile_for_peer(peer_id: int) -> WeaponProfile:
	return _weapon_profile_for_id(_weapon_id_for_peer(peer_id))

func _weapon_profile_for_id(weapon_id: String) -> WeaponProfile:
	var normalized := _normalize_weapon_id(weapon_id)
	if weapon_profiles.has(normalized):
		return weapon_profiles[normalized] as WeaponProfile
	return weapon_profiles[WEAPON_ID_AK47] as WeaponProfile

func _weapon_visual_for_id(weapon_id: String) -> Dictionary:
	_ensure_weapon_visual_texture_cache()
	var normalized := _normalize_weapon_id(weapon_id)
	var idle_texture = weapon_idle_texture_by_id.get(WEAPON_ID_AK47, null)
	var reload_texture_frames = weapon_reload_frames_by_id.get(WEAPON_ID_AK47, [])
	var muzzle_position := AK47_MUZZLE_POSITION
	var reload_frame_duration_sec := AK47_RELOAD_FRAME_DURATION_SEC
	if normalized == WEAPON_ID_GRENADE:
		idle_texture = weapon_idle_texture_by_id.get(WEAPON_ID_GRENADE, idle_texture)
		reload_texture_frames = weapon_reload_frames_by_id.get(WEAPON_ID_GRENADE, reload_texture_frames)
		muzzle_position = GRENADE_MUZZLE_POSITION
		reload_frame_duration_sec = GRENADE_RELOAD_FRAME_DURATION_SEC
		var grenade_shot_texture_frames: Array = []
		for frame_index in range(mini(3, reload_texture_frames.size())):
			var frame_value = reload_texture_frames[frame_index]
			if frame_value is Texture2D:
				grenade_shot_texture_frames.append(frame_value)
		return {
			"weapon_id": normalized,
			"texture": idle_texture,
			"region_enabled": false,
			"gun_position": GUN_BASE_POSITION,
			"muzzle_position": muzzle_position,
			"shot_texture_frames": grenade_shot_texture_frames,
			"shot_frame_duration_sec": 0.03,
			"reload_texture_frames": reload_texture_frames,
			"reload_frame_duration_sec": reload_frame_duration_sec,
			"recoil_scale_x": 0.8,
			"recoil_scale_y": 1.28,
			"recoil_distance": 12.8,
			"recoil_out_time": 0.02,
			"recoil_back_time": 0.2,
			"recoil_rotation": 0.24,
			"material": null
		}
	elif normalized == WEAPON_ID_KAR:
		idle_texture = weapon_idle_texture_by_id.get(WEAPON_ID_KAR, idle_texture)
		var kar_all_frames = weapon_reload_frames_by_id.get(WEAPON_ID_KAR, reload_texture_frames)
		var kar_reload_texture_frames: Array = []
		for frame_index in range(1, kar_all_frames.size()):
			var frame_value = kar_all_frames[frame_index]
			if frame_value is Texture2D:
				kar_reload_texture_frames.append(frame_value)
		reload_texture_frames = kar_reload_texture_frames
		muzzle_position = KAR_MUZZLE_POSITION
		reload_frame_duration_sec = KAR_RELOAD_FRAME_DURATION_SEC
		return {
			"weapon_id": normalized,
			"texture": idle_texture,
			"region_enabled": false,
			"gun_position": GUN_BASE_POSITION,
			"muzzle_position": muzzle_position,
			"shot_texture_frames": [],
			"shot_frame_duration_sec": 0.03,
			"reload_texture_frames": reload_texture_frames,
			"reload_frame_duration_sec": reload_frame_duration_sec,
			"recoil_scale_x": 0.7,
			"recoil_scale_y": 1.34,
			"recoil_distance": 18.0,
			"recoil_out_time": 0.014,
			"recoil_back_time": 0.18,
			"recoil_rotation": -0.22,
			"material": null
		}
	elif normalized == WEAPON_ID_SHOTGUN:
		idle_texture = weapon_idle_texture_by_id.get(WEAPON_ID_SHOTGUN, idle_texture)
		reload_texture_frames = weapon_reload_frames_by_id.get(WEAPON_ID_SHOTGUN, reload_texture_frames)
		muzzle_position = SHOTGUN_MUZZLE_POSITION
		reload_frame_duration_sec = SHOTGUN_RELOAD_FRAME_DURATION_SEC
		var shot_texture_frames: Array = []
		for frame_index in range(mini(3, reload_texture_frames.size())):
			var frame_value = reload_texture_frames[frame_index]
			if frame_value is Texture2D:
				shot_texture_frames.append(frame_value)
		return {
			"weapon_id": normalized,
			"texture": idle_texture,
			"region_enabled": false,
			"gun_position": GUN_BASE_POSITION,
			"muzzle_position": muzzle_position,
			"shot_texture_frames": shot_texture_frames,
			"shot_frame_duration_sec": 0.024,
			"reload_texture_frames": reload_texture_frames,
			"reload_frame_duration_sec": reload_frame_duration_sec,
			"recoil_scale_x": 0.78,
			"recoil_scale_y": 1.3,
			"recoil_distance": 14.0,
			"recoil_out_time": 0.018,
			"recoil_back_time": 0.09,
			"recoil_rotation": -0.28,
			"material": null
		}
	elif normalized == WEAPON_ID_UZI:
		idle_texture = weapon_idle_texture_by_id.get(WEAPON_ID_UZI, idle_texture)
		reload_texture_frames = weapon_reload_frames_by_id.get(WEAPON_ID_UZI, reload_texture_frames)
		muzzle_position = UZI_MUZZLE_POSITION
		reload_frame_duration_sec = UZI_RELOAD_FRAME_DURATION_SEC
	return {
		"weapon_id": normalized,
		"texture": idle_texture,
		"region_enabled": false,
		"gun_position": GUN_BASE_POSITION,
		"muzzle_position": muzzle_position,
		"reload_texture_frames": reload_texture_frames,
		"reload_frame_duration_sec": reload_frame_duration_sec,
		"material": null
	}

func _weapon_skin_for_peer(peer_id: int, weapon_id: String) -> int:
	if multiplayer != null and multiplayer.multiplayer_peer != null and peer_id == multiplayer.get_unique_id():
		if lobby_service != null:
			return int(lobby_service.get_local_selected_weapon_skin(weapon_id, selected_weapon_skin))
		return selected_weapon_skin
	if peer_weapon_skin_indices_by_peer.has(peer_id):
		return int(peer_weapon_skin_indices_by_peer.get(peer_id, 0))
	if lobby_service != null:
		return int(lobby_service.get_peer_weapon_skin(peer_id, 0))
	return 0

func _weapon_visual_for_peer(peer_id: int, weapon_id: String = "") -> Dictionary:
	var resolved_weapon_id := _normalize_weapon_id(weapon_id if not weapon_id.strip_edges().is_empty() else _weapon_id_for_peer(peer_id))
	var visual := _weapon_visual_for_id(resolved_weapon_id)
	if weapon_ui == null or not weapon_ui.has_method("weapon_skin_material"):
		return visual
	var skin_index := _weapon_skin_for_peer(peer_id, resolved_weapon_id)
	visual["material"] = weapon_ui.call("weapon_skin_material", resolved_weapon_id, skin_index)
	return visual

func _ensure_weapon_visual_texture_cache() -> void:
	if not weapon_idle_texture_by_id.is_empty() and not weapon_reload_frames_by_id.is_empty():
		return
	var ak_frames := _slice_strip_frames(AK47_RELOAD_STRIP, AK47_RELOAD_FRAME_SIZE, AK47_RELOAD_FRAME_COUNT)
	var grenade_frames := _slice_strip_frames(GRENADE_RELOAD_STRIP, GRENADE_RELOAD_FRAME_SIZE, GRENADE_RELOAD_FRAME_COUNT)
	var kar_frames := _slice_strip_frames(KAR_RELOAD_STRIP, KAR_RELOAD_FRAME_SIZE, KAR_RELOAD_FRAME_COUNT)
	var shotgun_frames := _slice_strip_frames(SHOTGUN_RELOAD_STRIP, SHOTGUN_RELOAD_FRAME_SIZE, SHOTGUN_RELOAD_FRAME_COUNT)
	var uzi_frames := _slice_strip_frames(UZI_RELOAD_STRIP, UZI_RELOAD_FRAME_SIZE, UZI_RELOAD_FRAME_COUNT)
	weapon_reload_frames_by_id[WEAPON_ID_AK47] = ak_frames
	weapon_reload_frames_by_id[WEAPON_ID_GRENADE] = grenade_frames
	weapon_reload_frames_by_id[WEAPON_ID_KAR] = kar_frames
	weapon_reload_frames_by_id[WEAPON_ID_SHOTGUN] = shotgun_frames
	weapon_reload_frames_by_id[WEAPON_ID_UZI] = uzi_frames
	weapon_idle_texture_by_id[WEAPON_ID_AK47] = _first_texture_or_fallback(ak_frames, AK47_GUN_FALLBACK_REGION)
	weapon_idle_texture_by_id[WEAPON_ID_GRENADE] = _first_texture_or_fallback(grenade_frames, GRENADE_GUN_FALLBACK_REGION)
	weapon_idle_texture_by_id[WEAPON_ID_KAR] = _first_texture_or_fallback(kar_frames, KAR_GUN_FALLBACK_REGION)
	weapon_idle_texture_by_id[WEAPON_ID_SHOTGUN] = _first_texture_or_fallback(shotgun_frames, SHOTGUN_GUN_FALLBACK_REGION)
	weapon_idle_texture_by_id[WEAPON_ID_UZI] = _first_texture_or_fallback(uzi_frames, UZI_GUN_FALLBACK_REGION)

func _slice_strip_frames(strip_texture: Texture2D, frame_size: Vector2i, frame_count: int) -> Array:
	var frames: Array = []
	if strip_texture == null:
		return frames
	if frame_count <= 0 or frame_size.x <= 0 or frame_size.y <= 0:
		return frames
	var texture_size := strip_texture.get_size()
	if texture_size.y < frame_size.y:
		return frames
	var max_frames := mini(frame_count, int(texture_size.x / float(frame_size.x)))
	for frame_index in range(max_frames):
		var frame := AtlasTexture.new()
		frame.atlas = strip_texture
		frame.region = Rect2(float(frame_index * frame_size.x), 0.0, float(frame_size.x), float(frame_size.y))
		frames.append(frame)
	return frames

func _first_texture_or_fallback(frames: Array, fallback_region: Rect2) -> Texture2D:
	if frames.is_empty():
		return _atlas_texture_from_region(GUNS_SPRITESHEET, fallback_region)
	var first_frame = frames[0]
	if first_frame is Texture2D:
		return first_frame
	return _atlas_texture_from_region(GUNS_SPRITESHEET, fallback_region)

func _atlas_texture_from_region(atlas_source: Texture2D, region_rect: Rect2) -> Texture2D:
	if atlas_source == null:
		return null
	if region_rect.size.x <= 0.0 or region_rect.size.y <= 0.0:
		return atlas_source
	var texture := AtlasTexture.new()
	texture.atlas = atlas_source
	texture.region = region_rect
	return texture

func _weapon_id_for_peer(peer_id: int) -> String:
	if peer_weapon_ids.has(peer_id):
		return _normalize_weapon_id(str(peer_weapon_ids[peer_id]))
	if lobby_service != null:
		var persisted_weapon := lobby_service.get_peer_weapon(peer_id, "")
		if not persisted_weapon.strip_edges().is_empty():
			return _normalize_weapon_id(persisted_weapon)
	if multiplayer != null and multiplayer.multiplayer_peer != null and peer_id == multiplayer.get_unique_id():
		return _normalize_weapon_id(selected_weapon_id)
	return WEAPON_ID_AK47

func _restore_peer_weapon_from_lobby_service(peer_id: int) -> void:
	if peer_weapon_ids.has(peer_id):
		return
	if lobby_service == null:
		return
	var persisted_weapon := lobby_service.get_peer_weapon(peer_id, "")
	if persisted_weapon.strip_edges().is_empty():
		return
	peer_weapon_ids[peer_id] = _normalize_weapon_id(persisted_weapon)

func _weapon_shot_sfx(weapon_id: String) -> AudioStream:
	var normalized := _normalize_weapon_id(weapon_id)
	if weapon_shot_sfx_by_id.has(normalized):
		return weapon_shot_sfx_by_id[normalized] as AudioStream
	return weapon_shot_sfx_by_id[WEAPON_ID_AK47] as AudioStream

func _weapon_reload_sfx(weapon_id: String) -> AudioStream:
	var normalized := _normalize_weapon_id(weapon_id)
	if weapon_reload_sfx_by_id.has(normalized):
		return weapon_reload_sfx_by_id[normalized] as AudioStream
	return weapon_reload_sfx_by_id[WEAPON_ID_AK47] as AudioStream

func _weapon_impact_sfx(weapon_id: String) -> AudioStream:
	var normalized := _normalize_weapon_id(weapon_id)
	if weapon_impact_sfx_by_id.has(normalized):
		return weapon_impact_sfx_by_id[normalized] as AudioStream
	return BULLET_TOUCH_SFX

func _normalize_weapon_id(weapon_id: String) -> String:
	var normalized := weapon_id.strip_edges().to_lower()
	if normalized == WEAPON_ID_GRENADE:
		return WEAPON_ID_GRENADE
	if normalized == WEAPON_ID_KAR:
		return WEAPON_ID_KAR
	if normalized == WEAPON_ID_SHOTGUN:
		return WEAPON_ID_SHOTGUN
	if normalized == WEAPON_ID_UZI:
		return WEAPON_ID_UZI
	return WEAPON_ID_AK47
