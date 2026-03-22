extends RefCounted

const LOBBY_RPC_BRIDGE_SCRIPT := preload("res://scripts/ui/main_menu/lobby_rpc_bridge.gd")
const LOBBY_SERVICE_SCRIPT := preload("res://scripts/lobby/lobby_service.gd")
const MAP_CATALOG_SCRIPT := preload("res://scripts/world/map_catalog.gd")
const MAP_FLOW_SERVICE_SCRIPT := preload("res://scripts/world/map_flow_service.gd")
const CONNECT_WATCHDOG_TIMEOUT_SEC := 8.0

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
var _header_title: Label
var _rooms_title_label: Label
var _rooms_box: VBoxContainer
var _selection_label: Label
var _mode_row: HBoxContainer
var _waiting_room_title_label: Label
var _actions_row: HBoxContainer
var _create_button: Button
var _join_button: Button
var _refresh_button: Button
var _leave_button: Button
var _back_button: Button
var _map_option: OptionButton
var _ctf_room_box: VBoxContainer
var _ctf_room_title: Label
var _ctf_room_red_label: Label
var _ctf_room_blue_label: Label
var _ctf_join_red_button: Button
var _ctf_join_blue_button: Button
var _ctf_start_button: Button
var _ctf_ready_button: Button
var _ctf_add_bots_check: CheckBox
var _ctf_room_state: Dictionary = {}
var _dm_room_box: VBoxContainer
var _dm_room_title: Label
var _dm_room_members_label: Label
var _dm_ready_button: Button
var _dm_start_button: Button
var _dm_add_bots_check: CheckBox
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
var _map_catalog = MAP_CATALOG_SCRIPT.new()
var _map_flow_service = MAP_FLOW_SERVICE_SCRIPT.new()
var _selected_mode_id := "deathmatch"
var _selected_map_id := ""

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
	_ensure_valid_map_selection()
	_refresh_map_dropdown_selection()
	_lobby_list_ready = false
	_pending_create_request = {}
	_ctf_room_state.clear()
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
	var target_w := clampf(viewport_size.x * 0.50, 380.0, 620.0)
	var target_h := clampf(viewport_size.y * 0.74, 320.0, 620.0)
	_panel.custom_minimum_size = Vector2(target_w, target_h)
	_panel.size = Vector2(target_w, target_h)
	_panel.position = (viewport_size - _panel.size) * 0.5

func _show_lobby_rooms() -> void:
	if _overlay == null:
		return
	_log("show_lobby_rooms visible=%s" % str(_overlay.visible))
	_lobby_list_ready = false
	if _header_title != null:
		_header_title.visible = true
	if _rooms_title_label != null:
		_rooms_title_label.visible = true
	if _loading_box != null:
		_loading_box.visible = false
	if _rooms_box != null:
		_rooms_box.visible = true
	_hide_ctf_room()
	_hide_dm_room()

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
	candidate_paths.append("res://build/release/launcher_config.json")
	candidate_paths.append("res://build/launcher/launcher_config.json")
	candidate_paths.append("res://launcher/launcher_config.json")

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

func _begin_connect_attempt(force_restart: bool, reason: String = "Connecting...", allow_while_connecting: bool = false) -> void:
	if _rpc_bridge == null:
		_log("begin_connect_attempt aborted rpc_bridge=null")
		return
	if not allow_while_connecting and not force_restart and bool(_rpc_bridge.call("is_connecting_to_server")):
		_log("begin_connect_attempt skipped already connecting")
		if _status_label != null:
			_status_label.text = "Connecting to lobby server..."
		_refresh_lobby_buttons_state()
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
	var timer := _host.get_tree().create_timer(CONNECT_WATCHDOG_TIMEOUT_SEC)
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
		var had_pending_create := not _pending_create_request.is_empty()
		_pending_create_request = {}
		_action_inflight = false
		_lobby_list_ready = true
		_room_entries = []
		_log("all connect candidates exhausted")
		if _status_label != null:
			_status_label.text = "Lobby server unavailable. Online create failed." if had_pending_create else "Connection failed. Try Refresh."
		_populate_lobby_room_list()
		_refresh_lobby_selection_summary()
		_refresh_lobby_buttons_state()
		return
	_begin_connect_attempt(false, "Retrying", true)

func _request_lobby_list_from_server() -> void:
	if _rpc_bridge == null:
		_log("request_lobby_list aborted rpc_bridge=null")
		return
	if _rpc_bridge.call("can_send_lobby_rpc"):
		_log("request_lobby_list sending immediately")
		_rpc_bridge.call("request_lobby_list")
		_refresh_lobby_buttons_state()
		return
	if bool(_rpc_bridge.call("is_connecting_to_server")):
		_log("request_lobby_list waiting existing connect attempt")
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
	if not _rpc_bridge.lobby_room_state_received.is_connected(_on_rpc_room_state):
		_rpc_bridge.lobby_room_state_received.connect(_on_rpc_room_state)

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
	_ctf_room_state.clear()
	_log("rpc disconnected signal")
	if _status_label != null:
		_status_label.text = "Disconnected from server"
	_hide_ctf_room()
	_hide_dm_room()
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
	if _joined_lobby_id <= 0:
		_ctf_room_state.clear()
		_hide_ctf_room()
		_hide_dm_room()
	_populate_lobby_room_list()
	_refresh_lobby_selection_summary()
	_refresh_lobby_buttons_state()

