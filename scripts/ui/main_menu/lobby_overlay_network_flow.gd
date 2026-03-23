extends RefCounted
class_name LobbyOverlayNetworkFlow

const CONNECT_WATCHDOG_TIMEOUT_SEC := 8.0

func begin_connect_attempt(host: Object, force_restart: bool, reason: String = "Connecting...", allow_while_connecting: bool = false) -> void:
	var rpc_bridge: Object = host.get("_rpc_bridge") as Object
	if rpc_bridge == null:
		host.call("_log", "begin_connect_attempt aborted rpc_bridge=null")
		return
	if not allow_while_connecting and not force_restart and bool(rpc_bridge.call("is_connecting_to_server")):
		host.call("_log", "begin_connect_attempt skipped already connecting")
		var status_label := host.get("_status_label") as Label
		if status_label != null:
			status_label.text = "Connecting to lobby server..."
		host.call("_refresh_lobby_buttons_state")
		return

	var connect_candidates := host.get("_connect_candidates") as Array
	if force_restart or connect_candidates.is_empty():
		connect_candidates = host.call("_build_connect_candidates") as Array
		host.set("_connect_candidates", connect_candidates)
		host.set("_connect_candidate_index", 0)

	var connect_candidate_index := int(host.get("_connect_candidate_index"))
	if connect_candidate_index < 0 or connect_candidate_index >= connect_candidates.size():
		connect_candidates = host.call("_build_connect_candidates") as Array
		host.set("_connect_candidates", connect_candidates)
		host.set("_connect_candidate_index", 0)
		connect_candidate_index = 0

	if connect_candidates.is_empty():
		host.call("_log", "begin_connect_attempt failed no candidates")
		var status_label_empty := host.get("_status_label") as Label
		if status_label_empty != null:
			status_label_empty.text = "No lobby server host configured"
		host.set("_action_inflight", false)
		host.call("_refresh_lobby_buttons_state")
		return

	var endpoint := connect_candidates[connect_candidate_index] as Dictionary
	var target_host := str(endpoint.get("host", "127.0.0.1"))
	var target_port := int(endpoint.get("port", 8080))
	var pending_create_request := host.get("_pending_create_request") as Dictionary
	host.call("_log", "begin_connect_attempt force_restart=%s reason=%s candidate_index=%d target=%s:%d pending_create=%s" % [
		str(force_restart),
		reason,
		connect_candidate_index,
		target_host,
		target_port,
		str(not pending_create_request.is_empty())
	])

	var status_label := host.get("_status_label") as Label
	if status_label != null:
		status_label.text = "%s %s:%d..." % [reason, target_host, target_port]
	rpc_bridge.call("disconnect_from_server")
	rpc_bridge.call("connect_to_server", target_host, target_port)
	start_connect_watchdog(host)
	host.call("_refresh_lobby_buttons_state")

func start_connect_watchdog(host: Object) -> void:
	var owner := host.get("_host") as Control
	if owner == null or owner.get_tree() == null:
		return
	var connect_nonce := int(host.get("_connect_nonce")) + 1
	host.set("_connect_nonce", connect_nonce)
	var nonce := connect_nonce
	host.call("_log", "start_connect_watchdog nonce=%d" % nonce)
	var timer := owner.get_tree().create_timer(CONNECT_WATCHDOG_TIMEOUT_SEC)
	timer.timeout.connect(func() -> void:
		if nonce != int(host.get("_connect_nonce")):
			return
		var rpc_bridge: Object = host.get("_rpc_bridge") as Object
		if rpc_bridge != null and bool(rpc_bridge.call("can_send_lobby_rpc")):
			host.call("_log", "watchdog nonce=%d sees connected rpc bridge" % nonce)
			return
		host.call("_log", "watchdog timeout nonce=%d advancing candidate" % nonce)
		host.call("_try_next_connect_candidate")
	)

