extends RefCounted

const LOBBY_RPC_BRIDGE_SCRIPT := preload("res://scripts/ui/main_menu/lobby_rpc_bridge.gd")
const LOBBY_SERVICE_SCRIPT := preload("res://scripts/lobby/lobby_service.gd")
const MAP_CATALOG_SCRIPT := preload("res://scripts/world/map_catalog.gd")
const MAP_FLOW_SERVICE_SCRIPT := preload("res://scripts/world/map_flow_service.gd")
const LOBBY_CHAT_CONTROLLER_SCRIPT := preload("res://scripts/ui/main_menu/lobby_chat_controller.gd")
const LOBBY_CONNECTION_CONFIG_CTRL_SCRIPT := preload("res://scripts/ui/main_menu/lobby_connection_config_controller.gd")
const LOBBY_CONNECTION_LIFECYCLE_CTRL_SCRIPT := preload("res://scripts/ui/main_menu/lobby_connection_lifecycle_controller.gd")
const LOBBY_ROOM_ACTIONS_CTRL_SCRIPT := preload("res://scripts/ui/main_menu/lobby_room_actions_controller.gd")
const LOBBY_ROOM_STATE_CTRL_SCRIPT := preload("res://scripts/ui/main_menu/lobby_room_state_controller.gd")
const MENU_PALETTE := preload("res://scripts/ui/main_menu/menu_palette.gd")
const CONNECT_WATCHDOG_CHECK_INTERVAL_SEC := 1.0
const CONNECT_WATCHDOG_MAX_WAIT_SEC := 35.0
const CONNECT_ATTEMPTS_PER_CANDIDATE := 3
const CONNECT_FALLBACK_PORTS := [8081]
const ALLOW_LOCALHOST_LOBBY_CONNECT := false
var BTN_RED_BG := MENU_PALETTE.base(0.96)
var BTN_RED_BORDER := MENU_PALETTE.highlight(1.0)
var BTN_GREEN_BG := MENU_PALETTE.accent(0.96)
var BTN_GREEN_BORDER := MENU_PALETTE.highlight(1.0)
var BTN_YELLOW_BG := MENU_PALETTE.hot(0.96)
var BTN_YELLOW_BORDER := MENU_PALETTE.highlight(1.0)

var _host: Control
var _make_button: Callable
var _add_hover_pop: Callable
var _bind_option_sfx: Callable
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
var _rooms_list_panel: PanelContainer
var _rooms_box: VBoxContainer
var _selection_label: Label
var _preset_row: HBoxContainer
var _mode_row: HBoxContainer
var _waiting_room_title_label: Label
var _actions_row: HBoxContainer
var _create_button: Button
var _join_button: Button
var _refresh_button: Button
var _leave_button: Button
var _ctf_leave_button: Button
var _back_button: Button
var _map_option: OptionButton
var _preset_rounds_button: Button
var _preset_deathmatch_button: Button
var _preset_br_button: Button
var _ctf_room_box: VBoxContainer
var _ctf_room_title: Label
var _ctf_room_red_label: Label
var _ctf_room_blue_label: Label
var _ctf_join_red_button: Button
var _ctf_join_blue_button: Button
var _ctf_start_button: Button
var _ctf_ready_button: Button
var _ctf_add_bots_check: CheckBox
var _ctf_show_starting_animation_check: CheckBox
var _ctf_room_state: Dictionary = {}
var _dm_room_box: VBoxContainer
var _dm_room_title: Label
var _dm_room_members_label: Label
var _dm_leave_button: Button
var _dm_ready_button: Button
var _dm_start_button: Button
var _dm_add_bots_check: CheckBox
var _dm_show_starting_animation_check: CheckBox
var _dm_ruleset_row: HBoxContainer
var _dm_ruleset_option: OptionButton
var _dm_target_row: HBoxContainer
var _dm_target_label: Label
var _dm_target_option: OptionButton
var _dm_time_row: HBoxContainer
var _dm_time_option: OptionButton
var _room_buttons: Array[Button] = []
var _interaction_enabled := true
var _room_entries: Array = []
var _selected_room_index := -1
var _joined_room_name := ""
var _joined_lobby_id := 0
var _last_create_requested_map_id := ""
var _forced_rounds_ruleset_lobby_id := 0
var _rpc_bridge: Node
var _lobby_list_ready := false
var _action_inflight := false
var _action_nonce := 0
var _pending_create_request := {}
var _connect_candidates: Array[Dictionary] = []
var _connect_candidate_index := -1
var _connect_attempt_in_candidate := 0
var _connect_nonce := 0
var _lobby_service = LOBBY_SERVICE_SCRIPT.new()
var _map_catalog = MAP_CATALOG_SCRIPT.new()
var _map_flow_service = MAP_FLOW_SERVICE_SCRIPT.new()
var _selected_mode_id := "deathmatch"
var _selected_map_id := ""
var _lobby_chat_ctrl = LOBBY_CHAT_CONTROLLER_SCRIPT.new()
var _connection_config_ctrl = LOBBY_CONNECTION_CONFIG_CTRL_SCRIPT.new()
var _connection_lifecycle_ctrl = LOBBY_CONNECTION_LIFECYCLE_CTRL_SCRIPT.new()
var _room_actions_ctrl = LOBBY_ROOM_ACTIONS_CTRL_SCRIPT.new()
var _room_state_ctrl = LOBBY_ROOM_STATE_CTRL_SCRIPT.new()

func _log(message: String) -> void:
	print("[lobby_overlay] %s" % message)

func configure(
	host: Control,
	make_button: Callable,
	add_hover_pop: Callable,
	bind_option_sfx: Callable,
	center_pivot: Callable,
	pixel_burst_at: Callable,
	center_of: Callable,
	on_closed: Callable
) -> void:
	_host = host
	_make_button = make_button
	_add_hover_pop = add_hover_pop
	_bind_option_sfx = bind_option_sfx
	_center_pivot = center_pivot
	_pixel_burst_at = pixel_burst_at
	_center_of = center_of
	_on_closed = on_closed
	_lobby_chat_ctrl.configure(Callable(self, "_send_lobby_chat_message"))
	_connection_config_ctrl.configure(self)
	_connection_lifecycle_ctrl.configure(self, LOBBY_RPC_BRIDGE_SCRIPT)
	_room_actions_ctrl.configure(self)
	_room_state_ctrl.configure(self)

func _send_lobby_chat_message(message: String) -> bool:
	if _rpc_bridge == null or not is_instance_valid(_rpc_bridge):
		return false
	if _joined_lobby_id <= 0:
		return false
	return bool(_rpc_bridge.call("send_lobby_chat_message", message))

func _on_rpc_lobby_chat_message(lobby_id: int, _peer_id: int, display_name: String, message: String) -> void:
	_lobby_chat_ctrl.append_message(lobby_id, display_name, message)

func _clear_lobby_chat_cache(lobby_id: int) -> void:
	if lobby_id <= 0:
		return
	_lobby_chat_ctrl.clear_lobby(lobby_id)

func _refresh_lobby_chat_context() -> void:
	_lobby_chat_ctrl.set_active_lobby(maxi(0, _joined_lobby_id))

func is_visible() -> bool:
	return _overlay != null and _overlay.visible

func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	if _panel != null:
		_set_control_tree_mouse_passthrough(_panel, not enabled)

