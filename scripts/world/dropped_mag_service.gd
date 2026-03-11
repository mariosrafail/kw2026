extends RefCounted
class_name DroppedMagService

const DROPPED_MAG_SCRIPT := preload("res://scripts/world/dropped_mag.gd")
const WEAPON_ID_AK47 := "ak47"
const WEAPON_ID_GRENADE := "grenade"
const AK47_MAG_TEXTURE := preload("res://assets/textures/guns/akMag.png")
const AK47_MAG_TEXTURE_PATH := "res://assets/textures/guns/akMag.png"
const AK47_MAG_SPAWN_OFFSET := Vector2(-10.0, 6.0)
const AK47_MAG_LAUNCH_LOCAL_MIN := Vector2(-126.0, -146.0)
const AK47_MAG_LAUNCH_LOCAL_MAX := Vector2(-92.0, -88.0)
const AK47_MAG_COLLISION_SIZE := Vector2(11.0, 5.0)
const GRENADE_MAG_TEXTURE := preload("res://assets/textures/guns/grenadeMag.png")
const GRENADE_MAG_TEXTURE_PATH := "res://assets/textures/guns/grenadeMag.png"
const GRENADE_MAG_SPAWN_OFFSET := Vector2(-32.0, 0.0)
const GRENADE_MAG_LAUNCH_LOCAL_MIN := Vector2(-118.0, -138.0)
const GRENADE_MAG_LAUNCH_LOCAL_MAX := Vector2(-86.0, -80.0)
const GRENADE_MAG_COLLISION_SIZE := Vector2(11.0, 5.0)
const DROPPED_MAG_SYNC_RATE := 18.0

var world_root: Node2D
var players: Dictionary = {}
var multiplayer: MultiplayerAPI

var normalize_weapon_id_cb: Callable = Callable()
var get_peer_lobby_cb: Callable = Callable()
var get_lobby_members_cb: Callable = Callable()
var resolve_mag_color_cb: Callable = Callable()
var send_spawn_dropped_mag_cb: Callable = Callable()
var send_sync_dropped_mag_cb: Callable = Callable()
var send_despawn_dropped_mag_cb: Callable = Callable()

var dropped_mags: Dictionary = {}
var pending_reload_mag_spawn_by_peer: Dictionary = {}
var next_dropped_mag_id := 1
var dropped_mag_sync_accumulator := 0.0
var ak47_mag_spawn_delay_sec := 0.16
var grenade_mag_spawn_delay_sec := 0.35

func configure(state_refs: Dictionary, callbacks: Dictionary, config: Dictionary = {}) -> void:
	world_root = state_refs.get("world_root", null) as Node2D
	players = state_refs.get("players", {}) as Dictionary
	multiplayer = state_refs.get("multiplayer", null) as MultiplayerAPI

	normalize_weapon_id_cb = callbacks.get("normalize_weapon_id", Callable()) as Callable
	get_peer_lobby_cb = callbacks.get("get_peer_lobby", Callable()) as Callable
	get_lobby_members_cb = callbacks.get("get_lobby_members", Callable()) as Callable
	resolve_mag_color_cb = callbacks.get("resolve_mag_color", Callable()) as Callable
	send_spawn_dropped_mag_cb = callbacks.get("send_spawn_dropped_mag", Callable()) as Callable
	send_sync_dropped_mag_cb = callbacks.get("send_sync_dropped_mag", Callable()) as Callable
	send_despawn_dropped_mag_cb = callbacks.get("send_despawn_dropped_mag", Callable()) as Callable

	ak47_mag_spawn_delay_sec = float(config.get("ak47_mag_spawn_delay_sec", ak47_mag_spawn_delay_sec))
	grenade_mag_spawn_delay_sec = float(config.get("grenade_mag_spawn_delay_sec", grenade_mag_spawn_delay_sec))

func reset() -> void:
	dropped_mag_sync_accumulator = 0.0
	next_dropped_mag_id = 1
	pending_reload_mag_spawn_by_peer.clear()
	_clear_dropped_mags()

func schedule_reload_mag_spawn(peer_id: int, weapon_id: String) -> void:
	var mag_profile := _mag_profile_for_weapon(weapon_id)
	if mag_profile.is_empty():
		return
	pending_reload_mag_spawn_by_peer[peer_id] = {
		"weapon_id": str(mag_profile.get("weapon_id", "")),
		"remaining": maxf(0.0, float(mag_profile.get("spawn_delay_sec", 0.0)))
	}

func clear_pending_reload_mag_spawn(peer_id: int) -> void:
	pending_reload_mag_spawn_by_peer.erase(peer_id)

