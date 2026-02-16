extends "res://scripts/app/runtime_setup_logic.gd"

func _rpc_request_spawn() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var peer_lobby_id := _peer_lobby(peer_id)
	if _uses_lobby_scene_flow():
		if peer_lobby_id <= 0:
			return
		_server_spawn_peer_if_needed(peer_id, peer_lobby_id)
		return
	if peer_lobby_id > 0:
		_server_spawn_peer_if_needed(peer_id, peer_lobby_id)
		return
	if lobby_service != null and lobby_service.has_active_lobbies():
		return
	_server_spawn_peer_if_needed(peer_id, 1)

func _rpc_spawn_player(peer_id: int, spawn_position: Vector2, display_name: String = "") -> void:
	if not display_name.strip_edges().is_empty():
		player_display_names[peer_id] = display_name
	_spawn_player_local(peer_id, spawn_position)
	_append_log("Spawn sync: player %d" % peer_id)

func _rpc_despawn_player(peer_id: int) -> void:
	_remove_player_local(peer_id)
	_update_score_labels()

func _rpc_sync_player_state(peer_id: int, new_position: Vector2, new_velocity: Vector2, aim_angle: float, health: int) -> void:
	if multiplayer.is_server():
		return
	player_replication.client_apply_state_snapshot(
		peer_id,
		new_position,
		new_velocity,
		aim_angle,
		health,
		multiplayer.get_unique_id()
	)

func _rpc_sync_player_stats(peer_id: int, kills: int, deaths: int) -> void:
	player_stats[peer_id] = {
		"kills": kills,
		"deaths": deaths
	}
	_update_score_labels()

func _rpc_submit_input(axis: float, jump_pressed: bool, jump_held: bool, aim_world: Vector2, shoot_held: bool, boost_damage: bool, reported_rtt_ms: int) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var weapon := _weapon_profile_for_peer(peer_id)
	player_replication.server_submit_input(
		peer_id,
		axis,
		jump_pressed,
		jump_held,
		aim_world,
		shoot_held,
		boost_damage,
		reported_rtt_ms,
		weapon
	)

func _rpc_ping_request(client_sent_msec: int) -> void:
	if not multiplayer.is_server():
		return
	_rpc_ping_response.rpc_id(multiplayer.get_remote_sender_id(), client_sent_msec)

func _rpc_ping_response(client_sent_msec: int) -> void:
	if multiplayer.is_server():
		return
	last_ping_ms = int(max(0, Time.get_ticks_msec() - client_sent_msec))
	_update_ping_label()
	_update_peer_labels()

func _rpc_spawn_projectile(projectile_id: int, owner_peer_id: int, spawn_position: Vector2, velocity: Vector2, lag_comp_ms: int, trail_origin: Vector2, weapon_id: String = "") -> void:
	if multiplayer.is_server():
		return
	var resolved_weapon_id := weapon_id.strip_edges()
	if resolved_weapon_id.is_empty():
		resolved_weapon_id = _weapon_id_for_peer(owner_peer_id)
	client_rpc_flow_service.rpc_spawn_projectile(
		projectile_id,
		owner_peer_id,
		spawn_position,
		velocity,
		lag_comp_ms,
		trail_origin,
		resolved_weapon_id,
		last_ping_ms
	)

func _rpc_despawn_projectile(projectile_id: int) -> void:
	if multiplayer.is_server():
		return
	client_rpc_flow_service.rpc_despawn_projectile(projectile_id)

func _rpc_projectile_impact(projectile_id: int, impact_position: Vector2) -> void:
	if multiplayer.is_server():
		return
	client_rpc_flow_service.rpc_projectile_impact(projectile_id, impact_position)

func _rpc_spawn_blood_particles(impact_position: Vector2, incoming_velocity: Vector2) -> void:
	if multiplayer.is_server():
		return
	client_rpc_flow_service.rpc_spawn_blood_particles(impact_position, incoming_velocity)

func _rpc_spawn_surface_particles(impact_position: Vector2, incoming_velocity: Vector2, particle_color: Color) -> void:
	if multiplayer.is_server():
		return
	client_rpc_flow_service.rpc_spawn_surface_particles(impact_position, incoming_velocity, particle_color)