func _set_control_tree_mouse_passthrough(root: Control, passthrough: bool) -> void:
	if root == null:
		return
	var stack: Array[Control] = [root]
	while not stack.is_empty():
		var c: Control = stack.pop_back() as Control
		if c == null:
			continue
		if passthrough:
			if not c.has_meta("kw_prev_mouse_filter"):
				c.set_meta("kw_prev_mouse_filter", c.mouse_filter)
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			if c.has_meta("kw_prev_mouse_filter"):
				c.mouse_filter = int(c.get_meta("kw_prev_mouse_filter"))
				c.remove_meta("kw_prev_mouse_filter")
			elif c == root:
				c.mouse_filter = Control.MOUSE_FILTER_STOP
		for child in c.get_children():
			if child is Control:
				stack.append(child as Control)

func hide() -> void:
	if _overlay == null or not _overlay.visible:
		return
	_overlay.visible = false
	set_interaction_enabled(true)
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
	_joined_lobby_id = 0
	_joined_room_name = ""
	_pending_create_request = {}
	_ctf_room_state.clear()
	_refresh_lobby_chat_context()
	_layout_overlay()
	if _host != null and _host.has_method("_apply_runtime_palette"):
		_host.call("_apply_runtime_palette", _overlay)

	_overlay.visible = true
	_overlay.modulate = Color(1, 1, 1, 0)
	set_interaction_enabled(true)
	if _loading_box != null:
		_loading_box.visible = false
	_set_rooms_list_visible(true)
	_populate_lobby_room_list()

	if _loading_label != null:
		_loading_label.text = "LOADING"
	if _status_label != null:
		_status_label.text = "Connecting to lobby server..."

	var fade := _host.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.tween_property(_overlay, "modulate:a", 1.0, 0.22)

	if play_button != null and _pixel_burst_at.is_valid() and _center_of.is_valid():
		_pixel_burst_at.call(_center_of.call(play_button), MENU_PALETTE.highlight(1.0))

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
	var target_w := clampf(viewport_size.x * 0.32, 280.0, 500.0)
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
	_set_rooms_list_visible(true)
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
	if selected_character_id != "erebus" and selected_character_id != "tasko" and selected_character_id != "juice" and selected_character_id != "madam" and selected_character_id != "celler" and selected_character_id != "kotro" and selected_character_id != "nova" and selected_character_id != "hindi" and selected_character_id != "loker" and selected_character_id != "gan" and selected_character_id != "veila" and selected_character_id != "krog" and selected_character_id != "aevilok" and selected_character_id != "franky" and selected_character_id != "varn":
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

func sync_current_loadout_to_lobby() -> void:
	_persist_local_loadout_selection()
	if _rpc_bridge == null or not bool(_rpc_bridge.call("can_send_lobby_rpc")):
		return
	_rpc_bridge.call("set_weapon", _selected_weapon_id())
	_rpc_bridge.call("set_character", _selected_warrior_id())
	_sync_selected_warrior_skin()
	_sync_selected_weapon_skin()

func _resolve_server_host_port_from_args(host: String = "127.0.0.1", port: int = 8080) -> Dictionary:
	return _connection_config_ctrl.resolve_server_host_port_from_args(host, port)

func _read_launcher_config_defaults() -> Dictionary:
	return _connection_config_ctrl.read_launcher_config_defaults()

func _resolve_server_host_port() -> Dictionary:
	return _connection_config_ctrl.resolve_server_host_port()

func _resolve_auth_api_host_port() -> Dictionary:
	return _connection_config_ctrl.resolve_auth_api_host_port()

func _build_connect_candidates() -> Array[Dictionary]:
	return _connection_config_ctrl.build_connect_candidates()

func _local_connect_fallback_hosts() -> PackedStringArray:
	return _connection_config_ctrl.local_connect_fallback_hosts()

func _begin_connect_attempt(force_restart: bool, reason: String = "Connecting...", allow_while_connecting: bool = false) -> void:
	_connection_lifecycle_ctrl.begin_connect_attempt(force_restart, reason, allow_while_connecting)

func _start_connect_watchdog() -> void:
	_connection_lifecycle_ctrl.start_connect_watchdog()

func _tick_connect_watchdog(nonce: int, elapsed_sec: float) -> void:
	_connection_lifecycle_ctrl.tick_connect_watchdog(nonce, elapsed_sec)

func _handle_failed_connect_attempt(source: String) -> void:
	_connection_lifecycle_ctrl.handle_failed_connect_attempt(source)

func _try_next_connect_candidate() -> void:
	_connection_lifecycle_ctrl.try_next_connect_candidate()

func _request_lobby_list_from_server() -> void:
	_connection_lifecycle_ctrl.request_lobby_list_from_server()

func _ensure_rpc_bridge() -> void:
	_connection_lifecycle_ctrl.ensure_rpc_bridge()

func _on_rpc_connected() -> void:
	_connection_lifecycle_ctrl.on_rpc_connected()

func _on_rpc_failed() -> void:
	_connection_lifecycle_ctrl.on_rpc_failed()

func _on_rpc_disconnected() -> void:
	_connection_lifecycle_ctrl.on_rpc_disconnected()

func _on_rpc_lobby_list(entries: Array, active_lobby_id: int) -> void:
	_log("lobby_list received entries=%d active_lobby_id=%d" % [entries.size(), active_lobby_id])
	_lobby_list_ready = true
	_room_entries = entries
	var previous_lobby_id := _joined_lobby_id
	_joined_lobby_id = active_lobby_id
	if previous_lobby_id > 0 and _joined_lobby_id <= 0:
		_clear_lobby_chat_cache(previous_lobby_id)
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
	_refresh_lobby_chat_context()
	_populate_lobby_room_list()
	_refresh_lobby_selection_summary()
	_refresh_lobby_buttons_state()

func _on_rpc_action_result(success: bool, message: String, active_lobby_id: int, _map_id: String) -> void:
	_log("action_result success=%s active_lobby_id=%d message=%s" % [str(success), active_lobby_id, message])
	if success and active_lobby_id > 0:
		_log("action_result result=SERVER_LOBBY_CONFIRMED lobby_id=%d" % active_lobby_id)
	elif not success:
		_log("action_result result=SERVER_ACTION_FAILED")
	var previous_lobby_id := _joined_lobby_id
	_joined_lobby_id = active_lobby_id
	if previous_lobby_id > 0 and _joined_lobby_id <= 0:
		_clear_lobby_chat_cache(previous_lobby_id)
	if active_lobby_id <= 0:
		_ctf_room_state.clear()
	_refresh_lobby_chat_context()
	_action_inflight = false
	_action_nonce += 1
	if _status_label != null:
		_status_label.text = message if success else "Failed: %s" % message
	if success and active_lobby_id > 0:
		var resolved_mode := _active_lobby_mode_id(active_lobby_id)
		if _is_team_mode_id(resolved_mode) or _is_free_for_all_mode_id(resolved_mode):
			if _status_label != null:
				_status_label.text = "Entered Team room. Pick team and start." if _is_team_mode_id(resolved_mode) else "Entered waiting room."
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
	var room_lobby_id := int(_ctf_room_state.get("lobby_id", 0))
	var room_map_id := _map_flow_service.normalize_map_id(_map_catalog, str(_ctf_room_state.get("map_id", "")))
	var room_started := bool(_ctf_room_state.get("started", false))
	var room_owner_id := int(_ctf_room_state.get("owner_peer_id", 0))
	var local_peer_id := _local_peer_id()
	var room_ruleset := str(_ctf_room_state.get("skull_ruleset", "kill_race")).strip_edges().to_lower()
	var skull_policy := _skull_ruleset_policy_for_map(room_map_id)
	var should_force_rounds_ruleset := (
		skull_policy == "round_only"
		and room_lobby_id > 0
		and room_lobby_id == _joined_lobby_id
		and not room_started
		and room_owner_id == local_peer_id
		and room_ruleset != "round_survival"
		and _forced_rounds_ruleset_lobby_id != room_lobby_id
	)
	if should_force_rounds_ruleset and _rpc_bridge != null and bool(_rpc_bridge.call("can_send_lobby_rpc")):
		_forced_rounds_ruleset_lobby_id = room_lobby_id
		ProjectSettings.set_setting("kw/pending_skull_ruleset", "round_survival")
		_log("forcing round_survival ruleset lobby_id=%d map_id=%s current_ruleset=%s" % [
			room_lobby_id,
			room_map_id,
			room_ruleset
		])
		_rpc_bridge.call("set_lobby_skull_ruleset", "round_survival")
	if int(_ctf_room_state.get("lobby_id", 0)) != _joined_lobby_id:
		_refresh_lobby_chat_context()
		return
	_refresh_lobby_chat_context()
	var mode_id := _active_lobby_mode_id(_joined_lobby_id)
	if _is_team_mode_id(mode_id):
		_hide_dm_room()
		_show_ctf_room(_ctf_room_state)
		return
	if _is_free_for_all_mode_id(mode_id):
		_hide_ctf_room()
		if bool(_ctf_room_state.get("started", false)):
			_hide_dm_room()
			return
		_show_dm_room(_ctf_room_state)
		return
	_hide_ctf_room()
	_hide_dm_room()

