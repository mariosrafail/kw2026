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

func _rpc_request_reload() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id <= 0:
		return
	var player := players.get(peer_id, null) as NetPlayer
	if player == null:
		return
	var weapon_profile := _weapon_profile_for_peer(peer_id)
	if weapon_profile == null:
		return
	var max_ammo := maxi(0, weapon_profile.magazine_size())
	var ammo := int(ammo_by_peer.get(peer_id, max_ammo))
	var reload_remaining := float(reload_remaining_by_peer.get(peer_id, 0.0))
	if reload_remaining > 0.0:
		return
	if ammo >= max_ammo:
		return
	combat_flow_service.server_begin_reload(peer_id, weapon_profile)

@rpc("authority", "reliable")
func _rpc_spawn_player(_peer_id: int, _spawn_position: Vector2, _display_name: String = "", _weapon_id: String = "", _character_id: String = "", _skin_index: int = 0, _weapon_skin_index: int = 0) -> void:
	var peer_id := _peer_id
	var spawn_position := _spawn_position
	var display_name := _display_name
	var weapon_id := _weapon_id
	var character_id := _character_id
	var skin_index := _skin_index
	var weapon_skin_index := _weapon_skin_index
	if not display_name.strip_edges().is_empty():
		var trimmed := display_name.strip_edges()
		player_display_names[peer_id] = trimmed
		if lobby_service != null and lobby_service.has_method("set_peer_display_name"):
			lobby_service.call("set_peer_display_name", peer_id, trimmed)
	if not weapon_id.strip_edges().is_empty():
		peer_weapon_ids[peer_id] = _normalize_weapon_id(weapon_id)
	if not character_id.strip_edges().is_empty():
		peer_character_ids[peer_id] = _normalize_character_id(character_id)
	var resolved_skin_index := maxi(0, int(skin_index))
	peer_skin_indices_by_peer[peer_id] = resolved_skin_index
	peer_weapon_skin_indices_by_peer[peer_id] = maxi(0, int(weapon_skin_index))
	if lobby_service != null:
		if not weapon_id.strip_edges().is_empty():
			lobby_service.set_peer_weapon(peer_id, _normalize_weapon_id(weapon_id))
		if not character_id.strip_edges().is_empty():
			lobby_service.set_peer_character(peer_id, _normalize_character_id(character_id))
		lobby_service.set_peer_skin(peer_id, resolved_skin_index)
		lobby_service.set_peer_weapon_skin(peer_id, maxi(0, int(weapon_skin_index)))
	_spawn_player_local(peer_id, spawn_position)
	_append_log("Spawn sync: player %d" % peer_id)

func _rpc_despawn_player(_peer_id: int) -> void:
	_remove_player_local(_peer_id)
	_update_score_labels()

func _rpc_sync_player_state(_peer_id: int, _new_position: Vector2, _new_velocity: Vector2, _aim_angle: float, _health: int, _part_animation_state: Dictionary = {}) -> void:
	if multiplayer.is_server():
		return
	player_replication.client_apply_state_snapshot(
		_peer_id,
		_new_position,
		_new_velocity,
		_aim_angle,
		_health,
		_part_animation_state,
		multiplayer.get_unique_id()
	)

func _rpc_sync_player_stats(_peer_id: int, _kills: int, _deaths: int) -> void:
	player_stats[_peer_id] = {
		"kills": _kills,
		"deaths": _deaths
	}
	_update_score_labels()

func _rpc_submit_input(_axis: float, _jump_pressed: bool, _jump_held: bool, _aim_world: Vector2, _shoot_held: bool, _boost_damage: bool, _reported_rtt_ms: int) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var weapon := _weapon_profile_for_peer(peer_id)
	player_replication.server_submit_input(
		peer_id,
		_axis,
		_jump_pressed,
		_jump_held,
		_aim_world,
		_shoot_held,
		_boost_damage,
		_reported_rtt_ms,
		weapon
	)

