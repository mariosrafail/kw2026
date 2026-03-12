extends "res://scripts/app/runtime/runtime_ctf_logic.gd"

func _server_respawn_player(peer_id: int, player: NetPlayer) -> void:
	var death_position := player.global_position if player != null else Vector2.ZERO
	if ctf_match_controller != null:
		ctf_match_controller.drop_flag_for_peer(peer_id, death_position)
		_sync_ctf_flag_to_clients()
	if _is_target_dummy_peer(peer_id):
		var bot_controller := _bot_controller_for_peer(peer_id)
		if bot_controller != null:
			bot_controller.respawn_player(player)
		return
	combat_flow_service.server_respawn_player(peer_id, player)

func _is_target_dummy_peer(peer_id: int) -> bool:
	for controller in bot_controllers:
		if controller != null and controller.is_bot_peer(peer_id):
			return true
	return false

func _bot_controller_for_peer(peer_id: int) -> TargetDummyBotController:
	for controller in bot_controllers:
		if controller != null and controller.is_bot_peer(peer_id):
			return controller
	return null

func _broadcast_target_dummy_spawn(bot_peer_id: int, bot_name: String, spawn_position: Vector2) -> void:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	var recipients: Array = []
	var self_peer_id := multiplayer.get_unique_id()
	if self_peer_id > 0:
		recipients.append(self_peer_id)
	for member_value in multiplayer.get_peers():
		var member_id := int(member_value)
		if member_id <= 0:
			continue
		if recipients.has(member_id):
			continue
		recipients.append(member_id)
	for member_value in recipients:
		var member_id := int(member_value)
		if member_id <= 0:
			continue
		_send_spawn_player_rpc(member_id, bot_peer_id, spawn_position, bot_name)

func _server_ensure_bots_if_needed() -> void:
	if role != Role.SERVER:
		return
	if _uses_lobby_scene_flow():
		return
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	var anchor_player: NetPlayer = null
	for peer_value in players.keys():
		var peer_id := int(peer_value)
		if _is_target_dummy_peer(peer_id):
			continue
		anchor_player = players.get(peer_id, null) as NetPlayer
		if anchor_player != null:
			break
	if anchor_player == null:
		return
	var lobby_id := _peer_lobby(anchor_player.peer_id)
	if _ctf_enabled():
		_assign_ctf_teams(lobby_id)
		var planned_teams := _planned_ctf_team_assignments(lobby_id)
		_append_log("CTF bot fill: lobby_id=%d human_count=%d planned=%s" % [
			lobby_id,
			_human_participant_count(lobby_id),
			str(planned_teams)
		])
		for index in range(bot_controllers.size()):
			var controller := bot_controllers[index]
			if controller == null:
				continue
			controller.set_lobby_id(lobby_id)
			var should_exist := planned_teams.has(controller.peer_id())
			if should_exist and not players.has(controller.peer_id()):
				_append_log("CTF bot spawn: peer_id=%d team=%d" % [controller.peer_id(), int(planned_teams.get(controller.peer_id(), -1))])
				controller.ensure_spawned(PLAYER_SCENE, anchor_player.global_position)
			elif not should_exist and players.has(controller.peer_id()):
				_server_remove_player(controller.peer_id(), [])
			if should_exist:
				var spawn_position := _spawn_position_for_peer(controller.peer_id())
				if spawn_position != Vector2.ZERO:
					var previous_spawn := controller.get_spawn_position()
					controller.set_spawn_position(spawn_position)
					var bot_player := players.get(controller.peer_id(), null) as NetPlayer
					if bot_player != null and (previous_spawn == Vector2.ZERO or previous_spawn.distance_squared_to(spawn_position) > 1.0):
						controller.setup_spawned_player(bot_player, spawn_position, false)
						bot_player.force_respawn(spawn_position)
		_configure_ctf_bot_targets(lobby_id)
		_assign_ctf_teams(lobby_id)
		if ctf_match_controller != null:
			ctf_match_controller.server_tick(true, 0.0)
		return
	if target_dummy_bot_controller == null:
		return
	target_dummy_bot_controller.set_lobby_id(lobby_id)
	if not players.has(target_dummy_bot_controller.peer_id()):
		target_dummy_bot_controller.ensure_spawned(PLAYER_SCENE, anchor_player.global_position)

func _server_tick_target_dummy_bot(delta: float) -> void:
	if role != Role.SERVER:
		return
	for controller in bot_controllers:
		if controller == null:
			continue
		if players.has(controller.peer_id()):
			controller.tick(delta)
	if ctf_match_controller != null:
		ctf_match_controller.server_tick(_ctf_enabled(), delta)
		if _ctf_enabled():
			_sync_ctf_flag_to_clients()

func _target_dummy_lobby_id() -> int:
	for controller in bot_controllers:
		if controller != null and controller.get_lobby_id() > 0:
			return controller.get_lobby_id()
	if lobby_service != null:
		for peer_value in players.keys():
			var candidate_peer_id := int(peer_value)
			if _is_target_dummy_peer(candidate_peer_id):
				continue
			var tracked_lobby := lobby_service.get_peer_lobby(candidate_peer_id)
			if tracked_lobby > 0:
				for controller in bot_controllers:
					if controller != null:
						controller.set_lobby_id(tracked_lobby)
				return tracked_lobby
		if client_lobby_id > 0:
			for controller in bot_controllers:
				if controller != null:
					controller.set_lobby_id(client_lobby_id)
			return client_lobby_id
	if not _uses_lobby_scene_flow():
		for controller in bot_controllers:
			if controller != null:
				controller.set_lobby_id(1)
		return 1
	return 0

# Downstream runtime layers override these when they own the non-bot flow.
func _uses_lobby_scene_flow() -> bool:
	return false

func _peer_lobby(_peer_id: int) -> int:
	return 0

func _lobby_members(_lobby_id: int) -> Array:
	return []

func _append_log(_message: String) -> void:
	pass

func _spawn_position_for_peer(_peer_id: int) -> Vector2:
	return Vector2.ZERO

func _server_remove_player(_peer_id: int, _target_peers: Array = []) -> void:
	pass

func _send_spawn_player_rpc(_target_peer_id: int, _peer_id: int, _spawn_position: Vector2, _display_name: String) -> void:
	pass
