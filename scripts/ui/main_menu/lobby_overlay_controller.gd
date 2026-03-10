extends RefCounted

const LOBBY_RPC_BRIDGE_SCRIPT := preload("res://scripts/ui/main_menu/lobby_rpc_bridge.gd")
const LOBBY_SERVICE_SCRIPT := preload("res://scripts/lobby/lobby_service.gd")

var _host: Control
var _make_button: Callable
var _add_hover_pop: Callable
var _center_pivot: Callable
var _pixel_burst_at: Callable
var _center_of: Callable
var _on_closed: Callable

var _overlay: Control
var _panel: PanelContainer
var _loading_box: PanelContainer
var _loading_label: Label
var _status_label: Label
var _rooms_box: VBoxContainer
var _selection_label: Label
var _create_button: Button
var _join_button: Button
var _refresh_button: Button
var _leave_button: Button
var _room_buttons: Array[Button] = []
var _room_entries: Array = []
var _selected_room_index := -1
var _joined_room_name := ""
var _joined_lobby_id := 0
var _rpc_bridge: Node
var _lobby_list_ready := false
var _action_inflight := false
var _action_nonce := 0
var _pending_create_request := {}
var _connect_candidates: Array[Dictionary] = []
var _connect_candidate_index := -1
var _connect_nonce := 0
var _lobby_service = LOBBY_SERVICE_SCRIPT.new()

func _log(message: String) -> void:
	print("[lobby_overlay] %s" % message)

func configure(
	host: Control,
	make_button: Callable,
	add_hover_pop: Callable,
	center_pivot: Callable,
	pixel_burst_at: Callable,
	center_of: Callable,
	on_closed: Callable
) -> void:
	_host = host
	_make_button = make_button
	_add_hover_pop = add_hover_pop
	_center_pivot = center_pivot
	_pixel_burst_at = pixel_burst_at
	_center_of = center_of
	_on_closed = on_closed

func is_visible() -> bool:
	return _overlay != null and _overlay.visible

func hide() -> void:
	if _overlay == null or not _overlay.visible:
		return
	_overlay.visible = false
	if _on_closed.is_valid():
		_on_closed.call()

func open(play_button: Control) -> void:
	_ensure_overlay()
	_ensure_rpc_bridge()
	if _overlay == null:
		return
	_lobby_list_ready = false
	_pending_create_request = {}
	_layout_overlay()

	_overlay.visible = true
	_overlay.modulate = Color(1, 1, 1, 0)
	if _loading_box != null:
		_loading_box.visible = true
	if _rooms_box != null:
		_rooms_box.visible = false

	if _loading_label != null:
		_loading_label.text = "LOADING"
	if _status_label != null:
		_status_label.text = "Connecting to lobby server..."

	var fade := _host.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.tween_property(_overlay, "modulate:a", 1.0, 0.22)

	if play_button != null and _pixel_burst_at.is_valid() and _center_of.is_valid():
		_pixel_burst_at.call(_center_of.call(play_button), Color(0.9, 0.74, 0.27, 1))

	_host.call_deferred("_run_lobby_menu_loading_sequence")

func run_loading_sequence() -> void:
	if _overlay == null or not _overlay.visible:
		return

	var steps := [
		{"title": "LOADING", "text": "Contacting lobby server...", "sec": 0.45},
		{"title": "LOADING.", "text": "Syncing session...", "sec": 0.45},
		{"title": "LOADING..", "text": "Preparing loadout...", "sec": 0.45},
		{"title": "LOADING...", "text": "Fetching lobby rooms...", "sec": 0.45},
	]

	for step in steps:
		if _overlay == null or not _overlay.visible:
			return
		if _loading_label != null:
			_loading_label.text = str(step.get("title", "LOADING"))
		if _status_label != null:
			_status_label.text = str(step.get("text", ""))
		await _host.get_tree().create_timer(float(step.get("sec", 0.35))).timeout

	_show_lobby_rooms()