func try_next_connect_candidate(host: Object) -> void:
	var connect_candidate_index := int(host.get("_connect_candidate_index")) + 1
	host.set("_connect_candidate_index", connect_candidate_index)
	var connect_candidates := host.get("_connect_candidates") as Array
	host.call("_log", "try_next_connect_candidate next_index=%d total=%d" % [connect_candidate_index, connect_candidates.size()])
	if connect_candidate_index >= connect_candidates.size():
		var pending_create_request := host.get("_pending_create_request") as Dictionary
		var had_pending_create := not pending_create_request.is_empty()
		var rpc_bridge: Object = host.get("_rpc_bridge") as Object
		if had_pending_create and rpc_bridge != null:
			var map_id: String = str(pending_create_request.get("map_id", "")).strip_edges().to_lower()
			var mode_id: String = str(pending_create_request.get("mode_id", "deathmatch")).strip_edges().to_lower()
			host.call("_log", "all connect candidates exhausted; create pending -> LOCAL fallback map=%s mode=%s" % [map_id, mode_id])
			var hosted_local: bool = bool(rpc_bridge.call("host_local_match", map_id, mode_id))
			host.call("_log", "local fallback host_local_match hosted=%s" % str(hosted_local))
			if hosted_local:
				host.set("_pending_create_request", {})
				host.set("_action_inflight", false)
				host.set("_lobby_list_ready", true)
				host.set("_connect_nonce", int(host.get("_connect_nonce")) + 1)
				var overlay := host.get("_overlay") as Control
				if overlay != null:
					overlay.visible = false
				var on_closed: Callable = host.get("_on_closed") as Callable
				if on_closed.is_valid():
					on_closed.call()
				host.call("_refresh_lobby_buttons_state")
				return
		host.set("_pending_create_request", {})
		host.set("_action_inflight", false)
		host.set("_lobby_list_ready", true)
		host.set("_room_entries", [])
		host.call("_log", "all connect candidates exhausted")
		var status_label := host.get("_status_label") as Label
		if status_label != null:
			status_label.text = "Lobby server unavailable. Online create failed." if had_pending_create else "Connection failed. Try Refresh."
		host.call("_populate_lobby_room_list")
		host.call("_refresh_lobby_selection_summary")
		host.call("_refresh_lobby_buttons_state")
		return
	host.call("_begin_connect_attempt", false, "Retrying", true)

func request_lobby_list_from_server(host: Object) -> void:
	var rpc_bridge: Object = host.get("_rpc_bridge") as Object
	if rpc_bridge == null:
		host.call("_log", "request_lobby_list aborted rpc_bridge=null")
		return
	if bool(rpc_bridge.call("can_send_lobby_rpc")):
		host.call("_log", "request_lobby_list sending immediately")
		rpc_bridge.call("request_lobby_list")
		host.call("_refresh_lobby_buttons_state")
		return
	if bool(rpc_bridge.call("is_connecting_to_server")):
		host.call("_log", "request_lobby_list waiting existing connect attempt")
		return
	host.call("_log", "request_lobby_list triggering connect first")
	host.call("_begin_connect_attempt", false)

func on_rpc_connected(host: Object) -> void:
	host.set("_connect_nonce", int(host.get("_connect_nonce")) + 1)
	var owner := host.get("_host") as Control
	host.call("_log", "rpc connected peer_id=%s pending_create=%s" % [
		str(owner.get_tree().get_multiplayer().get_unique_id() if owner != null and owner.get_tree() != null else -1),
		str(not (host.get("_pending_create_request") as Dictionary).is_empty())
	])
	var status_label := host.get("_status_label") as Label
	if status_label != null:
		status_label.text = "Connected. Fetching lobbies..."
	var rpc_bridge: Object = host.get("_rpc_bridge") as Object
	if owner != null and rpc_bridge != null:
		var username := str(owner.get("player_username")).strip_edges()
		if not username.is_empty():
			rpc_bridge.call("set_display_name", username)
	host.call("_sync_selected_warrior_skin")
	host.call("_sync_selected_weapon_skin")
	var pending_create_request := host.get("_pending_create_request") as Dictionary
	if not pending_create_request.is_empty():
		host.call("_send_create_lobby_request", pending_create_request)
		return
	if rpc_bridge != null:
		rpc_bridge.call("request_lobby_list")
	host.call("_refresh_lobby_buttons_state")

func on_rpc_failed(host: Object) -> void:
	host.call("_log", "rpc connection_failed signal")
	host.call("_try_next_connect_candidate")

func on_rpc_disconnected(host: Object) -> void:
	host.set("_connect_nonce", int(host.get("_connect_nonce")) + 1)
	host.set("_lobby_list_ready", false)
	host.set("_pending_create_request", {})
	host.set("_action_inflight", false)
	var ctf_room_state := host.get("_ctf_room_state") as Dictionary
	if ctf_room_state != null:
		ctf_room_state.clear()
	host.call("_log", "rpc disconnected signal")
	var status_label := host.get("_status_label") as Label
	if status_label != null:
		status_label.text = "Disconnected from server"
	host.call("_hide_ctf_room")
	host.call("_hide_dm_room")
	host.call("_refresh_lobby_buttons_state")

