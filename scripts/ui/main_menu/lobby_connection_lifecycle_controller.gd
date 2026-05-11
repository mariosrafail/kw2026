extends RefCounted

class_name LobbyConnectionLifecycleController

const CONNECT_WATCHDOG_CHECK_INTERVAL_SEC := 1.0
const CONNECT_WATCHDOG_MAX_WAIT_SEC := 35.0
const CONNECT_ATTEMPTS_PER_CANDIDATE := 3

var _host: Object
var _rpc_bridge_script

func configure(host: Object, rpc_bridge_script) -> void:
	_host = host
	_rpc_bridge_script = rpc_bridge_script

func _owner_control() -> Control:
	if _host == null:
		return null
	return _host.get("_host") as Control

func _format_endpoint(host: String, port: int) -> String:
	var trimmed := host.strip_edges()
	if trimmed.begins_with("ws://") or trimmed.begins_with("wss://"):
		return trimmed
	return "%s:%d" % [trimmed, port]

func begin_connect_attempt(force_restart: bool, reason: String = "Connecting...", allow_while_connecting: bool = false) -> void:
	var rpc_bridge: Variant = _host.get("_rpc_bridge")
	var owner := _owner_control()
	var runtime_label := "web" if OS.has_feature("web") else ("editor" if Engine.is_editor_hint() else "native")
	var network_mode := "ONLINE"
	if owner != null and owner.has_meta("kw_network_mode"):
		network_mode = "LAN" if str(owner.get_meta("kw_network_mode")).strip_edges().to_lower() == "lan" else "ONLINE"
	var lan_usable := true
	var lan_block_reason := ""
	if owner != null:
		lan_usable = bool(owner.get_meta("kw_lan_usable", true))
		lan_block_reason = str(owner.get_meta("kw_lan_blocked_reason", "")).strip_edges()
	var transport := str(ProjectSettings.get_setting("kw/network_transport", "websocket")).strip_edges().to_lower()
	if transport.is_empty():
		transport = "websocket"
	var auth_endpoint := str(ProjectSettings.get_setting("kw/auth_api_base_url", "")).strip_edges()
	var game_host := str(ProjectSettings.get_setting("kw/default_server_host", "")).strip_edges()
	var game_port := int(ProjectSettings.get_setting("kw/default_server_port", 0))
	if rpc_bridge == null:
		_host.call("_log", "begin_connect_attempt aborted rpc_bridge=null")
		return
	if not allow_while_connecting and not force_restart and bool(rpc_bridge.call("is_connecting_to_server")):
		_host.call("_log", "begin_connect_attempt skipped already connecting")
		var status_label := _host.get("_status_label") as Label
		if status_label != null:
			status_label.text = "Connecting to lobby server..."
		_host.call("_refresh_lobby_buttons_state")
		return
	if force_restart or (_host.get("_connect_candidates") as Array).is_empty():
		_host.set("_connect_candidates", _host.call("_build_connect_candidates"))
		_host.set("_connect_candidate_index", 0)
		_host.set("_connect_attempt_in_candidate", 0)
	var connect_candidates := _host.get("_connect_candidates") as Array
	print("[NET] runtime = %s" % runtime_label)
	print("[NET] selected mode = %s" % network_mode)
	if network_mode == "LAN":
		print("[NET] LAN usable from this page = %s" % str(lan_usable))
		if not lan_usable:
			print("[NET] LAN blocked reason = %s" % lan_block_reason)
	print("[NET] selected transport = %s" % transport)
	print("[NET] auth endpoint = %s" % auth_endpoint)
	var game_endpoint := game_host
	if transport == "websocket" and not game_endpoint.begins_with("ws://") and not game_endpoint.begins_with("wss://"):
		var ws_scheme := str(ProjectSettings.get_setting("kw/network_ws_scheme", "ws")).strip_edges().to_lower()
		if ws_scheme != "ws" and ws_scheme != "wss":
			ws_scheme = "ws"
		game_endpoint = "%s://%s:%d" % [ws_scheme, game_host, game_port]
	if transport == "websocket":
		print("[NET] websocket endpoint = %s" % game_endpoint)
	else:
		print("[NET] enet endpoint = %s:%d" % [game_host, game_port])
	print("[NET] candidates = %s" % str(connect_candidates))
	if network_mode == "LAN" and not lan_usable:
		_host.call("_log", "LAN mode cannot run from HTTPS public host because browser blocks HTTP LAN requests.")
		_host.call("_log", "Open the game from your LAN server instead: http://<LAN_IP>:8081/")
		_host.call("_log", "Or use ONLINE mode.")
		var status_label_blocked := _host.get("_status_label") as Label
		if status_label_blocked != null:
			status_label_blocked.text = "LAN blocked on HTTPS public page. Open http://<LAN_IP>:8081/ or use ONLINE."
		_host.set("_action_inflight", false)
		_host.call("_refresh_lobby_buttons_state")
		return
	var connect_candidate_index := int(_host.get("_connect_candidate_index"))
	if connect_candidate_index < 0 or connect_candidate_index >= connect_candidates.size():
		_host.set("_connect_candidates", _host.call("_build_connect_candidates"))
		_host.set("_connect_candidate_index", 0)
		_host.set("_connect_attempt_in_candidate", 0)
		connect_candidates = _host.get("_connect_candidates") as Array
		connect_candidate_index = int(_host.get("_connect_candidate_index"))
	if connect_candidates.is_empty():
		_host.call("_log", "begin_connect_attempt failed no candidates")
		var status_label := _host.get("_status_label") as Label
		if status_label != null:
			status_label.text = "No lobby server host configured"
		_host.set("_action_inflight", false)
		_host.call("_refresh_lobby_buttons_state")
		return
	var endpoint := connect_candidates[connect_candidate_index] as Dictionary
	var host_value := str(endpoint.get("host", "127.0.0.1"))
	var port_value := int(endpoint.get("port", 8080))
	var endpoint_label := _format_endpoint(host_value, port_value)
	var connect_attempt_in_candidate := int(_host.get("_connect_attempt_in_candidate")) + 1
	_host.set("_connect_attempt_in_candidate", connect_attempt_in_candidate)
	_host.call("_log", "begin_connect_attempt force_restart=%s reason=%s candidate_index=%d target=%s pending_create=%s" % [
		str(force_restart),
		reason,
		connect_candidate_index,
		endpoint_label,
		str(not (_host.get("_pending_create_request") as Dictionary).is_empty())
	])
	_host.call("_log", "begin_connect_attempt candidate_try=%d/%d for %s" % [
		connect_attempt_in_candidate,
		CONNECT_ATTEMPTS_PER_CANDIDATE,
		endpoint_label
	])
	var status_label := _host.get("_status_label") as Label
	if status_label != null:
		status_label.text = "%s %s..." % [reason, endpoint_label]
	rpc_bridge.call("disconnect_from_server")
	rpc_bridge.call("connect_to_server", host_value, port_value)
	start_connect_watchdog()
	_host.call("_refresh_lobby_buttons_state")