func server_tick(delta: float) -> void:
	_tick_pending_reload_mag_spawns(delta)
	_tick_live_dropped_mags(delta)

func sync_all_to_peer(target_peer_id: int) -> void:
	if target_peer_id <= 0:
		return
	for mag_key in dropped_mags.keys():
		var mag_id := int(mag_key)
		var mag := dropped_mags.get(mag_id, null) as DroppedMag
		if mag == null or not is_instance_valid(mag):
			continue
		var texture_path := str(mag.get_meta("texture_path", AK47_MAG_TEXTURE_PATH))
		var tint := mag.get_meta("tint", Color.WHITE) as Color
		_send_spawn_dropped_mag(target_peer_id, mag_id, texture_path, tint, mag.global_position, mag.linear_velocity, mag.angular_velocity)

func client_spawn_rpc(mag_id: int, texture_path: String, tint: Color, spawn_position: Vector2, linear_velocity: Vector2, angular_velocity: float) -> void:
	_spawn_dropped_mag_local(
		mag_id,
		texture_path,
		_collision_size_for_texture_path(texture_path),
		tint,
		spawn_position,
		linear_velocity,
		angular_velocity,
		true
	)

func client_sync_rpc(mag_id: int, world_position: Vector2, world_rotation: float, linear_velocity: Vector2, angular_velocity: float) -> void:
	var mag := dropped_mags.get(mag_id, null) as DroppedMag
	if mag == null or not is_instance_valid(mag):
		mag = _spawn_dropped_mag_local(
			mag_id,
			AK47_MAG_TEXTURE_PATH,
			_collision_size_for_texture_path(AK47_MAG_TEXTURE_PATH),
			Color.WHITE,
			world_position,
			linear_velocity,
			angular_velocity,
			true
		)
	if mag == null:
		return
	mag.apply_network_state(world_position, world_rotation, linear_velocity, angular_velocity)

func client_despawn_rpc(mag_id: int) -> void:
	_despawn_dropped_mag_local(mag_id)

func _tick_pending_reload_mag_spawns(delta: float) -> void:
	if pending_reload_mag_spawn_by_peer.is_empty():
		return
	var peers_to_spawn: Array[int] = []
	for peer_value in pending_reload_mag_spawn_by_peer.keys():
		var peer_id := int(peer_value)
		var pending_entry := pending_reload_mag_spawn_by_peer.get(peer_id, {}) as Dictionary
		var remaining := float(pending_entry.get("remaining", -1.0))
		if remaining < 0.0:
			continue
		remaining = maxf(remaining - delta, 0.0)
		pending_entry["remaining"] = remaining
		pending_reload_mag_spawn_by_peer[peer_id] = pending_entry
		if remaining <= 0.0:
			peers_to_spawn.append(peer_id)
	for peer_id in peers_to_spawn:
		var pending_entry := pending_reload_mag_spawn_by_peer.get(peer_id, {}) as Dictionary
		var weapon_id := str(pending_entry.get("weapon_id", ""))
		clear_pending_reload_mag_spawn(peer_id)
		_spawn_scheduled_reload_mag(peer_id, weapon_id)

func _spawn_scheduled_reload_mag(peer_id: int, weapon_id: String) -> void:
	var player := players.get(peer_id, null) as NetPlayer
	if player == null:
		return
	var mag_profile := _mag_profile_for_weapon(weapon_id)
	if mag_profile.is_empty():
		return
	var lobby_id := _peer_lobby(peer_id)
	if lobby_id <= 0:
		return
	var mag_id := next_dropped_mag_id
	next_dropped_mag_id += 1
	var aim_angle := player.get_aim_angle()
	var facing := signf(cos(aim_angle))
	if is_zero_approx(facing):
		facing = 1.0
	var texture_path := str(mag_profile.get("texture_path", AK47_MAG_TEXTURE_PATH))
	var spawn_offset_base := mag_profile.get("spawn_offset", AK47_MAG_SPAWN_OFFSET) as Vector2
	var spawn_offset := _weapon_relative_vector(spawn_offset_base, aim_angle)
	var collision_size := mag_profile.get("collision_size", AK47_MAG_COLLISION_SIZE) as Vector2
	var tint := _resolve_mag_color(peer_id, weapon_id)
	var launch_local_min := mag_profile.get("launch_local_min", AK47_MAG_LAUNCH_LOCAL_MIN) as Vector2
	var launch_local_max := mag_profile.get("launch_local_max", AK47_MAG_LAUNCH_LOCAL_MAX) as Vector2
	var spawn_position := player.get_muzzle_world_position() + spawn_offset
	var launch_velocity := (player.velocity * 0.35) + _sample_weapon_relative_vector(launch_local_min, launch_local_max, aim_angle)
	var spin_velocity := randf_range(5.0, 9.0) * -facing
	var mag := _spawn_dropped_mag_local(mag_id, texture_path, collision_size, tint, spawn_position, launch_velocity, spin_velocity, false)
	if mag != null:
		mag.set_meta("lobby_id", lobby_id)
		mag.set_meta("texture_path", texture_path)
		mag.set_meta("tint", tint)
	for member_value in _lobby_members(lobby_id):
		var member_id := int(member_value)
		if member_id <= 0:
			continue
		_send_spawn_dropped_mag(member_id, mag_id, texture_path, tint, spawn_position, launch_velocity, spin_velocity)

