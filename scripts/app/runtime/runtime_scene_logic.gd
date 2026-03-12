extends "res://scripts/app/runtime/runtime_bot_logic.gd"

const ESCAPE_LEAVE_TIMEOUT_SEC := 1.25

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

func _return_to_menu_scene(disconnect_session: bool = true) -> void:
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
	_request_menu_scene_switch()

func _begin_escape_return_to_lobby_menu() -> void:
	if escape_return_pending:
		return

	escape_return_pending = true
	escape_return_nonce += 1
	var nonce := escape_return_nonce
	_append_log("Escape pressed: leaving match and returning to lobby menu.")

	var effective_lobby_id := client_lobby_id
	if effective_lobby_id <= 0 and role == Role.CLIENT and lobby_service != null and multiplayer != null and multiplayer.multiplayer_peer != null:
		var local_peer_id := multiplayer.get_unique_id()
		if local_peer_id > 0:
			effective_lobby_id = lobby_service.get_peer_lobby(local_peer_id)

	if role == Role.CLIENT and _is_client_connected() and effective_lobby_id > 0:
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
	if role == Role.CLIENT:
		_return_to_menu_scene(true)
		return
	_return_to_lobby_scene(true)

func _request_menu_scene_switch() -> void:
	var menu_scene_path := _menu_scene_path()
	if scene_file_path == menu_scene_path:
		return
	if pending_scene_switch == menu_scene_path:
		return
	pending_scene_switch = menu_scene_path
	call_deferred("_deferred_scene_switch")

func _request_lobby_scene_switch() -> void:
	var lobby_scene_path := _lobby_scene_path()
	_append_log("Lobby scene request: role=%s is_server=%s display=%s target=%s current=%s pending=%s" % [
		_role_name(role),
		str(multiplayer != null and multiplayer.is_server()),
		DisplayServer.get_name(),
		lobby_scene_path,
		scene_file_path,
		pending_scene_switch
	])
	if scene_file_path == lobby_scene_path:
		return
	if pending_scene_switch == lobby_scene_path:
		return
	pending_scene_switch = lobby_scene_path
	call_deferred("_deferred_scene_switch")

func _lobby_scene_path() -> String:
	var dedicated_lobby_scene := "res://scenes/lobby.tscn"
	var should_use_runtime_lobby := (
		role == Role.SERVER
		or (multiplayer != null and multiplayer.is_server())
		or OS.has_feature("dedicated_server")
		or OS.has_feature("server")
		or DisplayServer.get_name().to_lower() == "headless"
	)
	if should_use_runtime_lobby and ResourceLoader.exists(dedicated_lobby_scene):
		return dedicated_lobby_scene
	var explicit_lobby_scene := "res://scenes/ui/main_menu.tscn"
	if ResourceLoader.exists(explicit_lobby_scene):
		return explicit_lobby_scene
	var lobby_scene_path := str(ProjectSettings.get_setting("application/run/main_scene", explicit_lobby_scene)).strip_edges()
	if lobby_scene_path.is_empty():
		lobby_scene_path = explicit_lobby_scene
	return lobby_scene_path

func _menu_scene_path() -> String:
	var configured := str(ProjectSettings.get_setting("application/run/main_scene", "res://scenes/ui/main_menu.tscn")).strip_edges()
	if configured.is_empty():
		configured = "res://scenes/ui/main_menu.tscn"
	return configured

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
		if _ctf_room_holds_in_lobby(effective_lobby):
			_server_send_lobby_room_state_to_peer(peer_id, effective_lobby)
			return
		var lobby_map_id := _lobby_map_id(effective_lobby)
		if lobby_map_id.is_empty():
			lobby_map_id = selected_map_id
		_server_switch_lobby_to_map_scene(effective_lobby, lobby_map_id, peer_id)
		return
	combat_flow_service.server_spawn_peer_if_needed(peer_id, effective_lobby)
	if _ctf_enabled() and peer_id > 0:
		for controller in bot_controllers:
			if controller == null:
				continue
			var bot_player := players.get(controller.peer_id(), null) as NetPlayer
			if bot_player == null:
				continue
			_send_spawn_player_rpc(peer_id, controller.peer_id(), bot_player.global_position, controller.display_name())
	if dropped_mag_service != null:
		dropped_mag_service.sync_all_to_peer(peer_id)
	_update_peer_labels()
	_update_score_labels()

