extends RefCounted
class_name UiController

const KILL_FEED_FONT := preload("res://assets/fonts/kwfont.ttf")

var start_server_button: Button
var stop_button: Button
var connect_button: Button
var disconnect_button: Button
var port_spin: SpinBox
var host_input: LineEdit
var peers_label: Label
var ping_label: Label
var kd_label: Label
var cooldown_label: Label
var cooldown_q_label: Label
var cooldown_e_label: Label
var scoreboard_label: Label
var ui_panel: PanelContainer
var world_root: Node2D
var lobby_panel: PanelContainer
var lobby_list: ItemList
var lobby_status_label: Label
var lobby_create_button: Button
var lobby_join_button: Button
var lobby_refresh_button: Button
var lobby_leave_button: Button
var lobby_room_bg: ColorRect
var lobby_room_title: Label
var _ctf_room_panel: PanelContainer
var _ctf_room_title: Label
var _ctf_room_red_label: Label
var _ctf_room_blue_label: Label
var _ctf_join_red_button: Button
var _ctf_join_blue_button: Button
var _ctf_start_button: Button
var _ctf_room_callbacks: Dictionary = {}
var _kill_feed_root: VBoxContainer
var _kill_feed_max_entries: int = 4
var _kill_feed_lifetime_sec: float = 2.4

func configure(refs: Dictionary) -> void:
	start_server_button = refs.get("start_server_button", null) as Button
	stop_button = refs.get("stop_button", null) as Button
	connect_button = refs.get("connect_button", null) as Button
	disconnect_button = refs.get("disconnect_button", null) as Button
	port_spin = refs.get("port_spin", null) as SpinBox
	host_input = refs.get("host_input", null) as LineEdit
	peers_label = refs.get("peers_label", null) as Label
	ping_label = refs.get("ping_label", null) as Label
	kd_label = refs.get("kd_label", null) as Label
	cooldown_label = refs.get("cooldown_label", null) as Label
	cooldown_q_label = refs.get("cooldown_q_label", null) as Label
	cooldown_e_label = refs.get("cooldown_e_label", null) as Label
	scoreboard_label = refs.get("scoreboard_label", null) as Label
	ui_panel = refs.get("ui_panel", null) as PanelContainer
	world_root = refs.get("world_root", null) as Node2D
	lobby_panel = refs.get("lobby_panel", null) as PanelContainer
	lobby_list = refs.get("lobby_list", null) as ItemList
	lobby_status_label = refs.get("lobby_status_label", null) as Label
	lobby_create_button = refs.get("lobby_create_button", null) as Button
	lobby_join_button = refs.get("lobby_join_button", null) as Button
	lobby_refresh_button = refs.get("lobby_refresh_button", null) as Button
	lobby_leave_button = refs.get("lobby_leave_button", null) as Button
	lobby_room_bg = refs.get("lobby_room_bg", null) as ColorRect
	lobby_room_title = refs.get("lobby_room_title", null) as Label
	_ensure_ctf_room_ui()
	_ensure_kill_feed_ui()

func update_buttons(
	has_active_session: bool,
	server_allowed: bool,
	client_allowed: bool,
	is_server_role: bool,
	is_client_role: bool
) -> void:
	if start_server_button != null:
		start_server_button.disabled = has_active_session or not server_allowed
	if connect_button != null:
		connect_button.disabled = has_active_session or not client_allowed
	if stop_button != null:
		stop_button.disabled = not is_server_role
	if disconnect_button != null:
		disconnect_button.disabled = not is_client_role
	if port_spin != null:
		port_spin.editable = not has_active_session
	if host_input != null:
		host_input.editable = not has_active_session and client_allowed

func local_ping_text(is_server_role: bool, is_client_role: bool, last_ping_ms: int) -> String:
	if is_server_role:
		return "server"
	if is_client_role:
		if last_ping_ms >= 0:
			return "%d ms" % last_ping_ms
		return "..."
	return "-"

