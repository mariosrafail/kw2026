extends "res://scripts/app/runtime_shared.gd"

const GUN_BASE_POSITION := Vector2(6.0, 2.0)
const AK47_GUN_FALLBACK_REGION := Rect2(31, 12, 50, 12)
const UZI_GUN_FALLBACK_REGION := Rect2(161, 85, 25, 21)
const AK47_MUZZLE_POSITION := Vector2(33.0, 2.5)
const UZI_MUZZLE_POSITION := Vector2(35.0, 2.5)
const AK47_RELOAD_STRIP := preload("res://assets/textures/guns/akReload.png")
const UZI_RELOAD_STRIP := preload("res://assets/textures/guns/uziReload.png")
const AK47_RELOAD_FRAME_SIZE := Vector2i(89, 39)
const UZI_RELOAD_FRAME_SIZE := Vector2i(64, 64)
const AK47_RELOAD_FRAME_COUNT := 15
const UZI_RELOAD_FRAME_COUNT := 13
const AK47_RELOAD_FRAME_DURATION_SEC := 1.0 / 15.0
const UZI_RELOAD_FRAME_DURATION_SEC := 1.0 / 13.0
const ESCAPE_LEAVE_TIMEOUT_SEC := 1.25

var weapon_idle_texture_by_id: Dictionary = {}
var weapon_reload_frames_by_id: Dictionary = {}

func _request_lobby_list() -> void:
	if not _is_client_connected():
		return
	_rpc_request_lobby_list.rpc_id(1)

func _request_spawn_from_server() -> void:
	if role != Role.CLIENT:
		return
	if multiplayer.multiplayer_peer == null:
		return
	if spawn_request_sent:
		return
	spawn_request_sent = true
	_rpc_request_spawn.rpc_id(1)

func _set_role(new_role: int) -> void:
	role = new_role
	if role == Role.SERVER and multiplayer.is_server() and not _uses_lobby_scene_flow():
		call_deferred("_spawn_server_local_if_needed")
	_update_buttons()
	_update_ui_visibility()

func _spawn_server_local_if_needed() -> void:
	if role != Role.SERVER:
		return
	if multiplayer.multiplayer_peer == null:
		return
	if not _should_spawn_local_server_player():
		return
	_server_spawn_peer_if_needed(multiplayer.get_unique_id(), 1)

func _should_spawn_local_server_player() -> bool:
	if OS.has_feature("dedicated_server") or OS.has_feature("server"):
		return false
	return DisplayServer.get_name().to_lower() != "headless"

func _get_role() -> int:
	return role

func _reset_runtime_state() -> void:
	snapshot_accumulator = 0.0
	escape_return_pending = false
	escape_return_nonce += 1
	_clear_players()
	projectile_system.clear()
	input_states.clear()
	fire_cooldowns.clear()
	player_history.clear()
	input_rate_window_start_ms.clear()
	input_rate_counts.clear()
	spawn_slots.clear()
	player_stats.clear()
	player_display_names.clear()
	ammo_by_peer.clear()
	reload_remaining_by_peer.clear()
	peer_weapon_ids.clear()
	peer_character_ids.clear()
	peer_skin_indices_by_peer.clear()
	_reset_spawn_request_state()
	_reset_ping_state()
	client_input_controller.reset()
	camera_shake.reset()
	if _uses_lobby_scene_flow():
		lobby_service.reset(true)
		lobby_entries.clear()
		lobby_map_by_id.clear()
		client_lobby_id = 0
		lobby_auto_action_inflight = false
	_update_score_labels()
	_update_peer_labels()

func _clear_players() -> void:
	for value in players.values():
		var player := value as NetPlayer
		if is_instance_valid(player):
			player.queue_free()
	players.clear()

func _reset_ping_state() -> void:
	ping_accumulator = 0.0
	last_ping_ms = -1

func _reset_spawn_request_state() -> void:
	spawn_request_sent = false

func _set_client_lobby_id(value: int) -> void:
	client_lobby_id = maxi(0, value)
	_refresh_lobby_buttons()

func _set_lobby_auto_action_inflight(value: bool) -> void:
	lobby_auto_action_inflight = value
	_refresh_lobby_buttons()

