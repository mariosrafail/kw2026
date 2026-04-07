extends RefCounted

class_name LobbyRoomStateController

var _host: Object

func configure(host: Object) -> void:
	_host = host

func refresh_lobby_buttons_state() -> void:
	if not _host_still_valid():
		return
	var rpc_bridge: Variant = _host.get("_rpc_bridge")
	var can_send := rpc_bridge != null and bool(rpc_bridge.call("can_send_lobby_rpc"))
	var ctf_room_state := _host.get("_ctf_room_state") as Dictionary
	var joined_lobby_id := int(_host.get("_joined_lobby_id"))
	var joined_room_name := str(_host.get("_joined_room_name"))
	var action_inflight := bool(_host.get("_action_inflight"))
	var in_waiting_room := not ctf_room_state.is_empty() and joined_lobby_id > 0 and not bool(ctf_room_state.get("started", false))
	var in_ctf_room := in_waiting_room and is_team_mode_id(active_lobby_mode_id(joined_lobby_id))
	var in_dm_room := in_waiting_room and is_free_for_all_mode_id(active_lobby_mode_id(joined_lobby_id))
	var supports_starting_animation_toggle := supports_starting_animation_testing_toggle()
	var skull_policy := str(_host.call("_skull_ruleset_policy_for_map", active_lobby_map_id(joined_lobby_id)))
	var supports_skull_options := in_dm_room and skull_policy != "none"
	var supports_ruleset_choice := supports_skull_options and skull_policy == "deathmatch_only"
	var local_peer_id := int(_host.call("_local_peer_id"))
	var is_owner := local_peer_id > 0 and local_peer_id == int(ctf_room_state.get("owner_peer_id", 0))
	var create_button := _button_from_host("_create_button")
	if create_button != null:
		create_button.visible = not in_waiting_room
		create_button.disabled = joined_lobby_id > 0 or action_inflight or in_waiting_room
	var join_button := _button_from_host("_join_button")
	if join_button != null:
		join_button.visible = not in_waiting_room
		join_button.disabled = not can_send or int(_host.get("_selected_room_index")) < 0 or action_inflight or in_waiting_room
	var refresh_button := _button_from_host("_refresh_button")
	if refresh_button != null:
		refresh_button.visible = not in_waiting_room
		refresh_button.disabled = action_inflight or in_waiting_room
	var leave_button := _button_from_host("_leave_button")
	if leave_button != null:
		leave_button.visible = false
		leave_button.disabled = not can_send or joined_room_name.is_empty() or action_inflight
	var ctf_leave_button := _button_from_host("_ctf_leave_button")
	if ctf_leave_button != null:
		ctf_leave_button.visible = in_ctf_room
		ctf_leave_button.disabled = not can_send or joined_room_name.is_empty() or action_inflight
	var dm_leave_button := _button_from_host("_dm_leave_button")
	if dm_leave_button != null:
		dm_leave_button.visible = in_dm_room
		dm_leave_button.disabled = not can_send or joined_room_name.is_empty() or action_inflight
	var back_button := _button_from_host("_back_button")
	if back_button != null:
		back_button.visible = not in_waiting_room
		back_button.disabled = action_inflight
	var preset_rounds_button := _button_from_host("_preset_rounds_button")
	if preset_rounds_button != null:
		preset_rounds_button.disabled = in_waiting_room or action_inflight
	var preset_deathmatch_button := _button_from_host("_preset_deathmatch_button")
	if preset_deathmatch_button != null:
		preset_deathmatch_button.disabled = in_waiting_room or action_inflight
	var preset_br_button := _button_from_host("_preset_br_button")
	if preset_br_button != null:
		preset_br_button.disabled = in_waiting_room or action_inflight
	var ctf_join_red_button := _button_from_host("_ctf_join_red_button")
	if ctf_join_red_button != null:
		ctf_join_red_button.disabled = not can_send or action_inflight or local_team_id() == 0
	var ctf_join_blue_button := _button_from_host("_ctf_join_blue_button")
	if ctf_join_blue_button != null:
		ctf_join_blue_button.disabled = not can_send or action_inflight or local_team_id() == 1
	var ctf_start_button := _button_from_host("_ctf_start_button")
	if ctf_start_button != null:
		ctf_start_button.visible = in_ctf_room and is_owner
		ctf_start_button.disabled = not can_send or action_inflight or local_peer_id != int(ctf_room_state.get("owner_peer_id", 0)) or not bool(ctf_room_state.get("can_start", false))
	var ctf_ready_button := _button_from_host("_ctf_ready_button")
	if ctf_ready_button != null:
		ctf_ready_button.visible = in_ctf_room and not is_owner
		ctf_ready_button.disabled = not can_send or action_inflight or not in_ctf_room
	var ctf_add_bots_check := _checkbox_from_host("_ctf_add_bots_check")
	if ctf_add_bots_check != null:
		ctf_add_bots_check.visible = in_ctf_room and is_owner
		ctf_add_bots_check.disabled = not can_send or action_inflight or not in_ctf_room or not is_owner
	var ctf_show_starting_animation_check := _checkbox_from_host("_ctf_show_starting_animation_check")
	if ctf_show_starting_animation_check != null:
		ctf_show_starting_animation_check.visible = in_ctf_room and is_owner and supports_starting_animation_toggle
		ctf_show_starting_animation_check.disabled = not can_send or action_inflight or not in_ctf_room or not is_owner or not supports_starting_animation_toggle
	var dm_ready_button := _button_from_host("_dm_ready_button")
	if dm_ready_button != null:
		dm_ready_button.visible = in_dm_room and not is_owner
		dm_ready_button.disabled = not can_send or action_inflight or not in_dm_room
	var dm_start_button := _button_from_host("_dm_start_button")
	if dm_start_button != null:
		dm_start_button.visible = in_dm_room and is_owner
		dm_start_button.disabled = not can_send or action_inflight or not in_dm_room or not is_owner or not bool(ctf_room_state.get("can_start", false))
	var dm_add_bots_check := _checkbox_from_host("_dm_add_bots_check")
	if dm_add_bots_check != null:
		dm_add_bots_check.visible = in_dm_room and is_owner
		dm_add_bots_check.disabled = not can_send or action_inflight or not in_dm_room or not is_owner
	var dm_show_starting_animation_check := _checkbox_from_host("_dm_show_starting_animation_check")
	if dm_show_starting_animation_check != null:
		dm_show_starting_animation_check.visible = in_dm_room and is_owner and supports_starting_animation_toggle
		dm_show_starting_animation_check.disabled = not can_send or action_inflight or not in_dm_room or not is_owner or not supports_starting_animation_toggle
	var dm_ruleset_row := _hbox_from_host("_dm_ruleset_row")
	if dm_ruleset_row != null:
		dm_ruleset_row.visible = supports_ruleset_choice
	var dm_target_row := _hbox_from_host("_dm_target_row")
	if dm_target_row != null:
		var selected_ruleset_target := str(ctf_room_state.get("skull_ruleset", "kill_race"))
		if skull_policy == "round_only":
			dm_target_row.visible = supports_skull_options
		else:
			dm_target_row.visible = supports_skull_options and selected_ruleset_target != "timed_kills"
	var dm_time_row := _hbox_from_host("_dm_time_row")
	if dm_time_row != null:
		var selected_ruleset := str(ctf_room_state.get("skull_ruleset", "kill_race"))
		dm_time_row.visible = supports_skull_options and skull_policy != "round_only" and selected_ruleset == "timed_kills"
	var dm_ruleset_option := _option_from_host("_dm_ruleset_option")
	if dm_ruleset_option != null:
		dm_ruleset_option.disabled = not supports_ruleset_choice or not is_owner or not can_send or action_inflight
	var dm_target_option := _option_from_host("_dm_target_option")
	if dm_target_option != null:
		dm_target_option.disabled = not supports_skull_options or not is_owner or not can_send or action_inflight
	var dm_time_option := _option_from_host("_dm_time_option")
	if dm_time_option != null:
		dm_time_option.disabled = not supports_skull_options or not is_owner or not can_send or action_inflight
	var ready_by_peer := ctf_room_state.get("ready_by_peer", {}) as Dictionary
	var local_ready := bool(ready_by_peer.get(local_peer_id, false))
	if ctf_ready_button != null:
		_host.call("_apply_ready_button_state_style", ctf_ready_button, local_ready)
	if dm_ready_button != null:
		_host.call("_apply_ready_button_state_style", dm_ready_button, local_ready)