func _begin_lobby_action(status_text: String) -> int:
	return _room_actions_ctrl.begin_lobby_action(status_text)

func _populate_lobby_room_list() -> void:
	_room_actions_ctrl.populate_lobby_room_list()

func _select_lobby_room(index: int) -> void:
	_room_actions_ctrl.select_lobby_room(index)

func _apply_room_button_selected_style(btn: Button, selected: bool) -> void:
	_room_actions_ctrl.apply_room_button_selected_style(btn, selected)

func _refresh_lobby_selection_summary() -> void:
	_room_actions_ctrl.refresh_lobby_selection_summary()

func _join_selected_lobby_room() -> void:
	_room_actions_ctrl.join_selected_lobby_room()

func _create_lobby_room() -> void:
	_room_actions_ctrl.create_lobby_room()

func _leave_lobby_room() -> void:
	_room_actions_ctrl.leave_lobby_room()

func _start_ctf_match() -> void:
	_start_lobby_match("Starting CTF match...")

func _start_lobby_match(status_text: String = "Starting match...") -> void:
	_room_actions_ctrl.start_lobby_match(status_text)

func _build_create_lobby_request() -> Dictionary:
	return _room_actions_ctrl.build_create_lobby_request()

func _send_create_lobby_request(request: Dictionary) -> void:
	_room_actions_ctrl.send_create_lobby_request(request)

func _ensure_valid_map_selection() -> void:
	var map_ids := _lobby_selectable_map_ids()
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

func _lobby_selectable_map_ids() -> Array[String]:
	var preferred_order := [
		"skull_deathmatch",
		"skull_rounds",
		"skull_br",
		"skull_ffa",
		"main_ffa",
		"main_tdth",
		"main_ctf"
	]
	var available := _map_catalog.all_map_ids()
	var selected: Array[String] = []
	for map_id_value in preferred_order:
		var map_id := str(map_id_value).strip_edges().to_lower()
		if available.find(map_id) >= 0:
			selected.append(map_id)
	if not selected.is_empty():
		return selected
	# Fallback safety if some catalog entries are missing for any reason.
	for map_id_value in available:
		var map_id := str(map_id_value).strip_edges().to_lower()
		if not map_id.is_empty():
			selected.append(map_id)
	return selected

func _populate_map_dropdown() -> void:
	if _map_option == null:
		return
	_map_option.clear()
	for map_id_value in _lobby_selectable_map_ids():
		var map_id := str(map_id_value)
		var label := _map_flow_service.map_label_for_id(_map_catalog, map_id)
		_map_option.add_item(label)
		_map_option.set_item_metadata(_map_option.get_item_count() - 1, map_id)
	var map_popup := _map_option.get_popup()
	_remove_popup_left_markers(map_popup)
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

# Quick preset buttons disabled for now by request.
#func _apply_quick_mode_preset(map_id: String, mode_id: String, status_text: String) -> void:
#	_selected_map_id = _map_flow_service.normalize_map_id(_map_catalog, map_id)
#	_selected_mode_id = _map_flow_service.select_mode_for_map(_map_catalog, _selected_map_id, mode_id)
#	_refresh_map_dropdown_selection()
#	_refresh_lobby_selection_summary()
#	if _status_label != null and not status_text.strip_edges().is_empty():
#		_status_label.text = status_text

func _skull_ruleset_policy_for_map(map_id: String) -> String:
	var normalized := _map_flow_service.normalize_map_id(_map_catalog, map_id)
	if normalized == "skull_rounds" or normalized == "skull_br":
		return "round_only"
	if normalized == "skull_deathmatch":
		return "deathmatch_only"
	if normalized == "skull_ffa":
		return "flex"
	return "none"

func _refresh_lobby_buttons_state() -> void:
	_room_state_ctrl.refresh_lobby_buttons_state()