func _layout_overlay() -> void:
	if _panel == null:
		return
	var viewport_size := _host.get_viewport_rect().size
	var target_w := clampf(viewport_size.x * 0.54, 360.0, 500.0)
	var target_h := clampf(viewport_size.y * 0.56, 230.0, 310.0)
	_panel.custom_minimum_size = Vector2(target_w, target_h)
	_panel.size = Vector2(target_w, target_h)
	_panel.position = (viewport_size - _panel.size) * 0.5

func _show_lobby_rooms() -> void:
	if _overlay == null:
		return
	_log("show_lobby_rooms visible=%s" % str(_overlay.visible))
	_lobby_list_ready = false
	if _loading_box != null:
		_loading_box.visible = false
	if _rooms_box != null:
		_rooms_box.visible = true

	_request_lobby_list_from_server()
	_populate_lobby_room_list()
	_refresh_lobby_selection_summary()

func _local_peer_id() -> int:
	if _host != null:
		var tree := _host.get_tree()
		if tree != null:
			var mp := tree.get_multiplayer()
			if mp != null and mp.multiplayer_peer != null:
				var peer_id := mp.get_unique_id()
				if peer_id > 0:
					return peer_id
	return 1

func _selected_weapon_id() -> String:
	var selected_weapon_id := "ak47"
	if _host != null:
		selected_weapon_id = str(_host.get("selected_weapon_id")).strip_edges().to_lower()
	if selected_weapon_id.is_empty():
		return "ak47"
	return selected_weapon_id

func _selected_warrior_id() -> String:
	var selected_character_id := "outrage"
	if _host != null:
		selected_character_id = str(_host.get("selected_warrior_id")).strip_edges().to_lower()
	if selected_character_id != "erebus" and selected_character_id != "tasko":
		selected_character_id = "outrage"
	return selected_character_id

func _selected_warrior_skin() -> int:
	if _host == null:
		return 0
	return maxi(0, int(_host.get("selected_warrior_skin")))

func _selected_weapon_skin() -> int:
	if _host == null:
		return 0
	return maxi(0, int(_host.get("selected_weapon_skin")))

func _sync_selected_warrior_skin() -> void:
	if _rpc_bridge == null:
		return
	_rpc_bridge.call("set_warrior_skin", _selected_warrior_skin())

func _sync_selected_weapon_skin() -> void:
	if _rpc_bridge == null:
		return
	_rpc_bridge.call("set_weapon_skin", _selected_weapon_skin())

func _persist_local_loadout_selection() -> void:
	if _lobby_service == null:
		return
	var weapon_id := _selected_weapon_id()
	var warrior_id := _selected_warrior_id()
	_lobby_service.set_local_selected_weapon(weapon_id)
	_lobby_service.set_local_selected_weapon_skin(weapon_id, _selected_weapon_skin())
	_lobby_service.set_local_selected_character(warrior_id)
	_lobby_service.set_local_selected_skin(warrior_id, _selected_warrior_skin())

func _resolve_server_host_port_from_args(host: String = "127.0.0.1", port: int = 8080) -> Dictionary:
	var resolved_host := host.strip_edges()
	var resolved_port := clampi(port, 1, 65535)
	if resolved_host.is_empty():
		resolved_host = "127.0.0.1"
	if _host != null:
		var args := OS.get_cmdline_user_args()
		for arg in args:
			if arg.begins_with("--host="):
				resolved_host = arg.substr("--host=".length()).strip_edges()
			elif arg.begins_with("--port="):
				var parsed := int(arg.substr("--port=".length()))
				if parsed >= 1 and parsed <= 65535:
					resolved_port = parsed
	if resolved_host.is_empty():
		resolved_host = "127.0.0.1"
	return {"host": resolved_host, "port": resolved_port}

func _read_launcher_config_defaults() -> Dictionary:
	var candidate_paths := PackedStringArray()
	var executable_config := OS.get_executable_path().get_base_dir().path_join("launcher_config.json")
	candidate_paths.append(executable_config)
	candidate_paths.append("res://launcher/launcher_config.json")
	candidate_paths.append("res://build/release/launcher_config.json")
	candidate_paths.append("res://build/launcher/launcher_config.json")

	for path in candidate_paths:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not (parsed is Dictionary):
			continue
		var payload := parsed as Dictionary
		return {
			"found": true,
			"host": str(payload.get("default_host", "")).strip_edges(),
			"port": int(payload.get("default_port", 8080))
		}

	return {"found": false}