func _on_rpc_action_result(success: bool, message: String, active_lobby_id: int, _map_id: String) -> void:
	_log("action_result success=%s active_lobby_id=%d message=%s" % [str(success), active_lobby_id, message])
	if success and active_lobby_id > 0:
		_log("action_result result=SERVER_LOBBY_CONFIRMED lobby_id=%d" % active_lobby_id)
	elif not success:
		_log("action_result result=SERVER_ACTION_FAILED")
	_joined_lobby_id = active_lobby_id
	_action_inflight = false
	_action_nonce += 1
	if _status_label != null:
		_status_label.text = message if success else "Failed: %s" % message
	if success and active_lobby_id > 0:
		var resolved_mode := _active_lobby_mode_id(active_lobby_id)
		if resolved_mode == "ctf" or resolved_mode == "deathmatch":
			if _status_label != null:
				_status_label.text = "Entered CTF room. Pick a team and start." if resolved_mode == "ctf" else "Entered Deathmatch waiting room."
			_pending_create_request = {}
			_request_lobby_list_from_server()
			_refresh_lobby_buttons_state()
			return
		_pending_create_request = {}
		_connect_nonce += 1
		if _overlay != null:
			_overlay.visible = false
		if _on_closed.is_valid():
			_on_closed.call()
		_refresh_lobby_buttons_state()
		return
	if success and active_lobby_id <= 0 and not _pending_create_request.is_empty():
		if _rpc_bridge != null and bool(_rpc_bridge.call("can_send_lobby_rpc")):
			_log("action_result post-leave sending pending create request")
			_send_create_lobby_request(_pending_create_request)
			return
		_log("action_result post-leave pending create exists; reconnecting")
		_request_lobby_list_from_server()
		_refresh_lobby_buttons_state()
		return
	_request_lobby_list_from_server()
	_refresh_lobby_buttons_state()

func _on_rpc_room_state(payload: Dictionary) -> void:
	_ctf_room_state = payload.duplicate(true)
	_log("room_state received payload=%s" % str(_ctf_room_state))
	if int(_ctf_room_state.get("lobby_id", 0)) != _joined_lobby_id:
		return
	var mode_id := _active_lobby_mode_id(_joined_lobby_id)
	if mode_id == "ctf":
		_hide_dm_room()
		_show_ctf_room(_ctf_room_state)
		return
	if mode_id == "deathmatch":
		_hide_ctf_room()
		if bool(_ctf_room_state.get("started", false)):
			_hide_dm_room()
			return
		_show_dm_room(_ctf_room_state)
		return
	_hide_ctf_room()
	_hide_dm_room()

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
		btn.custom_minimum_size = Vector2(0, 30)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lobby_id := int(entry.get("id", 0))
		var room_name := str(entry.get("name", "Room"))
		var players := int(entry.get("players", 0))
		var max_players := int(entry.get("max_players", 2))
		var map_id := str(entry.get("map_name", entry.get("map_id", "classic"))).to_upper()
		var mode_id := str(entry.get("mode_name", entry.get("mode_id", "deathmatch"))).to_upper()
		var in_room := lobby_id > 0 and lobby_id == _joined_lobby_id
		var suffix := "  [IN]" if in_room else ""
		btn.text = "#%d  %s   |   %d/%d   |   %s | %s%s" % [lobby_id, room_name, players, max_players, map_id, mode_id, suffix]
		btn.set_meta("kw_room_base_text", btn.text)
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
		_apply_room_button_selected_style(btn, i == index)
	if _join_button != null:
		_join_button.disabled = false
	_refresh_lobby_selection_summary()
	_refresh_lobby_buttons_state()

func _apply_room_button_selected_style(btn: Button, selected: bool) -> void:
	if btn == null:
		return
	var base_text := str(btn.get_meta("kw_room_base_text", btn.text))
	btn.text = ("> " + base_text) if selected else base_text
	if selected:
		btn.modulate = Color(1, 1, 1, 1)
		btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.75, 1.0))
		var selected_style := StyleBoxFlat.new()
		selected_style.bg_color = Color(0.24, 0.2, 0.12, 0.96)
		selected_style.border_width_left = 2
		selected_style.border_width_top = 2
		selected_style.border_width_right = 2
		selected_style.border_width_bottom = 2
		selected_style.border_color = Color(0.9, 0.74, 0.27, 1.0)
		btn.add_theme_stylebox_override("normal", selected_style)
		btn.add_theme_stylebox_override("hover", selected_style)
		btn.add_theme_stylebox_override("pressed", selected_style)
		btn.add_theme_stylebox_override("focus", selected_style)
		return
	btn.modulate = Color(0.88, 0.9, 0.96, 0.96)
	btn.remove_theme_color_override("font_color")
	btn.remove_theme_color_override("font_hover_color")
	btn.remove_theme_stylebox_override("normal")
	btn.remove_theme_stylebox_override("hover")
	btn.remove_theme_stylebox_override("pressed")
	btn.remove_theme_stylebox_override("focus")

func _refresh_lobby_selection_summary() -> void:
	if _selection_label == null:
		return
	if not _ctf_room_state.is_empty() and _active_lobby_mode_id(_joined_lobby_id) == "ctf":
		_selection_label.text = "CTF room: %s" % _joined_room_name
		return
	if not _ctf_room_state.is_empty() and _active_lobby_mode_id(_joined_lobby_id) == "deathmatch" and not bool(_ctf_room_state.get("started", false)):
		_selection_label.text = "DM waiting room: %s" % _joined_room_name
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
	var request := _build_create_lobby_request()
	if _joined_lobby_id > 0:
		_log("create_lobby while in lobby id=%d; leaving first then creating new lobby" % _joined_lobby_id)
		_pending_create_request = request.duplicate(true)
		if _status_label != null:
			_status_label.text = "Leaving current lobby..."
		_begin_lobby_action("Leaving current lobby...")
		var sent_leave := bool(_rpc_bridge.call("leave_lobby"))
		if not sent_leave:
			_action_inflight = false
			_request_lobby_list_from_server()
		_refresh_lobby_buttons_state()
		return
	_log("create_lobby clicked request=%s can_send=%s" % [str(request), str(bool(_rpc_bridge.call("can_send_lobby_rpc")))])
	if not bool(_rpc_bridge.call("can_send_lobby_rpc")):
		_log("create_lobby has no active lobby-server connection; queueing reconnect for ONLINE lobby create")
		_pending_create_request = request.duplicate(true)
		if _status_label != null:
			_status_label.text = "Connecting to lobby server..."
		if bool(_rpc_bridge.call("is_connecting_to_server")):
			_log("create_lobby queued while connect attempt is in-flight")
		else:
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
	_ctf_room_state.clear()
	_hide_ctf_room()
	_hide_dm_room()
	_refresh_lobby_selection_summary()
	_refresh_lobby_buttons_state()

func _start_ctf_match() -> void:
	_start_lobby_match("Starting CTF match...")