func _rpc_play_reload_sfx(peer_id: int, weapon_id: String) -> void:
	if multiplayer.is_server():
		return
	if peer_id <= 0:
		return
	var resolved_weapon_id := weapon_id.strip_edges()
	if resolved_weapon_id.is_empty():
		resolved_weapon_id = _weapon_id_for_peer(peer_id)
	client_rpc_flow_service.rpc_play_reload_sfx(peer_id, resolved_weapon_id)

func _rpc_sync_player_ammo(peer_id: int, ammo: int, is_reloading: bool) -> void:
	if multiplayer.is_server():
		return
	if peer_id <= 0:
		return
	client_rpc_flow_service.rpc_sync_player_ammo(peer_id, ammo, is_reloading)

func _rpc_play_death_sfx(impact_position: Vector2) -> void:
	if multiplayer.is_server():
		return
	client_rpc_flow_service.rpc_play_death_sfx(impact_position)

func _rpc_request_lobby_list() -> void:
	if not multiplayer.is_server():
		return
	lobby_flow_controller.server_request_lobby_list(multiplayer.get_remote_sender_id())

func _rpc_lobby_create(requested_name: String, payload: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var decoded := map_flow_service.decode_create_lobby_payload(
		map_catalog,
		Callable(self, "_normalize_weapon_id"),
		WEAPON_ID_AK47,
		payload
	)
	var weapon_id := _normalize_weapon_id(str(decoded.get("weapon_id", WEAPON_ID_AK47)))
	var map_id := map_flow_service.normalize_map_id(map_catalog, str(decoded.get("map_id", MAP_ID_CLASSIC)))
	peer_weapon_ids[peer_id] = weapon_id
	if lobby_service != null:
		lobby_service.set_peer_weapon(peer_id, weapon_id)
	lobby_flow_controller.server_create_lobby(peer_id, requested_name, map_id, map_catalog.max_players_for_id(map_id))
	if not _uses_lobby_scene_flow():
		var active_lobby_id := _peer_lobby(peer_id)
		if active_lobby_id > 0:
			_send_scene_switch_rpc(peer_id, _lobby_map_id(active_lobby_id))

func _rpc_lobby_join(lobby_id: int, weapon_id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	peer_weapon_ids[peer_id] = _normalize_weapon_id(weapon_id)
	if lobby_service != null:
		lobby_service.set_peer_weapon(peer_id, _normalize_weapon_id(weapon_id))
	lobby_flow_controller.server_join_lobby(peer_id, lobby_id)
	if not _uses_lobby_scene_flow():
		var active_lobby_id := _peer_lobby(peer_id)
		if active_lobby_id > 0:
			_send_scene_switch_rpc(peer_id, _lobby_map_id(active_lobby_id))

func _rpc_lobby_leave() -> void:
	if not multiplayer.is_server():
		return
	lobby_flow_controller.server_leave_lobby_request(multiplayer.get_remote_sender_id())

func _rpc_lobby_set_weapon(weapon_id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	peer_weapon_ids[peer_id] = _normalize_weapon_id(weapon_id)
	if lobby_service != null:
		lobby_service.set_peer_weapon(peer_id, _normalize_weapon_id(weapon_id))
	if players.has(peer_id):
		combat_flow_service.server_sync_player_ammo(peer_id)

func _rpc_lobby_list(entries: Array, active_lobby_id: int) -> void:
	if multiplayer.is_server() and role != Role.CLIENT:
		return
	var normalized := map_flow_service.normalize_client_lobby_entries(
		entries,
		active_lobby_id,
		selected_map_id,
		map_catalog
	)
	lobby_map_by_id = normalized.get("lobby_map_by_id", {}) as Dictionary
	client_target_map_id = str(normalized.get("client_target_map_id", selected_map_id))
	lobby_flow_controller.client_receive_lobby_list(normalized.get("entries", []) as Array, active_lobby_id)

func _rpc_lobby_action_result(success: bool, message: String, active_lobby_id: int, map_id: String, lobby_scene_mode: bool) -> void:
	if map_id.strip_edges() != "":
		client_target_map_id = map_flow_service.normalize_map_id(map_catalog, map_id)
	lobby_flow_controller.client_lobby_action_result(success, message, active_lobby_id, lobby_scene_mode)

func _rpc_scene_switch_to_map(map_id: String) -> void:
	_switch_to_map_scene(map_id)