func _ensure_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_refresh_lobby_selection_summary()
		return

	var overlay := Control.new()
	overlay.name = "LobbyOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.z_index = 980
	_host.add_child(overlay)
	_overlay = overlay

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.custom_minimum_size = Vector2(280, 250)
	panel.position = Vector2(40, 40)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(panel)
	_panel = panel

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0)
	panel_style.border_width_left = 0
	panel_style.border_width_top = 0
	panel_style.border_width_right = 0
	panel_style.border_width_bottom = 0
	panel_style.border_color = Color(0, 0, 0, 0)
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
	loading_box.custom_minimum_size = Vector2(0, 84)
	loading_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loading_box.visible = false
	root.add_child(loading_box)
	_loading_box = loading_box

	var loading_style := StyleBoxFlat.new()
	loading_style.bg_color = MENU_PALETTE.accent(0.96)
	loading_style.border_width_left = 3
	loading_style.border_width_top = 3
	loading_style.border_width_right = 3
	loading_style.border_width_bottom = 3
	loading_style.border_color = MENU_PALETTE.accent(1.0)
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

	var rooms_panel := PanelContainer.new()
	rooms_panel.custom_minimum_size = Vector2(0, 84)
	rooms_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rooms_panel.visible = false
	var rooms_panel_style := StyleBoxFlat.new()
	rooms_panel_style.bg_color = MENU_PALETTE.accent(0.92)
	rooms_panel_style.border_width_left = 2
	rooms_panel_style.border_width_top = 2
	rooms_panel_style.border_width_right = 2
	rooms_panel_style.border_width_bottom = 2
	rooms_panel_style.border_color = MENU_PALETTE.accent(1.0)
	rooms_panel.add_theme_stylebox_override("panel", rooms_panel_style)
	root.add_child(rooms_panel)
	_rooms_list_panel = rooms_panel

	var rooms_margin := MarginContainer.new()
	rooms_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	rooms_margin.add_theme_constant_override("margin_left", 4)
	rooms_margin.add_theme_constant_override("margin_top", 4)
	rooms_margin.add_theme_constant_override("margin_right", 4)
	rooms_margin.add_theme_constant_override("margin_bottom", 4)
	rooms_panel.add_child(rooms_margin)

	var rooms_scroll := ScrollContainer.new()
	rooms_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	rooms_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rooms_scroll.horizontal_scroll_mode = 0
	rooms_margin.add_child(rooms_scroll)

	var rooms_box := VBoxContainer.new()
	rooms_box.custom_minimum_size = Vector2(0, 64)
	rooms_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rooms_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rooms_box.add_theme_constant_override("separation", 4)
	rooms_box.visible = false
	rooms_scroll.add_child(rooms_box)
	_rooms_box = rooms_box

	var selection_label := Label.new()
	selection_label.text = "Select a room and press JOIN"
	selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_label.add_theme_font_size_override("font_size", 9)
	root.add_child(selection_label)
	_selection_label = selection_label

	# Quick preset row intentionally disabled for now.
	#var preset_row := HBoxContainer.new()
	#preset_row.add_theme_constant_override("separation", 6)
	#root.add_child(preset_row)
	#_preset_row = preset_row
	#
	#var preset_rounds_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	#preset_rounds_btn.text = "ROUNDS"
	#preset_rounds_btn.custom_minimum_size = Vector2(0, 20)
	#preset_rounds_btn.add_theme_font_size_override("font_size", 8)
	#preset_rounds_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#preset_rounds_btn.pressed.connect(func() -> void:
	#	_apply_quick_mode_preset("skull_rounds", "deathmatch", "Preset: Skull Rounds")
	#)
	#if _add_hover_pop.is_valid():
	#	_add_hover_pop.call(preset_rounds_btn)
	#preset_row.add_child(preset_rounds_btn)
	#_preset_rounds_button = preset_rounds_btn
	#
	#var preset_dm_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	#preset_dm_btn.text = "FFA"
	#preset_dm_btn.custom_minimum_size = Vector2(0, 20)
	#preset_dm_btn.add_theme_font_size_override("font_size", 8)
	#preset_dm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#preset_dm_btn.pressed.connect(func() -> void:
	#	_apply_quick_mode_preset("skull_deathmatch", "deathmatch", "Preset: Skull Deathmatch")
	#)
	#if _add_hover_pop.is_valid():
	#	_add_hover_pop.call(preset_dm_btn)
	#preset_row.add_child(preset_dm_btn)
	#_preset_deathmatch_button = preset_dm_btn
	#
	#var preset_br_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	#preset_br_btn.text = "BR ROUNDS"
	#preset_br_btn.custom_minimum_size = Vector2(0, 20)
	#preset_br_btn.add_theme_font_size_override("font_size", 8)
	#preset_br_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#preset_br_btn.pressed.connect(func() -> void:
	#	_apply_quick_mode_preset("skull_br", "battle_royale", "Preset: Skull BR Rounds")
	#)
	#if _add_hover_pop.is_valid():
	#	_add_hover_pop.call(preset_br_btn)
	#preset_row.add_child(preset_br_btn)
	#_preset_br_button = preset_br_btn

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
	map_label.add_theme_color_override("font_color", MENU_PALETTE.text_primary(1.0))
	mode_row.add_child(map_label)

	var map_option := OptionButton.new()
	map_option.custom_minimum_size = Vector2(170, 18)
	map_option.size_flags_horizontal = Control.SIZE_FILL
	map_option.alignment = HORIZONTAL_ALIGNMENT_LEFT
	map_option.add_theme_font_size_override("font_size", 8)
	map_option.add_theme_constant_override("arrow_margin", 4)
	map_option.add_theme_constant_override("h_separation", 4)
	map_option.add_theme_color_override("font_color", MENU_PALETTE.text_primary(1.0))
	map_option.add_theme_color_override("font_hover_color", MENU_PALETTE.text_primary(1.0))
	map_option.add_theme_color_override("font_pressed_color", MENU_PALETTE.text_primary(1.0))
	var map_option_normal := StyleBoxFlat.new()
	map_option_normal.bg_color = MENU_PALETTE.accent(1.0)
	map_option_normal.border_width_left = 2
	map_option_normal.border_width_top = 2
	map_option_normal.border_width_right = 2
	map_option_normal.border_width_bottom = 2
	map_option_normal.border_color = MENU_PALETTE.accent(1.0)
	map_option_normal.corner_radius_top_left = 0
	map_option_normal.corner_radius_top_right = 0
	map_option_normal.corner_radius_bottom_right = 0
	map_option_normal.corner_radius_bottom_left = 0
	map_option_normal.content_margin_left = 6
	map_option_normal.content_margin_right = 6
	map_option_normal.content_margin_top = 3
	map_option_normal.content_margin_bottom = 3
	var map_option_hover := map_option_normal.duplicate() as StyleBoxFlat
	map_option_hover.bg_color = MENU_PALETTE.accent(1.0)
	map_option_hover.border_color = MENU_PALETTE.highlight(1.0)
	map_option.add_theme_stylebox_override("normal", map_option_normal)
	map_option.add_theme_stylebox_override("hover", map_option_hover)
	map_option.add_theme_stylebox_override("pressed", map_option_normal)
	map_option.add_theme_stylebox_override("focus", map_option_normal)
	map_option.add_theme_icon_override("arrow", _make_pixel_dropdown_arrow())
	var map_popup := map_option.get_popup()
	var map_popup_panel := StyleBoxFlat.new()
	map_popup_panel.bg_color = MENU_PALETTE.accent(1.0)
	map_popup_panel.border_width_left = 2
	map_popup_panel.border_width_top = 2
	map_popup_panel.border_width_right = 2
	map_popup_panel.border_width_bottom = 2
	map_popup_panel.border_color = MENU_PALETTE.accent(1.0)
	map_popup_panel.corner_radius_top_left = 0
	map_popup_panel.corner_radius_top_right = 0
	map_popup_panel.corner_radius_bottom_right = 0
	map_popup_panel.corner_radius_bottom_left = 0
	var map_popup_hover := StyleBoxFlat.new()
	map_popup_hover.bg_color = MENU_PALETTE.hot(1.0)
	map_popup_hover.border_width_left = 1
	map_popup_hover.border_width_top = 1
	map_popup_hover.border_width_right = 1
	map_popup_hover.border_width_bottom = 1
	map_popup_hover.border_color = MENU_PALETTE.highlight(1.0)
	map_popup_hover.corner_radius_top_left = 0
	map_popup_hover.corner_radius_top_right = 0
	map_popup_hover.corner_radius_bottom_right = 0
	map_popup_hover.corner_radius_bottom_left = 0
	var map_popup_separator := StyleBoxFlat.new()
	map_popup_separator.bg_color = MENU_PALETTE.hot(1.0)
	map_popup_separator.content_margin_top = 1
	map_popup_separator.content_margin_bottom = 1
	var map_popup_selected := StyleBoxFlat.new()
	map_popup_selected.bg_color = MENU_PALETTE.accent(1.0)
	map_popup_selected.border_width_left = 1
	map_popup_selected.border_width_top = 1
	map_popup_selected.border_width_right = 1
	map_popup_selected.border_width_bottom = 1
	map_popup_selected.border_color = MENU_PALETTE.accent(1.0)
	map_popup_selected.corner_radius_top_left = 0
	map_popup_selected.corner_radius_top_right = 0
	map_popup_selected.corner_radius_bottom_right = 0
	map_popup_selected.corner_radius_bottom_left = 0
	map_popup.add_theme_stylebox_override("panel", map_popup_panel)
	map_popup.add_theme_stylebox_override("hover", map_popup_hover)
	map_popup.add_theme_stylebox_override("hover_pressed", map_popup_hover)
	map_popup.add_theme_stylebox_override("selected", map_popup_selected)
	map_popup.add_theme_stylebox_override("focus", map_popup_selected)
	map_popup.add_theme_stylebox_override("item_hover", map_popup_hover)
	map_popup.add_theme_stylebox_override("separator", map_popup_separator)
	map_popup.add_theme_constant_override("v_separation", 2)
	map_popup.add_theme_constant_override("h_separation", 6)
	map_popup.add_theme_color_override("font_color", MENU_PALETTE.text_primary(1.0))
	map_popup.add_theme_color_override("font_hover_color", MENU_PALETTE.text_primary(1.0))
	map_popup.add_theme_color_override("font_selected_color", MENU_PALETTE.text_primary(1.0))
	map_popup.add_theme_font_size_override("font_size", 8)
	map_popup.about_to_popup.connect(func() -> void:
		_remove_popup_left_markers(map_popup)
		_position_option_popup_below(map_option, map_popup)
	)
	map_popup.popup_hide.connect(func() -> void:
		_release_menu_cursor_click_state()
		map_option.release_focus()
	)
	map_popup.id_pressed.connect(func(_id: int) -> void:
		_release_menu_cursor_click_state()
	)
	map_option.item_selected.connect(_on_map_option_selected)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(map_option)
	if _bind_option_sfx.is_valid():
		_bind_option_sfx.call(map_option)
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
	_apply_button_palette(leave_btn, BTN_RED_BG, BTN_RED_BORDER)
	_remove_button_outlines(leave_btn)
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
	red_style.bg_color = MENU_PALETTE.hot(0.75)
	red_style.border_width_left = 2
	red_style.border_width_top = 2
	red_style.border_width_right = 2
	red_style.border_width_bottom = 2
	red_style.border_color = MENU_PALETTE.highlight(1.0)
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
	blue_style.bg_color = MENU_PALETTE.accent(0.78)
	blue_style.border_width_left = 2
	blue_style.border_width_top = 2
	blue_style.border_width_right = 2
	blue_style.border_width_bottom = 2
	blue_style.border_color = MENU_PALETTE.highlight(1.0)
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
	controls_style.bg_color = MENU_PALETTE.accent(0.86)
	controls_style.border_width_left = 2
	controls_style.border_width_top = 2
	controls_style.border_width_right = 2
	controls_style.border_width_bottom = 2
	controls_style.border_color = MENU_PALETTE.highlight(1.0)
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
	start_btn.size_flags_stretch_ratio = 4.0
	start_btn.pressed.connect(_start_ctf_match)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(start_btn)
	_apply_button_palette(start_btn, BTN_GREEN_BG, BTN_GREEN_BORDER)
	_remove_button_outlines(start_btn)
	var ctf_leave_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	ctf_leave_btn.text = "LEAVE"
	ctf_leave_btn.custom_minimum_size = Vector2(0, 22)
	ctf_leave_btn.add_theme_font_size_override("font_size", 9)
	ctf_leave_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctf_leave_btn.size_flags_stretch_ratio = 1.0
	ctf_leave_btn.disabled = true
	ctf_leave_btn.visible = false
	ctf_leave_btn.pressed.connect(_leave_lobby_room)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(ctf_leave_btn)
	_apply_button_palette(ctf_leave_btn, BTN_RED_BG, BTN_RED_BORDER)
	_remove_button_outlines(ctf_leave_btn)
	match_actions.add_child(ctf_leave_btn)
	_ctf_leave_button = ctf_leave_btn
	var ready_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	ready_btn.text = "READY"
	ready_btn.custom_minimum_size = Vector2(0, 22)
	ready_btn.add_theme_font_size_override("font_size", 9)
	ready_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ready_btn.size_flags_stretch_ratio = 4.0
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
	_apply_ready_button_state_style(ready_btn, false)
	match_actions.add_child(ready_btn)
	_ctf_ready_button = ready_btn

	match_actions.add_child(start_btn)
	_ctf_start_button = start_btn

	var ctf_add_bots_check := CheckBox.new()
	ctf_add_bots_check.text = "Add Bots"
	ctf_add_bots_check.add_theme_font_size_override("font_size", 9)
	_apply_pixel_checkbox_style(ctf_add_bots_check)
	ctf_add_bots_check.button_pressed = false
	ctf_add_bots_check.toggled.connect(func(toggled_on: bool) -> void:
		if _rpc_bridge != null:
			_rpc_bridge.call("set_lobby_add_bots", toggled_on)
	)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(ctf_add_bots_check)
	ctf_room_box.add_child(ctf_add_bots_check)
	_ctf_add_bots_check = ctf_add_bots_check

	var ctf_show_starting_animation_check := CheckBox.new()
	ctf_show_starting_animation_check.text = "Skip Intro"
	ctf_show_starting_animation_check.add_theme_font_size_override("font_size", 9)
	_apply_pixel_checkbox_style(ctf_show_starting_animation_check)
	ctf_show_starting_animation_check.button_pressed = false
	ctf_show_starting_animation_check.toggled.connect(func(toggled_on: bool) -> void:
		if _rpc_bridge != null:
			_rpc_bridge.call("set_lobby_show_starting_animation", not toggled_on)
	)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(ctf_show_starting_animation_check)
	ctf_room_box.add_child(ctf_show_starting_animation_check)
	_ctf_show_starting_animation_check = ctf_show_starting_animation_check
	_add_lobby_chat_section(ctf_room_box, "ctf")

	var dm_room_box := VBoxContainer.new()
	dm_room_box.visible = false
	dm_room_box.add_theme_constant_override("separation", 6)
	root.add_child(dm_room_box)
	_dm_room_box = dm_room_box

	var dm_title := Label.new()
	dm_title.text = "FFA ROOM"
	dm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dm_title.add_theme_font_size_override("font_size", 11)
	dm_room_box.add_child(dm_title)
	_dm_room_title = dm_title

	var dm_members_card := PanelContainer.new()
	dm_room_box.add_child(dm_members_card)
	var dm_members_style := StyleBoxFlat.new()
	dm_members_style.bg_color = MENU_PALETTE.accent(0.86)
	dm_members_style.border_width_left = 2
	dm_members_style.border_width_top = 2
	dm_members_style.border_width_right = 2
	dm_members_style.border_width_bottom = 2
	dm_members_style.border_color = MENU_PALETTE.highlight(1.0)
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
	dm_ready_btn.size_flags_stretch_ratio = 4.0
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
	_apply_ready_button_state_style(dm_ready_btn, false)
	dm_actions.add_child(dm_ready_btn)
	_dm_ready_button = dm_ready_btn

	var dm_leave_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	dm_leave_btn.text = "LEAVE"
	dm_leave_btn.custom_minimum_size = Vector2(0, 20)
	dm_leave_btn.add_theme_font_size_override("font_size", 9)
	dm_leave_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dm_leave_btn.size_flags_stretch_ratio = 1.0
	dm_leave_btn.disabled = true
	dm_leave_btn.visible = false
	dm_leave_btn.pressed.connect(_leave_lobby_room)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(dm_leave_btn)
	_apply_button_palette(dm_leave_btn, BTN_RED_BG, BTN_RED_BORDER)
	_remove_button_outlines(dm_leave_btn)
	dm_actions.add_child(dm_leave_btn)
	_dm_leave_button = dm_leave_btn

	var dm_start_btn: Button = (_make_button.call() as Button) if _make_button.is_valid() else Button.new()
	dm_start_btn.text = "START MATCH"
	dm_start_btn.custom_minimum_size = Vector2(0, 20)
	dm_start_btn.add_theme_font_size_override("font_size", 9)
	dm_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dm_start_btn.size_flags_stretch_ratio = 4.0
	dm_start_btn.pressed.connect(func() -> void:
		var mode_id := _active_lobby_mode_id(_joined_lobby_id)
		_start_lobby_match("Starting Battle Royale..." if mode_id == "battle_royale" else "Starting FFA...")
	)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(dm_start_btn)
	_apply_button_palette(dm_start_btn, BTN_GREEN_BG, BTN_GREEN_BORDER)
	_remove_button_outlines(dm_start_btn)
	dm_actions.add_child(dm_start_btn)
	_dm_start_button = dm_start_btn

	var dm_ruleset_row := HBoxContainer.new()
	dm_ruleset_row.add_theme_constant_override("separation", 6)
	dm_room_box.add_child(dm_ruleset_row)
	_dm_ruleset_row = dm_ruleset_row

	var dm_ruleset_label := Label.new()
	dm_ruleset_label.text = "Skull Mode:"
	dm_ruleset_label.add_theme_font_size_override("font_size", 9)
	dm_ruleset_row.add_child(dm_ruleset_label)

	var dm_ruleset_option := OptionButton.new()
	dm_ruleset_option.custom_minimum_size = Vector2(0, 20)
	dm_ruleset_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dm_ruleset_option.add_theme_font_size_override("font_size", 9)
	_apply_compact_option_style(dm_ruleset_option)
	dm_ruleset_option.add_item("Max Kills")
	dm_ruleset_option.set_item_metadata(0, "kill_race")
	dm_ruleset_option.add_item("Timed")
	dm_ruleset_option.set_item_metadata(1, "timed_kills")
	dm_ruleset_option.item_selected.connect(func(index: int) -> void:
		if _rpc_bridge == null:
			return
		if index < 0 or index >= dm_ruleset_option.get_item_count():
			return
		var ruleset_id := str(dm_ruleset_option.get_item_metadata(index))
		_rpc_bridge.call("set_lobby_skull_ruleset", ruleset_id)
	)
	var dm_ruleset_popup := dm_ruleset_option.get_popup()
	dm_ruleset_popup.position = Vector2i.ZERO
	dm_ruleset_popup.about_to_popup.connect(func() -> void:
		_position_option_popup_below(dm_ruleset_option, dm_ruleset_popup)
	)
	_remove_popup_left_markers(dm_ruleset_popup)
	dm_ruleset_row.add_child(dm_ruleset_option)
	_dm_ruleset_option = dm_ruleset_option

	var dm_target_row := HBoxContainer.new()
	dm_target_row.add_theme_constant_override("separation", 6)
	dm_room_box.add_child(dm_target_row)
	_dm_target_row = dm_target_row

	var dm_target_label := Label.new()
	dm_target_label.text = "Target:"
	dm_target_label.add_theme_font_size_override("font_size", 9)
	dm_target_row.add_child(dm_target_label)
	_dm_target_label = dm_target_label

	var dm_target_option := OptionButton.new()
	dm_target_option.custom_minimum_size = Vector2(0, 20)
	dm_target_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dm_target_option.add_theme_font_size_override("font_size", 9)
	_apply_compact_option_style(dm_target_option)
	for target_value in [3, 5, 10, 15, 20]:
		dm_target_option.add_item(str(target_value))
		dm_target_option.set_item_metadata(dm_target_option.get_item_count() - 1, int(target_value))
	dm_target_option.item_selected.connect(func(index: int) -> void:
		if _rpc_bridge == null:
			return
		if index < 0 or index >= dm_target_option.get_item_count():
			return
		_rpc_bridge.call("set_lobby_skull_target_score", int(dm_target_option.get_item_metadata(index)))
	)
	var dm_target_popup := dm_target_option.get_popup()
	dm_target_popup.position = Vector2i.ZERO
	dm_target_popup.about_to_popup.connect(func() -> void:
		_position_option_popup_below(dm_target_option, dm_target_popup)
	)
	_remove_popup_left_markers(dm_target_popup)
	dm_target_row.add_child(dm_target_option)
	_dm_target_option = dm_target_option

	var dm_time_row := HBoxContainer.new()
	dm_time_row.add_theme_constant_override("separation", 6)
	dm_room_box.add_child(dm_time_row)
	_dm_time_row = dm_time_row

	var dm_time_label := Label.new()
	dm_time_label.text = "Time (min):"
	dm_time_label.add_theme_font_size_override("font_size", 9)
	dm_time_row.add_child(dm_time_label)

	var dm_time_option := OptionButton.new()
	dm_time_option.custom_minimum_size = Vector2(0, 20)
	dm_time_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dm_time_option.add_theme_font_size_override("font_size", 9)
	_apply_compact_option_style(dm_time_option)
	for minute_value in [1, 2, 3, 5, 10]:
		dm_time_option.add_item(str(minute_value))
		dm_time_option.set_item_metadata(dm_time_option.get_item_count() - 1, int(minute_value) * 60)
	dm_time_option.item_selected.connect(func(index: int) -> void:
		if _rpc_bridge == null:
			return
		if index < 0 or index >= dm_time_option.get_item_count():
			return
		_rpc_bridge.call("set_lobby_skull_time_limit_sec", int(dm_time_option.get_item_metadata(index)))
	)
	var dm_time_popup := dm_time_option.get_popup()
	dm_time_popup.position = Vector2i.ZERO
	dm_time_popup.about_to_popup.connect(func() -> void:
		_position_option_popup_below(dm_time_option, dm_time_popup)
	)
	_remove_popup_left_markers(dm_time_popup)
	dm_time_row.add_child(dm_time_option)
	_dm_time_option = dm_time_option

	var dm_add_bots_check := CheckBox.new()
	dm_add_bots_check.text = "Add Bots"
	dm_add_bots_check.add_theme_font_size_override("font_size", 9)
	_apply_pixel_checkbox_style(dm_add_bots_check)
	dm_add_bots_check.button_pressed = false
	dm_add_bots_check.toggled.connect(func(toggled_on: bool) -> void:
		if _rpc_bridge != null:
			_rpc_bridge.call("set_lobby_add_bots", toggled_on)
	)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(dm_add_bots_check)
	dm_room_box.add_child(dm_add_bots_check)
	_dm_add_bots_check = dm_add_bots_check

	var dm_show_starting_animation_check := CheckBox.new()
	dm_show_starting_animation_check.text = "Skip Intro"
	dm_show_starting_animation_check.add_theme_font_size_override("font_size", 9)
	_apply_pixel_checkbox_style(dm_show_starting_animation_check)
	dm_show_starting_animation_check.button_pressed = false
	dm_show_starting_animation_check.toggled.connect(func(toggled_on: bool) -> void:
		if _rpc_bridge != null:
			_rpc_bridge.call("set_lobby_show_starting_animation", not toggled_on)
	)
	if _add_hover_pop.is_valid():
		_add_hover_pop.call(dm_show_starting_animation_check)
	dm_room_box.add_child(dm_show_starting_animation_check)
	_dm_show_starting_animation_check = dm_show_starting_animation_check
	_add_lobby_chat_section(dm_room_box, "dm")

	_refresh_lobby_selection_summary()
	_refresh_lobby_buttons_state()