func _rpc_ping_request(_client_sent_msec: int) -> void:
	if not multiplayer.is_server():
		return
	_rpc_ping_response.rpc_id(multiplayer.get_remote_sender_id(), _client_sent_msec)

func _rpc_ping_response(_client_sent_msec: int) -> void:
	if multiplayer.is_server():
		return
	last_ping_ms = int(max(0, Time.get_ticks_msec() - _client_sent_msec))
	_update_ping_label()
	_update_peer_labels()

func _rpc_spawn_projectile(_projectile_id: int, _owner_peer_id: int, _spawn_position: Vector2, _velocity: Vector2, _lag_comp_ms: int, _trail_origin: Vector2, _weapon_id: String = "") -> void:
	if multiplayer.is_server():
		return
	var resolved_weapon_id := _weapon_id.strip_edges()
	if resolved_weapon_id.is_empty():
		resolved_weapon_id = _weapon_id_for_peer(_owner_peer_id)
	client_rpc_flow_service.rpc_spawn_projectile(
		_projectile_id,
		_owner_peer_id,
		_spawn_position,
		_velocity,
		_lag_comp_ms,
		_trail_origin,
		resolved_weapon_id,
		last_ping_ms
	)

func _rpc_despawn_projectile(_projectile_id: int) -> void:
	if multiplayer.is_server():
		return
	client_rpc_flow_service.rpc_despawn_projectile(_projectile_id)

func _rpc_projectile_impact(_projectile_id: int, _impact_position: Vector2, _legacy_trail_start_position: Vector2 = Vector2.ZERO) -> void:
	if multiplayer.is_server():
		return
	client_rpc_flow_service.rpc_projectile_impact(_projectile_id, _impact_position)

func _rpc_spawn_blood_particles(_impact_position: Vector2, _incoming_velocity: Vector2, _blood_color: Color = Color(0.98, 0.02, 0.07, 1.0), _count_multiplier: float = 1.0) -> void:
	if multiplayer.is_server():
		return
	client_rpc_flow_service.rpc_spawn_blood_particles(_impact_position, _incoming_velocity, _blood_color, _count_multiplier)

func _rpc_spawn_surface_particles(_impact_position: Vector2, _incoming_velocity: Vector2, _particle_color: Color) -> void:
	if multiplayer.is_server():
		return
	client_rpc_flow_service.rpc_spawn_surface_particles(_impact_position, _incoming_velocity, _particle_color)

func _rpc_play_reload_sfx(_peer_or_payload: Variant, _weapon_id: String = "") -> void:
	if multiplayer.is_server():
		return
	var peer_id := 0
	var resolved_weapon_id := _weapon_id
	if _peer_or_payload is Array:
		var payload := _peer_or_payload as Array
		if payload.size() > 0:
			peer_id = int(payload[0])
		if payload.size() > 1 and resolved_weapon_id.strip_edges().is_empty():
			resolved_weapon_id = str(payload[1])
	else:
		peer_id = int(_peer_or_payload)
	if peer_id <= 0:
		return
	resolved_weapon_id = resolved_weapon_id.strip_edges()
	if resolved_weapon_id.is_empty():
		resolved_weapon_id = _weapon_id_for_peer(peer_id)
	client_rpc_flow_service.rpc_play_reload_sfx(peer_id, resolved_weapon_id)

func _rpc_sync_player_ammo(_peer_or_payload: Variant, _ammo: int = 0, _is_reloading: bool = false) -> void:
	if multiplayer.is_server():
		return
	var peer_id := 0
	var resolved_ammo := _ammo
	var resolved_is_reloading := _is_reloading
	if _peer_or_payload is Array:
		var payload := _peer_or_payload as Array
		if payload.size() > 0:
			peer_id = int(payload[0])
		if payload.size() > 1:
			resolved_ammo = int(payload[1])
		if payload.size() > 2:
			resolved_is_reloading = bool(payload[2])
	else:
		peer_id = int(_peer_or_payload)
	if peer_id <= 0:
		return
	client_rpc_flow_service.rpc_sync_player_ammo(peer_id, resolved_ammo, resolved_is_reloading)