func _tick_live_dropped_mags(delta: float) -> void:
	if dropped_mags.is_empty():
		return
	dropped_mag_sync_accumulator += delta
	var sync_interval := 1.0 / DROPPED_MAG_SYNC_RATE
	var should_sync := dropped_mag_sync_accumulator >= sync_interval
	if should_sync:
		dropped_mag_sync_accumulator = fmod(dropped_mag_sync_accumulator, sync_interval)
	var despawn_ids: Array[int] = []
	for mag_key in dropped_mags.keys():
		var mag_id := int(mag_key)
		var mag := dropped_mags.get(mag_id, null) as DroppedMag
		if mag == null or not is_instance_valid(mag):
			despawn_ids.append(mag_id)
			continue
		if mag.is_expired():
			despawn_ids.append(mag_id)
			continue
		if not should_sync:
			continue
		var lobby_id := int(mag.get_meta("lobby_id", 0))
		if lobby_id <= 0:
			continue
		var state := mag.authoritative_state()
		for member_value in _lobby_members(lobby_id):
			var member_id := int(member_value)
			if member_id <= 0:
				continue
			_send_sync_dropped_mag(
				member_id,
				mag_id,
				state.get("position", mag.global_position) as Vector2,
				float(state.get("rotation", mag.rotation)),
				state.get("linear_velocity", mag.linear_velocity) as Vector2,
				float(state.get("angular_velocity", mag.angular_velocity))
			)
	for mag_id in despawn_ids:
		_server_despawn_dropped_mag(mag_id)

func _server_despawn_dropped_mag(mag_id: int) -> void:
	var mag := dropped_mags.get(mag_id, null) as DroppedMag
	var lobby_id := int(mag.get_meta("lobby_id", 0)) if mag != null and is_instance_valid(mag) else 0
	_despawn_dropped_mag_local(mag_id)
	if lobby_id <= 0:
		return
	for member_value in _lobby_members(lobby_id):
		var member_id := int(member_value)
		if member_id <= 0:
			continue
		_send_despawn_dropped_mag(member_id, mag_id)

func _dropped_mags_root() -> Node2D:
	if world_root == null:
		return null
	var existing := world_root.get_node_or_null("DroppedMags") as Node2D
	if existing != null:
		return existing
	var root := Node2D.new()
	root.name = "DroppedMags"
	root.z_index = 8
	world_root.add_child(root)
	return root

func _spawn_dropped_mag_local(mag_id: int, texture_path: String, collision_size: Vector2, tint: Color, spawn_position: Vector2, linear_velocity: Vector2, angular_velocity: float, replica_mode: bool) -> DroppedMag:
	var root := _dropped_mags_root()
	if root == null:
		return null
	if dropped_mags.has(mag_id):
		var existing := dropped_mags.get(mag_id, null) as DroppedMag
		if existing != null and is_instance_valid(existing):
			existing.apply_network_state(spawn_position, existing.rotation, linear_velocity, angular_velocity)
			existing.set_tint(tint)
			existing.set_replica_mode(replica_mode)
			return existing
	var mag := DROPPED_MAG_SCRIPT.new() as DroppedMag
	if mag == null:
		return null
	mag.name = "DroppedMag_%d" % mag_id
	mag.global_position = spawn_position
	mag.rotation = randf_range(-0.28, 0.28)
	root.add_child(mag)
	var texture := load(texture_path) as Texture2D
	if texture == null:
		texture = AK47_MAG_TEXTURE
	mag.setup(mag_id, texture, collision_size, tint)
	mag.set_replica_mode(replica_mode)
	mag.linear_velocity = linear_velocity
	mag.angular_velocity = angular_velocity
	mag.set_meta("texture_path", texture_path)
	mag.set_meta("tint", tint)
	dropped_mags[mag_id] = mag
	return mag

