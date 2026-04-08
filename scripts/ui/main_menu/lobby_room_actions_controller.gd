extends RefCounted

class_name LobbyRoomActionsController

var _host: Object

func configure(host: Object) -> void:
	_host = host

func begin_lobby_action(status_text: String) -> int:
	_host.set("_action_inflight", true)
	var nonce := int(_host.get("_action_nonce")) + 1
	_host.set("_action_nonce", nonce)
	var status_label := _label_from_host("_status_label")
	if status_label != null:
		status_label.text = status_text
	_host.call("_refresh_lobby_buttons_state")
	var owner_control := _control_from_host("_host")
	if owner_control != null and owner_control.get_tree() != null:
		var timer := owner_control.get_tree().create_timer(6.0)
		timer.timeout.connect(func() -> void:
			if not _host_still_valid():
				return
			if nonce != int(_host.get("_action_nonce")):
				return
			if not bool(_host.get("_action_inflight")):
				return
			_host.set("_action_inflight", false)
			var timeout_status := _label_from_host("_status_label")
			if timeout_status != null:
				timeout_status.text = "Lobby request timed out. Try refresh."
			_host.call("_refresh_lobby_buttons_state")
		)
	return nonce

func populate_lobby_room_list() -> void:
	var rooms_box := _host.get("_rooms_box") as VBoxContainer
	if rooms_box == null:
		return
	var room_buttons := _host.get("_room_buttons") as Array
	for btn_ref in room_buttons:
		var btn := _button_from_ref(btn_ref)
		if btn != null:
			btn.queue_free()
	room_buttons.clear()
	_host.set("_selected_room_index", -1)
	var room_entries := _host.get("_room_entries") as Array
	for i in range(room_entries.size()):
		var entry := room_entries[i] as Dictionary
		var make_button := _host.get("_make_button") as Callable
		var btn: Button = make_button.call() as Button if make_button.is_valid() else Button.new()
		btn.custom_minimum_size = Vector2(0, 30)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 8)
		var lobby_id := int(entry.get("id", 0))
		var room_name := str(entry.get("name", "Room"))
		var players := int(entry.get("players", 0))
		var max_players := int(entry.get("max_players", 2))
		var map_id := str(entry.get("map_name", entry.get("map_id", "classic"))).to_upper()
		var mode_id := str(entry.get("mode_name", entry.get("mode_id", "deathmatch"))).to_upper()
		var in_room := lobby_id > 0 and lobby_id == int(_host.get("_joined_lobby_id"))
		var suffix := "  [IN]" if in_room else ""
		btn.text = "#%d  %s   |   %d/%d   |   %s | %s%s" % [lobby_id, room_name, players, max_players, map_id, mode_id, suffix]
		btn.set_meta("kw_room_base_text", btn.text)
		btn.pressed.connect(func() -> void:
			_host.call("_select_lobby_room", i)
		)
		var add_hover_pop := _host.get("_add_hover_pop") as Callable
		if add_hover_pop.is_valid():
			add_hover_pop.call(btn)
		_host.call("_apply_button_palette", btn, _host.get("BTN_GREEN_BG"), _host.get("BTN_GREEN_BORDER"))
		btn.add_theme_color_override("font_color", Color(0, 0, 0, 1))
		btn.add_theme_color_override("font_hover_color", Color(0, 0, 0, 1))
		btn.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 1))
		rooms_box.add_child(btn)
		var center_pivot := _host.get("_center_pivot") as Callable
		if center_pivot.is_valid():
			center_pivot.call(btn)
		room_buttons.append(btn)
	if room_entries.size() > 0:
		var preselect := 0
		for i in range(room_entries.size()):
			var entry := room_entries[i] as Dictionary
			if int(entry.get("id", 0)) == int(_host.get("_joined_lobby_id")):
				preselect = i
				break
		_host.call("_select_lobby_room", preselect)
	else:
		var join_button := _host.get("_join_button") as Button
		if join_button != null:
			join_button.disabled = true
		var status_label := _host.get("_status_label") as Label
		if status_label != null:
			status_label.text = "No lobbies yet. Create one."
	_host.call("_refresh_lobby_buttons_state")

func select_lobby_room(index: int) -> void:
	var room_entries := _host.get("_room_entries") as Array
	if index < 0 or index >= room_entries.size():
		return
	_host.set("_selected_room_index", index)
	var room_buttons := _host.get("_room_buttons") as Array
	for i in range(room_buttons.size()):
		var btn := _button_from_ref(room_buttons[i])
		if btn != null:
			apply_room_button_selected_style(btn, i == index)
	var join_button := _host.get("_join_button") as Button
	if join_button != null:
		join_button.disabled = false
	_host.call("_refresh_lobby_selection_summary")
	_host.call("_refresh_lobby_buttons_state")