func _rpc_sync_player_weapon(_peer_id: int, _weapon_id: String) -> void:
	if multiplayer.is_server():
		return
	var peer_id := _peer_id
	if peer_id <= 0:
		return
	var resolved_weapon_id := _normalize_weapon_id(_weapon_id)
	peer_weapon_ids[peer_id] = resolved_weapon_id
	var player := players.get(peer_id, null) as NetPlayer
	if player == null:
		return
	player.set_weapon_visual(_weapon_visual_for_peer(peer_id, resolved_weapon_id))
	player.set_shot_audio_stream(_weapon_shot_sfx(resolved_weapon_id))
	player.set_reload_audio_stream(_weapon_reload_sfx(resolved_weapon_id))

func _rpc_sync_player_weapon_skin(_peer_id: int, _skin_index: int) -> void:
	if multiplayer.is_server():
		return
	var peer_id := _peer_id
	if peer_id <= 0:
		return
	var resolved_skin_index := maxi(0, _skin_index)
	peer_weapon_skin_indices_by_peer[peer_id] = resolved_skin_index
	if lobby_service != null:
		lobby_service.set_peer_weapon_skin(peer_id, resolved_skin_index)
	var player := players.get(peer_id, null) as NetPlayer
	if player == null:
		return
	player.set_weapon_visual(_weapon_visual_for_peer(peer_id, _weapon_id_for_peer(peer_id)))

func _rpc_sync_player_character(_peer_id: int, _character_id: String) -> void:
	if multiplayer.is_server():
		return
	var peer_id := _peer_id
	if peer_id <= 0:
		return
	var resolved_character_id := _normalize_character_id(_character_id)
	peer_character_ids[peer_id] = resolved_character_id
	var player := players.get(peer_id, null) as NetPlayer
	if player != null and player.has_method("set_character_visual"):
		player.call("set_character_visual", resolved_character_id)

func _rpc_sync_player_skin(_peer_id: int, _skin_index: int) -> void:
	if multiplayer.is_server():
		return
	var peer_id := _peer_id
	if peer_id <= 0:
		return
	var resolved := maxi(0, _skin_index)
	peer_skin_indices_by_peer[peer_id] = resolved
	var player := players.get(peer_id, null) as NetPlayer
	if player != null and player.has_method("set_skin_index"):
		player.call("set_skin_index", resolved)

func _rpc_sync_player_display_name(_peer_id: int, _display_name: String) -> void:
	if multiplayer.is_server():
		return
	var peer_id := _peer_id
	if peer_id <= 0:
		return
	var trimmed := _display_name.strip_edges()
	if trimmed.is_empty():
		return
	player_display_names[peer_id] = trimmed
	if lobby_service != null and lobby_service.has_method("set_peer_display_name"):
		lobby_service.call("set_peer_display_name", peer_id, trimmed)
	var player := players.get(peer_id, null) as NetPlayer
	if player != null and player.has_method("set_display_name"):
		player.call("set_display_name", trimmed)
	_update_score_labels()

func _rpc_play_death_sfx(_impact_position: Vector2) -> void:
	if multiplayer.is_server():
		return
	client_rpc_flow_service.rpc_play_death_sfx(_impact_position)

func _rpc_request_lobby_list() -> void:
	if not multiplayer.is_server():
		return
	lobby_flow_controller.server_request_lobby_list(multiplayer.get_remote_sender_id())