func start_connect_watchdog() -> void:
	var host_control := _owner_control()
	if host_control == null or host_control.get_tree() == null:
		return
	var nonce := int(_host.get("_connect_nonce")) + 1
	_host.set("_connect_nonce", nonce)
	_host.call("_log", "start_connect_watchdog nonce=%d" % nonce)
	tick_connect_watchdog(nonce, 0.0)

func tick_connect_watchdog(nonce: int, elapsed_sec: float) -> void:
	var host_control := _owner_control()
	if host_control == null or host_control.get_tree() == null:
		return
	var timer := host_control.get_tree().create_timer(CONNECT_WATCHDOG_CHECK_INTERVAL_SEC)
	timer.timeout.connect(func() -> void:
		if nonce != int(_host.get("_connect_nonce")):
			return
		var rpc_bridge: Variant = _host.get("_rpc_bridge")
		if rpc_bridge == null:
			return
		if bool(rpc_bridge.call("can_send_lobby_rpc")):
			_host.call("_log", "watchdog nonce=%d sees connected rpc bridge" % nonce)
			return
		var still_connecting := bool(rpc_bridge.call("is_connecting_to_server"))
		var next_elapsed := elapsed_sec + CONNECT_WATCHDOG_CHECK_INTERVAL_SEC
		if still_connecting and next_elapsed < CONNECT_WATCHDOG_MAX_WAIT_SEC:
			tick_connect_watchdog(nonce, next_elapsed)
			return
		if still_connecting:
			_host.call("_log", "watchdog nonce=%d max_wait reached (%.1fs) while connecting; advancing candidate" % [nonce, next_elapsed])
			handle_failed_connect_attempt("watchdog_max_wait")
			return
		_host.call("_log", "watchdog nonce=%d peer no longer connecting; advancing candidate" % nonce)
		handle_failed_connect_attempt("watchdog_not_connecting")
	)