func show_ctf_room(payload: Dictionary) -> void:
	var ctf_room_box := _host.get("_ctf_room_box") as VBoxContainer
	if ctf_room_box == null:
		return
	_set_waiting_room_shell(true)
	var waiting_room_title_label := _host.get("_waiting_room_title_label") as Label
	var joined_lobby_id := int(_host.get("_joined_lobby_id"))
	if waiting_room_title_label != null:
		waiting_room_title_label.visible = true
		var mode_label := "CTF ROOM" if active_lobby_mode_id(joined_lobby_id) == "ctf" else "TDTH ROOM"
		waiting_room_title_label.text = "%s  |  %s" % [str(payload.get("name", "Team Room")), mode_label]
	ctf_room_box.visible = true
	_host.call("_refresh_lobby_chat_context")
	var ctf_room_title := _host.get("_ctf_room_title") as Label
	if ctf_room_title != null:
		ctf_room_title.visible = false
		var mode_title := "CTF ROOM" if active_lobby_mode_id(joined_lobby_id) == "ctf" else "TDTH ROOM"
		ctf_room_title.text = "%s  |  %s" % [str(payload.get("name", "Team Room")), mode_title]
	var teams := payload.get("teams", {}) as Dictionary
	var ctf_room_red_label := _host.get("_ctf_room_red_label") as Label
	if ctf_room_red_label != null:
		ctf_room_red_label.text = team_text("RED TEAM", teams.get("red", []) as Array)
	var ctf_room_blue_label := _host.get("_ctf_room_blue_label") as Label
	if ctf_room_blue_label != null:
		ctf_room_blue_label.text = team_text("BLUE TEAM", teams.get("blue", []) as Array)
	var ready_by_peer := payload.get("ready_by_peer", {}) as Dictionary
	var local_ready := bool(ready_by_peer.get(int(_host.call("_local_peer_id")), false))
	var ctf_ready_button := _host.get("_ctf_ready_button") as Button
	if ctf_ready_button != null:
		ctf_ready_button.text = "UNREADY" if local_ready else "READY"
		_host.call("_apply_ready_button_state_style", ctf_ready_button, local_ready)
	var ctf_add_bots_check := _host.get("_ctf_add_bots_check") as CheckBox
	if ctf_add_bots_check != null:
		var add_bots := bool(payload.get("add_bots", false))
		if ctf_add_bots_check.button_pressed != add_bots:
			if ctf_add_bots_check.has_method("set_pressed_no_signal"):
				ctf_add_bots_check.call("set_pressed_no_signal", add_bots)
			else:
				ctf_add_bots_check.button_pressed = add_bots
	var ctf_show_starting_animation_check := _host.get("_ctf_show_starting_animation_check") as CheckBox
	if ctf_show_starting_animation_check != null:
		var show_starting_animation := bool(payload.get("show_starting_animation", false))
		var skip_intro := not show_starting_animation
		if ctf_show_starting_animation_check.button_pressed != skip_intro:
			if ctf_show_starting_animation_check.has_method("set_pressed_no_signal"):
				ctf_show_starting_animation_check.call("set_pressed_no_signal", skip_intro)
			else:
				ctf_show_starting_animation_check.button_pressed = skip_intro
	_host.call("_refresh_lobby_selection_summary")
	_host.call("_refresh_lobby_buttons_state")