func _rpc_lobby_create(_requested_name: String, _payload: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var decoded := map_flow_service.decode_create_lobby_payload(
		map_catalog,
		Callable(self, "_normalize_weapon_id"),
		WEAPON_ID_AK47,
		_payload
	)
	var weapon_id := _normalize_weapon_id(str(decoded.get("weapon_id", WEAPON_ID_AK47)))
	var character_id := _normalize_character_id(str(decoded.get("character_id", CHARACTER_ID_OUTRAGE)))
	var map_id := map_flow_service.normalize_map_id(map_catalog, str(decoded.get("map_id", MAP_ID_CLASSIC)))
	peer_weapon_ids[peer_id] = weapon_id
	peer_character_ids[peer_id] = character_id
	if lobby_service != null:
		lobby_service.set_peer_weapon(peer_id, weapon_id)
		lobby_service.set_peer_character(peer_id, character_id)
	lobby_flow_controller.server_create_lobby(peer_id, _requested_name, map_id, map_catalog.max_players_for_id(map_id))
	if not _uses_lobby_scene_flow():
		var active_lobby_id := _peer_lobby(peer_id)
		if active_lobby_id > 0:
			_send_scene_switch_rpc(peer_id, _lobby_map_id(active_lobby_id))

func _rpc_lobby_join(_lobby_id: int, _weapon_id: String, _character_id: String = "") -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var normalized_character_id := _normalize_character_id(_character_id)
	print("[DBG JOIN] Peer %d joining with weapon=%s character=%s (normalized=%s)" % [peer_id, _weapon_id, _character_id, normalized_character_id])
	peer_weapon_ids[peer_id] = _normalize_weapon_id(_weapon_id)
	peer_character_ids[peer_id] = normalized_character_id
	if lobby_service != null:
		lobby_service.set_peer_weapon(peer_id, _normalize_weapon_id(_weapon_id))
		lobby_service.set_peer_character(peer_id, normalized_character_id)
	lobby_flow_controller.server_join_lobby(peer_id, _lobby_id)
	if not _uses_lobby_scene_flow():
		var active_lobby_id := _peer_lobby(peer_id)
		if active_lobby_id > 0:
			_send_scene_switch_rpc(peer_id, _lobby_map_id(active_lobby_id))

func _rpc_lobby_leave(_legacy_a: Variant = null, _legacy_b: Variant = null) -> void:
	if not multiplayer.is_server():
		return
	lobby_flow_controller.server_leave_lobby_request(multiplayer.get_remote_sender_id())

func _rpc_lobby_set_weapon(_peer_or_weapon: Variant, _weapon_id: String = "") -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var resolved_weapon_id := _weapon_id
	if resolved_weapon_id.strip_edges().is_empty():
		resolved_weapon_id = str(_peer_or_weapon)
	var normalized_weapon_id := _normalize_weapon_id(resolved_weapon_id)
	peer_weapon_ids[peer_id] = normalized_weapon_id
	if lobby_service != null:
		lobby_service.set_peer_weapon(peer_id, normalized_weapon_id)
	if players.has(peer_id):
		var player := players[peer_id] as NetPlayer
		if player != null:
			player.set_weapon_visual(_weapon_visual_for_peer(peer_id, normalized_weapon_id))
			player.set_shot_audio_stream(_weapon_shot_sfx(normalized_weapon_id))
			player.set_reload_audio_stream(_weapon_reload_sfx(normalized_weapon_id))
		combat_flow_service.server_sync_player_ammo(peer_id)
	var lobby_id := _peer_lobby(peer_id)
	var recipients := _lobby_members(lobby_id)
	if recipients.is_empty() and not _uses_lobby_scene_flow():
		if multiplayer != null and multiplayer.multiplayer_peer != null:
			recipients = []
			for id_value in multiplayer.get_peers():
				recipients.append(int(id_value))
	for member_value in recipients:
		var member_id := int(member_value)
		if member_id <= 0:
			continue
		_rpc_sync_player_weapon.rpc_id(member_id, peer_id, normalized_weapon_id)

func _rpc_lobby_set_weapon_skin(_skin_index: int) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var resolved_skin_index := maxi(0, _skin_index)
	peer_weapon_skin_indices_by_peer[peer_id] = resolved_skin_index
	if lobby_service != null:
		lobby_service.set_peer_weapon_skin(peer_id, resolved_skin_index)
	if players.has(peer_id):
		var player := players[peer_id] as NetPlayer
		if player != null:
			player.set_weapon_visual(_weapon_visual_for_peer(peer_id, _weapon_id_for_peer(peer_id)))
	var lobby_id := _peer_lobby(peer_id)
	var recipients := _lobby_members(lobby_id)
	if recipients.is_empty() and not _uses_lobby_scene_flow():
		if multiplayer != null and multiplayer.multiplayer_peer != null:
			recipients = []
			for id_value in multiplayer.get_peers():
				recipients.append(int(id_value))
	for member_value in recipients:
		var member_id := int(member_value)
		if member_id <= 0:
			continue
		_rpc_sync_player_weapon_skin.rpc_id(member_id, peer_id, resolved_skin_index)

func _rpc_lobby_set_character(_character_id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var normalized_character_id := _normalize_character_id(_character_id)
	print("[DBG SERVER] _rpc_lobby_set_character: peer_id=%d, character=%s" % [peer_id, normalized_character_id])
	peer_character_ids[peer_id] = normalized_character_id
	if lobby_service != null:
		lobby_service.set_peer_character(peer_id, normalized_character_id)
	if players.has(peer_id):
		var player := players[peer_id] as NetPlayer
		if player != null and player.has_method("set_character_visual"):
			print("[DBG SERVER] Calling set_character_visual on player %d with %s" % [peer_id, normalized_character_id])
			player.call("set_character_visual", normalized_character_id)
		else:
			print("[DBG SERVER] Player %d doesn't have set_character_visual method or is null" % peer_id)
	else:
		print("[DBG SERVER] Player %d not found in players dict" % peer_id)

	var lobby_id := _peer_lobby(peer_id)
	var recipients := _lobby_members(lobby_id)
	if recipients.is_empty() and not _uses_lobby_scene_flow():
		if multiplayer != null and multiplayer.multiplayer_peer != null:
			recipients = []
			for id_value in multiplayer.get_peers():
				recipients.append(int(id_value))
	for member_value in recipients:
		var member_id := int(member_value)
		if member_id <= 0:
			continue
		_rpc_sync_player_character.rpc_id(member_id, peer_id, normalized_character_id)

func _rpc_lobby_set_skin(_skin_index: int) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var resolved := maxi(0, _skin_index)
	peer_skin_indices_by_peer[peer_id] = resolved
	if lobby_service != null:
		lobby_service.set_peer_skin(peer_id, resolved)
	if players.has(peer_id):
		var player := players.get(peer_id, null) as NetPlayer
		if player != null and player.has_method("set_skin_index"):
			player.call("set_skin_index", resolved)

	var lobby_id := _peer_lobby(peer_id)
	var recipients := _lobby_members(lobby_id)
	if recipients.is_empty() and not _uses_lobby_scene_flow():
		if multiplayer != null and multiplayer.multiplayer_peer != null:
			recipients = []
			for id_value in multiplayer.get_peers():
				recipients.append(int(id_value))
	for member_value in recipients:
		var member_id := int(member_value)
		if member_id <= 0:
			continue
		_rpc_sync_player_skin.rpc_id(member_id, peer_id, resolved)

func _rpc_lobby_set_display_name(_display_name: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var trimmed := _display_name.strip_edges()
	if trimmed.is_empty():
		return
	if trimmed.length() > 16:
		trimmed = trimmed.substr(0, 16)
	player_display_names[peer_id] = trimmed
	if lobby_service != null and lobby_service.has_method("set_peer_display_name"):
		lobby_service.call("set_peer_display_name", peer_id, trimmed)
	if players.has(peer_id):
		var player := players.get(peer_id, null) as NetPlayer
		if player != null and player.has_method("set_display_name"):
			player.call("set_display_name", trimmed)

	var lobby_id := _peer_lobby(peer_id)
	var recipients := _lobby_members(lobby_id)
	if recipients.is_empty() and not _uses_lobby_scene_flow():
		if multiplayer != null and multiplayer.multiplayer_peer != null:
			recipients = []
			for id_value in multiplayer.get_peers():
				recipients.append(int(id_value))
	for member_value in recipients:
		var member_id := int(member_value)
		if member_id <= 0:
			continue
		_rpc_sync_player_display_name.rpc_id(member_id, peer_id, trimmed)

func _rpc_lobby_list(_entries: Array, _active_lobby_id: int) -> void:
	if multiplayer.is_server() and role != Role.CLIENT:
		return
	var normalized := map_flow_service.normalize_client_lobby_entries(
		_entries,
		_active_lobby_id,
		selected_map_id,
		map_catalog
	)
	lobby_map_by_id = normalized.get("lobby_map_by_id", {}) as Dictionary
	client_target_map_id = str(normalized.get("client_target_map_id", selected_map_id))
	lobby_flow_controller.client_receive_lobby_list(normalized.get("entries", []) as Array, _active_lobby_id)
	if escape_return_pending and _active_lobby_id <= 0:
		_complete_escape_return_to_lobby_menu(escape_return_nonce)

func _rpc_lobby_action_result(_success: bool, _message: String, _active_lobby_id: int, _map_id: String, _lobby_scene_mode: bool) -> void:
	if _map_id.strip_edges() != "":
		client_target_map_id = map_flow_service.normalize_map_id(map_catalog, _map_id)
	lobby_flow_controller.client_lobby_action_result(_success, _message, _active_lobby_id, _lobby_scene_mode)
	if escape_return_pending and _active_lobby_id <= 0:
		_complete_escape_return_to_lobby_menu(escape_return_nonce)

func _rpc_scene_switch_to_map(_map_id: String) -> void:
	_switch_to_map_scene(_map_id)

func _rpc_cast_skill1(_target_world: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var caster_peer_id := multiplayer.get_remote_sender_id()
	combat_flow_service.server_cast_skill(1, caster_peer_id, _target_world)

func _rpc_cast_skill2(_target_world: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var caster_peer_id := multiplayer.get_remote_sender_id()
	combat_flow_service.server_cast_skill(2, caster_peer_id, _target_world)

func _rpc_spawn_outrage_bomb(_caster_peer_id: int, _world_position: Vector2, _fuse_sec: float) -> void:
	if multiplayer.is_server():
		return
	# Delegate to new warrior system (Outrage skill 1 = Bomb)
	combat_flow_service.client_receive_skill_cast(1, _caster_peer_id, _world_position)

func _rpc_spawn_outrage_boost(_caster_peer_id: int, _duration_sec: float) -> void:
	if multiplayer.is_server():
		return
	# Delegate to new warrior system (Outrage skill 2 = Damage Boost)
	combat_flow_service.client_receive_skill_cast(2, _caster_peer_id, Vector2(_duration_sec, 0.0))

func _rpc_spawn_erebus_immunity(_caster_peer_id: int, _duration_sec: float) -> void:
	if multiplayer.is_server():
		return
	# Delegate to new warrior system (Erebus skill 1 = Immunity)
	combat_flow_service.client_receive_skill_cast(1, _caster_peer_id, Vector2.ZERO)

func _rpc_spawn_erebus_shield(_caster_peer_id: int, _duration_sec: float) -> void:
	if multiplayer.is_server():
		return
	# Delegate to new warrior system (Erebus skill 2 = Shield)
	combat_flow_service.client_receive_skill_cast(2, _caster_peer_id, Vector2.ZERO)

func _rpc_spawn_tasko_invis_field(_caster_peer_id: int, _world_position: Vector2) -> void:
	if multiplayer.is_server():
		return
	combat_flow_service.client_receive_skill_cast(1, _caster_peer_id, _world_position)

func _rpc_spawn_tasko_mine(_caster_peer_id: int, _world_position: Vector2) -> void:
	if multiplayer.is_server():
		return
	combat_flow_service.client_receive_skill_cast(2, _caster_peer_id, _world_position)