func _add_lobby_chat_section(parent: Control, view_id: String) -> void:
	if parent == null:
		return
	var chat_panel := PanelContainer.new()
	chat_panel.custom_minimum_size = Vector2(0, 112)
	chat_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var chat_style := StyleBoxFlat.new()
	chat_style.bg_color = MENU_PALETTE.accent(0.84)
	chat_style.border_width_left = 0
	chat_style.border_width_top = 0
	chat_style.border_width_right = 0
	chat_style.border_width_bottom = 0
	chat_style.border_color = Color(0, 0, 0, 0)
	chat_style.corner_radius_top_left = 6
	chat_style.corner_radius_top_right = 6
	chat_style.corner_radius_bottom_right = 6
	chat_style.corner_radius_bottom_left = 6
	chat_panel.add_theme_stylebox_override("panel", chat_style)
	parent.add_child(chat_panel)

	var chat_margin := MarginContainer.new()
	chat_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	chat_margin.add_theme_constant_override("margin_left", 6)
	chat_margin.add_theme_constant_override("margin_right", 6)
	chat_margin.add_theme_constant_override("margin_top", 5)
	chat_margin.add_theme_constant_override("margin_bottom", 5)
	chat_panel.add_child(chat_margin)

	var chat_v := VBoxContainer.new()
	chat_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	chat_v.add_theme_constant_override("separation", 4)
	chat_margin.add_child(chat_v)

	var chat_title := Label.new()
	chat_title.text = "Lobby Chat"
	chat_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	chat_title.add_theme_font_size_override("font_size", 9)
	chat_v.add_child(chat_title)

	var chat_list := RichTextLabel.new()
	chat_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_list.custom_minimum_size = Vector2(0, 54)
	chat_list.scroll_active = true
	chat_list.selection_enabled = false
	chat_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var chat_list_style := StyleBoxFlat.new()
	chat_list_style.bg_color = Color(0.04, 0.07, 0.12, 0.18)
	chat_list_style.border_width_left = 0
	chat_list_style.border_width_top = 0
	chat_list_style.border_width_right = 0
	chat_list_style.border_width_bottom = 0
	chat_list_style.corner_radius_top_left = 0
	chat_list_style.corner_radius_top_right = 0
	chat_list_style.corner_radius_bottom_right = 0
	chat_list_style.corner_radius_bottom_left = 0
	chat_list_style.content_margin_left = 4
	chat_list_style.content_margin_right = 4
	chat_list_style.content_margin_top = 3
	chat_list_style.content_margin_bottom = 3
	chat_list.add_theme_stylebox_override("normal", chat_list_style)
	chat_v.add_child(chat_list)

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 4)
	chat_v.add_child(input_row)

	var input := LineEdit.new()
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.custom_minimum_size = Vector2(0, 20)
	input.add_theme_color_override("font_color", MENU_PALETTE.text_primary(1.0))
	input.add_theme_color_override("font_placeholder_color", MENU_PALETTE.text_primary(0.64))
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = MENU_PALETTE.accent(0.92)
	input_style.border_width_left = 0
	input_style.border_width_top = 0
	input_style.border_width_right = 0
	input_style.border_width_bottom = 0
	input_style.corner_radius_top_left = 5
	input_style.corner_radius_top_right = 5
	input_style.corner_radius_bottom_right = 5
	input_style.corner_radius_bottom_left = 5
	input_style.content_margin_left = 6
	input_style.content_margin_right = 6
	input_style.content_margin_top = 3
	input_style.content_margin_bottom = 3
	input.add_theme_stylebox_override("normal", input_style)
	input.add_theme_stylebox_override("focus", input_style)
	input.add_theme_stylebox_override("read_only", input_style)
	input_row.add_child(input)

	_lobby_chat_ctrl.bind_view(view_id, chat_list, input)
	call_deferred("_style_lobby_chat_scrollbar", chat_list)

