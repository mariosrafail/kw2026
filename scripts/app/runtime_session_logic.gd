extends "res://scripts/app/runtime_world_logic.gd"

func _connect_local_signals() -> void:
	start_server_button.pressed.connect(_on_start_server_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	connect_button.pressed.connect(_on_connect_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)

	if lobby_create_button != null:
		lobby_create_button.pressed.connect(_on_lobby_create_pressed)
	if lobby_join_button != null:
		lobby_join_button.pressed.connect(_on_lobby_join_pressed)
	if lobby_refresh_button != null:
		lobby_refresh_button.pressed.connect(_on_lobby_refresh_pressed)
	if lobby_leave_button != null:
		lobby_leave_button.pressed.connect(_on_lobby_leave_pressed)
	if lobby_list != null:
		lobby_list.item_selected.connect(_on_lobby_list_item_selected)
		lobby_list.empty_clicked.connect(_on_lobby_list_empty_clicked)
	if lobby_weapon_option != null:
		lobby_weapon_option.item_selected.connect(_on_lobby_weapon_selected)
	if lobby_character_option != null:
		lobby_character_option.item_selected.connect(_on_lobby_character_selected)
	if lobby_map_option != null:
		lobby_map_option.item_selected.connect(_on_lobby_map_selected)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _setup_ui_defaults() -> void:
	_setup_weapon_picker()
	_setup_character_picker()
	_setup_map_picker()
	_refresh_lobby_buttons()
	_update_peer_labels()
	_update_ping_label()
	_update_buttons()
	_update_ui_visibility()
	_update_score_labels()

func _setup_weapon_picker() -> void:
	if lobby_weapon_option == null:
		return
	lobby_weapon_option.clear()
	lobby_weapon_option.add_item("AK47")
	lobby_weapon_option.set_item_metadata(0, WEAPON_ID_AK47)
	lobby_weapon_option.add_item("Uzi")
	lobby_weapon_option.set_item_metadata(1, WEAPON_ID_UZI)
	var target_weapon := _normalize_weapon_id(selected_weapon_id)
	for index in range(lobby_weapon_option.item_count):
		if _normalize_weapon_id(str(lobby_weapon_option.get_item_metadata(index))) == target_weapon:
			lobby_weapon_option.select(index)
			break

func _setup_map_picker() -> void:
	if lobby_map_option == null:
		return
	map_flow_service.setup_lobby_map_picker(lobby_map_option, map_catalog, selected_map_id)

func _setup_character_picker() -> void:
	if lobby_character_option == null:
		return
	lobby_character_option.clear()
	lobby_character_option.add_item("Outrage")
	lobby_character_option.set_item_metadata(0, CHARACTER_ID_OUTRAGE)
	lobby_character_option.add_item("Erebus")
	lobby_character_option.set_item_metadata(1, CHARACTER_ID_EREBUS)
	var target_character := _normalize_character_id(selected_character_id)
	for index in range(lobby_character_option.item_count):
		if _normalize_character_id(str(lobby_character_option.get_item_metadata(index))) == target_character:
			lobby_character_option.select(index)
			break

func _on_start_server_pressed() -> void:
	session_controller.start_server(int(port_spin.value))
	if role == Role.SERVER and not _uses_lobby_scene_flow() and multiplayer.is_server() and _should_spawn_local_server_player():
		_server_spawn_peer_if_needed(multiplayer.get_unique_id(), 1)

func _on_connect_pressed() -> void:
	session_controller.start_client(host_input.text.strip_edges(), int(port_spin.value), true, _uses_lobby_scene_flow())

func _on_stop_pressed() -> void:
	session_controller.stop_server()

func _on_disconnect_pressed() -> void:
	session_controller.disconnect_client()

func _on_connected_to_server() -> void:
	session_controller.on_connected_to_server()
	if not _uses_lobby_scene_flow():
		_request_spawn_from_server()

func _on_connection_failed() -> void:
	session_controller.on_connection_failed(get_tree(), _uses_lobby_scene_flow())

func _on_server_disconnected() -> void:
	session_controller.on_server_disconnected()

func _on_peer_connected(peer_id: int) -> void:
	_append_log("Peer connected: %d" % peer_id)
	if multiplayer.is_server():
		var peer_lobby_id := _peer_lobby(peer_id)
		if peer_lobby_id > 0:
			_server_spawn_peer_if_needed(peer_id, peer_lobby_id)
		elif not _uses_lobby_scene_flow() and (lobby_service == null or not lobby_service.has_active_lobbies()):
			_server_spawn_peer_if_needed(peer_id, 1)
		if _uses_lobby_scene_flow() or (lobby_service != null and lobby_service.has_active_lobbies()):
			_server_send_lobby_list_to_peer(peer_id)
	_update_peer_labels()

func _on_peer_disconnected(peer_id: int) -> void:
	_append_log("Peer disconnected: %d" % peer_id)
	if multiplayer.is_server():
		if _peer_lobby(peer_id) > 0:
			lobby_flow_controller.server_leave_lobby(peer_id, true, true)
		else:
			_server_remove_player(peer_id, [])
		if not _uses_lobby_scene_flow():
			_server_return_to_lobby_scene_if_idle()
	_update_peer_labels()
	_update_score_labels()

func _on_lobby_create_pressed() -> void:
	if not _is_client_connected() or lobby_auto_action_inflight:
		return
	_persist_local_weapon_selection()
	_persist_local_character_selection()
	lobby_auto_action_inflight = true
	_refresh_lobby_buttons()
	_set_lobby_status("Creating lobby...")
	var payload := map_flow_service.encode_create_lobby_payload(
		map_catalog,
		Callable(self, "_normalize_weapon_id"),
		selected_weapon_id,
		selected_map_id,
		selected_character_id
	)
	_rpc_lobby_create.rpc_id(1, _lobby_name_value(), payload)

func _on_lobby_join_pressed() -> void:
	if not _is_client_connected() or lobby_auto_action_inflight:
		return
	_persist_local_weapon_selection()
	_persist_local_character_selection()
	var lobby_id := ui_controller.selected_lobby_id()
	if lobby_id <= 0:
		_set_lobby_status("Select a lobby first.")
		return
	lobby_auto_action_inflight = true
	_refresh_lobby_buttons()
	_set_lobby_status("Joining lobby...")
	_rpc_lobby_join.rpc_id(1, lobby_id, selected_weapon_id, selected_character_id)

func _on_lobby_refresh_pressed() -> void:
	if not _is_client_connected():
		return
	_request_lobby_list()

func _on_lobby_leave_pressed() -> void:
	if not _is_client_connected() or lobby_auto_action_inflight:
		return
	lobby_auto_action_inflight = true
	_refresh_lobby_buttons()
	_set_lobby_status("Leaving lobby...")
	_rpc_lobby_leave.rpc_id(1)

func _on_lobby_list_item_selected(_index: int) -> void:
	_refresh_lobby_buttons()

func _on_lobby_list_empty_clicked(_position: Vector2, _button_index: int) -> void:
	_refresh_lobby_buttons()

func _on_lobby_weapon_selected(index: int) -> void:
	if lobby_weapon_option == null:
		return
	selected_weapon_id = _normalize_weapon_id(str(lobby_weapon_option.get_item_metadata(index)))
	_persist_local_weapon_selection()
	if _is_client_connected() and client_lobby_id > 0:
		_rpc_lobby_set_weapon.rpc_id(1, selected_weapon_id)

func _on_lobby_character_selected(index: int) -> void:
	if lobby_character_option == null:
		return
	selected_character_id = _normalize_character_id(str(lobby_character_option.get_item_metadata(index)))
	_persist_local_character_selection()
	if _is_client_connected() and client_lobby_id > 0:
		_rpc_lobby_set_character.rpc_id(1, selected_character_id)

func _on_lobby_map_selected(index: int) -> void:
	if lobby_map_option == null:
		return
	selected_map_id = map_flow_service.normalize_map_id(map_catalog, str(lobby_map_option.get_item_metadata(index)))
	if client_lobby_id <= 0:
		client_target_map_id = selected_map_id

func _persist_local_weapon_selection() -> void:
	if lobby_service == null:
		return
	lobby_service.set_local_selected_weapon(selected_weapon_id)
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	var local_peer_id := multiplayer.get_unique_id()
	if local_peer_id <= 0:
		return
	lobby_service.set_peer_weapon(local_peer_id, selected_weapon_id)

func _persist_local_character_selection() -> void:
	if lobby_service == null:
		return
	lobby_service.set_local_selected_character(selected_character_id)
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	var local_peer_id := multiplayer.get_unique_id()
	if local_peer_id <= 0:
		return
	lobby_service.set_peer_character(local_peer_id, selected_character_id)
