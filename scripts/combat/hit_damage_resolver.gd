extends RefCounted
class_name HitDamageResolver

var players: Dictionary = {}
var player_history: Dictionary = {}
var player_history_ms := 800

var get_peer_lobby_cb: Callable = Callable()
var get_lobby_members_cb: Callable = Callable()
var register_kill_death_cb: Callable = Callable()
var server_respawn_player_cb: Callable = Callable()
var server_broadcast_player_state_cb: Callable = Callable()
var get_projectile_cb: Callable = Callable()
var get_projectile_damage_cb: Callable = Callable()
var play_death_sfx_local_cb: Callable = Callable()
var send_play_death_sfx_cb: Callable = Callable()

func configure(state_refs: Dictionary, callbacks: Dictionary, config: Dictionary = {}) -> void:
	players = state_refs.get("players", {}) as Dictionary
	player_history = state_refs.get("player_history", {}) as Dictionary

	get_peer_lobby_cb = callbacks.get("get_peer_lobby", Callable()) as Callable
	get_lobby_members_cb = callbacks.get("get_lobby_members", Callable()) as Callable
	register_kill_death_cb = callbacks.get("register_kill_death", Callable()) as Callable
	server_respawn_player_cb = callbacks.get("server_respawn_player", Callable()) as Callable
	server_broadcast_player_state_cb = callbacks.get("server_broadcast_player_state", Callable()) as Callable
	get_projectile_cb = callbacks.get("get_projectile", Callable()) as Callable
	get_projectile_damage_cb = callbacks.get("get_projectile_damage", Callable()) as Callable
	play_death_sfx_local_cb = callbacks.get("play_death_sfx_local", Callable()) as Callable
	send_play_death_sfx_cb = callbacks.get("send_play_death_sfx", Callable()) as Callable

	player_history_ms = int(config.get("player_history_ms", player_history_ms))

func server_projectile_world_hit(from_position: Vector2, to_position: Vector2, world_2d: World2D) -> Dictionary:
	if world_2d == null:
		return {}
	if from_position.distance_squared_to(to_position) <= 0.000001:
		return {}

	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from_position, to_position, 1)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit: Dictionary = world_2d.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}

	var hit_position: Vector2 = hit.get("position", to_position) as Vector2
	var segment := to_position - from_position
	var segment_len_sq := segment.length_squared()
	var t := 1.0
	if segment_len_sq > 0.000001:
		t = clampf((hit_position - from_position).dot(segment) / segment_len_sq, 0.0, 1.0)
	hit["t"] = t
	return hit

func server_projectile_player_hit(projectile: NetProjectile, from_position: Vector2, to_position: Vector2, projectile_lobby_id: int) -> Dictionary:
	if projectile == null:
		return {}
	var best_t := 2.0
	var best_peer_id := -1
	var best_position := to_position
	var segment := to_position - from_position
	var segment_len_sq := segment.length_squared()
	if segment_len_sq <= 0.000001:
		return {}

	for key in players.keys():
		var target_peer_id := int(key)
		if target_peer_id == projectile.owner_peer_id:
			continue
		if projectile_lobby_id > 0 and _peer_lobby(target_peer_id) != projectile_lobby_id:
			continue

		var target_player := players[target_peer_id] as NetPlayer
		if target_player == null:
			continue

		var rewound_position := get_player_rewound_position(target_peer_id, projectile.lag_comp_ms)
		var combined_radius := projectile.get_hit_radius() + target_player.get_hit_radius()
		var t := clampf((rewound_position - from_position).dot(segment) / segment_len_sq, 0.0, 1.0)
		var closest := from_position + segment * t
		if rewound_position.distance_squared_to(closest) <= combined_radius * combined_radius and t < best_t:
			best_t = t
			best_peer_id = target_peer_id
			best_position = closest

	if best_peer_id == -1:
		return {}
	return {
		"peer_id": best_peer_id,
		"position": best_position,
		"t": best_t
	}