func _clear_lobby_list() -> void:
	lobby_entries.clear()
	lobby_map_by_id.clear()
	ui_controller.clear_lobby_list()
	_refresh_lobby_buttons()

func _set_lobby_status(text: String) -> void:
	ui_controller.set_lobby_status(text)

func _refresh_lobby_list_ui(entries: Array, active_lobby_id: int) -> void:
	lobby_entries = entries.duplicate(true)
	ui_controller.refresh_lobby_list_ui(entries, active_lobby_id, map_catalog.max_players_for_id(selected_map_id))
	_refresh_lobby_buttons()

func _refresh_lobby_buttons() -> void:
	ui_controller.update_lobby_buttons_state(_is_client_connected(), client_lobby_id > 0)
	if not lobby_auto_action_inflight:
		return
	if lobby_create_button != null:
		lobby_create_button.disabled = true
	if lobby_join_button != null:
		lobby_join_button.disabled = true
	if lobby_refresh_button != null:
		lobby_refresh_button.disabled = true
	if lobby_leave_button != null:
		lobby_leave_button.disabled = true

func _update_buttons() -> void:
	startup_mode = session_controller.get_startup_mode()
	var has_active_session := role != Role.NONE
	var server_allowed := startup_mode != Role.CLIENT
	var client_allowed := startup_mode != Role.SERVER
	ui_controller.update_buttons(
		has_active_session,
		server_allowed,
		client_allowed,
		role == Role.SERVER,
		role == Role.CLIENT
	)
	_refresh_lobby_buttons()

func _update_peer_labels() -> void:
	var spawned_ids := players.keys()
	spawned_ids.sort()
	var local_peer_id := 0
	var net_peers := PackedInt32Array()
	if multiplayer != null and multiplayer.multiplayer_peer != null:
		local_peer_id = multiplayer.get_unique_id()
		net_peers = multiplayer.get_peers()
	ui_controller.update_peer_labels(
		local_peer_id,
		net_peers,
		spawned_ids,
		ui_controller.local_ping_text(role == Role.SERVER, role == Role.CLIENT, last_ping_ms)
	)

func _update_ping_label() -> void:
	ui_controller.update_ping_label(ui_controller.local_ping_text(role == Role.SERVER, role == Role.CLIENT, last_ping_ms))

func _update_ui_visibility() -> void:
	ui_controller.update_ui_visibility(
		_uses_lobby_scene_flow(),
		role == Role.SERVER,
		role == Role.CLIENT,
		_is_local_player_spawned(),
		scoreboard_visible,
		true,
		true
	)

func _update_score_labels() -> void:
	var local_peer_id := 0
	if multiplayer != null and multiplayer.multiplayer_peer != null:
		local_peer_id = multiplayer.get_unique_id()
	ui_controller.update_kd_label(local_peer_id, player_stats)
	ui_controller.update_scoreboard_label(player_stats, player_display_names)
	# Cooldown UI is updated per-frame in runtime_controller (client only).

func _cooldown_text(prefix: String, remaining_sec: float) -> String:
	if remaining_sec <= 0.0:
		return "%s: Ready" % prefix
	return "%s: %.1fs" % [prefix, remaining_sec]

func _update_skill_cooldowns_hud(q_remaining: float, e_remaining: float) -> void:
	if ui_controller == null:
		return
	ui_controller.update_skill_cooldowns(_cooldown_text("Q", q_remaining), _cooldown_text("E", e_remaining))

func client_set_status_text(text: String) -> void:
	if ui_controller == null:
		return
	if ui_controller.has_method("set_status_text"):
		ui_controller.call("set_status_text", text)

func _show_local_ip() -> void:
	var ips := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.contains(".") and not address.begins_with("127."):
			ips.append(address)
	if ips.is_empty():
		local_ip_label.text = "Local IP: 127.0.0.1"
	else:
		local_ip_label.text = "Local IP(s): %s" % ", ".join(ips)

func _append_log(message: String) -> void:
	print("[runtime] %s" % message)
	if log_label == null:
		return
	log_label.append_text("%s\n" % message)
	log_label.scroll_to_line(max(log_label.get_line_count() - 1, 0))

