extends RefCounted


func after_auth_success(host: Node, is_client_role: bool) -> void:
	host.call("_refresh_lobby_buttons")
	host.call("_update_ui_visibility")
	host.call("_update_peer_labels")
	ensure_lobby_connection_after_auth(host, is_client_role)
	if not has_active_runtime_peer(host):
		maybe_dev_auto_create_lobby(host)
	host.call("_api_profile")

func ensure_lobby_connection_after_auth(host: Node, is_client_role: bool) -> void:
	if not bool(host.call("_uses_lobby_scene_flow")):
		if has_active_runtime_peer(host):
			return
		if should_dev_auto_create_lobby_on_autostart(host):
			var session_controller: Object = host.get("session_controller") as Object
			var host_input: LineEdit = host.get("host_input") as LineEdit
			var port_spin: SpinBox = host.get("port_spin") as SpinBox
			if session_controller != null and host_input != null and port_spin != null:
				session_controller.call("start_client", host_input.text.strip_edges(), int(port_spin.value), true, false)
		return

	var session_controller2: Object = host.get("session_controller") as Object
	if session_controller2 == null:
		return

	var multiplayer_api: MultiplayerAPI = host.get("multiplayer") as MultiplayerAPI
	if multiplayer_api != null and multiplayer_api.multiplayer_peer != null and is_client_role:
		var status: int = multiplayer_api.multiplayer_peer.get_connection_status()
		if status == MultiplayerPeer.CONNECTION_CONNECTED:
			var auth_username: String = str(host.get("auth_username")).strip_edges()
			if not auth_username.is_empty():
				host.rpc_id(1, "_rpc_lobby_set_display_name", auth_username)
			host.call("_request_lobby_list")
			return
		if status == MultiplayerPeer.CONNECTION_CONNECTING:
			host.call("_set_lobby_status", "Connecting to server...")
			return

	var host_input2: LineEdit = host.get("host_input") as LineEdit
	var port_spin2: SpinBox = host.get("port_spin") as SpinBox
	if host_input2 != null and port_spin2 != null:
		session_controller2.call("start_client", host_input2.text.strip_edges(), int(port_spin2.value), true, true)

func has_active_runtime_peer(host: Node) -> bool:
	var multiplayer_api: MultiplayerAPI = host.get("multiplayer") as MultiplayerAPI
	if multiplayer_api == null or multiplayer_api.multiplayer_peer == null:
		return false
	return multiplayer_api.is_server() or multiplayer_api.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED

func should_dev_auto_create_lobby_on_autostart(host: Node) -> bool:
	return OS.has_feature("editor") and bool(host.get("dev_auto_login_on_autostart")) and bool(host.get("dev_auto_create_lobby_on_autostart")) and not bool(host.call("_uses_lobby_scene_flow"))

func maybe_dev_auto_create_lobby(host: Node) -> void:
	if not should_dev_auto_create_lobby_on_autostart(host):
		return
	if bool(host.get("_dev_auto_lobby_create_attempted")):
		return
	if not bool(host.call("_is_client_connected")):
		return
	if int(host.get("client_lobby_id")) > 0:
		host.set("_dev_auto_lobby_create_attempted", true)
		return
	host.call_deferred("_dev_auto_create_lobby_if_ready")

func dev_auto_create_lobby_if_ready(host: Node, map_id_classic: int, game_mode_deathmatch: int) -> void:
	if not should_dev_auto_create_lobby_on_autostart(host):
		return
	if bool(host.get("_dev_auto_lobby_create_attempted")):
		return
	if not bool(host.call("_is_client_connected")):
		return
	if bool(host.get("lobby_auto_action_inflight")) or int(host.get("client_lobby_id")) > 0:
		return

	host.set("selected_map_id", map_id_classic)
	host.set("client_target_map_id", map_id_classic)
	host.set("selected_game_mode", game_mode_deathmatch)
	host.set("client_target_game_mode", game_mode_deathmatch)
	host.call("_persist_local_weapon_selection")
	host.call("_persist_local_character_selection")
	host.call("_persist_local_outage_skin_if_needed")

	var auth_username: String = str(host.get("auth_username")).strip_edges()
	if not auth_username.is_empty():
		host.rpc_id(1, "_rpc_lobby_set_display_name", auth_username)

	var lobby_name: String = str(host.get("dev_auto_create_lobby_name")).strip_edges()
	if lobby_name.is_empty():
		lobby_name = "%s lobby" % (auth_username if not auth_username.is_empty() else "mario")

	host.set("lobby_auto_action_inflight", true)
	host.set("_dev_auto_lobby_create_attempted", true)
	host.call("_refresh_lobby_buttons")
	host.call("_set_lobby_status", "Creating dev lobby...")

	var map_flow_service: Object = host.get("map_flow_service") as Object
	var map_catalog: Variant = host.get("map_catalog")
	var selected_weapon_id: String = str(host.get("selected_weapon_id"))
	var selected_map_id: int = int(host.get("selected_map_id"))
	var selected_character_id: String = str(host.get("selected_character_id"))
	var selected_game_mode: int = int(host.get("selected_game_mode"))
	var payload: Variant = map_flow_service.call(
		"encode_create_lobby_payload",
		map_catalog,
		Callable(host, "_normalize_weapon_id"),
		selected_weapon_id,
		selected_map_id,
		selected_character_id,
		selected_game_mode
	)
	host.rpc_id(1, "_rpc_lobby_create", lobby_name, payload)