func _style_lobby_chat_scrollbar(chat_list: RichTextLabel) -> void:
	if chat_list == null:
		return
	if _host == null:
		return
	var v_scroll := chat_list.get_v_scroll_bar()
	if v_scroll == null:
		return
	if _host.has_method("_ensure_scrollbar_styleboxes"):
		_host.call("_ensure_scrollbar_styleboxes")
	if _host.has_method("_apply_pixel_scrollbar"):
		_host.call("_apply_pixel_scrollbar", v_scroll)

func _show_ctf_room(payload: Dictionary) -> void:
	_room_state_ctrl.show_ctf_room(payload)

func _hide_ctf_room() -> void:
	_room_state_ctrl.hide_ctf_room()

func _show_dm_room(payload: Dictionary) -> void:
	_room_state_ctrl.show_dm_room(payload)

func _hide_dm_room() -> void:
	_room_state_ctrl.hide_dm_room()

func _active_lobby_mode_id(lobby_id: int) -> String:
	return _room_state_ctrl.active_lobby_mode_id(lobby_id)

func _active_lobby_map_id(lobby_id: int) -> String:
	return _room_state_ctrl.active_lobby_map_id(lobby_id)

func _supports_starting_animation_testing_toggle() -> bool:
	return _room_state_ctrl.supports_starting_animation_testing_toggle()

