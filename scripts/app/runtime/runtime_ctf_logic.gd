extends "res://scripts/app/runtime_shared.gd"

func _refresh_ctf_room_ui() -> void:
	if ui_controller == null:
		return
	if not _uses_lobby_scene_flow():
		ui_controller.hide_ctf_room()
		return
	if _is_local_player_spawned():
		ui_controller.hide_ctf_room()
		return
	if client_lobby_id <= 0:
		ui_controller.hide_ctf_room()
		return
	if active_lobby_room_state.is_empty():
		ui_controller.hide_ctf_room()
		return
	var mode_id := map_flow_service.normalize_mode_id(str(active_lobby_room_state.get("mode_id", GAME_MODE_DEATHMATCH)))
	if not _is_team_mode_id(mode_id) or bool(active_lobby_room_state.get("started", false)):
		ui_controller.hide_ctf_room()
		return
	var local_peer_id := multiplayer.get_unique_id() if multiplayer != null and multiplayer.multiplayer_peer != null else 0
	ui_controller.show_ctf_room(active_lobby_room_state, local_peer_id)

func _server_send_lobby_room_state_to_peer(peer_id: int, lobby_id: int) -> void:
	if lobby_service == null or peer_id <= 0 or lobby_id <= 0:
		return
	var payload := lobby_service.pack_lobby_room_state(lobby_id)
	print("[CTF ROOM][SERVER] send_room_state peer_id=%d lobby_id=%d payload=%s" % [peer_id, lobby_id, str(payload)])
	if peer_id == multiplayer.get_unique_id():
		_rpc_lobby_room_state(payload)
		return
	_rpc_lobby_room_state.rpc_id(peer_id, payload)

func _server_broadcast_lobby_room_state(lobby_id: int) -> void:
	if lobby_service == null or lobby_id <= 0:
		return
	var recipients := _lobby_members(lobby_id)
	if multiplayer != null and multiplayer.multiplayer_peer != null:
		var self_peer_id := multiplayer.get_unique_id()
		if self_peer_id > 0 and not recipients.has(self_peer_id):
			recipients.append(self_peer_id)
	for peer_value in recipients:
		_server_send_lobby_room_state_to_peer(int(peer_value), lobby_id)

func _request_ctf_team(team_id: int) -> void:
	if not _is_client_connected() or client_lobby_id <= 0:
		return
	_rpc_lobby_set_team.rpc_id(1, team_id)

func _request_ctf_start_match() -> void:
	if not _is_client_connected() or client_lobby_id <= 0:
		return
	var mode_id := map_flow_service.normalize_mode_id(str(active_lobby_room_state.get("mode_id", GAME_MODE_DEATHMATCH)))
	_set_lobby_status("Starting %s match..." % ("CTF" if mode_id == GAME_MODE_CTF else "TDTH"))
	_rpc_lobby_start_match.rpc_id(1)

func _server_start_ctf_lobby_match(peer_id: int) -> void:
	if lobby_service == null:
		return
	var lobby_id := _peer_lobby(peer_id)
	if lobby_id <= 0 or not lobby_service.is_team_lobby(lobby_id):
		_server_send_lobby_action_result(peer_id, false, "Team lobby not found.", lobby_id, _lobby_map_id(lobby_id))
		return
	if lobby_service.owner_peer_for_lobby(lobby_id) != peer_id:
		_server_send_lobby_action_result(peer_id, false, "Only the host can start.", lobby_id, _lobby_map_id(lobby_id))
		return
	if _uses_lobby_scene_flow():
		var can_start := lobby_service.can_start_ctf_lobby(lobby_id) if lobby_service.is_ctf_lobby(lobby_id) else lobby_service.can_start_tdth_lobby(lobby_id)
		if not can_start:
			_server_send_lobby_action_result(peer_id, false, "All other players must be READY.", lobby_id, _lobby_map_id(lobby_id))
			return
	_prepare_ctf_match_team_assignments(lobby_id)
	_append_log("TEAM start: lobby_id=%d teams=%s" % [lobby_id, str(lobby_service.team_assignments_for_lobby(lobby_id))])
	lobby_service.set_lobby_started(lobby_id, true)
	_server_broadcast_lobby_room_state(lobby_id)
	_server_switch_lobby_to_map_scene(lobby_id, _lobby_map_id(lobby_id), peer_id)

func _ctf_enabled() -> bool:
	return _is_team_mode_id(_active_game_mode())

func _ctf_objective_enabled() -> bool:
	return _active_game_mode() == GAME_MODE_CTF

func _human_participant_count(lobby_id: int) -> int:
	var count := 0
	for member_value in _lobby_members(lobby_id):
		var member_id := int(member_value)
		if member_id > 0:
			count += 1
	return count