func _resolve_server_host_port() -> Dictionary:
	var host := "127.0.0.1"
	var port := 8080
	var config := _read_launcher_config_defaults()
	if bool(config.get("found", false)):
		var config_host := str(config.get("host", "")).strip_edges()
		var config_port := int(config.get("port", 8080))
		if not config_host.is_empty():
			host = config_host
		if config_port >= 1 and config_port <= 65535:
			port = config_port
	var resolved := _resolve_server_host_port_from_args(host, port)
	_log("resolved primary server endpoint=%s:%d config_found=%s" % [
		str(resolved.get("host", "")),
		int(resolved.get("port", 0)),
		str(bool(config.get("found", false)))
	])
	return resolved

func _resolve_auth_api_host_port() -> Dictionary:
	var configured := str(ProjectSettings.get_setting("kw/auth_api_base_url", "http://127.0.0.1:8090")).strip_edges()
	if configured.is_empty():
		return {"host": "", "port": 8080}
	var scheme_idx := configured.find("://")
	if scheme_idx >= 0:
		configured = configured.substr(scheme_idx + 3)
	var slash_idx := configured.find("/")
	if slash_idx >= 0:
		configured = configured.substr(0, slash_idx)
	var host := configured
	var port := 8080
	var colon_idx := configured.rfind(":")
	if colon_idx > 0:
		host = configured.substr(0, colon_idx)
		var parsed_port := int(configured.substr(colon_idx + 1))
		if parsed_port >= 1 and parsed_port <= 65535:
			port = parsed_port
	return {"host": host.strip_edges(), "port": port}

func _build_connect_candidates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	for endpoint in [
		_resolve_server_host_port(),
		_resolve_server_host_port_from_args("127.0.0.1", 8080),
		_resolve_server_host_port_from_args("localhost", 8080),
		_resolve_auth_api_host_port(),
	]:
		var host := str(endpoint.get("host", "")).strip_edges()
		var port := int(endpoint.get("port", 8080))
		if host.is_empty() or port < 1 or port > 65535:
			continue
		var key := "%s:%d" % [host, port]
		if seen.has(key):
			continue
		seen[key] = true
		out.append({"host": host, "port": port})
	_log("connect candidates=%s" % str(out))
	return out

func _begin_connect_attempt(force_restart: bool, reason: String = "Connecting...") -> void:
	if _rpc_bridge == null:
		_log("begin_connect_attempt aborted rpc_bridge=null")
		return
	if force_restart or _connect_candidates.is_empty():
		_connect_candidates = _build_connect_candidates()
		_connect_candidate_index = 0
	if _connect_candidate_index < 0 or _connect_candidate_index >= _connect_candidates.size():
		_connect_candidates = _build_connect_candidates()
		_connect_candidate_index = 0
	if _connect_candidates.is_empty():
		_log("begin_connect_attempt failed no candidates")
		if _status_label != null:
			_status_label.text = "No lobby server host configured"
		_action_inflight = false
		_refresh_lobby_buttons_state()
		return
	var endpoint := _connect_candidates[_connect_candidate_index] as Dictionary
	var host := str(endpoint.get("host", "127.0.0.1"))
	var port := int(endpoint.get("port", 8080))
	_log("begin_connect_attempt force_restart=%s reason=%s candidate_index=%d target=%s:%d pending_create=%s" % [
		str(force_restart),
		reason,
		_connect_candidate_index,
		host,
		port,
		str(not _pending_create_request.is_empty())
	])
	if _status_label != null:
		_status_label.text = "%s %s:%d..." % [reason, host, port]
	_rpc_bridge.call("disconnect_from_server")
	_rpc_bridge.call("connect_to_server", host, port)
	_start_connect_watchdog()
	_refresh_lobby_buttons_state()