func _start_lobby_match(status_text: String = "Starting match...") -> void:
	if _rpc_bridge == null:
		return
	if _joined_lobby_id <= 0:
		return
	_begin_lobby_action(status_text)
	var sent_start := bool(_rpc_bridge.call("start_lobby_match"))
	if _status_label != null:
		_status_label.text = status_text if sent_start else "Still connecting..."
	if not sent_start:
		_action_inflight = false
		_request_lobby_list_from_server()
	_refresh_lobby_buttons_state()

func _build_create_lobby_request() -> Dictionary:
	_ensure_valid_map_selection()
	var requested_name := "My Lobby %d" % (_room_entries.size() + 1)
	var selected_weapon_id := _selected_weapon_id()
	var selected_character_id := _selected_warrior_id()
	var request := {
		"name": requested_name,
		"weapon_id": selected_weapon_id,
		"character_id": selected_character_id,
		"map_id": _selected_map_id,
		"mode_id": _selected_mode_id,
	}
	_log("build_create_lobby_request selected_map_id=%s selected_mode_id=%s request=%s" % [_selected_map_id, _selected_mode_id, str(request)])
	return request

func _send_create_lobby_request(request: Dictionary) -> void:
	_pending_create_request = {}
	_ensure_valid_map_selection()
	var default_map_id := _map_flow_service.normalize_map_id(_map_catalog, _map_catalog.default_map_id())
	var requested_name := str(request.get("name", "")).strip_edges()
	var selected_weapon_id := str(request.get("weapon_id", "ak47")).strip_edges().to_lower()
	var selected_character_id := str(request.get("character_id", "outrage")).strip_edges().to_lower()
	var map_id := str(request.get("map_id", default_map_id)).strip_edges().to_lower()
	var mode_id := str(request.get("mode_id", "deathmatch")).strip_edges().to_lower()
	if requested_name.is_empty():
		requested_name = "My Lobby %d" % (_room_entries.size() + 1)
	if selected_weapon_id.is_empty():
		selected_weapon_id = "ak47"
	if selected_character_id != "erebus" and selected_character_id != "tasko":
		selected_character_id = "outrage"
	if map_id.is_empty():
		map_id = default_map_id
	map_id = _map_flow_service.normalize_map_id(_map_catalog, map_id)
	mode_id = _map_flow_service.select_mode_for_map(_map_catalog, map_id, mode_id)
	_log("send_create_lobby_request name=%s weapon=%s character=%s map=%s mode=%s can_send=%s" % [
		requested_name,
		selected_weapon_id,
		selected_character_id,
		map_id,
		mode_id,
		str(bool(_rpc_bridge.call("can_send_lobby_rpc")))
	])
	_persist_local_loadout_selection()
	_sync_selected_warrior_skin()
	_sync_selected_weapon_skin()
	_begin_lobby_action("Creating lobby...")
	var sent_create := bool(_rpc_bridge.call("create_lobby", requested_name, selected_weapon_id, selected_character_id, map_id, mode_id))
	_log("create_lobby rpc sent=%s" % str(sent_create))
	if sent_create:
		_log("create_lobby result=RPC_SENT awaiting server confirmation")
	if _status_label != null:
		_status_label.text = "Creating lobby..." if sent_create else "Still connecting..."
	if not sent_create:
		_action_inflight = false
		_pending_create_request = request.duplicate(true)
		_request_lobby_list_from_server()
	_refresh_lobby_selection_summary()
	_refresh_lobby_buttons_state()

func _ensure_valid_map_selection() -> void:
	var map_ids := _map_catalog.all_map_ids()
	if map_ids.is_empty():
		_selected_map_id = "classic"
		_selected_mode_id = "deathmatch"
		_refresh_map_dropdown_selection()
		return
	var fallback_map := _map_flow_service.normalize_map_id(_map_catalog, str(map_ids[0]))
	var candidate := _selected_map_id
	if candidate.strip_edges().is_empty():
		candidate = _map_catalog.default_map_id()
	_selected_map_id = _map_flow_service.normalize_map_id(_map_catalog, candidate)
	if map_ids.find(_selected_map_id) < 0:
		_selected_map_id = fallback_map
	_selected_mode_id = _map_flow_service.select_mode_for_map(_map_catalog, _selected_map_id, _selected_mode_id)
	_refresh_map_dropdown_selection()

func _populate_map_dropdown() -> void:
	if _map_option == null:
		return
	_map_option.clear()
	for map_id_value in _map_catalog.all_map_ids():
		var map_id := str(map_id_value)
		var label := _map_flow_service.map_label_for_id(_map_catalog, map_id)
		_map_option.add_item(label)
		_map_option.set_item_metadata(_map_option.get_item_count() - 1, map_id)
	_refresh_map_dropdown_selection()

func _refresh_map_dropdown_selection() -> void:
	if _map_option == null:
		return
	var idx := -1
	for i in range(_map_option.get_item_count()):
		if str(_map_option.get_item_metadata(i)) == _selected_map_id:
			idx = i
			break
	if idx >= 0:
		_map_option.select(idx)

func _on_map_option_selected(index: int) -> void:
	if _map_option == null:
		return
	if index < 0 or index >= _map_option.get_item_count():
		return
	var next_map_id := str(_map_option.get_item_metadata(index)).strip_edges()
	if next_map_id.is_empty():
		return
	_selected_map_id = _map_flow_service.normalize_map_id(_map_catalog, next_map_id)
	_selected_mode_id = _map_flow_service.select_mode_for_map(_map_catalog, _selected_map_id, _selected_mode_id)
	_log("map_dropdown selected_map_id=%s selected_mode_id=%s" % [_selected_map_id, _selected_mode_id])