func update_peer_labels(my_peer_id: int, net_peer_ids: PackedInt32Array, spawned_player_ids: Array, ping_text: String) -> void:
	if peers_label == null:
		return
	var players_text := "-"
	var sorted_ids := spawned_player_ids.duplicate()
	sorted_ids.sort()
	if not sorted_ids.is_empty():
		var player_parts := PackedStringArray()
		for id in sorted_ids:
			player_parts.append(str(int(id)))
		players_text = ", ".join(player_parts)
	peers_label.text = "My peer id: %d | Net peers: %s | Players: %s | Ping: %s" % [
		my_peer_id,
		_peer_list_to_text(net_peer_ids),
		players_text,
		ping_text
	]

func update_ping_label(ping_text: String) -> void:
	if ping_label != null:
		ping_label.text = "Ping: %s" % ping_text

func update_kd_label(local_peer_id: int, player_stats: Dictionary) -> void:
	if kd_label == null:
		return
	var kills := 0
	var deaths := 0
	if local_peer_id > 0 and player_stats.has(local_peer_id):
		var stats := player_stats[local_peer_id] as Dictionary
		kills = int(stats.get("kills", 0))
		deaths = int(stats.get("deaths", 0))
	kd_label.text = "K/D : %d/%d" % [kills, deaths]

func update_cooldown_label(cooldown_text: String) -> void:
	if cooldown_label != null:
		cooldown_label.text = cooldown_text

func set_status_text(text: String) -> void:
	if cooldown_label == null:
		return
	var normalized := text.strip_edges()
	cooldown_label.visible = not normalized.is_empty()
	cooldown_label.text = normalized

func update_skill_cooldowns(q_text: String, e_text: String) -> void:
	if cooldown_q_label != null:
		cooldown_q_label.visible = false
		cooldown_q_label.text = q_text
	if cooldown_e_label != null:
		cooldown_e_label.visible = false
		cooldown_e_label.text = e_text

func update_scoreboard_label(player_stats: Dictionary, player_display_names: Dictionary) -> void:
	if scoreboard_label == null:
		return
	var lines := PackedStringArray()
	lines.append("K/D")
	var peer_ids := player_stats.keys()
	peer_ids.sort_custom(func(a, b) -> bool:
		return _display_order_for_peer(int(a), player_display_names) < _display_order_for_peer(int(b), player_display_names)
	)
	if peer_ids.is_empty():
		lines.append("-")
	else:
		for peer_id_value in peer_ids:
			var peer_id := int(peer_id_value)
			var stats := player_stats[peer_id] as Dictionary
			var kills := int(stats.get("kills", 0))
			var deaths := int(stats.get("deaths", 0))
			lines.append("%s  %d/%d" % [_display_name_for_peer(peer_id, player_display_names), kills, deaths])
	scoreboard_label.text = "\n".join(lines)

func selected_lobby_id() -> int:
	if lobby_list == null:
		return 0
	var selected := lobby_list.get_selected_items()
	if selected.is_empty():
		return 0
	return int(lobby_list.get_item_metadata(selected[0]))

func update_lobby_buttons_state(connected_client: bool, has_active_lobby: bool) -> void:
	if lobby_panel == null:
		return
	var selected_lobby := selected_lobby_id()
	if lobby_create_button != null:
		lobby_create_button.disabled = not connected_client or has_active_lobby
	if lobby_join_button != null:
		lobby_join_button.disabled = not connected_client or has_active_lobby or selected_lobby <= 0
	if lobby_refresh_button != null:
		lobby_refresh_button.disabled = not connected_client
	if lobby_leave_button != null:
		lobby_leave_button.disabled = not connected_client or not has_active_lobby
	if _ctf_join_red_button != null:
		_ctf_join_red_button.disabled = not connected_client
	if _ctf_join_blue_button != null:
		_ctf_join_blue_button.disabled = not connected_client

func set_lobby_status(text: String) -> void:
	if lobby_status_label != null:
		lobby_status_label.text = text