func _start_connect_watchdog() -> void:
	if _host == null or _host.get_tree() == null:
		return
	_connect_nonce += 1
	var nonce := _connect_nonce
	_log("start_connect_watchdog nonce=%d" % nonce)
	var timer := _host.get_tree().create_timer(2.5)
	timer.timeout.connect(func() -> void:
		if nonce != _connect_nonce:
			return
		if _rpc_bridge != null and bool(_rpc_bridge.call("can_send_lobby_rpc")):
			_log("watchdog nonce=%d sees connected rpc bridge" % nonce)
			return
		_log("watchdog timeout nonce=%d advancing candidate" % nonce)
		_try_next_connect_candidate()
	)

func _try_next_connect_candidate() -> void:
	_connect_candidate_index += 1
	_log("try_next_connect_candidate next_index=%d total=%d" % [_connect_candidate_index, _connect_candidates.size()])
	if _connect_candidate_index >= _connect_candidates.size():
		_pending_create_request = {}
		_action_inflight = false
		_lobby_list_ready = true
		_room_entries = []
		_log("all connect candidates exhausted")
		if _status_label != null:
			_status_label.text = "Connection failed. You can still press Create or Refresh."
		_populate_lobby_room_list()
		_refresh_lobby_selection_summary()
		_refresh_lobby_buttons_state()
		return
	_begin_connect_attempt(false, "Retrying")

func _request_lobby_list_from_server() -> void:
	if _rpc_bridge == null:
		_log("request_lobby_list aborted rpc_bridge=null")
		return
	if _rpc_bridge.call("can_send_lobby_rpc"):
		_log("request_lobby_list sending immediately")
		_rpc_bridge.call("request_lobby_list")
		_refresh_lobby_buttons_state()
		return
	_log("request_lobby_list triggering connect first")
	_begin_connect_attempt(false)

func _ensure_rpc_bridge() -> void:
	if _rpc_bridge != null and is_instance_valid(_rpc_bridge):
		return
	if _host == null or _host.get_tree() == null:
		return
	_rpc_bridge = LOBBY_RPC_BRIDGE_SCRIPT.new()
	_rpc_bridge.call("ensure_attached", _host.get_tree())
	if not _rpc_bridge.connected_to_lobby_server.is_connected(_on_rpc_connected):
		_rpc_bridge.connected_to_lobby_server.connect(_on_rpc_connected)
	if not _rpc_bridge.lobby_connection_failed.is_connected(_on_rpc_failed):
		_rpc_bridge.lobby_connection_failed.connect(_on_rpc_failed)
	if not _rpc_bridge.lobby_server_disconnected.is_connected(_on_rpc_disconnected):
		_rpc_bridge.lobby_server_disconnected.connect(_on_rpc_disconnected)
	if not _rpc_bridge.lobby_list_received.is_connected(_on_rpc_lobby_list):
		_rpc_bridge.lobby_list_received.connect(_on_rpc_lobby_list)
	if not _rpc_bridge.lobby_action_result_received.is_connected(_on_rpc_action_result):
		_rpc_bridge.lobby_action_result_received.connect(_on_rpc_action_result)

func _on_rpc_connected() -> void:
	_connect_nonce += 1
	_log("rpc connected peer_id=%s pending_create=%s" % [
		str(_host.get_tree().get_multiplayer().get_unique_id() if _host != null and _host.get_tree() != null else -1),
		str(not _pending_create_request.is_empty())
	])
	if _status_label != null:
		_status_label.text = "Connected. Fetching lobbies..."
	if _host != null:
		var username := str(_host.get("player_username")).strip_edges()
		if not username.is_empty():
			_rpc_bridge.call("set_display_name", username)
	_sync_selected_warrior_skin()
	_sync_selected_weapon_skin()
	if not _pending_create_request.is_empty():
		_send_create_lobby_request(_pending_create_request)
		return
	_rpc_bridge.call("request_lobby_list")
	_refresh_lobby_buttons_state()

