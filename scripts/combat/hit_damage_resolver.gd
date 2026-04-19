extends RefCounted
class_name HitDamageResolver

const HEADSHOT_TOP_PORTION := 1.5 / 5.0
const HEADSHOT_DAMAGE_MULTIPLIER := 2
const BLOOD_COLOR_BY_CHARACTER := {
	"outrage": Color(0.98, 0.02, 0.07, 1.0),
	"erebus": Color(0.72, 0.78, 1.0, 1.0),
	"tasko": Color(1.0, 0.65, 0.92, 1.0),
	"juice": Color(0.95, 1.0, 0.56, 1.0),
	"madam": Color(0.86, 0.48, 0.42, 1.0),
	"celler": Color(0.63, 0.74, 1.0, 1.0),
	"kotro": Color(0.47, 0.92, 0.86, 1.0),
	"nova": Color(0.41, 0.24, 0.28, 1.0),
	"hindi": Color(0.88, 0.55, 0.36, 1.0),
	"loker": Color(0.13, 0.44, 0.15, 1.0),
	"gan": Color(0.24, 0.82, 0.96, 1.0),
	"veila": Color(0.16, 0.18, 0.28, 1.0),
	"krog": Color(0.78, 0.22, 0.18, 1.0),
	"aevilok": Color(0.62, 0.18, 0.09, 1.0),
	"franky": Color(0.18, 0.78, 0.44, 1.0),
	"varn": Color(0.56, 0.61, 0.12, 1.0),
	"lalou": Color(0.68, 0.27, 0.55, 1.0),
	"m4": Color(0.22, 0.55, 0.72, 1.0),
	"rp": Color(0.18, 0.45, 0.76, 1.0),
	"crashout": Color(0.88, 0.16, 0.22, 1.0),
	"ctrlalt": Color(0.26, 0.82, 0.33, 1.0),
	"woman": Color(0.96, 0.32, 0.48, 1.0),
}

var players: Dictionary = {}
var player_history: Dictionary = {}
var player_history_ms := 800

var get_peer_lobby_cb: Callable = Callable()
var get_lobby_members_cb: Callable = Callable()
var register_kill_death_cb: Callable = Callable()
var should_use_round_survival_elimination_cb: Callable = Callable()
var server_handle_round_survival_elimination_cb: Callable = Callable()
var server_respawn_player_cb: Callable = Callable()
var server_broadcast_player_state_cb: Callable = Callable()
var get_projectile_cb: Callable = Callable()
var get_projectile_damage_cb: Callable = Callable()
var play_death_sfx_local_cb: Callable = Callable()
var send_play_death_sfx_cb: Callable = Callable()
var spawn_blood_particles_local_cb: Callable = Callable()
var send_spawn_blood_particles_cb: Callable = Callable()
var can_damage_peer_cb: Callable = Callable()
var character_id_for_peer_cb: Callable = Callable()
var authoritative_blood_color_for_peer_cb: Callable = Callable()
var incoming_damage_multiplier_for_peer_cb: Callable = Callable()
var clear_all_debuffs_for_peer_cb: Callable = Callable()