func _client_ping_tick(delta: float) -> void:
	if role != Role.CLIENT:
		return
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	var peer := multiplayer.multiplayer_peer
	if peer is OfflineMultiplayerPeer:
		return
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	ping_accumulator += delta
	if ping_accumulator < PING_INTERVAL:
		return
	ping_accumulator = 0.0
	_rpc_ping_request.rpc_id(1, Time.get_ticks_msec())

func _spawn_player_local(peer_id: int, spawn_position: Vector2) -> void:
	if _uses_lobby_scene_flow():
		return
	var resolved_spawn := spawn_flow_service.sanitize_spawn_position(spawn_position, _get_world_2d_ref(), 1)
	if players.has(peer_id):
		var existing := players[peer_id] as NetPlayer
		if existing != null:
			existing.set_weapon_visual(_weapon_visual_for_id(_weapon_id_for_peer(peer_id)))
			if existing.has_method("set_character_visual"):
				existing.call("set_character_visual", _warrior_id_for_peer(peer_id))
			if existing.has_method("set_skin_index") and peer_skin_indices_by_peer.has(peer_id):
				existing.call("set_skin_index", int(peer_skin_indices_by_peer.get(peer_id, 1)))
			existing.force_respawn(resolved_spawn)
		return

	var player := PLAYER_SCENE.instantiate() as NetPlayer
	if player == null:
		return
	player.global_position = resolved_spawn
	players_root.add_child(player)
	player.configure(peer_id, _player_color(peer_id))
	player.use_network_smoothing = role == Role.CLIENT and peer_id != multiplayer.get_unique_id()
	player.set_weapon_visual(_weapon_visual_for_id(_weapon_id_for_peer(peer_id)))
	if player.has_method("set_character_visual"):
		player.call("set_character_visual", _warrior_id_for_peer(peer_id))
	if player.has_method("set_skin_index") and peer_skin_indices_by_peer.has(peer_id):
		player.call("set_skin_index", int(peer_skin_indices_by_peer.get(peer_id, 1)))
	player.set_shot_audio_stream(_weapon_shot_sfx(_weapon_id_for_peer(peer_id)))
	player.set_reload_audio_stream(_weapon_reload_sfx(_weapon_id_for_peer(peer_id)))
	if ammo_by_peer.has(peer_id):
		player.set_ammo(int(ammo_by_peer[peer_id]), float(reload_remaining_by_peer.get(peer_id, 0.0)) > 0.0)

	players[peer_id] = player
	combat_flow_service.record_player_history(peer_id, resolved_spawn)
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
	peer_weapon_ids.erase(peer_id)
	peer_character_ids.erase(peer_id)
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
	peer_weapon_ids.erase(peer_id)
	peer_character_ids.erase(peer_id)
	spawn_slots.erase(peer_id)
	_update_peer_labels()
	_update_score_labels()

func _server_return_to_lobby_scene_if_idle() -> void:
	if not multiplayer.is_server():
		return
	if _uses_lobby_scene_flow():
		return
	if multiplayer.multiplayer_peer == null:
		return
	if not multiplayer.get_peers().is_empty():
		return

	_append_log("No remote peers connected. Returning server to lobby scene.")
	_request_lobby_scene_switch()

func _return_to_lobby_scene(disconnect_session: bool = true) -> void:
	escape_return_pending = false
	escape_return_nonce += 1
	if disconnect_session and session_controller != null:
		match role:
			Role.SERVER:
				session_controller.stop_server()
			Role.CLIENT:
				session_controller.disconnect_client()
			_:
				session_controller.close_peer()
				session_controller.set_idle_state()
	_request_lobby_scene_switch()

func _begin_escape_return_to_lobby_menu() -> void:
	if _uses_lobby_scene_flow():
		return
	if escape_return_pending:
		return

	escape_return_pending = true
	escape_return_nonce += 1
	var nonce := escape_return_nonce
	_append_log("Escape pressed: leaving match and returning to lobby menu.")

	if role == Role.CLIENT and _is_client_connected() and client_lobby_id > 0:
		lobby_auto_action_inflight = true
		_refresh_lobby_buttons()
		_set_lobby_status("Leaving lobby...")
		_rpc_lobby_leave.rpc_id(1)
		var tree := get_tree()
		if tree != null:
			var timeout := tree.create_timer(ESCAPE_LEAVE_TIMEOUT_SEC)
			timeout.timeout.connect(Callable(self, "_on_escape_leave_timeout").bind(nonce))
			return

	_complete_escape_return_to_lobby_menu(nonce)