func apply_room_button_selected_style(btn: Button, selected: bool) -> void:
	if btn == null:
		return
	var base_text := str(btn.get_meta("kw_room_base_text", btn.text))
	btn.text = ("> " + base_text) if selected else base_text
	if selected:
		btn.modulate = Color(1, 1, 1, 1)
		btn.add_theme_color_override("font_color", Color(0, 0, 0, 1))
		btn.add_theme_color_override("font_hover_color", Color(0, 0, 0, 1))
		var selected_style := StyleBoxFlat.new()
		selected_style.bg_color = _host.get("BTN_YELLOW_BG") as Color
		selected_style.border_width_left = 2
		selected_style.border_width_top = 2
		selected_style.border_width_right = 2
		selected_style.border_width_bottom = 2
		selected_style.border_color = _host.get("BTN_YELLOW_BORDER") as Color
		btn.add_theme_stylebox_override("normal", selected_style)
		btn.add_theme_stylebox_override("hover", selected_style)
		btn.add_theme_stylebox_override("pressed", selected_style)
		btn.add_theme_stylebox_override("focus", selected_style)
		return
	btn.modulate = Color(1, 1, 1, 1)
	_host.call("_apply_button_palette", btn, _host.get("BTN_GREEN_BG"), _host.get("BTN_GREEN_BORDER"))
	btn.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	btn.add_theme_color_override("font_hover_color", Color(0, 0, 0, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 1))

func refresh_lobby_selection_summary() -> void:
	var selection_label := _host.get("_selection_label") as Label
	if selection_label == null:
		return
	var ctf_room_state := _host.get("_ctf_room_state") as Dictionary
	var joined_lobby_id := int(_host.get("_joined_lobby_id"))
	var joined_room_name := str(_host.get("_joined_room_name"))
	if not ctf_room_state.is_empty() and bool(_host.call("_is_team_mode_id", _host.call("_active_lobby_mode_id", joined_lobby_id))):
		selection_label.text = "Team room: %s" % joined_room_name
		return
	if not ctf_room_state.is_empty() and bool(_host.call("_is_free_for_all_mode_id", _host.call("_active_lobby_mode_id", joined_lobby_id))) and not bool(ctf_room_state.get("started", false)):
		selection_label.text = "Waiting room: %s" % joined_room_name
		return
	if joined_room_name.is_empty():
		var room_entries := _host.get("_room_entries") as Array
		if room_entries.is_empty():
			selection_label.text = "Select a room or create one."
			return
		var selected_room_index := int(_host.get("_selected_room_index"))
		if selected_room_index < 0 or selected_room_index >= room_entries.size():
			selection_label.text = "Select a room to join."
			return
		var room := room_entries[selected_room_index] as Dictionary
		selection_label.text = "Selected: %s" % str(room.get("name", "Room"))
		return
	selection_label.text = "In room: %s" % joined_room_name

func join_selected_lobby_room() -> void:
	var room_entries := _host.get("_room_entries") as Array
	var selected_room_index := int(_host.get("_selected_room_index"))
	if selected_room_index < 0 or selected_room_index >= room_entries.size():
		return
	var room := room_entries[selected_room_index] as Dictionary
	var lobby_id := int(room.get("id", 0))
	var room_name := str(room.get("name", "Room"))
	var rpc_bridge: Variant = _host.get("_rpc_bridge")
	if rpc_bridge == null or lobby_id <= 0:
		return
	if int(_host.get("_joined_lobby_id")) == lobby_id:
		var status_label := _host.get("_status_label") as Label
		if status_label != null:
			status_label.text = "Already in %s" % room_name
		_host.call("_refresh_lobby_selection_summary")
		_host.call("_refresh_lobby_buttons_state")
		return
	_host.call("_persist_local_loadout_selection")
	_host.call("_sync_selected_warrior_skin")
	_host.call("_sync_selected_weapon_skin")
	begin_lobby_action("Joining %s..." % room_name)
	var sent_join := bool(rpc_bridge.call("join_lobby", lobby_id, _host.call("_selected_weapon_id"), _host.call("_selected_warrior_id")))
	var status_label := _host.get("_status_label") as Label
	if status_label != null:
		status_label.text = ("Joining %s..." % room_name) if sent_join else "Still connecting..."
	if not sent_join:
		_host.set("_action_inflight", false)
		_host.call("_request_lobby_list_from_server")
	_host.call("_refresh_lobby_selection_summary")
	_host.call("_refresh_lobby_buttons_state")