func _refresh_lobby_buttons_state() -> void:
	var can_send := _rpc_bridge != null and bool(_rpc_bridge.call("can_send_lobby_rpc"))
	var in_waiting_room := not _ctf_room_state.is_empty() and _joined_lobby_id > 0 and not bool(_ctf_room_state.get("started", false))
	var in_ctf_room := in_waiting_room and _active_lobby_mode_id(_joined_lobby_id) == "ctf"
	var in_dm_room := in_waiting_room and _active_lobby_mode_id(_joined_lobby_id) == "deathmatch"
	var local_peer_id := _local_peer_id()
	var is_owner := local_peer_id > 0 and local_peer_id == int(_ctf_room_state.get("owner_peer_id", 0))
	if _create_button != null:
		_create_button.visible = not in_waiting_room
		_create_button.disabled = _joined_lobby_id > 0 or _action_inflight or in_waiting_room
	if _join_button != null:
		_join_button.visible = not in_waiting_room
		_join_button.disabled = not can_send or _selected_room_index < 0 or _action_inflight or in_waiting_room
	if _refresh_button != null:
		_refresh_button.visible = not in_waiting_room
		_refresh_button.disabled = _action_inflight or in_waiting_room
	if _leave_button != null:
		_leave_button.visible = in_waiting_room
		_leave_button.disabled = not can_send or _joined_room_name.is_empty() or _action_inflight
	if _back_button != null:
		_back_button.visible = not in_waiting_room
		_back_button.disabled = _action_inflight
	if _ctf_join_red_button != null:
		_ctf_join_red_button.disabled = not can_send or _action_inflight or _local_team_id() == 0
	if _ctf_join_blue_button != null:
		_ctf_join_blue_button.disabled = not can_send or _action_inflight or _local_team_id() == 1
	if _ctf_start_button != null:
		_ctf_start_button.disabled = not can_send or _action_inflight or _local_peer_id() != int(_ctf_room_state.get("owner_peer_id", 0)) or not bool(_ctf_room_state.get("can_start", false))
	if _ctf_ready_button != null:
		_ctf_ready_button.visible = in_ctf_room and not is_owner
		_ctf_ready_button.disabled = not can_send or _action_inflight or not in_ctf_room
	if _ctf_add_bots_check != null:
		_ctf_add_bots_check.visible = in_ctf_room and is_owner
		_ctf_add_bots_check.disabled = not can_send or _action_inflight or not in_ctf_room or not is_owner
	if _dm_ready_button != null:
		_dm_ready_button.visible = in_dm_room and not is_owner
		_dm_ready_button.disabled = not can_send or _action_inflight or not in_dm_room
	if _dm_start_button != null:
		_dm_start_button.disabled = not can_send or _action_inflight or not in_dm_room or not is_owner or not bool(_ctf_room_state.get("can_start", false))
	if _dm_add_bots_check != null:
		_dm_add_bots_check.visible = in_dm_room and is_owner
		_dm_add_bots_check.disabled = not can_send or _action_inflight or not in_dm_room or not is_owner

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
	panel.custom_minimum_size = Vector2(380, 250)
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
	root.add_theme_constant_override("separation", 4)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(root)

	var title := Label.new()
	title.text = "LOBBY ROOMS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	root.add_child(title)
	_header_title = title

	var status := Label.new()
	status.text = "Status: Idle"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 10)
	root.add_child(status)
	_status_label = status

	var loading_box := PanelContainer.new()
	loading_box.custom_minimum_size = Vector2(0, 64)
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
	loading_v.add_theme_constant_override("separation", 4)
	loading_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_margin.add_child(loading_v)

	var loading_title := Label.new()
	loading_title.text = "LOADING"
	loading_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_title.add_theme_font_size_override("font_size", 13)
	loading_v.add_child(loading_title)
	_loading_label = loading_title

	var loading_sub := Label.new()
	loading_sub.text = "Please wait..."
	loading_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_sub.add_theme_font_size_override("font_size", 9)
	loading_v.add_child(loading_sub)

	var rooms_title := Label.new()
	rooms_title.text = "Lobbies"
	rooms_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rooms_title.add_theme_font_size_override("font_size", 11)
	root.add_child(rooms_title)
	_rooms_title_label = rooms_title

	var rooms_box := VBoxContainer.new()
	rooms_box.custom_minimum_size = Vector2(0, 64)
	rooms_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rooms_box.add_theme_constant_override("separation", 4)
	rooms_box.visible = false
	root.add_child(rooms_box)
	_rooms_box = rooms_box

	var selection_label := Label.new()
	selection_label.text = "Select a room and press JOIN"
	selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_label.add_theme_font_size_override("font_size", 9)
	root.add_child(selection_label)
	_selection_label = selection_label

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	root.add_child(mode_row)
	_mode_row = mode_row

	var waiting_room_title := Label.new()
	waiting_room_title.visible = false
	waiting_room_title.text = ""
	waiting_room_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	waiting_room_title.add_theme_font_size_override("font_size", 11)
	root.add_child(waiting_room_title)
	_waiting_room_title_label = waiting_room_title

	var map_label := Label.new()
	map_label.text = "Map"
	map_label.add_theme_font_size_override("font_size", 9)
	mode_row.add_child(map_label)

	var map_option := OptionButton.new()
	map_option.custom_minimum_size = Vector2(170, 18)
	map_option.size_flags_horizontal = Control.SIZE_FILL
	map_option.alignment = HORIZONTAL_ALIGNMENT_LEFT
	map_option.add_theme_font_size_override("font_size", 8)
	map_option.add_theme_constant_override("arrow_margin", 4)
	map_option.add_theme_constant_override("h_separation", 4)
	map_option.add_theme_color_override("font_color", Color(0.94, 0.93, 0.9, 1))
	map_option.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	map_option.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	var map_option_normal := StyleBoxFlat.new()
	map_option_normal.bg_color = Color(0.11, 0.1, 0.16, 1.0)
	map_option_normal.border_width_left = 2
	map_option_normal.border_width_top = 2
	map_option_normal.border_width_right = 2
	map_option_normal.border_width_bottom = 2
	map_option_normal.border_color = Color(0.29, 0.28, 0.4, 1)
	map_option_normal.corner_radius_top_left = 0
	map_option_normal.corner_radius_top_right = 0
	map_option_normal.corner_radius_bottom_right = 0
	map_option_normal.corner_radius_bottom_left = 0
	map_option_normal.content_margin_left = 6
	map_option_normal.content_margin_right = 6
	map_option_normal.content_margin_top = 3
	map_option_normal.content_margin_bottom = 3
	var map_option_hover := map_option_normal.duplicate() as StyleBoxFlat
	map_option_hover.bg_color = Color(0.17, 0.15, 0.22, 1.0)
	map_option_hover.border_color = Color(0.9, 0.74, 0.27, 1.0)
	map_option.add_theme_stylebox_override("normal", map_option_normal)
	map_option.add_theme_stylebox_override("hover", map_option_hover)
	map_option.add_theme_stylebox_override("pressed", map_option_hover)
	map_option.add_theme_stylebox_override("focus", map_option_hover)
	map_option.add_theme_icon_override("arrow", _make_pixel_dropdown_arrow())
	var map_popup := map_option.get_popup()
	var map_popup_panel := StyleBoxFlat.new()
	map_popup_panel.bg_color = Color(0.1, 0.09, 0.15, 1.0)
	map_popup_panel.border_width_left = 2
	map_popup_panel.border_width_top = 2
	map_popup_panel.border_width_right = 2
	map_popup_panel.border_width_bottom = 2
	map_popup_panel.border_color = Color(0.29, 0.28, 0.4, 1)
	map_popup_panel.corner_radius_top_left = 0
	map_popup_panel.corner_radius_top_right = 0
	map_popup_panel.corner_radius_bottom_right = 0
	map_popup_panel.corner_radius_bottom_left = 0
	var map_popup_hover := StyleBoxFlat.new()
	map_popup_hover.bg_color = Color(0.28, 0.22, 0.12, 1.0)
	map_popup_hover.border_width_left = 1
	map_popup_hover.border_width_top = 1
	map_popup_hover.border_width_right = 1
	map_popup_hover.border_width_bottom = 1
	map_popup_hover.border_color = Color(0.9, 0.74, 0.27, 1.0)
	map_popup_hover.corner_radius_top_left = 0
	map_popup_hover.corner_radius_top_right = 0
	map_popup_hover.corner_radius_bottom_right = 0
	map_popup_hover.corner_radius_bottom_left = 0
	var map_popup_separator := StyleBoxFlat.new()
	map_popup_separator.bg_color = Color(0.27, 0.24, 0.35, 1.0)
	map_popup_separator.content_margin_top = 1
	map_popup_separator.content_margin_bottom = 1
	map_popup.add_theme_stylebox_override("panel", map_popup_panel)
	map_popup.add_theme_stylebox_override("hover", map_popup_hover)
	map_popup.add_theme_stylebox_override("hover_pressed", map_popup_hover)
	map_popup.add_theme_stylebox_override("selected", map_popup_hover)
	map_popup.add_theme_stylebox_override("focus", map_popup_hover)
	map_popup.add_theme_stylebox_override("item_hover", map_popup_hover)
	map_popup.add_theme_stylebox_override("separator", map_popup_separator)
	map_popup.add_theme_constant_override("v_separation", 2)
	map_popup.add_theme_constant_override("h_separation", 6)
	map_popup.add_theme_color_override("font_color", Color(0.92, 0.92, 0.9, 1))
	map_popup.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	map_popup.add_theme_color_override("font_selected_color", Color(1, 1, 1, 1))
	map_popup.add_theme_font_size_override("font_size", 8)
	var map_popup_checked_icon := _make_pixel_popup_marker(true)
	var map_popup_unchecked_icon := _make_pixel_popup_marker(false)
	map_popup.add_theme_icon_override("checked", map_popup_checked_icon)
	map_popup.add_theme_icon_override("unchecked", map_popup_unchecked_icon)
	map_popup.add_theme_icon_override("radio_checked", map_popup_checked_icon)
	map_popup.add_theme_icon_override("radio_unchecked", map_popup_unchecked_icon)
	map_popup.about_to_popup.connect(func() -> void:
		_position_option_popup_below(map_option, map_popup)
	)
	map_option.item_selected.connect(_on_map_option_selected)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(map_option)
	mode_row.add_child(map_option)
	_map_option = map_option
	_populate_map_dropdown()

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	root.add_child(actions)
	_actions_row = actions

	var create_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	create_btn.text = "CREATE"
	create_btn.custom_minimum_size = Vector2(0, 22)
	create_btn.add_theme_font_size_override("font_size", 9)
	create_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_btn.pressed.connect(_create_lobby_room)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(create_btn)
	actions.add_child(create_btn)
	_create_button = create_btn

	var join_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	join_btn.text = "JOIN"
	join_btn.custom_minimum_size = Vector2(0, 22)
	join_btn.add_theme_font_size_override("font_size", 9)
	join_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_btn.disabled = true
	join_btn.pressed.connect(_join_selected_lobby_room)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(join_btn)
	actions.add_child(join_btn)
	_join_button = join_btn

	var refresh_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	refresh_btn.text = "REFRESH"
	refresh_btn.custom_minimum_size = Vector2(0, 22)
	refresh_btn.add_theme_font_size_override("font_size", 9)
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
	leave_btn.custom_minimum_size = Vector2(0, 22)
	leave_btn.add_theme_font_size_override("font_size", 9)
	leave_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave_btn.disabled = true
	leave_btn.pressed.connect(_leave_lobby_room)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(leave_btn)
	actions.add_child(leave_btn)
	_leave_button = leave_btn

	var back_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	back_btn.text = "BACK"
	back_btn.custom_minimum_size = Vector2(0, 22)
	back_btn.add_theme_font_size_override("font_size", 9)
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void:
		hide()
	)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(back_btn)
	actions.add_child(back_btn)
	_back_button = back_btn

	var ctf_room_box := VBoxContainer.new()
	ctf_room_box.visible = false
	ctf_room_box.add_theme_constant_override("separation", 6)
	root.add_child(ctf_room_box)
	_ctf_room_box = ctf_room_box

	var ctf_title := Label.new()
	ctf_title.text = "CTF ROOM"
	ctf_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctf_title.add_theme_font_size_override("font_size", 11)
	ctf_room_box.add_child(ctf_title)
	_ctf_room_title = ctf_title

	var teams_header := Label.new()
	teams_header.text = "TEAMS"
	teams_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	teams_header.add_theme_font_size_override("font_size", 9)
	ctf_room_box.add_child(teams_header)

	var teams_row := HBoxContainer.new()
	teams_row.add_theme_constant_override("separation", 6)
	ctf_room_box.add_child(teams_row)

	var red_card := PanelContainer.new()
	red_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	teams_row.add_child(red_card)
	var red_style := StyleBoxFlat.new()
	red_style.bg_color = Color(0.24, 0.11, 0.12, 0.9)
	red_style.border_width_left = 2
	red_style.border_width_top = 2
	red_style.border_width_right = 2
	red_style.border_width_bottom = 2
	red_style.border_color = Color(0.8, 0.32, 0.32, 1)
	red_card.add_theme_stylebox_override("panel", red_style)
	var red_margin := MarginContainer.new()
	red_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	red_margin.add_theme_constant_override("margin_left", 6)
	red_margin.add_theme_constant_override("margin_top", 5)
	red_margin.add_theme_constant_override("margin_right", 6)
	red_margin.add_theme_constant_override("margin_bottom", 5)
	red_card.add_child(red_margin)

	var red_label := Label.new()
	red_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	red_label.custom_minimum_size = Vector2(0, 68)
	red_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	red_label.text = "RED TEAM"
	red_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	red_label.add_theme_font_size_override("font_size", 9)
	red_margin.add_child(red_label)
	_ctf_room_red_label = red_label

	var blue_card := PanelContainer.new()
	blue_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	teams_row.add_child(blue_card)
	var blue_style := StyleBoxFlat.new()
	blue_style.bg_color = Color(0.1, 0.15, 0.26, 0.9)
	blue_style.border_width_left = 2
	blue_style.border_width_top = 2
	blue_style.border_width_right = 2
	blue_style.border_width_bottom = 2
	blue_style.border_color = Color(0.35, 0.55, 0.95, 1)
	blue_card.add_theme_stylebox_override("panel", blue_style)
	var blue_margin := MarginContainer.new()
	blue_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	blue_margin.add_theme_constant_override("margin_left", 6)
	blue_margin.add_theme_constant_override("margin_top", 5)
	blue_margin.add_theme_constant_override("margin_right", 6)
	blue_margin.add_theme_constant_override("margin_bottom", 5)
	blue_card.add_child(blue_margin)

	var blue_label := Label.new()
	blue_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blue_label.custom_minimum_size = Vector2(0, 68)
	blue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	blue_label.text = "BLUE TEAM"
	blue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blue_label.add_theme_font_size_override("font_size", 9)
	blue_margin.add_child(blue_label)
	_ctf_room_blue_label = blue_label

	var controls_header := Label.new()
	controls_header.text = "MATCH CONTROLS"
	controls_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	controls_header.add_theme_font_size_override("font_size", 9)
	ctf_room_box.add_child(controls_header)

	var controls_card := PanelContainer.new()
	ctf_room_box.add_child(controls_card)
	var controls_style := StyleBoxFlat.new()
	controls_style.bg_color = Color(0.12, 0.11, 0.17, 0.95)
	controls_style.border_width_left = 2
	controls_style.border_width_top = 2
	controls_style.border_width_right = 2
	controls_style.border_width_bottom = 2
	controls_style.border_color = Color(0.29, 0.28, 0.4, 1)
	controls_card.add_theme_stylebox_override("panel", controls_style)
	var controls_margin := MarginContainer.new()
	controls_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	controls_margin.add_theme_constant_override("margin_left", 6)
	controls_margin.add_theme_constant_override("margin_top", 6)
	controls_margin.add_theme_constant_override("margin_right", 6)
	controls_margin.add_theme_constant_override("margin_bottom", 6)
	controls_card.add_child(controls_margin)

	var room_actions := VBoxContainer.new()
	room_actions.add_theme_constant_override("separation", 5)
	controls_margin.add_child(room_actions)

	var team_actions := HBoxContainer.new()
	team_actions.add_theme_constant_override("separation", 6)
	room_actions.add_child(team_actions)

	var join_red_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	join_red_btn.text = "JOIN RED"
	join_red_btn.custom_minimum_size = Vector2(0, 22)
	join_red_btn.add_theme_font_size_override("font_size", 9)
	join_red_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_red_btn.pressed.connect(func() -> void:
		if _rpc_bridge != null:
			_rpc_bridge.call("set_lobby_team", 0)
	)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(join_red_btn)
	team_actions.add_child(join_red_btn)
	_ctf_join_red_button = join_red_btn

	var join_blue_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	join_blue_btn.text = "JOIN BLUE"
	join_blue_btn.custom_minimum_size = Vector2(0, 22)
	join_blue_btn.add_theme_font_size_override("font_size", 9)
	join_blue_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_blue_btn.pressed.connect(func() -> void:
		if _rpc_bridge != null:
			_rpc_bridge.call("set_lobby_team", 1)
	)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(join_blue_btn)
	team_actions.add_child(join_blue_btn)
	_ctf_join_blue_button = join_blue_btn

	var match_actions := HBoxContainer.new()
	match_actions.add_theme_constant_override("separation", 6)
	room_actions.add_child(match_actions)

	var start_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	start_btn.text = "START MATCH"
	start_btn.custom_minimum_size = Vector2(0, 22)
	start_btn.add_theme_font_size_override("font_size", 9)
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn.pressed.connect(_start_ctf_match)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(start_btn)
	var ready_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	ready_btn.text = "READY"
	ready_btn.custom_minimum_size = Vector2(0, 22)
	ready_btn.add_theme_font_size_override("font_size", 9)
	ready_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ready_btn.pressed.connect(func() -> void:
		if _rpc_bridge == null:
			return
		if _ctf_room_state.is_empty():
			return
		var ready_by_peer := _ctf_room_state.get("ready_by_peer", {}) as Dictionary
		var local_ready := bool(ready_by_peer.get(_local_peer_id(), false))
		_rpc_bridge.call("set_lobby_ready", not local_ready)
	)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(ready_btn)
	match_actions.add_child(ready_btn)
	_ctf_ready_button = ready_btn

	match_actions.add_child(start_btn)
	_ctf_start_button = start_btn

	var ctf_add_bots_check := CheckBox.new()
	ctf_add_bots_check.text = "Add Bots"
	ctf_add_bots_check.add_theme_font_size_override("font_size", 9)
	ctf_add_bots_check.button_pressed = false
	ctf_add_bots_check.toggled.connect(func(toggled_on: bool) -> void:
		if _rpc_bridge != null:
			_rpc_bridge.call("set_lobby_add_bots", toggled_on)
	)
	ctf_room_box.add_child(ctf_add_bots_check)
	_ctf_add_bots_check = ctf_add_bots_check

	var dm_room_box := VBoxContainer.new()
	dm_room_box.visible = false
	dm_room_box.add_theme_constant_override("separation", 6)
	root.add_child(dm_room_box)
	_dm_room_box = dm_room_box

	var dm_title := Label.new()
	dm_title.text = "DEATHMATCH ROOM"
	dm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dm_title.add_theme_font_size_override("font_size", 11)
	dm_room_box.add_child(dm_title)
	_dm_room_title = dm_title

	var dm_members_card := PanelContainer.new()
	dm_room_box.add_child(dm_members_card)
	var dm_members_style := StyleBoxFlat.new()
	dm_members_style.bg_color = Color(0.12, 0.11, 0.17, 0.95)
	dm_members_style.border_width_left = 2
	dm_members_style.border_width_top = 2
	dm_members_style.border_width_right = 2
	dm_members_style.border_width_bottom = 2
	dm_members_style.border_color = Color(0.29, 0.28, 0.4, 1)
	dm_members_card.add_theme_stylebox_override("panel", dm_members_style)
	var dm_members_margin := MarginContainer.new()
	dm_members_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	dm_members_margin.add_theme_constant_override("margin_left", 6)
	dm_members_margin.add_theme_constant_override("margin_top", 6)
	dm_members_margin.add_theme_constant_override("margin_right", 6)
	dm_members_margin.add_theme_constant_override("margin_bottom", 6)
	dm_members_card.add_child(dm_members_margin)

	var dm_members := Label.new()
	dm_members.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dm_members.text = "Waiting for players..."
	dm_members.add_theme_font_size_override("font_size", 9)
	dm_members_margin.add_child(dm_members)
	_dm_room_members_label = dm_members

	var dm_actions := HBoxContainer.new()
	dm_actions.add_theme_constant_override("separation", 6)
	dm_room_box.add_child(dm_actions)

	var dm_ready_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	dm_ready_btn.text = "READY"
	dm_ready_btn.custom_minimum_size = Vector2(0, 20)
	dm_ready_btn.add_theme_font_size_override("font_size", 9)
	dm_ready_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dm_ready_btn.pressed.connect(func() -> void:
		if _rpc_bridge == null:
			return
		if _ctf_room_state.is_empty():
			return
		var ready_by_peer := _ctf_room_state.get("ready_by_peer", {}) as Dictionary
		var local_ready := bool(ready_by_peer.get(_local_peer_id(), false))
		_rpc_bridge.call("set_lobby_ready", not local_ready)
	)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(dm_ready_btn)
	dm_actions.add_child(dm_ready_btn)
	_dm_ready_button = dm_ready_btn

	var dm_start_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	dm_start_btn.text = "START MATCH"
	dm_start_btn.custom_minimum_size = Vector2(0, 20)
	dm_start_btn.add_theme_font_size_override("font_size", 9)
	dm_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dm_start_btn.pressed.connect(func() -> void:
		_start_lobby_match("Starting Deathmatch...")
	)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(dm_start_btn)
	dm_actions.add_child(dm_start_btn)
	_dm_start_button = dm_start_btn

	var dm_add_bots_check := CheckBox.new()
	dm_add_bots_check.text = "Add Bots"
	dm_add_bots_check.add_theme_font_size_override("font_size", 9)
	dm_add_bots_check.button_pressed = false
	dm_add_bots_check.toggled.connect(func(toggled_on: bool) -> void:
		if _rpc_bridge != null:
			_rpc_bridge.call("set_lobby_add_bots", toggled_on)
	)
	dm_room_box.add_child(dm_add_bots_check)
	_dm_add_bots_check = dm_add_bots_check

	_refresh_lobby_selection_summary()
	_refresh_lobby_buttons_state()