func _on_rpc_failed() -> void:
	_log("rpc connection_failed signal")
	_try_next_connect_candidate()

func _on_rpc_disconnected() -> void:
	_connect_nonce += 1
	_lobby_list_ready = false
	_pending_create_request = {}
	_action_inflight = false
	_log("rpc disconnected signal")
	if _status_label != null:
		_status_label.text = "Disconnected from server"
	_refresh_lobby_buttons_state()

func _on_rpc_lobby_list(entries: Array, active_lobby_id: int) -> void:
	_log("lobby_list received entries=%d active_lobby_id=%d" % [entries.size(), active_lobby_id])
	_lobby_list_ready = true
	_room_entries = entries
	_joined_lobby_id = active_lobby_id
	_joined_room_name = ""
	for entry in _room_entries:
		if not (entry is Dictionary):
			continue
		var data := entry as Dictionary
		if int(data.get("id", 0)) == _joined_lobby_id:
			_joined_room_name = str(data.get("name", ""))
			break
	_populate_lobby_room_list()
	_refresh_lobby_selection_summary()
	_refresh_lobby_buttons_state()

func _on_rpc_action_result(success: bool, message: String, active_lobby_id: int, _map_id: String) -> void:
	_log("action_result success=%s active_lobby_id=%d message=%s" % [str(success), active_lobby_id, message])
	_joined_lobby_id = active_lobby_id
	_action_inflight = false
	_action_nonce += 1
	if _status_label != null:
		_status_label.text = message if success else "Failed: %s" % message
	if success and active_lobby_id > 0:
		# A successful create/join immediately transitions into the match.
		# Do not start a fresh lobby-list reconnect here or it will stomp the active gameplay peer.
		_pending_create_request = {}
		_connect_nonce += 1
		if _overlay != null:
			_overlay.visible = false
		if _on_closed.is_valid():
			_on_closed.call()
		_refresh_lobby_buttons_state()
		return
	_request_lobby_list_from_server()
	_refresh_lobby_buttons_state()

func _begin_lobby_action(status_text: String) -> int:
	_action_inflight = true
	_action_nonce += 1
	var nonce := _action_nonce
	if _status_label != null:
		_status_label.text = status_text
	_refresh_lobby_buttons_state()
	if _host != null and _host.get_tree() != null:
		var timer := _host.get_tree().create_timer(6.0)
		timer.timeout.connect(func() -> void:
			if nonce != _action_nonce:
				return
			if not _action_inflight:
				return
			_action_inflight = false
			if _status_label != null:
				_status_label.text = "Lobby request timed out. Try refresh."
			_refresh_lobby_buttons_state()
		)
	return nonce

func _populate_lobby_room_list() -> void:
	if _rooms_box == null:
		return

	for b in _room_buttons:
		if b != null:
			b.queue_free()
	_room_buttons.clear()
	_selected_room_index = -1

	for i in range(_room_entries.size()):
		var entry := _room_entries[i] as Dictionary
		var btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
		btn.custom_minimum_size = Vector2(0, 38)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lobby_id := int(entry.get("id", 0))
		var room_name := str(entry.get("name", "Room"))
		var players := int(entry.get("players", 0))
		var max_players := int(entry.get("max_players", 2))
		var map_id := str(entry.get("map_name", entry.get("map_id", "classic"))).to_upper()
		var in_room := lobby_id > 0 and lobby_id == _joined_lobby_id
		var suffix := "  [IN]" if in_room else ""
		btn.text = "#%d  %s   |   %d/%d   |   %s%s" % [lobby_id, room_name, players, max_players, map_id, suffix]
		btn.pressed.connect(func() -> void:
			_select_lobby_room(i)
		)
		if _add_hover_pop.is_valid():
			_add_hover_pop.call(btn)
		_rooms_box.add_child(btn)
		if _center_pivot.is_valid():
			_center_pivot.call(btn)
		_room_buttons.append(btn)

	if _room_entries.size() > 0:
		var preselect := 0
		for i in range(_room_entries.size()):
			var entry := _room_entries[i] as Dictionary
			if int(entry.get("id", 0)) == _joined_lobby_id:
				preselect = i
				break
		_select_lobby_room(preselect)
	else:
		if _join_button != null:
			_join_button.disabled = true
		if _status_label != null:
			_status_label.text = "No lobbies yet. Create one."
	_refresh_lobby_buttons_state()