func hide_ctf_room() -> void:
	var ctf_room_box := _host.get("_ctf_room_box") as VBoxContainer
	if ctf_room_box != null:
		ctf_room_box.visible = false
	_set_waiting_room_shell(false)

func show_dm_room(payload: Dictionary) -> void:
	var dm_room_box := _host.get("_dm_room_box") as VBoxContainer
	if dm_room_box == null:
		return
	_set_waiting_room_shell(true)
	var joined_lobby_id := int(_host.get("_joined_lobby_id"))
	var mode_id := active_lobby_mode_id(joined_lobby_id)
	var map_id := active_lobby_map_id(joined_lobby_id)
	var waiting_room_type := "BR WAITING ROOM" if mode_id == "battle_royale" else "ROUNDS WAITING ROOM" if map_id == "skull_rounds" else "DEATHMATCH WAITING ROOM"
	var waiting_room_title_label := _host.get("_waiting_room_title_label") as Label
	if waiting_room_title_label != null:
		waiting_room_title_label.visible = true
		waiting_room_title_label.text = "%s  |  %s" % [str(payload.get("name", "FFA Room")), waiting_room_type]
	dm_room_box.visible = true
	_host.call("_refresh_lobby_chat_context")
	var dm_room_title := _host.get("_dm_room_title") as Label
	if dm_room_title != null:
		dm_room_title.visible = false
		dm_room_title.text = "%s  |  %s" % [str(payload.get("name", "FFA Room")), waiting_room_type]
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
	var dm_room_members_label := _host.get("_dm_room_members_label") as Label
	if dm_room_members_label != null:
		dm_room_members_label.text = "\n".join(lines)
	var ready_by_peer := payload.get("ready_by_peer", {}) as Dictionary
	var local_ready := bool(ready_by_peer.get(int(_host.call("_local_peer_id")), false))
	var dm_ready_button := _host.get("_dm_ready_button") as Button
	if dm_ready_button != null:
		dm_ready_button.text = "UNREADY" if local_ready else "READY"
		_host.call("_apply_ready_button_state_style", dm_ready_button, local_ready)
	var dm_add_bots_check := _host.get("_dm_add_bots_check") as CheckBox
	if dm_add_bots_check != null:
		var add_bots := bool(payload.get("add_bots", false))
		if dm_add_bots_check.button_pressed != add_bots:
			if dm_add_bots_check.has_method("set_pressed_no_signal"):
				dm_add_bots_check.call("set_pressed_no_signal", add_bots)
			else:
				dm_add_bots_check.button_pressed = add_bots
	var dm_show_starting_animation_check := _host.get("_dm_show_starting_animation_check") as CheckBox
	if dm_show_starting_animation_check != null:
		var show_starting_animation := bool(payload.get("show_starting_animation", false))
		var skip_intro := not show_starting_animation
		if dm_show_starting_animation_check.button_pressed != skip_intro:
			if dm_show_starting_animation_check.has_method("set_pressed_no_signal"):
				dm_show_starting_animation_check.call("set_pressed_no_signal", skip_intro)
			else:
				dm_show_starting_animation_check.button_pressed = skip_intro
	var skull_policy := str(_host.call("_skull_ruleset_policy_for_map", map_id))
	if skull_policy != "none":
		var skull_ruleset := str(payload.get("skull_ruleset", "kill_race")).strip_edges().to_lower()
		if skull_policy == "round_only":
			skull_ruleset = "round_survival"
		elif skull_policy == "deathmatch_only" and skull_ruleset == "round_survival":
			skull_ruleset = "kill_race"
		var skull_target := int(payload.get("skull_target_score", 10))
		var skull_time_limit := int(payload.get("skull_time_limit_sec", 180))
		var dm_ruleset_option := _host.get("_dm_ruleset_option") as OptionButton
		if dm_ruleset_option != null:
			_host.call("_select_option_by_metadata", dm_ruleset_option, skull_ruleset)
		var dm_target_option := _host.get("_dm_target_option") as OptionButton
		if dm_target_option != null:
			_host.call("_select_option_by_metadata", dm_target_option, skull_target)
		var dm_time_option := _host.get("_dm_time_option") as OptionButton
		if dm_time_option != null:
			_host.call("_select_option_by_metadata", dm_time_option, skull_time_limit)
		var dm_target_label := _host.get("_dm_target_label") as Label
		if dm_target_label != null:
			dm_target_label.text = "Choose Rounds:" if skull_ruleset == "round_survival" else "Choose Kills:"
		var dm_target_row := _host.get("_dm_target_row") as HBoxContainer
		if dm_target_row != null:
			dm_target_row.visible = skull_policy == "round_only" or skull_ruleset != "timed_kills"
		var dm_time_row := _host.get("_dm_time_row") as HBoxContainer
		if dm_time_row != null:
			dm_time_row.visible = skull_policy != "round_only" and skull_ruleset == "timed_kills"
	_host.call("_refresh_lobby_selection_summary")
	_host.call("_refresh_lobby_buttons_state")