func _on_escape_leave_timeout(nonce: int) -> void:
	if not escape_return_pending or nonce != escape_return_nonce:
		return
	_append_log("Escape leave confirmation timed out. Forcing return to lobby menu.")
	_complete_escape_return_to_lobby_menu(nonce)

func _complete_escape_return_to_lobby_menu(nonce: int) -> void:
	if not escape_return_pending or nonce != escape_return_nonce:
		return
	_return_to_lobby_scene(true)

func _request_lobby_scene_switch() -> void:
	var lobby_scene_path := _lobby_scene_path()
	if scene_file_path == lobby_scene_path:
		return
	if pending_scene_switch == lobby_scene_path:
		return
	pending_scene_switch = lobby_scene_path
	call_deferred("_deferred_scene_switch")

func _lobby_scene_path() -> String:
	var lobby_scene_path := str(ProjectSettings.get_setting("application/run/main_scene", "res://scenes/lobby.tscn")).strip_edges()
	if lobby_scene_path.is_empty():
		lobby_scene_path = "res://scenes/lobby.tscn"
	return lobby_scene_path

func _server_spawn_peer_if_needed(peer_id: int, lobby_id: int) -> void:
	_restore_peer_weapon_from_lobby_service(peer_id)
	var effective_lobby := lobby_id
	if effective_lobby <= 0:
		effective_lobby = _peer_lobby(peer_id)
	if effective_lobby <= 0 and not _uses_lobby_scene_flow() and not _has_active_lobbies():
		effective_lobby = 1
	if effective_lobby <= 0:
		return
	if _uses_lobby_scene_flow():
		var lobby_map_id := _lobby_map_id(effective_lobby)
		if lobby_map_id.is_empty():
			lobby_map_id = selected_map_id
		_server_switch_lobby_to_map_scene(effective_lobby, lobby_map_id, peer_id)
		return
	combat_flow_service.server_spawn_peer_if_needed(peer_id, effective_lobby)
	_update_peer_labels()
	_update_score_labels()

func _server_switch_lobby_to_map_scene(lobby_id: int, map_id: String, trigger_peer_id: int = 0) -> void:
	if lobby_id <= 0:
		return
	var normalized_map := map_flow_service.normalize_map_id(map_catalog, map_id)
	var target_scene := map_flow_service.scene_path_for_id(map_catalog, normalized_map)
	if target_scene.strip_edges().is_empty():
		return
	if scene_file_path == target_scene or pending_scene_switch == target_scene:
		return

	var recipients := _lobby_members(lobby_id)
	if recipients.is_empty() and trigger_peer_id > 0:
		recipients.append(trigger_peer_id)
	var self_peer_id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
	for member_value in recipients:
		var member_id := int(member_value)
		if member_id <= 0:
			continue
		if member_id == self_peer_id:
			continue
		_send_scene_switch_rpc(member_id, normalized_map)

	if multiplayer.is_server():
		_switch_to_map_scene(normalized_map)

func _server_sync_player_stats(peer_id: int) -> void:
	player_replication.server_sync_player_stats(peer_id)

func _server_register_kill_death(attacker_peer_id: int, target_peer_id: int) -> void:
	player_replication.server_register_kill_death(attacker_peer_id, target_peer_id)
	_update_score_labels()

func _server_respawn_player(peer_id: int, player: NetPlayer) -> void:
	combat_flow_service.server_respawn_player(peer_id, player)

func _server_broadcast_player_state(peer_id: int, player: NetPlayer) -> void:
	player_replication.server_broadcast_player_state(peer_id, player)

func _server_send_lobby_list_to_peer(peer_id: int) -> void:
	var entries := lobby_service.pack_lobby_list()
	var packed_entries := map_flow_service.server_pack_lobby_entries(entries, map_catalog)
	_rpc_lobby_list.rpc_id(peer_id, packed_entries, _peer_lobby(peer_id))
	if peer_id == multiplayer.get_unique_id():
		_rpc_lobby_list(packed_entries, _peer_lobby(peer_id))

