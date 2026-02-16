extends RefCounted
class_name LobbyFlowController

var multiplayer: MultiplayerAPI
var lobby_service: LobbyService
var players: Dictionary = {}

var server_remove_player_cb: Callable = Callable()
var server_sync_player_stats_cb: Callable = Callable()
var server_spawn_peer_if_needed_cb: Callable = Callable()
var server_send_lobby_list_to_peer_cb: Callable = Callable()
var server_broadcast_lobby_list_cb: Callable = Callable()
var send_lobby_action_result_cb: Callable = Callable()
var refresh_lobby_list_ui_cb: Callable = Callable()
var update_ui_visibility_cb: Callable = Callable()
var set_client_lobby_id_cb: Callable = Callable()
var set_lobby_auto_action_inflight_cb: Callable = Callable()
var set_lobby_status_cb: Callable = Callable()
var append_log_cb: Callable = Callable()
var is_client_connected_cb: Callable = Callable()
var request_lobby_list_cb: Callable = Callable()

func configure(refs: Dictionary, callbacks: Dictionary) -> void:
	multiplayer = refs.get("multiplayer", null) as MultiplayerAPI
	lobby_service = refs.get("lobby_service", null) as LobbyService
	players = refs.get("players", {}) as Dictionary

	server_remove_player_cb = callbacks.get("server_remove_player", Callable()) as Callable
	server_sync_player_stats_cb = callbacks.get("server_sync_player_stats", Callable()) as Callable
	server_spawn_peer_if_needed_cb = callbacks.get("server_spawn_peer_if_needed", Callable()) as Callable
	server_send_lobby_list_to_peer_cb = callbacks.get("server_send_lobby_list_to_peer", Callable()) as Callable
	server_broadcast_lobby_list_cb = callbacks.get("server_broadcast_lobby_list", Callable()) as Callable
	send_lobby_action_result_cb = callbacks.get("send_lobby_action_result", Callable()) as Callable
	refresh_lobby_list_ui_cb = callbacks.get("refresh_lobby_list_ui", Callable()) as Callable
	update_ui_visibility_cb = callbacks.get("update_ui_visibility", Callable()) as Callable
	set_client_lobby_id_cb = callbacks.get("set_client_lobby_id", Callable()) as Callable
	set_lobby_auto_action_inflight_cb = callbacks.get("set_lobby_auto_action_inflight", Callable()) as Callable
	set_lobby_status_cb = callbacks.get("set_lobby_status", Callable()) as Callable
	append_log_cb = callbacks.get("append_log", Callable()) as Callable
	is_client_connected_cb = callbacks.get("is_client_connected", Callable()) as Callable
	request_lobby_list_cb = callbacks.get("request_lobby_list", Callable()) as Callable

func server_leave_lobby(peer_id: int, remove_player: bool = true, update_lists: bool = true) -> void:
	var lobby_id := _peer_lobby(peer_id)
	if lobby_id <= 0:
		if remove_player and players.has(peer_id) and server_remove_player_cb.is_valid():
			server_remove_player_cb.call(peer_id, [])
		if update_lists:
			_server_broadcast_lobby_list()
		return

	var members := _lobby_members(lobby_id)
	var despawn_targets: Array = []
	for member_value in members:
		var member_id := int(member_value)
		if not despawn_targets.has(member_id):
			despawn_targets.append(member_id)

	if remove_player and server_remove_player_cb.is_valid():
		server_remove_player_cb.call(peer_id, despawn_targets)

	members.erase(peer_id)
	lobby_service.remove_peer_from_lobby(peer_id)

	if members.is_empty():
		lobby_service.remove_lobby(lobby_id)
	else:
		lobby_service.set_lobby_members(lobby_id, members)
		if server_sync_player_stats_cb.is_valid():
			for member_value in members:
				server_sync_player_stats_cb.call(int(member_value))

	if update_lists:
		_server_broadcast_lobby_list()

func server_request_lobby_list(peer_id: int) -> void:
	_server_send_lobby_list_to_peer(peer_id)

func server_create_lobby(
	peer_id: int,
	requested_name: String,
	requested_map_id: String = "classic",
	requested_max_players: int = 0
) -> void:
	if _peer_lobby(peer_id) > 0:
		var existing_lobby_id := _peer_lobby(peer_id)
		_send_lobby_action_result(peer_id, false, "Already in lobby. Leave first.", existing_lobby_id, _lobby_map_id(existing_lobby_id))
		return

	var create_result := lobby_service.create_lobby(peer_id, requested_name, requested_map_id, requested_max_players)
	var lobby_id := int(create_result.get("lobby_id", 0))
	var lobby_name := str(create_result.get("lobby_name", "Lobby %d" % lobby_id))
	var map_id := _lobby_map_id(lobby_id)
	if server_spawn_peer_if_needed_cb.is_valid():
		server_spawn_peer_if_needed_cb.call(peer_id, lobby_id)
	_send_lobby_action_result(peer_id, true, "Created %s" % lobby_name, lobby_id, map_id)
	_server_broadcast_lobby_list()