func _mag_profile_for_weapon(weapon_id: String) -> Dictionary:
	match _normalize_weapon_id(weapon_id):
		WEAPON_ID_AK47:
			return {
				"weapon_id": WEAPON_ID_AK47,
				"texture": AK47_MAG_TEXTURE,
				"texture_path": AK47_MAG_TEXTURE_PATH,
				"spawn_offset": AK47_MAG_SPAWN_OFFSET,
				"launch_local_min": AK47_MAG_LAUNCH_LOCAL_MIN,
				"launch_local_max": AK47_MAG_LAUNCH_LOCAL_MAX,
				"collision_size": AK47_MAG_COLLISION_SIZE,
				"spawn_delay_sec": ak47_mag_spawn_delay_sec
			}
		WEAPON_ID_GRENADE:
			return {
				"weapon_id": WEAPON_ID_GRENADE,
				"texture": GRENADE_MAG_TEXTURE,
				"texture_path": GRENADE_MAG_TEXTURE_PATH,
				"spawn_offset": GRENADE_MAG_SPAWN_OFFSET,
				"launch_local_min": GRENADE_MAG_LAUNCH_LOCAL_MIN,
				"launch_local_max": GRENADE_MAG_LAUNCH_LOCAL_MAX,
				"collision_size": GRENADE_MAG_COLLISION_SIZE,
				"spawn_delay_sec": grenade_mag_spawn_delay_sec
			}
		_:
			return {}

func _collision_size_for_texture_path(texture_path: String) -> Vector2:
	match texture_path:
		GRENADE_MAG_TEXTURE_PATH:
			return GRENADE_MAG_COLLISION_SIZE
		_:
			return AK47_MAG_COLLISION_SIZE

func _weapon_relative_vector(local_vector: Vector2, aim_angle: float) -> Vector2:
	var adjusted_offset := local_vector
	if cos(aim_angle) < 0.0:
		adjusted_offset.y = -adjusted_offset.y
	return adjusted_offset.rotated(aim_angle)

func _sample_weapon_relative_vector(local_min: Vector2, local_max: Vector2, aim_angle: float) -> Vector2:
	var sampled_local := Vector2(
		randf_range(minf(local_min.x, local_max.x), maxf(local_min.x, local_max.x)),
		randf_range(minf(local_min.y, local_max.y), maxf(local_min.y, local_max.y))
	)
	return _weapon_relative_vector(sampled_local, aim_angle)

func _resolve_mag_color(peer_id: int, weapon_id: String) -> Color:
	if resolve_mag_color_cb.is_valid():
		var value = resolve_mag_color_cb.call(peer_id, weapon_id)
		if value is Color:
			return value as Color
	return Color.WHITE

func _despawn_dropped_mag_local(mag_id: int) -> void:
	var mag := dropped_mags.get(mag_id, null) as DroppedMag
	if mag != null and is_instance_valid(mag):
		mag.queue_free()
	dropped_mags.erase(mag_id)

func _clear_dropped_mags() -> void:
	for mag_value in dropped_mags.values():
		var mag := mag_value as DroppedMag
		if mag != null and is_instance_valid(mag):
			mag.queue_free()
	dropped_mags.clear()

func _normalize_weapon_id(weapon_id: String) -> String:
	if normalize_weapon_id_cb.is_valid():
		return str(normalize_weapon_id_cb.call(weapon_id)).strip_edges().to_lower()
	return str(weapon_id).strip_edges().to_lower()

func _peer_lobby(peer_id: int) -> int:
	if get_peer_lobby_cb.is_valid():
		return int(get_peer_lobby_cb.call(peer_id))
	return 0

func _lobby_members(lobby_id: int) -> Array:
	if get_lobby_members_cb.is_valid():
		return get_lobby_members_cb.call(lobby_id) as Array
	return []

func _send_spawn_dropped_mag(target_peer_id: int, mag_id: int, texture_path: String, tint: Color, spawn_position: Vector2, linear_velocity: Vector2, angular_velocity: float) -> void:
	if send_spawn_dropped_mag_cb.is_valid():
		send_spawn_dropped_mag_cb.call(target_peer_id, mag_id, texture_path, tint, spawn_position, linear_velocity, angular_velocity)

func _send_sync_dropped_mag(target_peer_id: int, mag_id: int, world_position: Vector2, world_rotation: float, linear_velocity: Vector2, angular_velocity: float) -> void:
	if send_sync_dropped_mag_cb.is_valid():
		send_sync_dropped_mag_cb.call(target_peer_id, mag_id, world_position, world_rotation, linear_velocity, angular_velocity)

func _send_despawn_dropped_mag(target_peer_id: int, mag_id: int) -> void:
	if send_despawn_dropped_mag_cb.is_valid():
		send_despawn_dropped_mag_cb.call(target_peer_id, mag_id)