func hide_dm_room() -> void:
	var dm_room_box := _host.get("_dm_room_box") as VBoxContainer
	if dm_room_box != null:
		dm_room_box.visible = false
	_set_waiting_room_shell(false)

func active_lobby_mode_id(lobby_id: int) -> String:
	var room_entries := _host.get("_room_entries") as Array
	var map_flow_service: Variant = _host.get("_map_flow_service")
	for entry in room_entries:
		if not (entry is Dictionary):
			continue
		var data := entry as Dictionary
		if int(data.get("id", 0)) != lobby_id:
			continue
		return str(map_flow_service.call("normalize_mode_id", str(data.get("mode_id", "deathmatch"))))
	var ctf_room_state := _host.get("_ctf_room_state") as Dictionary
	if not ctf_room_state.is_empty() and int(ctf_room_state.get("lobby_id", 0)) == lobby_id:
		return str(map_flow_service.call("normalize_mode_id", str(ctf_room_state.get("mode_id", "deathmatch"))))
	return str(map_flow_service.call("normalize_mode_id", str(_host.get("_selected_mode_id"))))

func active_lobby_map_id(lobby_id: int) -> String:
	var room_entries := _host.get("_room_entries") as Array
	var ctf_room_state := _host.get("_ctf_room_state") as Dictionary
	var map_flow_service: Variant = _host.get("_map_flow_service")
	var map_catalog: Variant = _host.get("_map_catalog")
	for entry in room_entries:
		if not (entry is Dictionary):
			continue
		var data := entry as Dictionary
		if int(data.get("id", 0)) != lobby_id:
			continue
		return str(map_flow_service.call("normalize_map_id", map_catalog, str(data.get("map_id", ""))))
	if not ctf_room_state.is_empty() and int(ctf_room_state.get("lobby_id", 0)) == lobby_id:
		return str(map_flow_service.call("normalize_map_id", map_catalog, str(ctf_room_state.get("map_id", ""))))
	return str(_host.get("_selected_map_id"))