func _is_free_for_all_mode_id(mode_id: String) -> bool:
	return _room_state_ctrl.is_free_for_all_mode_id(mode_id)

func _is_team_mode_id(mode_id: String) -> bool:
	return _room_state_ctrl.is_team_mode_id(mode_id)

func _local_team_id() -> int:
	return _room_state_ctrl.local_team_id()

func _team_text(title: String, members: Array) -> String:
	return _room_state_ctrl.team_text(title, members)

func _position_option_popup_below(option: OptionButton, popup: PopupMenu) -> void:
	if option == null or popup == null:
		return
	var origin := option.get_screen_position()
	var popup_x := int(round(origin.x))
	var popup_y := int(round(origin.y + option.size.y + 2.0))
	popup.position = Vector2i(popup_x, popup_y)

func _remove_popup_left_markers(popup: PopupMenu) -> void:
	if popup == null:
		return
	for i in range(popup.get_item_count()):
		popup.set_item_as_checkable(i, false)
		popup.set_item_as_radio_checkable(i, false)
		popup.set_item_icon(i, null)

func _release_menu_cursor_click_state() -> void:
	if _host == null:
		return
	var tree := _host.get_tree()
	if tree == null:
		return
	var root := tree.get_root()
	if root == null:
		return
	var cursor_manager := root.get_node_or_null("CursorManager")
	if cursor_manager != null and cursor_manager.has_method("clear_menu_click_state"):
		cursor_manager.call("clear_menu_click_state")

func _select_option_by_metadata(option: OptionButton, metadata: Variant) -> void:
	if option == null:
		return
	for i in range(option.get_item_count()):
		if option.get_item_metadata(i) == metadata:
			option.select(i)
			return