func _select_lobby_room(index: int) -> void:
	if index < 0 or index >= _room_entries.size():
		return
	_selected_room_index = index
	for i in range(_room_buttons.size()):
		var btn := _room_buttons[i]
		if btn == null:
			continue
		btn.modulate = Color(1, 1, 1, 1) if i == index else Color(0.82, 0.84, 0.9, 0.9)
	if _join_button != null:
		_join_button.disabled = false

func _refresh_lobby_selection_summary() -> void:
	if _selection_label == null:
		return
	if _joined_room_name.is_empty():
		if _room_entries.is_empty():
			_selection_label.text = "No active lobbies"
		else:
			_selection_label.text = "Select a room and press JOIN"
	else:
		_selection_label.text = "In room: %s" % _joined_room_name

func _join_selected_lobby_room() -> void:
	if _selected_room_index < 0 or _selected_room_index >= _room_entries.size():
		return
	var room := _room_entries[_selected_room_index] as Dictionary
	var lobby_id := int(room.get("id", 0))
	var room_name := str(room.get("name", "room"))
	if _rpc_bridge == null or lobby_id <= 0:
		return

	if _joined_lobby_id == lobby_id:
		if _status_label != null:
			_status_label.text = "Already in %s" % room_name
		_refresh_lobby_selection_summary()
		_refresh_lobby_buttons_state()
		return

	var selected_weapon_id := _selected_weapon_id()
	var selected_character_id := _selected_warrior_id()
	_persist_local_loadout_selection()
	_sync_selected_warrior_skin()
	_sync_selected_weapon_skin()
	_begin_lobby_action("Joining %s..." % room_name)
	var sent_join := bool(_rpc_bridge.call("join_lobby", lobby_id, selected_weapon_id, selected_character_id))
	if _status_label != null:
		_status_label.text = ("Joining %s..." % room_name) if sent_join else "Still connecting..."
	if not sent_join:
		_action_inflight = false
		_request_lobby_list_from_server()
	_refresh_lobby_selection_summary()
	_refresh_lobby_buttons_state()

func _create_lobby_room() -> void:
	if _rpc_bridge == null:
		_log("create_lobby clicked but rpc_bridge=null")
		return
	if not _lobby_list_ready:
		_log("create_lobby blocked lobby_list_ready=false")
		if _status_label != null:
			_status_label.text = "Wait for lobbies to finish loading"
		_refresh_lobby_buttons_state()
		return
	if _joined_lobby_id > 0:
		_log("create_lobby blocked already_in_lobby id=%d" % _joined_lobby_id)
		if _status_label != null:
			_status_label.text = "Leave current lobby first"
		return
	var request := _build_create_lobby_request()
	_log("create_lobby clicked request=%s can_send=%s" % [str(request), str(bool(_rpc_bridge.call("can_send_lobby_rpc")))])
	if not bool(_rpc_bridge.call("can_send_lobby_rpc")):
		_log("create_lobby queueing reconnect because can_send=false")
		_pending_create_request = request.duplicate(true)
		if _status_label != null:
			_status_label.text = "Reconnecting to create lobby..."
		_begin_connect_attempt(true, "Reconnecting")
		_refresh_lobby_buttons_state()
		return
	_send_create_lobby_request(request)

func _leave_lobby_room() -> void:
	if _joined_lobby_id <= 0 and _joined_room_name.is_empty():
		return
	if _rpc_bridge == null:
		return
	var previous := _joined_room_name if not _joined_room_name.is_empty() else "lobby"
	_begin_lobby_action("Leaving %s..." % previous)
	var sent_leave := bool(_rpc_bridge.call("leave_lobby"))
	if _status_label != null:
		_status_label.text = ("Leaving %s..." % previous) if sent_leave else "Still connecting..."
	if not sent_leave:
		_action_inflight = false
		_request_lobby_list_from_server()
	_refresh_lobby_selection_summary()
	_refresh_lobby_buttons_state()