func clear_lobby_list() -> void:
	if lobby_list != null:
		lobby_list.clear()

func refresh_lobby_list_ui(entries: Array, active_lobby_id: int, default_max_players: int) -> void:
	if lobby_list == null:
		return
	var previously_selected := selected_lobby_id()
	lobby_list.clear()
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var item := entry as Dictionary
		var lobby_id := int(item.get("id", 0))
		if lobby_id <= 0:
			continue
		var name := str(item.get("name", "Lobby %d" % lobby_id))
		var players_count := int(item.get("players", 0))
		var max_players := int(item.get("max_players", default_max_players))
		var map_name := str(item.get("map_name", "")).strip_edges()
		if map_name.is_empty():
			map_name = str(item.get("map_id", "")).strip_edges()
		var mode_name := str(item.get("mode_name", "")).strip_edges()
		var row := "%s  [%d/%d]" % [name, players_count, max_players]
		if not map_name.is_empty():
			row += "  {%s}" % map_name
		if not mode_name.is_empty():
			row += "  <%s>" % mode_name
		var index := lobby_list.get_item_count()
		lobby_list.add_item(row)
		lobby_list.set_item_metadata(index, lobby_id)
		if lobby_id == previously_selected:
			lobby_list.select(index)

	if active_lobby_id > 0:
		var lobby_name := "Lobby %d" % active_lobby_id
		for entry in entries:
			if entry is Dictionary and int((entry as Dictionary).get("id", 0)) == active_lobby_id:
				lobby_name = str((entry as Dictionary).get("name", lobby_name))
				break
		set_lobby_status("In %s" % lobby_name)
	elif lobby_list.get_item_count() == 0:
		set_lobby_status("")
	else:
		set_lobby_status("Choose or create lobby.")

func set_ctf_room_callbacks(on_join_red: Callable, on_join_blue: Callable, on_start_match: Callable) -> void:
	_ctf_room_callbacks = {
		"join_red": on_join_red,
		"join_blue": on_join_blue,
		"start_match": on_start_match
	}

func show_ctf_room(room_state: Dictionary, local_peer_id: int) -> void:
	_ensure_ctf_room_ui()
	if _ctf_room_panel == null:
		return
	var owner_peer_id := int(room_state.get("owner_peer_id", 0))
	var room_name := str(room_state.get("name", "CTF Room"))
	var teams := room_state.get("teams", {}) as Dictionary
	var red_members := teams.get("red", []) as Array
	var blue_members := teams.get("blue", []) as Array
	var team_by_peer := room_state.get("team_by_peer", {}) as Dictionary
	var local_team := int(team_by_peer.get(local_peer_id, -1))

	if _ctf_room_title != null:
		_ctf_room_title.text = "%s  |  CTF ROOM" % room_name
	if _ctf_room_red_label != null:
		_ctf_room_red_label.text = _team_text("RED TEAM", red_members)
	if _ctf_room_blue_label != null:
		_ctf_room_blue_label.text = _team_text("BLUE TEAM", blue_members)
	if _ctf_join_red_button != null:
		_ctf_join_red_button.disabled = local_team == 0
	if _ctf_join_blue_button != null:
		_ctf_join_blue_button.disabled = local_team == 1
	if _ctf_start_button != null:
		_ctf_start_button.disabled = owner_peer_id != local_peer_id or local_peer_id <= 0
		_ctf_start_button.text = "START MATCH" if owner_peer_id == local_peer_id else "HOST STARTS"
	_ctf_room_panel.visible = true

func hide_ctf_room() -> void:
	if _ctf_room_panel != null:
		_ctf_room_panel.visible = false

