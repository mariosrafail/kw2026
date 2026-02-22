extends RefCounted
class_name UiController

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
		cooldown_q_label.text = q_text
	if cooldown_e_label != null:
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
		var row := "%s  [%d/%d]" % [name, players_count, max_players]
		if not map_name.is_empty():
			row += "  {%s}" % map_name
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

func update_ui_visibility(
	lobby_scene_mode: bool,
	is_server_role: bool,
	is_client_role: bool,
	local_spawned: bool,
	scoreboard_visible: bool,
	lobby_room_bg_enabled: bool,
	lobby_room_title_enabled: bool
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
			ui_panel.visible = not is_client_role or not local_spawned
	if ping_label != null:
		ping_label.visible = is_client_role and local_spawned
	if kd_label != null:
		kd_label.visible = is_client_role and local_spawned
	if scoreboard_label != null:
		scoreboard_label.visible = is_client_role and local_spawned and scoreboard_visible
	if lobby_panel != null:
		lobby_panel.visible = show_lobby_room
	if lobby_room_bg != null:
		lobby_room_bg.visible = show_lobby_room and lobby_room_bg_enabled
	if lobby_room_title != null:
		lobby_room_title.visible = show_lobby_room and lobby_room_title_enabled
	if world_root != null:
		world_root.visible = not lobby_scene_mode

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