func get_player_rewound_position(peer_id: int, rewind_ms: int) -> Vector2:
	var target_player := players.get(peer_id, null) as NetPlayer
	if target_player == null:
		return Vector2.ZERO

	var history: Array = player_history.get(peer_id, [])
	if history.is_empty():
		return target_player.global_position

	var target_time: int = Time.get_ticks_msec() - maxi(0, rewind_ms)
	var older: Dictionary = history[0] as Dictionary
	var newer: Dictionary = history[history.size() - 1] as Dictionary

	for i in range(history.size() - 1):
		var current: Dictionary = history[i] as Dictionary
		var next: Dictionary = history[i + 1] as Dictionary
		var current_t := int(current.get("t", 0))
		var next_t := int(next.get("t", 0))
		if target_time >= current_t and target_time <= next_t:
			older = current
			newer = next
			break
		if target_time < current_t:
			older = current
			newer = current
			break

	var older_pos: Vector2 = older.get("p", target_player.global_position) as Vector2
	var newer_pos: Vector2 = newer.get("p", target_player.global_position) as Vector2
	var older_t := int(older.get("t", 0))
	var newer_t := int(newer.get("t", older_t))
	if newer_t <= older_t:
		return older_pos
	var alpha := clampf(float(target_time - older_t) / float(newer_t - older_t), 0.0, 1.0)
	return older_pos.lerp(newer_pos, alpha)

func record_player_history(peer_id: int, position: Vector2) -> void:
	var history: Array = player_history.get(peer_id, [])
	var now := Time.get_ticks_msec()
	history.append({
		"t": now,
		"p": position
	})
	var min_time := now - player_history_ms
	while history.size() > 2 and int((history[0] as Dictionary).get("t", 0)) < min_time:
		history.remove_at(0)
	player_history[peer_id] = history

func server_apply_projectile_damage(projectile_id: int, target_peer_id: int, target_player: NetPlayer, base_damage: int) -> void:
	if target_player == null:
		return

	var attacker_peer_id := -1
	var projectile: NetProjectile = null
	if get_projectile_cb.is_valid():
		projectile = get_projectile_cb.call(projectile_id) as NetProjectile
	if projectile != null:
		attacker_peer_id = projectile.owner_peer_id

	var shot_damage := base_damage
	if get_projectile_damage_cb.is_valid():
		shot_damage = int(get_projectile_damage_cb.call(projectile_id, base_damage))

	var remaining_health := target_player.apply_damage(shot_damage)
	var target_lobby_id := _peer_lobby(target_peer_id)
	if remaining_health <= 0:
		if register_kill_death_cb.is_valid():
			register_kill_death_cb.call(attacker_peer_id, target_peer_id)
		var death_position := target_player.global_position
		if play_death_sfx_local_cb.is_valid():
			play_death_sfx_local_cb.call(death_position)
		if send_play_death_sfx_cb.is_valid():
			for member_value in _lobby_members(target_lobby_id):
				send_play_death_sfx_cb.call(int(member_value), death_position)
		if server_respawn_player_cb.is_valid():
			server_respawn_player_cb.call(target_peer_id, target_player)

	if server_broadcast_player_state_cb.is_valid():
		server_broadcast_player_state_cb.call(target_peer_id, target_player)

func server_apply_direct_damage(attacker_peer_id: int, target_peer_id: int, target_player: NetPlayer, damage: int) -> void:
	if target_player == null:
		return
	var applied_damage := maxi(0, damage)
	var remaining_health := target_player.apply_damage(applied_damage)
	var target_lobby_id := _peer_lobby(target_peer_id)
	if remaining_health <= 0:
		if register_kill_death_cb.is_valid():
			register_kill_death_cb.call(attacker_peer_id, target_peer_id)
		var death_position := target_player.global_position
		if play_death_sfx_local_cb.is_valid():
			play_death_sfx_local_cb.call(death_position)
		if send_play_death_sfx_cb.is_valid():
			for member_value in _lobby_members(target_lobby_id):
				send_play_death_sfx_cb.call(int(member_value), death_position)
		if server_respawn_player_cb.is_valid():
			server_respawn_player_cb.call(target_peer_id, target_player)
	if server_broadcast_player_state_cb.is_valid():
		server_broadcast_player_state_cb.call(target_peer_id, target_player)

func _peer_lobby(peer_id: int) -> int:
	if get_peer_lobby_cb.is_valid():
		return int(get_peer_lobby_cb.call(peer_id))
	return 0

func _lobby_members(lobby_id: int) -> Array:
	if get_lobby_members_cb.is_valid():
		return get_lobby_members_cb.call(lobby_id) as Array
	return []
