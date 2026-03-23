extends RefCounted


func can_issue_lobby_actions(host: Node) -> bool:
	if bool(host.call("_is_client_connected")):
		return true
	var multiplayer_api: MultiplayerAPI = host.get("multiplayer") as MultiplayerAPI
	if multiplayer_api != null and multiplayer_api.multiplayer_peer != null and multiplayer_api.is_server():
		return true
	return false

func on_lobby_create_pressed(host: Node) -> void:
	if not can_issue_lobby_actions(host) or bool(host.get("lobby_auto_action_inflight")):
		return
	host.call("_persist_local_weapon_selection")
	host.call("_persist_local_character_selection")
	host.call("_persist_local_outage_skin_if_needed")
	var auth_username: String = str(host.get("auth_username")).strip_edges()
	if not auth_username.is_empty():
		host.rpc_id(1, "_rpc_lobby_set_display_name", auth_username)
	host.set("lobby_auto_action_inflight", true)
	host.call("_refresh_lobby_buttons")
	host.call("_set_lobby_status", "Creating lobby...")
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
	var lobby_name: String = str(host.call("_lobby_name_value"))
	host.rpc_id(1, "_rpc_lobby_create", lobby_name, payload)

func on_lobby_join_pressed(host: Node) -> void:
	if not can_issue_lobby_actions(host) or bool(host.get("lobby_auto_action_inflight")):
		return
	host.call("_persist_local_weapon_selection")
	host.call("_persist_local_character_selection")
	host.call("_persist_local_outage_skin_if_needed")
	var auth_username: String = str(host.get("auth_username")).strip_edges()
	if not auth_username.is_empty():
		host.rpc_id(1, "_rpc_lobby_set_display_name", auth_username)
	var ui_controller: Object = host.get("ui_controller") as Object
	if ui_controller == null:
		host.call("_set_lobby_status", "Lobby UI unavailable.")
		return
	var lobby_id: int = int(ui_controller.call("selected_lobby_id"))
	if lobby_id <= 0:
		host.call("_set_lobby_status", "Select a lobby first.")
		return
	host.set("lobby_auto_action_inflight", true)
	host.call("_refresh_lobby_buttons")
	host.call("_set_lobby_status", "Joining lobby...")
	print("[DBG CHAR] JOIN pressed -> lobby_id=%d weapon=%s character=%s" % [
		lobby_id,
		str(host.get("selected_weapon_id")),
		str(host.get("selected_character_id"))
	])
	host.rpc_id(1, "_rpc_lobby_join", lobby_id, str(host.get("selected_weapon_id")), str(host.get("selected_character_id")))

func on_lobby_refresh_pressed(host: Node) -> void:
	if not can_issue_lobby_actions(host):
		return
	host.call("_request_lobby_list")

func on_lobby_leave_pressed(host: Node) -> void:
	if not can_issue_lobby_actions(host) or bool(host.get("lobby_auto_action_inflight")):
		return
	host.set("lobby_auto_action_inflight", true)
	host.call("_refresh_lobby_buttons")
	host.call("_set_lobby_status", "Leaving lobby...")
	host.rpc_id(1, "_rpc_lobby_leave")

func on_lobby_list_item_selected(host: Node, _index: int) -> void:
	host.call("_refresh_lobby_buttons")

func on_lobby_list_empty_clicked(host: Node, _position: Vector2, _button_index: int) -> void:
	host.call("_refresh_lobby_buttons")