func on_rpc_lobby_list(host: Object, entries: Array, active_lobby_id: int) -> void:
	host.call("_log", "lobby_list received entries=%d active_lobby_id=%d" % [entries.size(), active_lobby_id])
	host.set("_lobby_list_ready", true)
	host.set("_room_entries", entries)
	host.set("_joined_lobby_id", active_lobby_id)
	host.set("_joined_room_name", "")
	var joined_room_name := ""
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var data := entry as Dictionary
		if int(data.get("id", 0)) == active_lobby_id:
			joined_room_name = str(data.get("name", ""))
			break
	host.set("_joined_room_name", joined_room_name)
	if active_lobby_id <= 0:
		var ctf_room_state := host.get("_ctf_room_state") as Dictionary
		if ctf_room_state != null:
			ctf_room_state.clear()
		host.call("_hide_ctf_room")
		host.call("_hide_dm_room")
	host.call("_populate_lobby_room_list")
	host.call("_refresh_lobby_selection_summary")
	host.call("_refresh_lobby_buttons_state")

func on_rpc_action_result(host: Object, success: bool, message: String, active_lobby_id: int, _map_id: String) -> void:
	host.call("_log", "action_result success=%s active_lobby_id=%d message=%s" % [str(success), active_lobby_id, message])
	if success and active_lobby_id > 0:
		host.call("_log", "action_result result=SERVER_LOBBY_CONFIRMED lobby_id=%d" % active_lobby_id)
	elif not success:
		host.call("_log", "action_result result=SERVER_ACTION_FAILED")

	host.set("_joined_lobby_id", active_lobby_id)
	host.set("_action_inflight", false)
	host.set("_action_nonce", int(host.get("_action_nonce")) + 1)
	var status_label := host.get("_status_label") as Label
	if status_label != null:
		status_label.text = message if success else "Failed: %s" % message
	if success and active_lobby_id > 0:
		var resolved_mode := str(host.call("_active_lobby_mode_id", active_lobby_id))
		var team_mode := bool(host.call("_is_team_mode_id", resolved_mode))
		if team_mode or resolved_mode == "deathmatch":
			if status_label != null:
				status_label.text = "Entered Team room. Pick team and start." if team_mode else "Entered FFA waiting room."
			host.set("_pending_create_request", {})
			host.call("_request_lobby_list_from_server")
			host.call("_refresh_lobby_buttons_state")
			return
		host.set("_pending_create_request", {})
		host.set("_connect_nonce", int(host.get("_connect_nonce")) + 1)
		var overlay := host.get("_overlay") as Control
		if overlay != null:
			overlay.visible = false
		var on_closed: Callable = host.get("_on_closed") as Callable
		if on_closed.is_valid():
			on_closed.call()
		host.call("_refresh_lobby_buttons_state")
		return
	var pending_create_request := host.get("_pending_create_request") as Dictionary
	if success and active_lobby_id <= 0 and not pending_create_request.is_empty():
		var rpc_bridge: Object = host.get("_rpc_bridge") as Object
		if rpc_bridge != null and bool(rpc_bridge.call("can_send_lobby_rpc")):
			host.call("_log", "action_result post-leave sending pending create request")
			host.call("_send_create_lobby_request", pending_create_request)
			return
		host.call("_log", "action_result post-leave pending create exists; reconnecting")
		host.call("_request_lobby_list_from_server")
		host.call("_refresh_lobby_buttons_state")
		return
	host.call("_request_lobby_list_from_server")
	host.call("_refresh_lobby_buttons_state")

func on_rpc_room_state(host: Object, payload: Dictionary) -> void:
	host.set("_ctf_room_state", payload.duplicate(true))
	var ctf_room_state := host.get("_ctf_room_state") as Dictionary
	host.call("_log", "room_state received payload=%s" % str(ctf_room_state))
	if int(ctf_room_state.get("lobby_id", 0)) != int(host.get("_joined_lobby_id")):
		return
	var mode_id := str(host.call("_active_lobby_mode_id", int(host.get("_joined_lobby_id"))))
	if bool(host.call("_is_team_mode_id", mode_id)):
		host.call("_hide_dm_room")
		host.call("_show_ctf_room", ctf_room_state)
		return
	if mode_id == "deathmatch":
		host.call("_hide_ctf_room")
		if bool(ctf_room_state.get("started", false)):
			host.call("_hide_dm_room")
			return
		host.call("_show_dm_room", ctf_room_state)
		return
	host.call("_hide_ctf_room")
	host.call("_hide_dm_room")