func _active_match_participant_count(lobby_id: int) -> int:
	var count := _human_participant_count(lobby_id)
	for controller in bot_controllers:
		if controller != null and controller.get_lobby_id() == lobby_id and players.has(controller.peer_id()):
			count += 1
	return count

func _assign_ctf_teams(lobby_id: int) -> void:
	if lobby_id <= 0 or ctf_match_controller == null:
		return
	var planned := _planned_ctf_team_assignments(lobby_id)
	if planned.is_empty():
		var participants: Array[int] = []
		for member_value in _lobby_members(lobby_id):
			var member_id := int(member_value)
			if member_id > 0 and not participants.has(member_id):
				participants.append(member_id)
		for controller in bot_controllers:
			if controller == null:
				continue
			if controller.get_lobby_id() != lobby_id:
				continue
			if players.has(controller.peer_id()) and not participants.has(controller.peer_id()):
				participants.append(controller.peer_id())
		ctf_match_controller.assign_teams(participants)
		return
	peer_team_by_peer.clear()
	for peer_value in planned.keys():
		peer_team_by_peer[int(peer_value)] = int(planned.get(peer_value, 0))
	ctf_match_controller.assign_teams([])

func _planned_ctf_team_assignments(lobby_id: int) -> Dictionary:
	if lobby_service == null or lobby_id <= 0:
		return {}
	var planned := lobby_service.team_assignments_for_lobby(lobby_id)
	if planned.is_empty():
		return {}
	var out: Dictionary = {}
	for peer_value in planned.keys():
		out[int(peer_value)] = int(planned.get(peer_value, -1))
	return out

func _ctf_room_holds_in_lobby(lobby_id: int) -> bool:
	if lobby_service == null or lobby_id <= 0:
		return false
	return lobby_service.is_team_lobby(lobby_id) and not lobby_service.lobby_started(lobby_id)

func _deathmatch_room_holds_in_lobby(lobby_id: int) -> bool:
	if lobby_service == null or lobby_id <= 0:
		return false
	return (
		(lobby_service.is_deathmatch_lobby(lobby_id) or lobby_service.is_battle_royale_lobby(lobby_id))
		and not lobby_service.lobby_started(lobby_id)
	)

func _prepare_ctf_match_team_assignments(lobby_id: int) -> void:
	if lobby_service == null or lobby_id <= 0 or not lobby_service.is_team_lobby(lobby_id):
		return
	lobby_service.clear_non_member_teams(lobby_id)
	if not lobby_service.add_bots_enabled(lobby_id):
		lobby_service.clear_bot_team_assignments(lobby_id)
		return
	var teams := lobby_service.team_assignments_for_lobby(lobby_id)
	var human_members := _lobby_members(lobby_id)
	var red_count := 0
	var blue_count := 0
	for peer_value in teams.keys():
		var peer_id := int(peer_value)
		if peer_id < 0:
			continue
		var team_id := int(teams.get(peer_id, -1))
		if team_id == 1:
			blue_count += 1
		else:
			red_count += 1
	var bot_assignments: Dictionary = {}
	if human_members.size() == 1:
		var solo_peer_id := int(human_members[0])
		var solo_team_id := int(teams.get(solo_peer_id, 0))
		var enemy_team_id := 1 if solo_team_id == 0 else 0
		if bot_controllers.size() > 0 and bot_controllers[0] != null:
			bot_assignments[(bot_controllers[0] as TargetDummyBotController).peer_id()] = solo_team_id
		if bot_controllers.size() > 1 and bot_controllers[1] != null:
			bot_assignments[(bot_controllers[1] as TargetDummyBotController).peer_id()] = enemy_team_id
		if bot_controllers.size() > 2 and bot_controllers[2] != null:
			bot_assignments[(bot_controllers[2] as TargetDummyBotController).peer_id()] = enemy_team_id
	else:
		for controller in bot_controllers:
			if controller == null:
				continue
			var team_id := -1
			if red_count < 2:
				team_id = 0
				red_count += 1
			elif blue_count < 2:
				team_id = 1
				blue_count += 1
			if team_id < 0:
				break
			bot_assignments[controller.peer_id()] = team_id
	lobby_service.set_bot_team_assignments(lobby_id, bot_assignments)