func supports_starting_animation_testing_toggle() -> bool:
	var ctf_room_state := _host.get("_ctf_room_state") as Dictionary
	return not ctf_room_state.is_empty()

func is_free_for_all_mode_id(mode_id: String) -> bool:
	var map_flow_service: Variant = _host.get("_map_flow_service")
	var normalized := str(map_flow_service.call("normalize_mode_id", mode_id))
	return normalized == "deathmatch" or normalized == "battle_royale"

func is_team_mode_id(mode_id: String) -> bool:
	var map_flow_service: Variant = _host.get("_map_flow_service")
	var normalized := str(map_flow_service.call("normalize_mode_id", mode_id))
	return normalized == "ctf" or normalized == "tdth"

func local_team_id() -> int:
	var ctf_room_state := _host.get("_ctf_room_state") as Dictionary
	if ctf_room_state.is_empty():
		return -1
	var team_by_peer := ctf_room_state.get("team_by_peer", {}) as Dictionary
	return int(team_by_peer.get(int(_host.call("_local_peer_id")), -1))

func team_text(title: String, members: Array) -> String:
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

func _set_waiting_room_shell(waiting_room_visible: bool) -> void:
	var header_title := _label_from_host("_header_title")
	if header_title != null:
		header_title.visible = not waiting_room_visible
	var rooms_title_label := _label_from_host("_rooms_title_label")
	if rooms_title_label != null:
		rooms_title_label.visible = not waiting_room_visible
	var status_label := _label_from_host("_status_label")
	if status_label != null:
		status_label.visible = not waiting_room_visible
	var selection_label := _label_from_host("_selection_label")
	if selection_label != null:
		selection_label.visible = not waiting_room_visible
	_host.call("_set_rooms_list_visible", not waiting_room_visible)
	var preset_row := _hbox_from_host("_preset_row")
	if preset_row != null:
		preset_row.visible = not waiting_room_visible
	var mode_row := _hbox_from_host("_mode_row")
	if mode_row != null:
		mode_row.visible = not waiting_room_visible
	var waiting_room_title_label := _label_from_host("_waiting_room_title_label")
	if waiting_room_title_label != null and not waiting_room_visible:
		waiting_room_title_label.visible = false

func _button_from_host(key: String) -> Button:
	return _object_from_host(key) as Button

func _checkbox_from_host(key: String) -> CheckBox:
	return _object_from_host(key) as CheckBox

func _hbox_from_host(key: String) -> HBoxContainer:
	return _object_from_host(key) as HBoxContainer

func _label_from_host(key: String) -> Label:
	return _object_from_host(key) as Label

func _option_from_host(key: String) -> OptionButton:
	return _object_from_host(key) as OptionButton

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