func _apply_compact_option_style(option: OptionButton) -> void:
	if option == null:
		return
	option.alignment = HORIZONTAL_ALIGNMENT_LEFT
	option.add_theme_constant_override("arrow_margin", 4)
	option.add_theme_constant_override("h_separation", 4)
	option.add_theme_color_override("font_color", MENU_PALETTE.text_primary(1.0))
	option.add_theme_color_override("font_hover_color", MENU_PALETTE.text_primary(1.0))
	option.add_theme_color_override("font_pressed_color", MENU_PALETTE.text_primary(1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = MENU_PALETTE.accent(1.0)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = MENU_PALETTE.accent(1.0)
	normal.content_margin_left = 6
	normal.content_margin_right = 6
	normal.content_margin_top = 3
	normal.content_margin_bottom = 3
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = MENU_PALETTE.highlight(1.0)
	option.add_theme_stylebox_override("normal", normal)
	option.add_theme_stylebox_override("hover", hover)
	option.add_theme_stylebox_override("pressed", normal)
	option.add_theme_stylebox_override("focus", normal)
	option.add_theme_icon_override("arrow", _make_pixel_dropdown_arrow())
	var popup := option.get_popup()
	var panel := StyleBoxFlat.new()
	panel.bg_color = MENU_PALETTE.accent(1.0)
	panel.border_width_left = 2
	panel.border_width_top = 2
	panel.border_width_right = 2
	panel.border_width_bottom = 2
	panel.border_color = MENU_PALETTE.accent(1.0)
	var hover_popup := StyleBoxFlat.new()
	hover_popup.bg_color = MENU_PALETTE.hot(1.0)
	hover_popup.border_width_left = 1
	hover_popup.border_width_top = 1
	hover_popup.border_width_right = 1
	hover_popup.border_width_bottom = 1
	hover_popup.border_color = MENU_PALETTE.highlight(1.0)
	var selected_popup := StyleBoxFlat.new()
	selected_popup.bg_color = MENU_PALETTE.accent(1.0)
	selected_popup.border_width_left = 1
	selected_popup.border_width_top = 1
	selected_popup.border_width_right = 1
	selected_popup.border_width_bottom = 1
	selected_popup.border_color = MENU_PALETTE.accent(1.0)
	popup.add_theme_stylebox_override("panel", panel)
	popup.add_theme_stylebox_override("hover", hover_popup)
	popup.add_theme_stylebox_override("hover_pressed", hover_popup)
	popup.add_theme_stylebox_override("selected", selected_popup)
	popup.add_theme_stylebox_override("focus", selected_popup)
	popup.add_theme_stylebox_override("item_hover", hover_popup)
	popup.add_theme_constant_override("v_separation", 2)
	popup.add_theme_constant_override("h_separation", 6)
	popup.add_theme_color_override("font_color", MENU_PALETTE.text_primary(1.0))
	popup.add_theme_color_override("font_hover_color", MENU_PALETTE.text_primary(1.0))
	popup.add_theme_color_override("font_selected_color", MENU_PALETTE.text_primary(1.0))
	popup.add_theme_font_size_override("font_size", 8)

func _make_pixel_dropdown_arrow() -> Texture2D:
	var img := Image.create(9, 9, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var color := MENU_PALETTE.highlight(1.0)
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

func _make_pixel_checkbox_icon(checked: bool) -> Texture2D:
	var img := Image.create(11, 11, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var border := MENU_PALETTE.highlight(1.0)
	var fill := MENU_PALETTE.hot(1.0)
	for y in range(11):
		for x in range(11):
			var on_border := x == 0 or x == 10 or y == 0 or y == 10
			img.set_pixel(x, y, border if on_border else fill)
	if checked:
		var accent := MENU_PALETTE.highlight(1.0)
		for y in range(2, 9):
			for x in range(2, 9):
				img.set_pixel(x, y, accent)
	return ImageTexture.create_from_image(img)

func _apply_pixel_checkbox_style(check: CheckBox) -> void:
	if check == null:
		return
	check.alignment = HORIZONTAL_ALIGNMENT_LEFT
	check.add_theme_constant_override("h_separation", 6)
	check.add_theme_color_override("font_color", MENU_PALETTE.text_dark(1.0))
	check.add_theme_color_override("font_hover_color", MENU_PALETTE.text_dark(1.0))
	check.add_theme_color_override("font_pressed_color", MENU_PALETTE.text_dark(1.0))
	check.add_theme_color_override("font_disabled_color", MENU_PALETTE.text_dark(0.74))
	var unchecked := _make_pixel_checkbox_icon(false)
	var checked := _make_pixel_checkbox_icon(true)
	check.add_theme_icon_override("unchecked", unchecked)
	check.add_theme_icon_override("checked", checked)
	check.add_theme_icon_override("unchecked_disabled", unchecked)
	check.add_theme_icon_override("checked_disabled", checked)
	check.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _tinted_color(color: Color, amount: float) -> Color:
	return Color(
		clampf(color.r + amount, 0.0, 1.0),
		clampf(color.g + amount, 0.0, 1.0),
		clampf(color.b + amount, 0.0, 1.0),
		color.a
	)

func _apply_button_palette(btn: Button, normal_bg: Color, border: Color) -> void:
	if btn == null:
		return
	for sb_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := btn.get_theme_stylebox(sb_name)
		var flat := StyleBoxFlat.new()
		if sb is StyleBoxFlat:
			flat = (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
		flat.border_width_left = maxi(1, flat.border_width_left)
		flat.border_width_top = maxi(1, flat.border_width_top)
		flat.border_width_right = maxi(1, flat.border_width_right)
		flat.border_width_bottom = maxi(1, flat.border_width_bottom)
		flat.corner_radius_top_left = 0
		flat.corner_radius_top_right = 0
		flat.corner_radius_bottom_right = 0
		flat.corner_radius_bottom_left = 0
		if sb_name == "hover":
			flat.bg_color = _tinted_color(normal_bg, 0.06)
		elif sb_name == "pressed":
			flat.bg_color = _tinted_color(normal_bg, -0.07)
		elif sb_name == "disabled":
			flat.bg_color = Color(normal_bg.r, normal_bg.g, normal_bg.b, 0.42)
		else:
			flat.bg_color = normal_bg
		flat.border_color = Color(border.r, border.g, border.b, 0.48) if sb_name == "disabled" else border
		btn.add_theme_stylebox_override(sb_name, flat)
	btn.add_theme_color_override("font_color", MENU_PALETTE.text_dark(1.0))
	btn.add_theme_color_override("font_hover_color", MENU_PALETTE.text_dark(1.0))
	btn.add_theme_color_override("font_pressed_color", MENU_PALETTE.text_dark(1.0))
	btn.add_theme_color_override("font_disabled_color", MENU_PALETTE.text_dark(0.9))

func _apply_ready_button_state_style(btn: Button, is_ready: bool) -> void:
	if btn == null:
		return
	if is_ready:
		_apply_button_palette(btn, BTN_GREEN_BG, BTN_GREEN_BORDER)
	else:
		_apply_button_palette(btn, BTN_YELLOW_BG, BTN_YELLOW_BORDER)

func _remove_button_outlines(btn: Button) -> void:
	if btn == null:
		return
	for sb_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := btn.get_theme_stylebox(sb_name)
		if not (sb is StyleBoxFlat):
			continue
		var flat := (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
		flat.border_width_left = 0
		flat.border_width_top = 0
		flat.border_width_right = 0
		flat.border_width_bottom = 0
		btn.add_theme_stylebox_override(sb_name, flat)

func _set_rooms_list_visible(visible: bool) -> void:
	if _rooms_box != null:
		_rooms_box.visible = visible
	if _rooms_list_panel != null:
		_rooms_list_panel.visible = visible