func _configure_ctf_bot_targets(lobby_id: int) -> void:
	if lobby_id <= 0:
		return
	var human_members := _lobby_members(lobby_id)
	if human_members.size() != 1:
		for controller in bot_controllers:
			if controller != null:
				controller.set_preferred_target_peer_id(0)
		return
	var solo_peer_id := int(human_members[0])
	var ally_bot_peer_id := 0
	var enemy_bot_peer_ids: Array[int] = []
	for controller in bot_controllers:
		if controller == null:
			continue
		var bot_peer_id := controller.peer_id()
		if _team_for_peer(bot_peer_id) == _team_for_peer(solo_peer_id):
			ally_bot_peer_id = bot_peer_id
		else:
			enemy_bot_peer_ids.append(bot_peer_id)
	enemy_bot_peer_ids.sort()
	for controller in bot_controllers:
		if controller == null:
			continue
		var bot_peer_id := controller.peer_id()
		if bot_peer_id == ally_bot_peer_id:
			if not enemy_bot_peer_ids.is_empty():
				controller.set_preferred_target_peer_id(enemy_bot_peer_ids[0])
			else:
				controller.set_preferred_target_peer_id(0)
			continue
		if not enemy_bot_peer_ids.has(bot_peer_id):
			controller.set_preferred_target_peer_id(0)
			continue
		var enemy_index := enemy_bot_peer_ids.find(bot_peer_id)
		if enemy_index == 0:
			controller.set_preferred_target_peer_id(solo_peer_id)
		elif ally_bot_peer_id != 0:
			controller.set_preferred_target_peer_id(ally_bot_peer_id)
		else:
			controller.set_preferred_target_peer_id(solo_peer_id)

func _team_for_peer(peer_id: int) -> int:
	if ctf_match_controller != null:
		return ctf_match_controller.team_for_peer(peer_id)
	return int(peer_team_by_peer.get(peer_id, -1))

func _bot_movement_goal_position(peer_id: int) -> Vector2:
	if not _ctf_objective_enabled() or ctf_match_controller == null:
		return Vector2.ZERO
	var team_id := _team_for_peer(peer_id)
	if team_id < 0:
		return Vector2.ZERO
	# Priority 1: carrying the flag → deliver it to the capture goal.
	if ctf_match_controller.is_peer_carrying_flag(peer_id):
		return ctf_match_controller.capture_goal_for_team(team_id)
	# Priority 2: flag is loose (nobody carrying it) → navigate to pick it up.
	if ctf_flag_carrier_peer_id <= 0 and ctf_flag_world_position != Vector2.ZERO:
		return ctf_flag_world_position
	return Vector2.ZERO

func _is_enemy_target(attacker_peer_id: int, target_peer_id: int) -> bool:
	if attacker_peer_id == target_peer_id:
		return false
	if not _ctf_enabled():
		return true
	if ctf_match_controller != null:
		return ctf_match_controller.is_enemy_target(attacker_peer_id, target_peer_id)
	return _team_for_peer(attacker_peer_id) != _team_for_peer(target_peer_id)

func _can_damage_peer(attacker_peer_id: int, target_peer_id: int) -> bool:
	return _is_enemy_target(attacker_peer_id, target_peer_id)

func _player_world_position_or_flag(peer_id: int) -> Vector2:
	var player := players.get(peer_id, null) as NetPlayer
	if player != null:
		return player.global_position
	return Vector2.ZERO

func _sync_ctf_flag_to_clients() -> void:
	if not _ctf_objective_enabled():
		return
	if multiplayer == null or multiplayer.multiplayer_peer == null or ctf_match_controller == null:
		return
	ctf_flag_carrier_peer_id = ctf_match_controller.flag_carrier_peer_id()
	ctf_flag_world_position = ctf_match_controller.flag_world_position()
	var red_score := ctf_match_controller.team_score(0)
	var blue_score := ctf_match_controller.team_score(1)
	for peer_value in multiplayer.get_peers():
		_rpc_sync_ctf_flag.rpc_id(int(peer_value), ctf_flag_carrier_peer_id, ctf_flag_world_position, red_score, blue_score)

# Downstream runtime layers override these. They exist here so this split base
# script parses cleanly without depending on child-only methods during load.
func _uses_lobby_scene_flow() -> bool:
	return false

func _is_local_player_spawned() -> bool:
	return false

func _is_client_connected() -> bool:
	return false

func _peer_lobby(_peer_id: int) -> int:
	return 0

func _server_send_lobby_action_result(_peer_id: int, _success: bool, _message: String, _active_lobby_id: int, _map_id: String = "") -> void:
	pass

func _lobby_map_id(_lobby_id: int) -> String:
	return ""

func _server_switch_lobby_to_map_scene(_lobby_id: int, _map_id: String, _trigger_peer_id: int = 0) -> void:
	pass

func _active_game_mode() -> String:
	return GAME_MODE_DEATHMATCH

func _lobby_members(_lobby_id: int) -> Array:
	return []

func _append_log(_message: String) -> void:
	pass

func _is_team_mode_id(mode_id: String) -> bool:
	var normalized := map_flow_service.normalize_mode_id(mode_id)
	return normalized == GAME_MODE_CTF or normalized == GAME_MODE_TDTH

func _set_lobby_status(_text: String) -> void:
	pass