func server_join_lobby(peer_id: int, lobby_id: int) -> void:
	if not lobby_service.has_lobby(lobby_id):
		var current_lobby_id := _peer_lobby(peer_id)
		_send_lobby_action_result(peer_id, false, "Lobby not found.", current_lobby_id, _lobby_map_id(current_lobby_id))
		_server_send_lobby_list_to_peer(peer_id)
		return

	var current_lobby_id := _peer_lobby(peer_id)
	if current_lobby_id == lobby_id:
		if server_spawn_peer_if_needed_cb.is_valid():
			server_spawn_peer_if_needed_cb.call(peer_id, lobby_id)
		_send_lobby_action_result(peer_id, true, "Already in %s" % lobby_service.get_lobby_name(lobby_id), lobby_id, _lobby_map_id(lobby_id))
		_server_send_lobby_list_to_peer(peer_id)
		return

	var members := _lobby_members(lobby_id)
	if members.size() >= lobby_service.max_players_for_lobby(lobby_id) and not members.has(peer_id):
		_send_lobby_action_result(peer_id, false, "Lobby is full.", current_lobby_id, _lobby_map_id(current_lobby_id))
		_server_send_lobby_list_to_peer(peer_id)
		return

	if current_lobby_id > 0:
		server_leave_lobby(peer_id, true, false)

	if not members.has(peer_id):
		members.append(peer_id)
	lobby_service.set_lobby_members(lobby_id, members)
	lobby_service.assign_peer_to_lobby(peer_id, lobby_id)

	if server_spawn_peer_if_needed_cb.is_valid():
		server_spawn_peer_if_needed_cb.call(peer_id, lobby_id)
	_send_lobby_action_result(peer_id, true, "Joined %s" % lobby_service.get_lobby_name(lobby_id), lobby_id, _lobby_map_id(lobby_id))
	_server_broadcast_lobby_list()

func server_leave_lobby_request(peer_id: int) -> void:
	if _peer_lobby(peer_id) <= 0:
		_send_lobby_action_result(peer_id, false, "Not in lobby.", 0, "")
		_server_send_lobby_list_to_peer(peer_id)
		return
	server_leave_lobby(peer_id, true, true)
	_send_lobby_action_result(peer_id, true, "Left lobby.", 0, "")

func client_receive_lobby_list(entries: Array, active_lobby_id: int) -> void:
	if set_client_lobby_id_cb.is_valid():
		set_client_lobby_id_cb.call(active_lobby_id)
	if refresh_lobby_list_ui_cb.is_valid():
		refresh_lobby_list_ui_cb.call(entries, active_lobby_id)
	if update_ui_visibility_cb.is_valid():
		update_ui_visibility_cb.call()

func client_lobby_action_result(success: bool, message: String, active_lobby_id: int, _lobby_scene_mode: bool) -> void:
	if set_client_lobby_id_cb.is_valid():
		set_client_lobby_id_cb.call(active_lobby_id)
	if set_lobby_auto_action_inflight_cb.is_valid():
		set_lobby_auto_action_inflight_cb.call(false)
	if set_lobby_status_cb.is_valid():
		set_lobby_status_cb.call(message)
	if append_log_cb.is_valid():
		append_log_cb.call("Lobby: %s" % message)
	if is_client_connected_cb.is_valid() and bool(is_client_connected_cb.call()):
		if request_lobby_list_cb.is_valid():
			request_lobby_list_cb.call()
	# Scene transition is triggered by local spawn visibility path to avoid duplicate switches.
	if update_ui_visibility_cb.is_valid():
		update_ui_visibility_cb.call()

func _peer_lobby(peer_id: int) -> int:
	if lobby_service == null:
		return 0
	return lobby_service.get_peer_lobby(peer_id)

func _lobby_members(lobby_id: int) -> Array:
	if lobby_service == null:
		return []
	return lobby_service.get_lobby_members(lobby_id)

func _server_send_lobby_list_to_peer(peer_id: int) -> void:
	if server_send_lobby_list_to_peer_cb.is_valid():
		server_send_lobby_list_to_peer_cb.call(peer_id)

func _server_broadcast_lobby_list() -> void:
	if server_broadcast_lobby_list_cb.is_valid():
		server_broadcast_lobby_list_cb.call()

func _send_lobby_action_result(peer_id: int, success: bool, message: String, active_lobby_id: int, map_id: String = "") -> void:
	if send_lobby_action_result_cb.is_valid():
		send_lobby_action_result_cb.call(peer_id, success, message, active_lobby_id, map_id)

func _lobby_map_id(lobby_id: int) -> String:
	if lobby_id <= 0 or lobby_service == null:
		return ""
	var lobby := lobby_service.get_lobby_data(lobby_id)
	var map_id := str(lobby.get("map_id", "")).strip_edges().to_lower()
	return map_id