func create_lobby_room() -> void:
	var rpc_bridge: Variant = _host.get("_rpc_bridge")
	if rpc_bridge == null:
		_host.call("_log", "create_lobby clicked but rpc_bridge=null")
		return
	var request := build_create_lobby_request()
	if int(_host.get("_joined_lobby_id")) > 0:
		_host.call("_log", "create_lobby while in lobby id=%d; leaving first then creating new lobby" % int(_host.get("_joined_lobby_id")))
		_host.set("_pending_create_request", request.duplicate(true))
		var status_label := _host.get("_status_label") as Label
		if status_label != null:
			status_label.text = "Leaving current lobby..."
		begin_lobby_action("Leaving current lobby...")
		var sent_leave := bool(rpc_bridge.call("leave_lobby"))
		if not sent_leave:
			_host.set("_action_inflight", false)
			_host.call("_request_lobby_list_from_server")
		_host.call("_refresh_lobby_buttons_state")
		return
	_host.call("_log", "create_lobby clicked request=%s can_send=%s" % [str(request), str(bool(rpc_bridge.call("can_send_lobby_rpc")))])
	if not bool(rpc_bridge.call("can_send_lobby_rpc")):
		_host.set("_pending_create_request", request.duplicate(true))
		var status_label := _host.get("_status_label") as Label
		if status_label != null:
			status_label.text = "Connecting to lobby server..."
		if bool(rpc_bridge.call("is_connecting_to_server")):
			_host.call("_log", "create_lobby queued while connect attempt is in-flight")
		else:
			_host.call("_begin_connect_attempt", true, "Reconnecting")
		_host.call("_refresh_lobby_buttons_state")
		return
	send_create_lobby_request(request)

func leave_lobby_room() -> void:
	var joined_lobby_id := int(_host.get("_joined_lobby_id"))
	var joined_room_name := str(_host.get("_joined_room_name"))
	if joined_lobby_id <= 0 and joined_room_name.is_empty():
		return
	var rpc_bridge: Variant = _host.get("_rpc_bridge")
	if rpc_bridge == null:
		return
	var previous := joined_room_name if not joined_room_name.is_empty() else "lobby"
	begin_lobby_action("Leaving %s..." % previous)
	var sent_leave := bool(rpc_bridge.call("leave_lobby"))
	var status_label := _host.get("_status_label") as Label
	if status_label != null:
		status_label.text = ("Leaving %s..." % previous) if sent_leave else "Still connecting..."
	if not sent_leave:
		_host.set("_action_inflight", false)
		_host.call("_request_lobby_list_from_server")
	var ctf_room_state := _host.get("_ctf_room_state") as Dictionary
	ctf_room_state.clear()
	_host.call("_hide_ctf_room")
	_host.call("_hide_dm_room")
	_host.call("_refresh_lobby_chat_context")
	_host.call("_refresh_lobby_selection_summary")
	_host.call("_refresh_lobby_buttons_state")

func start_lobby_match(status_text: String = "Starting match...") -> void:
	var rpc_bridge: Variant = _host.get("_rpc_bridge")
	if rpc_bridge == null:
		return
	if int(_host.get("_joined_lobby_id")) <= 0:
		return
	begin_lobby_action(status_text)
	var sent_start := bool(rpc_bridge.call("start_lobby_match"))
	var status_label := _host.get("_status_label") as Label
	if status_label != null:
		status_label.text = status_text if sent_start else "Still connecting..."
	if not sent_start:
		_host.set("_action_inflight", false)
		_host.call("_request_lobby_list_from_server")
	_host.call("_refresh_lobby_buttons_state")

func build_create_lobby_request() -> Dictionary:
	_host.call("_ensure_valid_map_selection")
	var dropdown_map_id := str(_host.get("_selected_map_id"))
	var map_option := _host.get("_map_option") as OptionButton
	var map_flow_service: Variant = _host.get("_map_flow_service")
	var map_catalog: Variant = _host.get("_map_catalog")
	if map_option != null:
		var selected_index := map_option.get_selected()
		if selected_index >= 0 and selected_index < map_option.get_item_count():
			var selected_meta := str(map_option.get_item_metadata(selected_index)).strip_edges().to_lower()
			if not selected_meta.is_empty():
				dropdown_map_id = str(map_flow_service.call("normalize_map_id", map_catalog, selected_meta))
	_host.set("_selected_map_id", dropdown_map_id)
	_host.set("_selected_mode_id", map_flow_service.call("select_mode_for_map", map_catalog, str(_host.get("_selected_map_id")), str(_host.get("_selected_mode_id"))))
	var room_entries := _host.get("_room_entries") as Array
	var requested_name := "My Lobby %d" % (room_entries.size() + 1)
	var request := {
		"name": requested_name,
		"weapon_id": _host.call("_selected_weapon_id"),
		"character_id": _host.call("_selected_warrior_id"),
		"map_id": _host.get("_selected_map_id"),
		"mode_id": _host.get("_selected_mode_id"),
	}
	_host.call("_log", "build_create_lobby_request selected_map_id=%s selected_mode_id=%s request=%s" % [str(_host.get("_selected_map_id")), str(_host.get("_selected_mode_id")), str(request)])
	return request