func _show_ctf_room(payload: Dictionary) -> void:
	if _ctf_room_box == null:
		return
	if _header_title != null:
		_header_title.visible = false
	if _rooms_title_label != null:
		_rooms_title_label.visible = false
	if _status_label != null:
		_status_label.visible = false
	if _selection_label != null:
		_selection_label.visible = false
	if _rooms_box != null:
		_rooms_box.visible = false
	if _mode_row != null:
		_mode_row.visible = false
	if _waiting_room_title_label != null:
		_waiting_room_title_label.visible = true
		_waiting_room_title_label.text = "%s  |  CTF ROOM" % str(payload.get("name", "CTF Room"))
	_ctf_room_box.visible = true
	if _ctf_room_title != null:
		_ctf_room_title.visible = false
		_ctf_room_title.text = "%s  |  CTF ROOM" % str(payload.get("name", "CTF Room"))
	var teams := payload.get("teams", {}) as Dictionary
	if _ctf_room_red_label != null:
		_ctf_room_red_label.text = _team_text("RED TEAM", teams.get("red", []) as Array)
	if _ctf_room_blue_label != null:
		_ctf_room_blue_label.text = _team_text("BLUE TEAM", teams.get("blue", []) as Array)
	var ready_by_peer := payload.get("ready_by_peer", {}) as Dictionary
	var local_ready := bool(ready_by_peer.get(_local_peer_id(), false))
	if _ctf_ready_button != null:
		_ctf_ready_button.text = "UNREADY" if local_ready else "READY"
	if _ctf_add_bots_check != null:
		var add_bots := bool(payload.get("add_bots", false))
		if _ctf_add_bots_check.button_pressed != add_bots:
			if _ctf_add_bots_check.has_method("set_pressed_no_signal"):
				_ctf_add_bots_check.call("set_pressed_no_signal", add_bots)
			else:
				_ctf_add_bots_check.button_pressed = add_bots
	_refresh_lobby_selection_summary()
	_refresh_lobby_buttons_state()