func _server_switch_lobby_to_map_scene(lobby_id: int, map_id: String, trigger_peer_id: int = 0) -> void:
	if lobby_id <= 0:
		return
	var normalized_map := map_flow_service.normalize_map_id(map_catalog, map_id)
	var lobby_mode := GAME_MODE_DEATHMATCH
	if lobby_service != null:
		var lobby := lobby_service.get_lobby_data(lobby_id)
		if not lobby.is_empty():
			lobby_mode = map_flow_service.normalize_mode_id(str(lobby.get("mode_id", GAME_MODE_DEATHMATCH)))
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
		_append_log("Server lobby->map switch: lobby_id=%d map=%s mode=%s scene=%s" % [lobby_id, normalized_map, lobby_mode, target_scene])
		_switch_to_map_scene(normalized_map, lobby_mode)

func _server_send_lobby_list_to_peer(peer_id: int) -> void:
	var entries := lobby_service.pack_lobby_list()
	var packed_entries := map_flow_service.server_pack_lobby_entries(entries, map_catalog)
	if peer_id == multiplayer.get_unique_id():
		_rpc_lobby_list(packed_entries, _peer_lobby(peer_id))
		return
	_rpc_lobby_list.rpc_id(peer_id, packed_entries, _peer_lobby(peer_id))

func _server_broadcast_lobby_list() -> void:
	for peer_id in multiplayer.get_peers():
		_server_send_lobby_list_to_peer(int(peer_id))
	if multiplayer.is_server():
		_server_send_lobby_list_to_peer(multiplayer.get_unique_id())

func _server_send_lobby_action_result(peer_id: int, success: bool, message: String, active_lobby_id: int, map_id: String = "") -> void:
	print("[LOBBY FLOW] send_action_result peer_id=%d success=%s active_lobby_id=%d map_id=%s message=%s self_peer=%d" % [
		peer_id,
		str(success),
		active_lobby_id,
		map_id,
		message,
		multiplayer.get_unique_id() if multiplayer != null and multiplayer.multiplayer_peer != null else 0
	])
	if peer_id == multiplayer.get_unique_id():
		_rpc_lobby_action_result(success, message, active_lobby_id, map_id, _uses_lobby_scene_flow())
		return
	_rpc_lobby_action_result.rpc_id(peer_id, success, message, active_lobby_id, map_id, _uses_lobby_scene_flow())

func _send_scene_switch_rpc(peer_id: int, map_id: String) -> void:
	var normalized_map := map_flow_service.normalize_map_id(map_catalog, map_id)
	if peer_id == multiplayer.get_unique_id():
		_rpc_scene_switch_to_map(normalized_map)
		return
	_rpc_scene_switch_to_map.rpc_id(peer_id, normalized_map)

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

func _switch_to_map_scene(map_id: String, forced_mode_id: String = "") -> void:
	var normalized_map := map_flow_service.normalize_map_id(map_catalog, map_id)
	var scene_path := map_flow_service.scene_path_for_id(map_catalog, normalized_map)
	if scene_path.strip_edges().is_empty():
		scene_path = map_flow_service.scene_path_for_id(map_catalog, map_catalog.default_map_id())
	if scene_path.strip_edges().is_empty():
		return
	if scene_path == scene_file_path:
		return
	var next_mode := _active_game_mode()
	if not forced_mode_id.strip_edges().is_empty():
		next_mode = map_flow_service.normalize_mode_id(forced_mode_id)
	ProjectSettings.set_setting("kw/pending_game_mode", next_mode)
	pending_scene_switch = scene_path
	_append_log("Scene switch request: lobby_id=%d map=%s mode=%s scene=%s" % [client_lobby_id, normalized_map, next_mode, scene_path])
	call_deferred("_deferred_scene_switch")

func _deferred_scene_switch() -> void:
	if pending_scene_switch.strip_edges().is_empty():
		return
	var target_scene := pending_scene_switch
	pending_scene_switch = ""
	_append_log("Deferred scene switch: target=%s current=%s" % [target_scene, scene_file_path])
	var err := get_tree().change_scene_to_file(target_scene)
	if err != OK:
		_append_log("Scene switch failed: %s" % error_string(err))

func _refresh_lobby_buttons() -> void:
	pass

func _restore_peer_weapon_from_lobby_service(_peer_id: int) -> void:
	pass

func _has_active_lobbies() -> bool:
	return false

func _update_peer_labels() -> void:
	pass

func _update_score_labels() -> void:
	pass

func _role_name(_role_value: int) -> String:
	return "none"