func _server_broadcast_lobby_list() -> void:
	for peer_id in multiplayer.get_peers():
		_server_send_lobby_list_to_peer(int(peer_id))
	if multiplayer.is_server():
		_server_send_lobby_list_to_peer(multiplayer.get_unique_id())

func _server_send_lobby_action_result(peer_id: int, success: bool, message: String, active_lobby_id: int, map_id: String = "") -> void:
	_rpc_lobby_action_result.rpc_id(peer_id, success, message, active_lobby_id, map_id, _uses_lobby_scene_flow())
	if peer_id == multiplayer.get_unique_id():
		_rpc_lobby_action_result(success, message, active_lobby_id, map_id, _uses_lobby_scene_flow())

func _send_scene_switch_rpc(peer_id: int, map_id: String) -> void:
	var normalized_map := map_flow_service.normalize_map_id(map_catalog, map_id)
	_rpc_scene_switch_to_map.rpc_id(peer_id, normalized_map)
	if peer_id == multiplayer.get_unique_id():
		_rpc_scene_switch_to_map(normalized_map)

func _try_switch_to_target_map_scene() -> void:
	if not _uses_lobby_scene_flow():
		return
	if role == Role.NONE:
		return
	if client_lobby_id <= 0:
		return
	var target_map_id := map_flow_service.effective_target_map_id(
		map_catalog,
		role,
		Role.SERVER,
		selected_map_id,
		client_target_map_id,
		client_lobby_id,
		lobby_map_by_id
	)
	_switch_to_map_scene(target_map_id)

func _switch_to_map_scene(map_id: String) -> void:
	var normalized_map := map_flow_service.normalize_map_id(map_catalog, map_id)
	var scene_path := map_flow_service.scene_path_for_id(map_catalog, normalized_map)
	if scene_path.strip_edges().is_empty():
		scene_path = map_flow_service.scene_path_for_id(map_catalog, map_catalog.default_map_id())
	if scene_path.strip_edges().is_empty():
		return
	if scene_path == scene_file_path:
		return
	pending_scene_switch = scene_path
	_append_log("Scene switch request: lobby_id=%d map=%s scene=%s" % [client_lobby_id, normalized_map, scene_path])
	call_deferred("_deferred_scene_switch")

func _deferred_scene_switch() -> void:
	if pending_scene_switch.strip_edges().is_empty():
		return
	var target_scene := pending_scene_switch
	pending_scene_switch = ""
	var err := get_tree().change_scene_to_file(target_scene)
	if err != OK:
		_append_log("Scene switch failed: %s" % error_string(err))

func _send_spawn_player_rpc(target_peer_id: int, peer_id: int, spawn_position: Vector2, display_name: String) -> void:
	var warrior_id = _warrior_id_for_peer(peer_id)
	print("[DBG SPAWN] Sending spawn RPC to peer %d for peer_id %d with warrior_id=%s (from peer_character_ids[%d]=%s)" % [target_peer_id, peer_id, warrior_id, peer_id, peer_character_ids.get(peer_id, "NOT SET")])
	var skin_index: int = 0
	if lobby_service != null:
		skin_index = int(lobby_service.get_peer_skin(peer_id, 0))
	if skin_index <= 0:
		skin_index = int(peer_skin_indices_by_peer.get(peer_id, 0))
	if skin_index <= 0 and warrior_id == CHARACTER_ID_OUTRAGE:
		skin_index = 12
	_rpc_spawn_player.rpc_id(
		target_peer_id,
		peer_id,
		spawn_position,
		display_name,
		_weapon_id_for_peer(peer_id),
		warrior_id,
		skin_index
	)

func _broadcast_despawn_player_rpc(peer_id: int) -> void:
	_rpc_despawn_player.rpc(peer_id)

func _send_despawn_player_rpc_to_peer(target_peer_id: int, peer_id: int) -> void:
	_rpc_despawn_player.rpc_id(target_peer_id, peer_id)