func _hide_ctf_room() -> void:
	if _ctf_room_box != null:
		_ctf_room_box.visible = false
	if _header_title != null:
		_header_title.visible = true
	if _rooms_title_label != null:
		_rooms_title_label.visible = true
	if _status_label != null:
		_status_label.visible = true
	if _selection_label != null:
		_selection_label.visible = true
	if _rooms_box != null:
		_rooms_box.visible = true
	if _mode_row != null:
		_mode_row.visible = true
	if _waiting_room_title_label != null:
		_waiting_room_title_label.visible = false

func _show_dm_room(payload: Dictionary) -> void:
	if _dm_room_box == null:
		return
	if _header_title != null:
		_header_title.visible = false
	if _rooms_title_label != null:
		_rooms_title_label.visible = false
	if _status_label != null:
		_status_label.visible = false
	if _selection_label != null:
		_selection_label.visible = false
	if _rooms_box != null:
		_rooms_box.visible = false
	if _mode_row != null:
		_mode_row.visible = false
	if _waiting_room_title_label != null:
		_waiting_room_title_label.visible = true
		_waiting_room_title_label.text = "%s  |  DEATHMATCH WAITING ROOM" % str(payload.get("name", "DM Room"))
	_dm_room_box.visible = true
	if _dm_room_title != null:
		_dm_room_title.visible = false
		_dm_room_title.text = "%s  |  DEATHMATCH WAITING ROOM" % str(payload.get("name", "DM Room"))
	var members := payload.get("members", []) as Array
	var lines := PackedStringArray()
	for i in range(members.size()):
		if not (members[i] is Dictionary):
			continue
		var member := members[i] as Dictionary
		var display := str(member.get("display_name", "Player"))
		var ready := bool(member.get("ready", false))
		lines.append("%d. %s  [%s]" % [i + 1, display, "READY" if ready else "NOT READY"])
	var max_players := int(payload.get("max_players", members.size()))
	for i in range(members.size(), max_players):
		lines.append("%d. [EMPTY]" % (i + 1))
	if lines.is_empty():
		lines.append("Waiting for players...")
	if _dm_room_members_label != null:
		_dm_room_members_label.text = "\n".join(lines)
	var ready_by_peer := payload.get("ready_by_peer", {}) as Dictionary
	var local_ready := bool(ready_by_peer.get(_local_peer_id(), false))
	if _dm_ready_button != null:
		_dm_ready_button.text = "UNREADY" if local_ready else "READY"
	if _dm_add_bots_check != null:
		var add_bots := bool(payload.get("add_bots", false))
		if _dm_add_bots_check.button_pressed != add_bots:
			if _dm_add_bots_check.has_method("set_pressed_no_signal"):
				_dm_add_bots_check.call("set_pressed_no_signal", add_bots)
			else:
				_dm_add_bots_check.button_pressed = add_bots
	_refresh_lobby_selection_summary()
	_refresh_lobby_buttons_state()

