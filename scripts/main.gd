extends "res://scripts/app/main_runtime.gd"
const CLIENT_VERSION := "alpha-0.1.20"

@rpc("any_peer", "reliable")
func _rpc_request_spawn() -> void:
	super._rpc_request_spawn()

@rpc("authority", "reliable")
func _rpc_spawn_player(peer_id: int, spawn_position: Vector2, display_name: String = "") -> void:
	super._rpc_spawn_player(peer_id, spawn_position, display_name)

@rpc("authority", "reliable")
func _rpc_despawn_player(peer_id: int) -> void:
	super._rpc_despawn_player(peer_id)

@rpc("authority", "unreliable_ordered")
func _rpc_sync_player_state(peer_id: int, new_position: Vector2, new_velocity: Vector2, aim_angle: float, health: int) -> void:
	super._rpc_sync_player_state(peer_id, new_position, new_velocity, aim_angle, health)

@rpc("authority", "reliable")
func _rpc_sync_player_stats(peer_id: int, kills: int, deaths: int) -> void:
	super._rpc_sync_player_stats(peer_id, kills, deaths)

@rpc("any_peer", "unreliable_ordered")
func _rpc_submit_input(axis: float, jump_pressed: bool, jump_held: bool, aim_world: Vector2, shoot_held: bool, boost_or_rtt: Variant, reported_rtt_ms: int = -1) -> void:
	var boost_damage := false
	var effective_rtt := reported_rtt_ms
	if reported_rtt_ms < 0:
		effective_rtt = int(boost_or_rtt)
	else:
		boost_damage = bool(boost_or_rtt)
	super._rpc_submit_input(axis, jump_pressed, jump_held, aim_world, shoot_held, boost_damage, effective_rtt)

@rpc("any_peer", "unreliable")
func _rpc_ping_request(client_sent_msec: int) -> void:
	super._rpc_ping_request(client_sent_msec)

@rpc("authority", "unreliable")
func _rpc_ping_response(client_sent_msec: int) -> void:
	super._rpc_ping_response(client_sent_msec)

@rpc("authority", "reliable")
func _rpc_spawn_projectile(projectile_id: int, owner_peer_id: int, spawn_position: Vector2, velocity: Vector2, lag_comp_ms: int, trail_origin: Vector2, weapon_id: String = "") -> void:
	super._rpc_spawn_projectile(projectile_id, owner_peer_id, spawn_position, velocity, lag_comp_ms, trail_origin, weapon_id)

@rpc("authority", "reliable")
func _rpc_despawn_projectile(projectile_id: int) -> void:
	super._rpc_despawn_projectile(projectile_id)

@rpc("authority", "reliable")
func _rpc_projectile_impact(projectile_id: int, impact_position: Vector2, _legacy_trail_start_position: Vector2 = Vector2.ZERO) -> void:
	super._rpc_projectile_impact(projectile_id, impact_position)

@rpc("authority", "reliable")
func _rpc_spawn_blood_particles(impact_position: Vector2, incoming_velocity: Vector2) -> void:
	super._rpc_spawn_blood_particles(impact_position, incoming_velocity)

@rpc("authority", "reliable")
func _rpc_spawn_surface_particles(impact_position: Vector2, incoming_velocity: Vector2, particle_color: Color) -> void:
	super._rpc_spawn_surface_particles(impact_position, incoming_velocity, particle_color)

@rpc("authority", "reliable")
func _rpc_play_reload_sfx(peer_or_payload: Variant, weapon_id: String = "") -> void:
	var peer_id := 0
	var resolved_weapon_id := weapon_id
	if peer_or_payload is Array:
		var payload := peer_or_payload as Array
		if payload.size() > 0:
			peer_id = int(payload[0])
		if payload.size() > 1 and resolved_weapon_id.strip_edges().is_empty():
			resolved_weapon_id = str(payload[1])
	else:
		peer_id = int(peer_or_payload)
	super._rpc_play_reload_sfx(peer_id, resolved_weapon_id)

@rpc("authority", "reliable")
func _rpc_sync_player_ammo(peer_or_payload: Variant, ammo: int = 0, is_reloading: bool = false) -> void:
	var peer_id := 0
	var resolved_ammo := ammo
	var resolved_is_reloading := is_reloading
	if peer_or_payload is Array:
		var payload := peer_or_payload as Array
		if payload.size() > 0:
			peer_id = int(payload[0])
		if payload.size() > 1:
			resolved_ammo = int(payload[1])
		if payload.size() > 2:
			resolved_is_reloading = bool(payload[2])
	else:
		peer_id = int(peer_or_payload)
	super._rpc_sync_player_ammo(peer_id, resolved_ammo, resolved_is_reloading)

@rpc("authority", "reliable")
func _rpc_play_death_sfx(impact_position: Vector2) -> void:
	super._rpc_play_death_sfx(impact_position)

@rpc("any_peer", "reliable")
func _rpc_request_lobby_list() -> void:
	super._rpc_request_lobby_list()

@rpc("any_peer", "reliable")
func _rpc_lobby_create(requested_name: String, payload: String) -> void:
	super._rpc_lobby_create(requested_name, payload)

@rpc("any_peer", "reliable")
func _rpc_lobby_join(lobby_id: int, weapon_id: String) -> void:
	super._rpc_lobby_join(lobby_id, weapon_id)

@rpc("any_peer", "reliable")
func _rpc_lobby_leave() -> void:
	super._rpc_lobby_leave()

@rpc("any_peer", "reliable")
func _rpc_lobby_set_weapon(weapon_id: String) -> void:
	super._rpc_lobby_set_weapon(weapon_id)

@rpc("authority", "reliable")
func _rpc_lobby_list(entries: Array, active_lobby_id: int) -> void:
	super._rpc_lobby_list(entries, active_lobby_id)

@rpc("authority", "reliable")
func _rpc_lobby_action_result(success: bool, message: String, active_lobby_id: int, map_id: String, lobby_scene_mode: bool) -> void:
	super._rpc_lobby_action_result(success, message, active_lobby_id, map_id, lobby_scene_mode)

@rpc("authority", "reliable")
func _rpc_scene_switch_to_map(map_id: String) -> void:
	super._rpc_scene_switch_to_map(map_id)