func send_create_lobby_request(request: Dictionary) -> void:
	_host.set("_pending_create_request", {})
	_host.call("_ensure_valid_map_selection")
	var map_flow_service: Variant = _host.get("_map_flow_service")
	var map_catalog: Variant = _host.get("_map_catalog")
	var default_map_id := str(map_flow_service.call("normalize_map_id", map_catalog, map_catalog.call("default_map_id")))
	var requested_name := str(request.get("name", "")).strip_edges()
	var selected_weapon_id := str(request.get("weapon_id", "ak47")).strip_edges().to_lower()
	var selected_character_id := str(request.get("character_id", "outrage")).strip_edges().to_lower()
	var map_id := str(request.get("map_id", default_map_id)).strip_edges().to_lower()
	var mode_id := str(request.get("mode_id", "deathmatch")).strip_edges().to_lower()
	if requested_name.is_empty():
		var room_entries := _host.get("_room_entries") as Array
		requested_name = "My Lobby %d" % (room_entries.size() + 1)
	if selected_weapon_id.is_empty():
		selected_weapon_id = "ak47"
	if selected_character_id != "erebus" and selected_character_id != "tasko" and selected_character_id != "juice" and selected_character_id != "madam" and selected_character_id != "celler" and selected_character_id != "kotro" and selected_character_id != "nova" and selected_character_id != "hindi" and selected_character_id != "loker" and selected_character_id != "gan" and selected_character_id != "veila":
		selected_character_id = "outrage"
	if map_id.is_empty():
		map_id = default_map_id
	map_id = str(map_flow_service.call("normalize_map_id", map_catalog, map_id))
	_host.set("_last_create_requested_map_id", map_id)
	_host.set("_forced_rounds_ruleset_lobby_id", 0)
	mode_id = str(map_flow_service.call("select_mode_for_map", map_catalog, map_id, mode_id))
	var rpc_bridge: Variant = _host.get("_rpc_bridge")
	_host.call("_log", "send_create_lobby_request name=%s weapon=%s character=%s map=%s mode=%s can_send=%s" % [
		requested_name,
		selected_weapon_id,
		selected_character_id,
		map_id,
		mode_id,
		str(bool(rpc_bridge.call("can_send_lobby_rpc")))
	])
	_host.call("_persist_local_loadout_selection")
	_host.call("_sync_selected_warrior_skin")
	_host.call("_sync_selected_weapon_skin")
	begin_lobby_action("Creating lobby...")
	var sent_create := bool(rpc_bridge.call("create_lobby", requested_name, selected_weapon_id, selected_character_id, map_id, mode_id))
	_host.call("_log", "create_lobby rpc sent=%s" % str(sent_create))
	if sent_create:
		_host.call("_log", "create_lobby result=RPC_SENT awaiting server confirmation")
	var status_label := _host.get("_status_label") as Label
	if status_label != null:
		status_label.text = "Creating lobby..." if sent_create else "Still connecting..."
	if not sent_create:
		_host.set("_action_inflight", false)
		_host.set("_pending_create_request", request.duplicate(true))
		_host.call("_request_lobby_list_from_server")
	_host.call("_refresh_lobby_selection_summary")
	_host.call("_refresh_lobby_buttons_state")

func _button_from_ref(value: Variant) -> Button:
	if value == null:
		return null
	if value is Object and not is_instance_valid(value):
		return null
	return value as Button

func _control_from_host(key: String) -> Control:
	return _object_from_host(key) as Control

func _label_from_host(key: String) -> Label:
	return _object_from_host(key) as Label

func _object_from_host(key: String) -> Object:
	if not _host_still_valid():
		return null
	var value: Variant = _host.get(key)
	if value == null:
		return null
	if value is Object and not is_instance_valid(value):
		return null
	return value as Object

func _host_still_valid() -> bool:
	if _host == null:
		return false
	if _host is Object and not is_instance_valid(_host):
		return false
	return true