func _hide_dm_room() -> void:
	if _dm_room_box != null:
		_dm_room_box.visible = false
	if _header_title != null:
		_header_title.visible = true
	if _rooms_title_label != null:
		_rooms_title_label.visible = true
	if _status_label != null:
		_status_label.visible = true
	if _selection_label != null:
		_selection_label.visible = true
	if _rooms_box != null:
		_rooms_box.visible = true
	if _mode_row != null:
		_mode_row.visible = true
	if _waiting_room_title_label != null:
		_waiting_room_title_label.visible = false

func _active_lobby_mode_id(lobby_id: int) -> String:
	for entry in _room_entries:
		if not (entry is Dictionary):
			continue
		var data := entry as Dictionary
		if int(data.get("id", 0)) != lobby_id:
			continue
		return _map_flow_service.normalize_mode_id(str(data.get("mode_id", "deathmatch")))
	if not _ctf_room_state.is_empty() and int(_ctf_room_state.get("lobby_id", 0)) == lobby_id:
		return _map_flow_service.normalize_mode_id(str(_ctf_room_state.get("mode_id", "deathmatch")))
	return _map_flow_service.normalize_mode_id(_selected_mode_id)

func _local_team_id() -> int:
	if _ctf_room_state.is_empty():
		return -1
	var team_by_peer := _ctf_room_state.get("team_by_peer", {}) as Dictionary
	return int(team_by_peer.get(_local_peer_id(), -1))