func _build_create_lobby_request() -> Dictionary:
	var requested_name := "My Lobby %d" % (_room_entries.size() + 1)
	var selected_weapon_id := _selected_weapon_id()
	var selected_character_id := _selected_warrior_id()
	return {
		"name": requested_name,
		"weapon_id": selected_weapon_id,
		"character_id": selected_character_id,
		"map_id": "classic",
	}

func _send_create_lobby_request(request: Dictionary) -> void:
	_pending_create_request = {}
	var requested_name := str(request.get("name", "")).strip_edges()
	var selected_weapon_id := str(request.get("weapon_id", "ak47")).strip_edges().to_lower()
	var selected_character_id := str(request.get("character_id", "outrage")).strip_edges().to_lower()
	var map_id := str(request.get("map_id", "classic")).strip_edges().to_lower()
	if requested_name.is_empty():
		requested_name = "My Lobby %d" % (_room_entries.size() + 1)
	if selected_weapon_id.is_empty():
		selected_weapon_id = "ak47"
	if selected_character_id != "erebus" and selected_character_id != "tasko":
		selected_character_id = "outrage"
	if map_id.is_empty():
		map_id = "classic"
	_log("send_create_lobby_request name=%s weapon=%s character=%s map=%s can_send=%s" % [
		requested_name,
		selected_weapon_id,
		selected_character_id,
		map_id,
		str(bool(_rpc_bridge.call("can_send_lobby_rpc")))
	])
	_persist_local_loadout_selection()
	_sync_selected_warrior_skin()
	_sync_selected_weapon_skin()
	_begin_lobby_action("Creating lobby...")
	var sent_create := bool(_rpc_bridge.call("create_lobby", requested_name, selected_weapon_id, selected_character_id, map_id))
	_log("create_lobby rpc sent=%s" % str(sent_create))
	if _status_label != null:
		_status_label.text = "Creating lobby..." if sent_create else "Still connecting..."
	if not sent_create:
		_action_inflight = false
		_pending_create_request = request.duplicate(true)
		_request_lobby_list_from_server()
	_refresh_lobby_selection_summary()
	_refresh_lobby_buttons_state()

func _refresh_lobby_buttons_state() -> void:
	var can_send := _rpc_bridge != null and bool(_rpc_bridge.call("can_send_lobby_rpc"))
	if _create_button != null:
		_create_button.disabled = not _lobby_list_ready or _joined_lobby_id > 0 or _action_inflight
	if _join_button != null:
		_join_button.disabled = not can_send or _selected_room_index < 0 or _action_inflight
	if _refresh_button != null:
		_refresh_button.disabled = _action_inflight
	if _leave_button != null:
		_leave_button.disabled = not can_send or _joined_room_name.is_empty() or _action_inflight