func update_ui_visibility(
	lobby_scene_mode: bool,
	is_server_role: bool,
	is_client_role: bool,
	local_spawned: bool,
	scoreboard_visible: bool,
	lobby_room_bg_enabled: bool,
	lobby_room_title_enabled: bool,
	auth_blocking: bool = false
) -> void:
	var show_lobby_room := lobby_scene_mode and not is_server_role and not local_spawned
	if lobby_scene_mode and lobby_panel == null:
		if ui_panel != null:
			ui_panel.visible = true
		if world_root != null:
			world_root.visible = false
		if ping_label != null:
			ping_label.visible = false
		if kd_label != null:
			kd_label.visible = false
		if scoreboard_label != null:
			scoreboard_label.visible = false
		return

	if ui_panel != null:
		if lobby_scene_mode:
			# Keep network controls/log visible in lobby mode so connect/start flow remains usable.
			ui_panel.visible = true
		else:
			ui_panel.visible = not local_spawned
	if ping_label != null:
		ping_label.visible = local_spawned and (is_client_role or is_server_role)
	if kd_label != null:
		kd_label.visible = local_spawned and (is_client_role or is_server_role)
	if scoreboard_label != null:
		scoreboard_label.visible = local_spawned and scoreboard_visible
	if lobby_panel != null:
		lobby_panel.visible = show_lobby_room and not auth_blocking
	if lobby_room_bg != null:
		lobby_room_bg.visible = show_lobby_room and lobby_room_bg_enabled
	if lobby_room_title != null:
		lobby_room_title.visible = show_lobby_room and lobby_room_title_enabled
	if world_root != null:
		world_root.visible = not lobby_scene_mode
	if not show_lobby_room:
		hide_ctf_room()

func _ensure_ctf_room_ui() -> void:
	if lobby_panel == null:
		return
	if _ctf_room_panel != null and is_instance_valid(_ctf_room_panel):
		return
	var panel := PanelContainer.new()
	panel.name = "CtfRoomPanel"
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 14.0
	panel.offset_top = 42.0
	panel.offset_right = -14.0
	panel.offset_bottom = -54.0
	lobby_panel.add_child(panel)
	_ctf_room_panel = panel

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "CTF ROOM"
	root.add_child(title)
	_ctf_room_title = title

	var teams_row := HBoxContainer.new()
	teams_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	teams_row.add_theme_constant_override("separation", 12)
	root.add_child(teams_row)

	var red_label := Label.new()
	red_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	red_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	red_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	red_label.text = "RED TEAM"
	teams_row.add_child(red_label)
	_ctf_room_red_label = red_label

	var blue_label := Label.new()
	blue_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	blue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	blue_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	blue_label.text = "BLUE TEAM"
	teams_row.add_child(blue_label)
	_ctf_room_blue_label = blue_label

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)

	var join_red := Button.new()
	join_red.text = "JOIN RED"
	join_red.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_red.pressed.connect(func() -> void:
		var cb := _ctf_room_callbacks.get("join_red", Callable()) as Callable
		if cb.is_valid():
			cb.call()
	)
	actions.add_child(join_red)
	_ctf_join_red_button = join_red

	var join_blue := Button.new()
	join_blue.text = "JOIN BLUE"
	join_blue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_blue.pressed.connect(func() -> void:
		var cb := _ctf_room_callbacks.get("join_blue", Callable()) as Callable
		if cb.is_valid():
			cb.call()
	)
	actions.add_child(join_blue)
	_ctf_join_blue_button = join_blue

	var start_match := Button.new()
	start_match.text = "START MATCH"
	start_match.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_match.pressed.connect(func() -> void:
		var cb := _ctf_room_callbacks.get("start_match", Callable()) as Callable
		if cb.is_valid():
			cb.call()
	)
	actions.add_child(start_match)
	_ctf_start_button = start_match

func _team_text(title: String, members: Array) -> String:
	var lines := PackedStringArray()
	lines.append(title)
	lines.append("")
	for slot in range(2):
		if slot < members.size() and members[slot] is Dictionary:
			var entry := members[slot] as Dictionary
			lines.append("%d. %s" % [slot + 1, str(entry.get("display_name", "Player"))])
		else:
			lines.append("%d. [EMPTY]" % (slot + 1))
	return "\n".join(lines)