func configure(state_refs: Dictionary, callbacks: Dictionary, config: Dictionary = {}) -> void:
	players = state_refs.get("players", {}) as Dictionary
	player_history = state_refs.get("player_history", {}) as Dictionary

	get_peer_lobby_cb = callbacks.get("get_peer_lobby", Callable()) as Callable
	get_lobby_members_cb = callbacks.get("get_lobby_members", Callable()) as Callable
	register_kill_death_cb = callbacks.get("register_kill_death", Callable()) as Callable
	should_use_round_survival_elimination_cb = callbacks.get("should_use_round_survival_elimination", Callable()) as Callable
	server_handle_round_survival_elimination_cb = callbacks.get("server_handle_round_survival_elimination", Callable()) as Callable
	server_respawn_player_cb = callbacks.get("server_respawn_player", Callable()) as Callable
	server_broadcast_player_state_cb = callbacks.get("server_broadcast_player_state", Callable()) as Callable
	get_projectile_cb = callbacks.get("get_projectile", Callable()) as Callable
	get_projectile_damage_cb = callbacks.get("get_projectile_damage", Callable()) as Callable
	play_death_sfx_local_cb = callbacks.get("play_death_sfx_local", Callable()) as Callable
	send_play_death_sfx_cb = callbacks.get("send_play_death_sfx", Callable()) as Callable
	spawn_blood_particles_local_cb = callbacks.get("spawn_blood_particles_local", Callable()) as Callable
	send_spawn_blood_particles_cb = callbacks.get("send_spawn_blood_particles", Callable()) as Callable
	can_damage_peer_cb = callbacks.get("can_damage_peer", Callable()) as Callable
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable
	authoritative_blood_color_for_peer_cb = callbacks.get("authoritative_blood_color_for_peer", Callable()) as Callable
	incoming_damage_multiplier_for_peer_cb = callbacks.get("incoming_damage_multiplier_for_peer", Callable()) as Callable
	clear_all_debuffs_for_peer_cb = callbacks.get("clear_all_debuffs_for_peer", Callable()) as Callable

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
		if can_damage_peer_cb.is_valid() and not bool(can_damage_peer_cb.call(projectile.owner_peer_id, target_peer_id)):
			continue
		if projectile_lobby_id > 0 and _peer_lobby(target_peer_id) != projectile_lobby_id:
			continue

		var target_player := players[target_peer_id] as NetPlayer
		if target_player == null:
			continue
		if target_player.get_health() <= 0:
			continue
		if target_player.has_method("is_respawn_hidden") and bool(target_player.call("is_respawn_hidden")):
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
	var headshot := false
	var hit_player := players.get(best_peer_id, null) as NetPlayer
	if hit_player != null:
		var hit_rewound_position := get_player_rewound_position(best_peer_id, projectile.lag_comp_ms)
		headshot = _is_headshot_hit(hit_player, best_position, hit_rewound_position)
	return {
		"peer_id": best_peer_id,
		"position": best_position,
		"t": best_t,
		"headshot": headshot
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

func server_apply_projectile_damage(projectile_id: int, target_peer_id: int, target_player: NetPlayer, base_damage: int, incoming_velocity: Vector2 = Vector2.ZERO, is_headshot: bool = false) -> int:
	if target_player == null:
		return 0
	if target_player.get_health() <= 0:
		return 0

	var attacker_peer_id := -1
	var projectile: NetProjectile = null
	if get_projectile_cb.is_valid():
		projectile = get_projectile_cb.call(projectile_id) as NetProjectile
	if projectile != null:
		attacker_peer_id = projectile.owner_peer_id

	var shot_damage := base_damage
	if get_projectile_damage_cb.is_valid():
		shot_damage = int(get_projectile_damage_cb.call(projectile_id, base_damage))
	if is_headshot:
		shot_damage *= HEADSHOT_DAMAGE_MULTIPLIER
	var incoming_multiplier := _incoming_damage_multiplier(target_peer_id)
	shot_damage = maxi(1, int(round(float(shot_damage) * incoming_multiplier)))

	var remaining_health := target_player.apply_damage(shot_damage, incoming_velocity)
	var target_lobby_id := _peer_lobby(target_peer_id)
	if remaining_health <= 0:
		if register_kill_death_cb.is_valid():
			register_kill_death_cb.call(attacker_peer_id, target_peer_id)
		_clear_debuffs_for_dead_peer(target_peer_id)
		var death_position := target_player.global_position
		var death_blood_color := _target_blood_color(target_peer_id, target_player)
		var death_blood_velocity := incoming_velocity
		if death_blood_velocity.length_squared() <= 0.0001:
			death_blood_velocity = Vector2.UP * -120.0
		if spawn_blood_particles_local_cb.is_valid():
			spawn_blood_particles_local_cb.call(death_position, death_blood_velocity, death_blood_color, 10.0)
		if send_spawn_blood_particles_cb.is_valid():
			for member_value in _lobby_members(target_lobby_id):
				send_spawn_blood_particles_cb.call(int(member_value), death_position, death_blood_velocity, death_blood_color, 10.0)
		if play_death_sfx_local_cb.is_valid():
			play_death_sfx_local_cb.call(target_peer_id, death_position, death_blood_velocity)
		if send_play_death_sfx_cb.is_valid():
			for member_value in _lobby_members(target_lobby_id):
				send_play_death_sfx_cb.call(int(member_value), target_peer_id, death_position, death_blood_velocity)
		if _should_use_round_survival_elimination(target_peer_id):
			print("[BR ROUND DBG] projectile death -> round elimination target=%d attacker=%d lobby=%d" % [
				target_peer_id,
				attacker_peer_id,
				target_lobby_id
			])
			if server_handle_round_survival_elimination_cb.is_valid():
				server_handle_round_survival_elimination_cb.call(target_peer_id, target_player)
		elif server_respawn_player_cb.is_valid():
			print("[BR ROUND DBG] projectile death -> normal respawn target=%d attacker=%d lobby=%d" % [
				target_peer_id,
				attacker_peer_id,
				target_lobby_id
			])
			server_respawn_player_cb.call(target_peer_id, target_player)

	if server_broadcast_player_state_cb.is_valid():
		server_broadcast_player_state_cb.call(target_peer_id, target_player)
	return remaining_health

func _is_headshot_hit(target_player: NetPlayer, hit_position: Vector2, target_center: Vector2) -> bool:
	if target_player == null:
		return false
	var hit_height := 34.0
	if target_player.has_method("get_hit_height"):
		hit_height = maxf(1.0, float(target_player.call("get_hit_height")))
	var top_y := target_center.y - (hit_height * 0.5)
	var headshot_limit_y := top_y + (hit_height * HEADSHOT_TOP_PORTION)
	return hit_position.y <= headshot_limit_y

func server_apply_direct_damage(attacker_peer_id: int, target_peer_id: int, target_player: NetPlayer, damage: int, incoming_velocity: Vector2 = Vector2.ZERO) -> int:
	if target_player == null:
		return 0
	if target_player.get_health() <= 0:
		return 0
	if can_damage_peer_cb.is_valid() and not bool(can_damage_peer_cb.call(attacker_peer_id, target_peer_id)):
		return target_player.get_health()
	var applied_damage := maxi(0, damage)
	if applied_damage > 0:
		var incoming_multiplier := _incoming_damage_multiplier(target_peer_id)
		applied_damage = maxi(1, int(round(float(applied_damage) * incoming_multiplier)))
	var resolved_incoming_velocity := incoming_velocity
	if resolved_incoming_velocity.length_squared() <= 0.0001 and attacker_peer_id > 0:
		var attacker_player := players.get(attacker_peer_id, null) as NetPlayer
		if attacker_player != null:
			resolved_incoming_velocity = target_player.global_position - attacker_player.global_position
	var remaining_health := target_player.apply_damage(applied_damage, resolved_incoming_velocity)
	var target_lobby_id := _peer_lobby(target_peer_id)
	if remaining_health <= 0:
		if register_kill_death_cb.is_valid():
			register_kill_death_cb.call(attacker_peer_id, target_peer_id)
		_clear_debuffs_for_dead_peer(target_peer_id)
		var death_position := target_player.global_position
		var death_blood_color := _target_blood_color(target_peer_id, target_player)
		var death_blood_velocity := resolved_incoming_velocity
		if death_blood_velocity.length_squared() <= 0.0001:
			death_blood_velocity = Vector2.UP * -120.0
		if spawn_blood_particles_local_cb.is_valid():
			spawn_blood_particles_local_cb.call(death_position, death_blood_velocity, death_blood_color, 10.0)
		if send_spawn_blood_particles_cb.is_valid():
			for member_value in _lobby_members(target_lobby_id):
				send_spawn_blood_particles_cb.call(int(member_value), death_position, death_blood_velocity, death_blood_color, 10.0)
		if play_death_sfx_local_cb.is_valid():
			play_death_sfx_local_cb.call(target_peer_id, death_position, death_blood_velocity)
		if send_play_death_sfx_cb.is_valid():
			for member_value in _lobby_members(target_lobby_id):
				send_play_death_sfx_cb.call(int(member_value), target_peer_id, death_position, death_blood_velocity)
		if _should_use_round_survival_elimination(target_peer_id):
			print("[BR ROUND DBG] direct death -> round elimination target=%d attacker=%d lobby=%d" % [
				target_peer_id,
				attacker_peer_id,
				target_lobby_id
			])
			if server_handle_round_survival_elimination_cb.is_valid():
				server_handle_round_survival_elimination_cb.call(target_peer_id, target_player)
		elif server_respawn_player_cb.is_valid():
			print("[BR ROUND DBG] direct death -> normal respawn target=%d attacker=%d lobby=%d" % [
				target_peer_id,
				attacker_peer_id,
				target_lobby_id
			])
			server_respawn_player_cb.call(target_peer_id, target_player)
	if server_broadcast_player_state_cb.is_valid():
		server_broadcast_player_state_cb.call(target_peer_id, target_player)
	return remaining_health

func _should_use_round_survival_elimination(target_peer_id: int) -> bool:
	if should_use_round_survival_elimination_cb.is_valid():
		return bool(should_use_round_survival_elimination_cb.call(target_peer_id))
	return false

func _peer_lobby(peer_id: int) -> int:
	if get_peer_lobby_cb.is_valid():
		return int(get_peer_lobby_cb.call(peer_id))
	return 0

func _lobby_members(lobby_id: int) -> Array:
	if get_lobby_members_cb.is_valid():
		return get_lobby_members_cb.call(lobby_id) as Array
	return []

func _target_blood_color(target_peer_id: int, target_player: NetPlayer) -> Color:
	if authoritative_blood_color_for_peer_cb.is_valid():
		var color_value: Variant = authoritative_blood_color_for_peer_cb.call(target_peer_id)
		if color_value is Color:
			return color_value as Color
	if character_id_for_peer_cb.is_valid():
		var warrior_id := str(character_id_for_peer_cb.call(target_peer_id)).strip_edges().to_lower()
		if BLOOD_COLOR_BY_CHARACTER.has(warrior_id):
			return BLOOD_COLOR_BY_CHARACTER[warrior_id] as Color
	if target_player != null and target_player.has_method("get_torso_dominant_color"):
		var color_value: Variant = target_player.call("get_torso_dominant_color")
		if color_value is Color:
			return color_value as Color
	return Color(0.98, 0.02, 0.07, 1.0)

func _incoming_damage_multiplier(target_peer_id: int) -> float:
	if incoming_damage_multiplier_for_peer_cb.is_valid():
		return maxf(0.01, float(incoming_damage_multiplier_for_peer_cb.call(target_peer_id)))
	return 1.0

func _clear_debuffs_for_dead_peer(target_peer_id: int) -> void:
	if target_peer_id == 0:
		return
	if clear_all_debuffs_for_peer_cb.is_valid():
		clear_all_debuffs_for_peer_cb.call(target_peer_id, true)