func _ensure_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_refresh_lobby_selection_summary()
		return

	var overlay := Control.new()
	overlay.name = "LobbyOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.z_index = 980
	_host.add_child(overlay)
	_overlay = overlay

	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.08, 0.95)
	overlay.add_child(bg)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.custom_minimum_size = Vector2(420, 270)
	panel.position = Vector2(40, 40)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(panel)
	_panel = panel

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.16, 0.14, 0.22, 0.98)
	panel_style.border_width_left = 4
	panel_style.border_width_top = 4
	panel_style.border_width_right = 4
	panel_style.border_width_bottom = 4
	panel_style.border_color = Color(0.9, 0.74, 0.27, 1)
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(root)

	var title := Label.new()
	title.text = "LOBBY ROOMS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	root.add_child(title)

	var status := Label.new()
	status.text = "Status: Idle"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 12)
	root.add_child(status)
	_status_label = status

	var loading_box := PanelContainer.new()
	loading_box.custom_minimum_size = Vector2(0, 90)
	root.add_child(loading_box)
	_loading_box = loading_box

	var loading_style := StyleBoxFlat.new()
	loading_style.bg_color = Color(0.11, 0.1, 0.16, 0.96)
	loading_style.border_width_left = 3
	loading_style.border_width_top = 3
	loading_style.border_width_right = 3
	loading_style.border_width_bottom = 3
	loading_style.border_color = Color(0.06, 0.05, 0.08, 1)
	loading_box.add_theme_stylebox_override("panel", loading_style)

	var loading_margin := MarginContainer.new()
	loading_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_margin.add_theme_constant_override("margin_left", 8)
	loading_margin.add_theme_constant_override("margin_top", 8)
	loading_margin.add_theme_constant_override("margin_right", 8)
	loading_margin.add_theme_constant_override("margin_bottom", 8)
	loading_box.add_child(loading_margin)

	var loading_v := VBoxContainer.new()
	loading_v.alignment = BoxContainer.ALIGNMENT_CENTER
	loading_v.add_theme_constant_override("separation", 6)
	loading_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_margin.add_child(loading_v)

	var loading_title := Label.new()
	loading_title.text = "LOADING"
	loading_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_title.add_theme_font_size_override("font_size", 17)
	loading_v.add_child(loading_title)
	_loading_label = loading_title

	var loading_sub := Label.new()
	loading_sub.text = "Please wait..."
	loading_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_sub.add_theme_font_size_override("font_size", 11)
	loading_v.add_child(loading_sub)

	var rooms_title := Label.new()
	rooms_title.text = "Lobbies"
	rooms_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rooms_title.add_theme_font_size_override("font_size", 13)
	root.add_child(rooms_title)

	var rooms_box := VBoxContainer.new()
	rooms_box.custom_minimum_size = Vector2(0, 78)
	rooms_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rooms_box.add_theme_constant_override("separation", 4)
	rooms_box.visible = false
	root.add_child(rooms_box)
	_rooms_box = rooms_box

	var selection_label := Label.new()
	selection_label.text = "Select a room and press JOIN"
	selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_label.add_theme_font_size_override("font_size", 11)
	root.add_child(selection_label)
	_selection_label = selection_label

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)

	var create_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	create_btn.text = "CREATE"
	create_btn.custom_minimum_size = Vector2(0, 26)
	create_btn.add_theme_font_size_override("font_size", 10)
	create_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_btn.pressed.connect(_create_lobby_room)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(create_btn)
	actions.add_child(create_btn)
	_create_button = create_btn

	var join_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	join_btn.text = "JOIN"
	join_btn.custom_minimum_size = Vector2(0, 26)
	join_btn.add_theme_font_size_override("font_size", 10)
	join_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_btn.disabled = true
	join_btn.pressed.connect(_join_selected_lobby_room)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(join_btn)
	actions.add_child(join_btn)
	_join_button = join_btn

	var refresh_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	refresh_btn.text = "REFRESH"
	refresh_btn.custom_minimum_size = Vector2(0, 26)
	refresh_btn.add_theme_font_size_override("font_size", 10)
	refresh_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh_btn.pressed.connect(func() -> void:
		if _status_label != null:
			_status_label.text = "Refreshing rooms..."
		_request_lobby_list_from_server()
	)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(refresh_btn)
	actions.add_child(refresh_btn)
	_refresh_button = refresh_btn

	var leave_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	leave_btn.text = "LEAVE"
	leave_btn.custom_minimum_size = Vector2(0, 26)
	leave_btn.add_theme_font_size_override("font_size", 10)
	leave_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave_btn.disabled = true
	leave_btn.pressed.connect(_leave_lobby_room)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(leave_btn)
	actions.add_child(leave_btn)
	_leave_button = leave_btn

	var back_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	back_btn.text = "BACK"
	back_btn.custom_minimum_size = Vector2(0, 26)
	back_btn.add_theme_font_size_override("font_size", 10)
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void:
		hide()
	)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(back_btn)
	actions.add_child(back_btn)

	_refresh_lobby_selection_summary()
	_refresh_lobby_buttons_state()
