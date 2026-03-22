extends "res://scripts/app/runtime/runtime_weapon_logic.gd"

func _spawn_player_local(peer_id: int, spawn_position: Vector2) -> void:
	if _uses_lobby_scene_flow():
		return
	var resolved_spawn := spawn_flow_service.sanitize_spawn_position(spawn_position, _get_world_2d_ref(), 1)
	if players.has(peer_id):
		var existing := players[peer_id] as NetPlayer
		if existing != null:
			if _is_target_dummy_peer(peer_id):
				var bot_controller := _bot_controller_for_peer(peer_id)
				if bot_controller != null:
					bot_controller.setup_spawned_player(existing, resolved_spawn, role == Role.CLIENT)
			elif existing.has_method("set_display_name"):
				existing.call("set_display_name", _ensure_player_display_name(peer_id))
				existing.set_weapon_visual(_weapon_visual_for_peer(peer_id))
				if existing.has_method("set_character_visual"):
					existing.call("set_character_visual", _warrior_id_for_peer(peer_id))
				if existing.has_method("set_skin_index") and peer_skin_indices_by_peer.has(peer_id):
					existing.call("set_skin_index", int(peer_skin_indices_by_peer.get(peer_id, 0)))
			existing.force_respawn(resolved_spawn)
		return

	var player := PLAYER_SCENE.instantiate() as NetPlayer
	if player == null:
		return
	player.global_position = resolved_spawn
	players_root.add_child(player)
	player.configure(peer_id, _player_color(peer_id))
	if _is_target_dummy_peer(peer_id):
		var bot_controller := _bot_controller_for_peer(peer_id)
		if bot_controller != null:
			player.configure(peer_id, bot_controller.bot_color)
			bot_controller.setup_spawned_player(player, resolved_spawn, role == Role.CLIENT)
	elif player.has_method("set_display_name"):
		player.call("set_display_name", _ensure_player_display_name(peer_id))
		player.use_network_smoothing = role == Role.CLIENT and peer_id != multiplayer.get_unique_id()
		player.set_weapon_visual(_weapon_visual_for_peer(peer_id))
		if player.has_method("set_character_visual"):
			player.call("set_character_visual", _warrior_id_for_peer(peer_id))
		if player.has_method("set_skin_index") and peer_skin_indices_by_peer.has(peer_id):
			player.call("set_skin_index", int(peer_skin_indices_by_peer.get(peer_id, 0)))
		player.set_shot_audio_stream(_weapon_shot_sfx(_weapon_id_for_peer(peer_id)))
		player.set_reload_audio_stream(_weapon_reload_sfx(_weapon_id_for_peer(peer_id)))
		if ammo_by_peer.has(peer_id):
			player.set_ammo(int(ammo_by_peer[peer_id]), float(reload_remaining_by_peer.get(peer_id, 0.0)) > 0.0)

	players[peer_id] = player
	combat_flow_service.record_player_history(peer_id, resolved_spawn)
	if role == Role.SERVER and multiplayer != null and multiplayer.multiplayer_peer != null and peer_id == multiplayer.get_unique_id():
		_server_ensure_bots_if_needed()
	_update_peer_labels()
	_update_ui_visibility()
	if peer_id == multiplayer.get_unique_id() and _uses_lobby_scene_flow():
		_try_switch_to_target_map_scene()

func _remove_player_local(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	var player := players[peer_id] as NetPlayer
	if is_instance_valid(player):
		player.queue_free()
	players.erase(peer_id)
	ammo_by_peer.erase(peer_id)
	reload_remaining_by_peer.erase(peer_id)
	pending_reload_delay_by_peer.erase(peer_id)
	peer_weapon_ids.erase(peer_id)
	peer_weapon_skin_indices_by_peer.erase(peer_id)
	peer_character_ids.erase(peer_id)
	peer_team_by_peer.erase(peer_id)
	_update_peer_labels()
	_update_ui_visibility()

func _server_remove_player(peer_id: int, target_peers: Array = []) -> void:
	var recipients := target_peers.duplicate()
	if recipients.is_empty():
		var peer_lobby_id := _peer_lobby(peer_id)
		if peer_lobby_id > 0:
			recipients = _lobby_members(peer_lobby_id)
	player_replication.server_remove_player(
		peer_id,
		recipients,
		multiplayer.get_peers(),
		multiplayer.get_unique_id()
	)
	ammo_by_peer.erase(peer_id)
	reload_remaining_by_peer.erase(peer_id)
	pending_reload_delay_by_peer.erase(peer_id)
	peer_weapon_ids.erase(peer_id)
	peer_weapon_skin_indices_by_peer.erase(peer_id)
	peer_character_ids.erase(peer_id)
	peer_team_by_peer.erase(peer_id)
	spawn_slots.erase(peer_id)
	if ctf_match_controller != null and _ctf_objective_enabled():
		ctf_match_controller.drop_flag_for_peer(peer_id, _player_world_position_or_flag(peer_id))
		_sync_ctf_flag_to_clients()
	_update_peer_labels()
	_update_score_labels()

func _server_sync_player_stats(peer_id: int) -> void:
	if _is_target_dummy_peer(peer_id):
		return
	player_replication.server_sync_player_stats(peer_id)

func _server_register_kill_death(attacker_peer_id: int, target_peer_id: int) -> void:
	player_replication.server_register_kill_death(attacker_peer_id, target_peer_id)
	_update_score_labels()

func _server_broadcast_player_state(peer_id: int, player: NetPlayer) -> void:
	player_replication.server_broadcast_player_state(peer_id, player)

func _player_color(peer_id: int) -> Color:
	return spawn_identity.player_color(peer_id)

func _projectile_color(peer_id: int, weapon_id: String = "") -> Color:
	var resolved_weapon_id := _normalize_weapon_id(weapon_id if not weapon_id.strip_edges().is_empty() else _weapon_id_for_peer(peer_id))
	var skin_index := _weapon_skin_for_peer(peer_id, resolved_weapon_id)
	if weapon_ui != null and weapon_ui.has_method("weapon_skin_dominant_color"):
		var color_value = weapon_ui.call("weapon_skin_dominant_color", resolved_weapon_id, skin_index)
		if color_value is Color:
			return color_value as Color
	return _player_color(peer_id)

func _update_peer_labels() -> void:
	pass

func _update_ui_visibility() -> void:
	pass

func _update_score_labels() -> void:
	pass

func _ensure_player_display_name(_peer_id: int) -> String:
	return ""

func _warrior_id_for_peer(_peer_id: int) -> String:
	return CHARACTER_ID_OUTRAGE

func _get_world_2d_ref() -> World2D:
	return null