func _send_sync_player_state_rpc(target_peer_id: int, peer_id: int, new_position: Vector2, new_velocity: Vector2, aim_angle: float, health: int) -> void:
	_rpc_sync_player_state.rpc_id(target_peer_id, peer_id, new_position, new_velocity, aim_angle, health)

func _send_sync_player_stats_rpc(target_peer_id: int, peer_id: int, kills: int, deaths: int) -> void:
	_rpc_sync_player_stats.rpc_id(target_peer_id, peer_id, kills, deaths)

func _send_input_rpc(axis: float, jump_pressed: bool, jump_held: bool, aim_world: Vector2, shoot_held: bool, boost_damage: bool, reported_rtt_ms: int) -> void:
	_rpc_submit_input.rpc_id(1, axis, jump_pressed, jump_held, aim_world, shoot_held, boost_damage, reported_rtt_ms)

func _send_player_ammo_rpc(target_peer_id: int, peer_id: int, ammo: int, is_reloading: bool) -> void:
	_rpc_sync_player_ammo.rpc_id(target_peer_id, peer_id, ammo, is_reloading)

func _send_reload_sfx_rpc(target_peer_id: int, peer_id: int, weapon_id: String) -> void:
	_rpc_play_reload_sfx.rpc_id(target_peer_id, peer_id, weapon_id)

func _send_spawn_projectile_rpc(target_peer_id: int, projectile_id: int, owner_peer_id: int, spawn_position: Vector2, velocity: Vector2, lag_comp_ms: int, trail_origin: Vector2, weapon_id: String) -> void:
	_rpc_spawn_projectile.rpc_id(target_peer_id, projectile_id, owner_peer_id, spawn_position, velocity, lag_comp_ms, trail_origin, weapon_id)

func _send_spawn_blood_particles_rpc(target_peer_id: int, impact_position: Vector2, incoming_velocity: Vector2) -> void:
	_rpc_spawn_blood_particles.rpc_id(target_peer_id, impact_position, incoming_velocity)

func _send_spawn_surface_particles_rpc(target_peer_id: int, impact_position: Vector2, incoming_velocity: Vector2, particle_color: Color) -> void:
	_rpc_spawn_surface_particles.rpc_id(target_peer_id, impact_position, incoming_velocity, particle_color)

func _send_projectile_impact_rpc(target_peer_id: int, projectile_id: int, impact_position: Vector2) -> void:
	_rpc_projectile_impact.rpc_id(target_peer_id, projectile_id, impact_position)

func _send_despawn_projectile_rpc(target_peer_id: int, projectile_id: int) -> void:
	_rpc_despawn_projectile.rpc_id(target_peer_id, projectile_id)

func _play_death_sfx_local(impact_position: Vector2) -> void:
	combat_effects.play_death_sfx(impact_position)

func _send_play_death_sfx_rpc(target_peer_id: int, impact_position: Vector2) -> void:
	_rpc_play_death_sfx.rpc_id(target_peer_id, impact_position)

func _send_spawn_outrage_bomb_rpc(target_peer_id: int, caster_peer_id: int, world_position: Vector2, fuse_sec: float) -> void:
	_rpc_spawn_outrage_bomb.rpc_id(target_peer_id, caster_peer_id, world_position, fuse_sec)

func _send_spawn_erebus_immunity_rpc(target_peer_id: int, caster_peer_id: int, duration_sec: float) -> void:
	_rpc_spawn_erebus_immunity.rpc_id(target_peer_id, caster_peer_id, duration_sec)

func _send_spawn_erebus_shield_rpc(target_peer_id: int, caster_peer_id: int, duration_sec: float) -> void:
	_rpc_spawn_erebus_shield.rpc_id(target_peer_id, caster_peer_id, duration_sec)