func _peer_list_to_text(ids: PackedInt32Array) -> String:
	if ids.is_empty():
		return "-"
	var parts := PackedStringArray()
	for id in ids:
		parts.append(str(id))
	return ", ".join(parts)

func _display_name_for_peer(peer_id: int, player_display_names: Dictionary) -> String:
	if player_display_names.has(peer_id):
		return str(player_display_names[peer_id])
	return "P?"

func _display_order_for_peer(peer_id: int, player_display_names: Dictionary) -> int:
	var display_name := _display_name_for_peer(peer_id, player_display_names)
	if display_name.begins_with("P"):
		var suffix := display_name.substr(1)
		if suffix.is_valid_int():
			return int(suffix)
	return 9999 + peer_id

func push_kill_feed(attacker_name: String, victim_name: String) -> void:
	_ensure_kill_feed_ui()
	if _kill_feed_root == null or not is_instance_valid(_kill_feed_root):
		return
	_update_kill_feed_position()

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320.0, 30.0)
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	panel.scale = Vector2(0.72, 0.72)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.07, 0.15, 0.93)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.16, 0.88, 1.0, 1.0)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 2
	style.corner_radius_bottom_left = 2
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", KILL_FEED_FONT)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0, 1.0))
	label.text = "%s has killed %s" % [attacker_name, victim_name]
	panel.add_child(label)

	_kill_feed_root.add_child(panel)
	_kill_feed_root.move_child(panel, 0)
	panel.resized.connect(func() -> void:
		panel.pivot_offset = panel.size * 0.5
	, CONNECT_ONE_SHOT)

	while _kill_feed_root.get_child_count() > _kill_feed_max_entries:
		var old_entry := _kill_feed_root.get_child(_kill_feed_root.get_child_count() - 1)
		if old_entry != null:
			old_entry.queue_free()

	var tween := panel.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.08)
	tween.parallel().tween_property(panel, "scale", Vector2(1.08, 1.08), 0.10)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.08)
	tween.tween_interval(_kill_feed_lifetime_sec)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, 0.20)
	tween.tween_callback(panel.queue_free)

func _kill_feed_host_canvas() -> CanvasItem:
	if ping_label != null and is_instance_valid(ping_label):
		var ping_parent := ping_label.get_parent()
		if ping_parent is CanvasItem:
			return ping_parent as CanvasItem
	if kd_label != null and is_instance_valid(kd_label):
		var kd_parent := kd_label.get_parent()
		if kd_parent is CanvasItem:
			return kd_parent as CanvasItem
	if scoreboard_label != null and is_instance_valid(scoreboard_label):
		var score_parent := scoreboard_label.get_parent()
		if score_parent is CanvasItem:
			return score_parent as CanvasItem
	return null

func _ensure_kill_feed_ui() -> void:
	if _kill_feed_root != null and is_instance_valid(_kill_feed_root):
		return
	var host := _kill_feed_host_canvas()
	if (host == null or not is_instance_valid(host)) and ping_label != null and is_instance_valid(ping_label):
		host = ping_label
	if host == null or not is_instance_valid(host):
		return

	var root := VBoxContainer.new()
	root.name = "KillFeedRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.z_index = 200
	root.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_theme_constant_override("separation", 6)
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.size = Vector2(360.0, 160.0)
	root.set_as_top_level(true)
	host.add_child(root)
	_kill_feed_root = root
	_update_kill_feed_position()

func _update_kill_feed_position() -> void:
	if _kill_feed_root == null or not is_instance_valid(_kill_feed_root):
		return
	if scoreboard_label != null and is_instance_valid(scoreboard_label):
		var score_pos := scoreboard_label.get_global_position()
		_kill_feed_root.global_position = Vector2(maxf(8.0, score_pos.x - 90.0), maxf(8.0, score_pos.y - 50.0))
		return
	_kill_feed_root.global_position = Vector2(24.0, 12.0)