func handle_failed_connect_attempt(source: String) -> void:
	var connect_candidate_index := int(_host.get("_connect_candidate_index"))
	var connect_candidates := _host.get("_connect_candidates") as Array
	if connect_candidate_index < 0 or connect_candidate_index >= connect_candidates.size():
		try_next_connect_candidate()
		return
	var endpoint := connect_candidates[connect_candidate_index] as Dictionary
	var host_value := str(endpoint.get("host", "127.0.0.1"))
	var port_value := int(endpoint.get("port", 8080))
	_host.call("_log", "connect attempt failed source=%s candidate_index=%d try=%d/%d target=%s" % [
		source,
		connect_candidate_index,
		int(_host.get("_connect_attempt_in_candidate")),
		CONNECT_ATTEMPTS_PER_CANDIDATE,
		_format_endpoint(host_value, port_value)
	])
	if source == "connection_failed":
		try_next_connect_candidate()
		return
	if int(_host.get("_connect_attempt_in_candidate")) < CONNECT_ATTEMPTS_PER_CANDIDATE:
		begin_connect_attempt(false, "Retrying", true)
		return
	try_next_connect_candidate()

func try_next_connect_candidate() -> void:
	var next_index := int(_host.get("_connect_candidate_index")) + 1
	_host.set("_connect_candidate_index", next_index)
	_host.set("_connect_attempt_in_candidate", 0)
	var connect_candidates := _host.get("_connect_candidates") as Array
	_host.call("_log", "try_next_connect_candidate next_index=%d total=%d" % [next_index, connect_candidates.size()])
	if next_index >= connect_candidates.size():
		var had_pending_create := not (_host.get("_pending_create_request") as Dictionary).is_empty()
		var rpc_bridge: Variant = _host.get("_rpc_bridge")
		if rpc_bridge != null:
			rpc_bridge.call("disconnect_from_server")
		_host.set("_action_inflight", false)
		_host.set("_lobby_list_ready", true)
		_host.set("_room_entries", [])
		_host.set("_pending_create_request", {})
		_host.call("_log", "all connect candidates exhausted")
		var status_label := _host.get("_status_label") as Label
		if status_label != null:
			status_label.text = "Online server unavailable. Try again."
		_host.call("_populate_lobby_room_list")
		_host.call("_refresh_lobby_selection_summary")
		_host.call("_refresh_lobby_buttons_state")
		return
	begin_connect_attempt(false, "Retrying", true)

func request_lobby_list_from_server() -> void:
	var rpc_bridge: Variant = _host.get("_rpc_bridge")
	if rpc_bridge == null:
		_host.call("_log", "request_lobby_list aborted rpc_bridge=null")
		return
	if rpc_bridge.call("can_send_lobby_rpc"):
		_host.call("_log", "request_lobby_list sending immediately")
		rpc_bridge.call("request_lobby_list")
		_host.call("_refresh_lobby_buttons_state")
		return
	if bool(rpc_bridge.call("is_connecting_to_server")):
		_host.call("_log", "request_lobby_list waiting existing connect attempt")
		return
	_host.call("_log", "request_lobby_list triggering connect first")
	begin_connect_attempt(false)