func _send_skill_cast_rpc(target_peer_id: int, skill_number: int, caster_peer_id: int, target_world: Vector2) -> void:
	"""Generic skill cast RPC dispatcher - routes to appropriate warrior skill RPC"""
	var warrior_id = _warrior_id_for_peer(caster_peer_id)
	match warrior_id:
		"outrage":
			if skill_number == 1:
				# Outrage Skill 1: Bomb Blast
				_rpc_spawn_outrage_bomb.rpc_id(target_peer_id, caster_peer_id, target_world, 0.9)
			elif skill_number == 2:
				# Outrage Skill 2: Damage Boost
				_rpc_spawn_outrage_boost.rpc_id(target_peer_id, caster_peer_id, 4.0)
		"erebus":
			if skill_number == 1:
				# Erebus Skill 1: Immunity
				_rpc_spawn_erebus_immunity.rpc_id(target_peer_id, caster_peer_id, 5.0)
			elif skill_number == 2:
				# Erebus Skill 2: Shield
				_rpc_spawn_erebus_shield.rpc_id(target_peer_id, caster_peer_id, 6.0)
		"tasko":
			if skill_number == 1:
				_rpc_spawn_tasko_invis_field.rpc_id(target_peer_id, caster_peer_id, target_world)
			elif skill_number == 2:
				_rpc_spawn_tasko_mine.rpc_id(target_peer_id, caster_peer_id, target_world)

func _warrior_id_for_peer(peer_id: int) -> String:
	var normalized := str(peer_character_ids.get(peer_id, "")).strip_edges().to_lower()
	if normalized == CHARACTER_ID_EREBUS:
		return CHARACTER_ID_EREBUS
	if normalized == CHARACTER_ID_OUTRAGE:
		return CHARACTER_ID_OUTRAGE
	if normalized == CHARACTER_ID_TASKO:
		return CHARACTER_ID_TASKO
	if lobby_service != null:
		var persisted := str(lobby_service.get_peer_character(peer_id, "")).strip_edges().to_lower()
		if persisted == CHARACTER_ID_EREBUS:
			peer_character_ids[peer_id] = CHARACTER_ID_EREBUS
			return CHARACTER_ID_EREBUS
		if persisted == CHARACTER_ID_OUTRAGE:
			peer_character_ids[peer_id] = CHARACTER_ID_OUTRAGE
			return CHARACTER_ID_OUTRAGE
		if persisted == CHARACTER_ID_TASKO:
			peer_character_ids[peer_id] = CHARACTER_ID_TASKO
			return CHARACTER_ID_TASKO
	# Fallback to local selection for local peer (useful before server echoes selection).
	if multiplayer != null and multiplayer.multiplayer_peer != null and peer_id == multiplayer.get_unique_id():
		var local_normalized := str(selected_character_id).strip_edges().to_lower()
		if local_normalized == CHARACTER_ID_EREBUS:
			return CHARACTER_ID_EREBUS
		if local_normalized == CHARACTER_ID_TASKO:
			return CHARACTER_ID_TASKO
		return CHARACTER_ID_OUTRAGE
	return CHARACTER_ID_OUTRAGE

func _default_input_state() -> Dictionary:
	return {
		"axis": 0.0,
		"jump_pressed": false,
		"jump_held": false,
		"aim_world": Vector2.ZERO,
		"shoot_held": false,
		"boost_damage": false,
		"reported_rtt_ms": 0
	}

func _spawn_position_for_peer(peer_id: int) -> Vector2:
	return spawn_identity.spawn_position_for_peer(peer_id)

func _random_spawn_position() -> Vector2:
	return spawn_identity.random_spawn_position()

func _ensure_player_display_name(peer_id: int) -> String:
	return spawn_identity.ensure_player_display_name(peer_id)

func _player_color(peer_id: int) -> Color:
	return spawn_identity.player_color(peer_id)

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
	if normalized == WEAPON_ID_UZI:
		idle_texture = weapon_idle_texture_by_id.get(WEAPON_ID_UZI, idle_texture)
		reload_texture_frames = weapon_reload_frames_by_id.get(WEAPON_ID_UZI, reload_texture_frames)
		muzzle_position = UZI_MUZZLE_POSITION
		reload_frame_duration_sec = UZI_RELOAD_FRAME_DURATION_SEC
	return {
		"texture": idle_texture,
		"region_enabled": false,
		"gun_position": GUN_BASE_POSITION,
		"muzzle_position": muzzle_position,
		"reload_texture_frames": reload_texture_frames,
		"reload_frame_duration_sec": reload_frame_duration_sec
	}