func _team_text(title: String, members: Array) -> String:
	var lines := PackedStringArray()
	lines.append(title)
	lines.append("")
	for slot in range(2):
		if slot < members.size() and members[slot] is Dictionary:
			var entry := members[slot] as Dictionary
			var display := str(entry.get("display_name", "Player"))
			var ready := bool(entry.get("ready", false))
			lines.append("%d. %s [%s]" % [slot + 1, display, "R" if ready else "-"])
		else:
			lines.append("%d. [EMPTY]" % (slot + 1))
	return "\n".join(lines)

func _position_option_popup_below(option: OptionButton, popup: PopupMenu) -> void:
	if option == null or popup == null:
		return
	var origin := option.get_screen_position()
	var popup_x := int(round(origin.x))
	var popup_y := int(round(origin.y + option.size.y + 2.0))
	popup.position = Vector2i(popup_x, popup_y)

func _make_pixel_popup_marker(active: bool) -> Texture2D:
	var img := Image.create(9, 9, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var border := Color(0.32, 0.3, 0.44, 1.0)
	var fill := Color(0.08, 0.08, 0.12, 1.0)
	for y in range(9):
		for x in range(9):
			var on_border := x == 0 or x == 8 or y == 0 or y == 8
			img.set_pixel(x, y, border if on_border else fill)
	if active:
		var accent := Color(0.9, 0.74, 0.27, 1.0)
		for y in range(2, 7):
			for x in range(2, 7):
				img.set_pixel(x, y, accent)
	var tex := ImageTexture.create_from_image(img)
	return tex

func _make_pixel_dropdown_arrow() -> Texture2D:
	var img := Image.create(9, 9, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var color := Color(0.9, 0.74, 0.27, 1.0)
	# Down-facing chunky pixel arrow.
	var rows := {
		2: PackedInt32Array([2, 3, 4, 5, 6]),
		3: PackedInt32Array([3, 4, 5]),
		4: PackedInt32Array([3, 4, 5]),
		5: PackedInt32Array([4]),
	}
	for y in rows.keys():
		var xs := rows[y] as PackedInt32Array
		for x in xs:
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)