func ensure_rpc_bridge() -> void:
	var rpc_bridge: Variant = _host.get("_rpc_bridge")
	if rpc_bridge != null and is_instance_valid(rpc_bridge):
		return
	var host_control := _owner_control()
	if host_control == null or host_control.get_tree() == null:
		return
	rpc_bridge = _rpc_bridge_script.new()
	_host.set("_rpc_bridge", rpc_bridge)
	rpc_bridge.call("ensure_attached", host_control.get_tree())
	if not rpc_bridge.connected_to_lobby_server.is_connected(Callable(_host, "_on_rpc_connected")):
		rpc_bridge.connected_to_lobby_server.connect(Callable(_host, "_on_rpc_connected"))
	if not rpc_bridge.lobby_connection_failed.is_connected(Callable(_host, "_on_rpc_failed")):
		rpc_bridge.lobby_connection_failed.connect(Callable(_host, "_on_rpc_failed"))
	if not rpc_bridge.lobby_server_disconnected.is_connected(Callable(_host, "_on_rpc_disconnected")):
		rpc_bridge.lobby_server_disconnected.connect(Callable(_host, "_on_rpc_disconnected"))
	if not rpc_bridge.lobby_list_received.is_connected(Callable(_host, "_on_rpc_lobby_list")):
		rpc_bridge.lobby_list_received.connect(Callable(_host, "_on_rpc_lobby_list"))
	if not rpc_bridge.lobby_action_result_received.is_connected(Callable(_host, "_on_rpc_action_result")):
		rpc_bridge.lobby_action_result_received.connect(Callable(_host, "_on_rpc_action_result"))
	if not rpc_bridge.lobby_room_state_received.is_connected(Callable(_host, "_on_rpc_room_state")):
		rpc_bridge.lobby_room_state_received.connect(Callable(_host, "_on_rpc_room_state"))
	if rpc_bridge.has_signal("lobby_chat_received"):
		if not rpc_bridge.lobby_chat_received.is_connected(Callable(_host, "_on_rpc_lobby_chat_message")):
			rpc_bridge.lobby_chat_received.connect(Callable(_host, "_on_rpc_lobby_chat_message"))

func on_rpc_connected() -> void:
	_host.set("_connect_nonce", int(_host.get("_connect_nonce")) + 1)
	var host_control := _owner_control()
	_host.call("_log", "rpc connected peer_id=%s pending_create=%s" % [
		str(host_control.get_tree().get_multiplayer().get_unique_id() if host_control != null and host_control.get_tree() != null else -1),
		str(not (_host.get("_pending_create_request") as Dictionary).is_empty())
	])
	var status_label := _host.get("_status_label") as Label
	if status_label != null:
		status_label.text = "Connected. Fetching lobbies..."
	if host_control != null:
		var username := str(host_control.get("player_username")).strip_edges()
		if not username.is_empty():
			var rpc_bridge: Variant = _host.get("_rpc_bridge")
			rpc_bridge.call("set_display_name", username)
	_host.call("_sync_selected_warrior_skin")
	_host.call("_sync_selected_weapon_skin")
	var pending_create_request := _host.get("_pending_create_request") as Dictionary
	if not pending_create_request.is_empty():
		_host.call("_send_create_lobby_request", pending_create_request)
		return
	var rpc_bridge: Variant = _host.get("_rpc_bridge")
	rpc_bridge.call("request_lobby_list")
	_host.call("_refresh_lobby_buttons_state")

func on_rpc_failed() -> void:
	_host.call("_log", "rpc connection_failed signal")
	handle_failed_connect_attempt("connection_failed")

func on_rpc_disconnected() -> void:
	_host.set("_connect_nonce", int(_host.get("_connect_nonce")) + 1)
	_host.set("_lobby_list_ready", false)
	_host.set("_joined_lobby_id", 0)
	_host.set("_joined_room_name", "")
	var rpc_bridge: Variant = _host.get("_rpc_bridge")
	var pending_create_exists := not (_host.get("_pending_create_request") as Dictionary).is_empty()
	var reconnect_in_progress := false
	if rpc_bridge != null:
		reconnect_in_progress = bool(rpc_bridge.call("is_connecting_to_server"))
	if bool(_host.get("_action_inflight")) or pending_create_exists or reconnect_in_progress:
		_host.call("_log", "rpc disconnected while reconnect/pending action; keeping pending request")
	else:
		_host.set("_pending_create_request", {})
	_host.set("_action_inflight", false)
	var ctf_room_state := _host.get("_ctf_room_state") as Dictionary
	ctf_room_state.clear()
	_host.call("_refresh_lobby_chat_context")
	_host.call("_log", "rpc disconnected signal")
	var status_label := _host.get("_status_label") as Label
	if status_label != null:
		status_label.text = "Disconnected from server"
	_host.call("_hide_ctf_room")
	_host.call("_hide_dm_room")
	_host.call("_refresh_lobby_buttons_state")