func _ensure_weapon_visual_texture_cache() -> void:
	if not weapon_idle_texture_by_id.is_empty() and not weapon_reload_frames_by_id.is_empty():
		return
	var ak_frames := _slice_strip_frames(AK47_RELOAD_STRIP, AK47_RELOAD_FRAME_SIZE, AK47_RELOAD_FRAME_COUNT)
	var uzi_frames := _slice_strip_frames(UZI_RELOAD_STRIP, UZI_RELOAD_FRAME_SIZE, UZI_RELOAD_FRAME_COUNT)
	weapon_reload_frames_by_id[WEAPON_ID_AK47] = ak_frames
	weapon_reload_frames_by_id[WEAPON_ID_UZI] = uzi_frames
	weapon_idle_texture_by_id[WEAPON_ID_AK47] = _first_texture_or_fallback(ak_frames, AK47_GUN_FALLBACK_REGION)
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
		frame.region = Rect2(
			float(frame_index * frame_size.x),
			0.0,
			float(frame_size.x),
			float(frame_size.y)
		)
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
	if peer_id == multiplayer.get_unique_id():
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

func _normalize_weapon_id(weapon_id: String) -> String:
	var normalized := weapon_id.strip_edges().to_lower()
	if normalized == WEAPON_ID_UZI:
		return WEAPON_ID_UZI
	return WEAPON_ID_AK47

func _normalize_character_id(character_id: String) -> String:
	var normalized := character_id.strip_edges().to_lower()
	if normalized == CHARACTER_ID_EREBUS:
		return CHARACTER_ID_EREBUS
	if normalized == CHARACTER_ID_TASKO:
		return CHARACTER_ID_TASKO
	return CHARACTER_ID_OUTRAGE

func _has_active_lobbies() -> bool:
	return lobby_service != null and lobby_service.has_active_lobbies()

func _peer_lobby(peer_id: int) -> int:
	if lobby_service != null:
		var tracked_lobby := lobby_service.get_peer_lobby(peer_id)
		if tracked_lobby > 0:
			return tracked_lobby
		if lobby_service.has_active_lobbies():
			return 0
	if not _uses_lobby_scene_flow():
		return 1
	return 0

func _lobby_members(lobby_id: int) -> Array:
	if lobby_service != null and lobby_id > 0 and lobby_service.has_lobby(lobby_id):
		return lobby_service.get_lobby_members(lobby_id)
	if lobby_service != null and lobby_service.has_active_lobbies():
		return []
	if not _uses_lobby_scene_flow():
		var members: Array = []
		if multiplayer.multiplayer_peer != null:
			var self_id := multiplayer.get_unique_id()
			if self_id > 0 and not members.has(self_id):
				members.append(self_id)
			for id_value in multiplayer.get_peers():
				var id := int(id_value)
				if not members.has(id):
					members.append(id)
		return members
	return []

func _lobby_map_id(lobby_id: int) -> String:
	if lobby_id <= 0:
		return ""
	var lobby := lobby_service.get_lobby_data(lobby_id)
	if lobby.is_empty():
		return ""
	return map_flow_service.normalize_map_id(map_catalog, str(lobby.get("map_id", MAP_ID_CLASSIC)))

func _lobby_name_value() -> String:
	if lobby_name_input == null:
		return ""
	return lobby_name_input.text.strip_edges()

func _is_client_connected() -> bool:
	if role != Role.CLIENT:
		return false
	if multiplayer.multiplayer_peer == null:
		return false
	return multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _is_local_player_spawned() -> bool:
	if multiplayer.multiplayer_peer == null:
		return false
	var local_id := multiplayer.get_unique_id()
	return local_id > 0 and players.has(local_id)

func _uses_lobby_scene_flow() -> bool:
	return enable_lobby_scene_flow

func _get_world_2d_ref() -> World2D:
	return get_world_2d()

func _first_private_ipv4() -> String:
	for address in IP.get_local_addresses():
		if not address.contains("."):
			continue
		if address.begins_with("127."):
			continue
		if address.begins_with("169.254."):
			continue
		return address
	return ""

func _role_name(value: int) -> String:
	match value:
		Role.SERVER:
			return "server"
		Role.CLIENT:
			return "client"
		_:
			return "manual"
