extends RefCounted

const LOBBY_RPC_BRIDGE_SCRIPT := preload("res://scripts/ui/test_menu/lobby_rpc_bridge.gd")
const MAP_CATALOG_SCRIPT := preload("res://scripts/world/map_catalog.gd")

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
var _action_inflight := false
var _action_nonce := 0
var _map_catalog = MAP_CATALOG_SCRIPT.new()

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

func _resolve_server_host_port_from_args() -> Dictionary:
	var host := "127.0.0.1"
	var port := 8080
	if _host != null:
		var args := OS.get_cmdline_user_args()
		for arg in args:
			if arg.begins_with("--host="):
				host = arg.substr("--host=".length()).strip_edges()
			elif arg.begins_with("--port="):
				var parsed := int(arg.substr("--port=".length()))
				if parsed >= 1 and parsed <= 65535:
					port = parsed
	if host.is_empty():
		host = "127.0.0.1"
	return {"host": host, "port": port}

func _resolve_server_host_port() -> Dictionary:
	return _resolve_server_host_port_from_args()

func _request_lobby_list_from_server() -> void:
	if _rpc_bridge == null:
		return
	if _rpc_bridge.call("can_send_lobby_rpc"):
		_rpc_bridge.call("request_lobby_list")
		_refresh_lobby_buttons_state()
		return
	var endpoint := _resolve_server_host_port()
	if _status_label != null:
		_status_label.text = "Connecting..."
	_rpc_bridge.call("connect_to_server", str(endpoint.get("host", "127.0.0.1")), int(endpoint.get("port", 8080)))
	_refresh_lobby_buttons_state()

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
	if _status_label != null:
		_status_label.text = "Connected. Fetching lobbies..."
	if _host != null:
		var username := str(_host.get("player_username")).strip_edges()
		if not username.is_empty():
			_rpc_bridge.call("set_display_name", username)
	_rpc_bridge.call("request_lobby_list")
	_refresh_lobby_buttons_state()

func _on_rpc_failed() -> void:
	if _status_label != null:
		_status_label.text = "Connection failed"
	_refresh_lobby_buttons_state()

func _on_rpc_disconnected() -> void:
	if _status_label != null:
		_status_label.text = "Disconnected from server"
	_refresh_lobby_buttons_state()

func _on_rpc_lobby_list(entries: Array, active_lobby_id: int) -> void:
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
	_joined_lobby_id = active_lobby_id
	_action_inflight = false
	_action_nonce += 1
	if _status_label != null:
		_status_label.text = message if success else "Failed: %s" % message
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

	var selected_weapon_id := "ak47"
	var selected_character_id := "outrage"
	if _host != null:
		selected_weapon_id = str(_host.get("selected_weapon_id")).strip_edges().to_lower()
		selected_character_id = str(_host.get("selected_warrior_id")).strip_edges().to_lower()
	if selected_character_id != "erebus" and selected_character_id != "tasko":
		selected_character_id = "outrage"
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
		return
	if _joined_lobby_id > 0:
		if _status_label != null:
			_status_label.text = "Leave current lobby first"
		return

	var requested_name := "My Lobby %d" % (_room_entries.size() + 1)
	var selected_weapon_id := "ak47"
	var selected_character_id := "outrage"
	if _host != null:
		selected_weapon_id = str(_host.get("selected_weapon_id")).strip_edges().to_lower()
		selected_character_id = str(_host.get("selected_warrior_id")).strip_edges().to_lower()
	if selected_character_id != "erebus" and selected_character_id != "tasko":
		selected_character_id = "outrage"
	_begin_lobby_action("Creating lobby...")
	var sent_create := bool(_rpc_bridge.call("create_lobby", requested_name, selected_weapon_id, selected_character_id, "classic"))
	if _status_label != null:
		_status_label.text = "Creating lobby..." if sent_create else "Still connecting..."
	if not sent_create:
		_action_inflight = false
		_request_lobby_list_from_server()
	_refresh_lobby_selection_summary()
	_refresh_lobby_buttons_state()

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

func _refresh_lobby_buttons_state() -> void:
	var can_send := _rpc_bridge != null and bool(_rpc_bridge.call("can_send_lobby_rpc"))
	if _create_button != null:
		_create_button.disabled = not can_send or _joined_lobby_id > 0 or _action_inflight
	if _join_button != null:
		_join_button.disabled = not can_send or _selected_room_index < 0 or _action_inflight
	if _refresh_button != null:
		_refresh_button.disabled = not can_send or _action_inflight
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
