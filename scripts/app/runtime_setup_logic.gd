extends "res://scripts/app/runtime_session_logic.gd"

func _init_services() -> void:
	map_catalog = MAP_CATALOG_SCRIPT.new()
	map_flow_service = MAP_FLOW_SERVICE_SCRIPT.new()
	spawn_flow_service = SPAWN_FLOW_SERVICE_SCRIPT.new()
	lobby_service = LOBBY_SERVICE_SCRIPT.new(LOBBY_CONFIG_SCRIPT.new())
	lobby_flow_controller = LOBBY_FLOW_CONTROLLER_SCRIPT.new()
	session_controller = SESSION_CONTROLLER_SCRIPT.new()
	connect_retry = CONNECT_RETRY_SCRIPT.new()
	ui_controller = UI_CONTROLLER_SCRIPT.new()
	spawn_identity = SPAWN_IDENTITY_SCRIPT.new()
	player_replication = PLAYER_REPLICATION_SCRIPT.new()
	projectile_system = PROJECTILE_SYSTEM_SCRIPT.new()
	hit_damage_resolver = HIT_DAMAGE_RESOLVER_SCRIPT.new()
	combat_flow_service = COMBAT_FLOW_SERVICE_SCRIPT.new()
	client_rpc_flow_service = CLIENT_RPC_FLOW_SERVICE_SCRIPT.new()
	client_input_controller = CLIENT_INPUT_CONTROLLER_SCRIPT.new()
	combat_effects = COMBAT_EFFECTS_SCRIPT.new()
	camera_shake = CAMERA_SHAKE_SCRIPT.new()
	dropped_mag_service = DROPPED_MAG_SERVICE_SCRIPT.new()
	target_dummy_bot_controller = TARGET_DUMMY_BOT_CONTROLLER_SCRIPT.new()
	bot_controllers = [
		target_dummy_bot_controller,
		TARGET_DUMMY_BOT_CONTROLLER_SCRIPT.new(),
		TARGET_DUMMY_BOT_CONTROLLER_SCRIPT.new()
	]
	ctf_match_controller = CTF_MATCH_CONTROLLER_SCRIPT.new()
	weapon_ui = WEAPON_UI_SCRIPT.new()

func _init_weapons() -> void:
	weapon_profiles = {
		WEAPON_ID_AK47: AK47_SCRIPT.new(),
		WEAPON_ID_GRENADE: GRENADE_SCRIPT.new(),
		WEAPON_ID_KAR: KAR_SCRIPT.new(),
		WEAPON_ID_SHOTGUN: SHOTGUN_SCRIPT.new(),
		WEAPON_ID_UZI: UZI_SCRIPT.new()
	}
	weapon_shot_sfx_by_id = {
		WEAPON_ID_AK47: AK47_SHOT_SFX,
		WEAPON_ID_GRENADE: GRENADE_SHOT_SFX,
		WEAPON_ID_KAR: KAR_SHOT_SFX,
		WEAPON_ID_SHOTGUN: SHOTGUN_SHOT_SFX,
		WEAPON_ID_UZI: UZI_SHOT_SFX
	}
	weapon_reload_sfx_by_id = {
		WEAPON_ID_AK47: AK47_RELOAD_SFX,
		WEAPON_ID_GRENADE: GRENADE_RELOAD_SFX,
		WEAPON_ID_KAR: KAR_RELOAD_SFX,
		WEAPON_ID_SHOTGUN: SHOTGUN_RELOAD_SFX,
		WEAPON_ID_UZI: UZI_RELOAD_SFX
	}
	weapon_impact_sfx_by_id = {
		WEAPON_ID_AK47: BULLET_TOUCH_SFX,
		WEAPON_ID_GRENADE: GRENADE_IMPACT_SFX,
		WEAPON_ID_KAR: BULLET_TOUCH_SFX,
		WEAPON_ID_SHOTGUN: BULLET_TOUCH_SFX,
		WEAPON_ID_UZI: BULLET_TOUCH_SFX
	}
	var startup_weapon_id := default_selected_weapon_id
	var startup_character_id := default_selected_character_id
	if lobby_service != null:
		startup_weapon_id = lobby_service.get_local_selected_weapon(default_selected_weapon_id)
		startup_character_id = lobby_service.get_local_selected_character(default_selected_character_id)
	selected_weapon_id = _normalize_weapon_id(startup_weapon_id)
	if lobby_service != null:
		selected_weapon_skin = int(lobby_service.get_local_selected_weapon_skin(selected_weapon_id, 0))
	selected_character_id = _normalize_character_id(startup_character_id)
	if lobby_service != null:
		lobby_service.set_local_selected_weapon(selected_weapon_id)
		lobby_service.set_local_selected_weapon_skin(selected_weapon_id, selected_weapon_skin)
		lobby_service.set_local_selected_character(selected_character_id)

func _init_scene_map_context() -> void:
	var scene_map_id := map_catalog.map_id_for_scene_path(scene_file_path)
	if map_controller != null:
		scene_map_id = map_controller.normalized_map_id()
	if _uses_lobby_scene_flow():
		selected_map_id = map_flow_service.normalize_map_id(map_catalog, default_selected_map_id)
	else:
		selected_map_id = map_flow_service.normalize_map_id(map_catalog, scene_map_id)
	client_target_map_id = selected_map_id
	var pending_mode := str(ProjectSettings.get_setting("kw/pending_game_mode", "")).strip_edges().to_lower()
	var resolved_from_lobby := false
	if multiplayer != null and multiplayer.multiplayer_peer != null and lobby_service != null:
		var local_peer_id := multiplayer.get_unique_id()
		var local_lobby_id := lobby_service.get_peer_lobby(local_peer_id)
		if local_lobby_id > 0:
			var lobby := lobby_service.get_lobby_data(local_lobby_id)
			selected_game_mode = map_flow_service.select_mode_for_map(
				map_catalog,
				selected_map_id,
				str(lobby.get("mode_id", selected_game_mode))
			)
			resolved_from_lobby = true
	if not resolved_from_lobby and not pending_mode.is_empty():
		selected_game_mode = map_flow_service.select_mode_for_map(
			map_catalog,
			selected_map_id,
			pending_mode
		)
		ProjectSettings.set_setting("kw/pending_game_mode", "")
	selected_game_mode = map_flow_service.select_mode_for_map(map_catalog, selected_map_id, selected_game_mode)
	client_target_game_mode = selected_game_mode
	print("[MATCH MODE] scene=%s selected_map=%s pending_mode=%s resolved_mode=%s lobby_scene=%s" % [
		scene_file_path,
		selected_map_id,
		pending_mode,
		selected_game_mode,
		str(_uses_lobby_scene_flow())
	])

	spawn_flow_service.apply_map_controller_bounds(
		map_controller,
		main_camera,
		map_front_sprite,
		{
			"top": border_top,
			"bottom": border_bottom,
			"left": border_left,
			"right": border_right,
			"top_shape": border_top_shape,
			"bottom_shape": border_bottom_shape,
			"left_shape": border_left_shape,
			"right_shape": border_right_shape
		}
	)

func _refresh_spawn_points() -> void:
	spawn_points = spawn_flow_service.configured_spawn_points(map_controller, map_catalog, scene_file_path)
	spawn_identity.spawn_points = spawn_points.duplicate()
	for controller in bot_controllers:
		if controller != null:
			controller.update_spawn_points(spawn_points)

func _configure_services() -> void:
	projectile_system.configure(projectiles_root, PROJECTILE_SCENE, Callable(self, "_projectile_color"))
	combat_effects.configure(projectiles_root, map_front_sprite, SPLASH_HIT_SFX, DEATH_HIT_SFX, BULLET_TOUCH_SFX, EXPLOSION_EFFECT_TEXTURE, HIT_EFFECT_TEXTURE)

	spawn_identity.configure(
		{
			"spawn_slots": spawn_slots,
			"players": players,
			"player_display_names": player_display_names
		},
		{
			"get_peer_lobby": Callable(self, "_peer_lobby")
		},
		{
			"spawn_points": spawn_points
		}
	)

	player_replication.configure(
		{
			"players": players,
			"input_states": input_states,
			"fire_cooldowns": fire_cooldowns,
			"player_history": player_history,
			"input_rate_window_start_ms": input_rate_window_start_ms,
			"input_rate_counts": input_rate_counts,
			"spawn_slots": spawn_slots,
			"player_stats": player_stats,
			"player_display_names": player_display_names
		},
		{
			"get_peer_lobby": Callable(self, "_peer_lobby"),
			"get_lobby_members": Callable(self, "_lobby_members"),
			"ensure_player_display_name": Callable(self, "_ensure_player_display_name"),
			"spawn_position_for_peer": Callable(self, "_spawn_position_for_peer"),
			"random_spawn_position": Callable(self, "_random_spawn_position"),
			"default_input_state": Callable(self, "_default_input_state"),
			"spawn_player_local": Callable(self, "_spawn_player_local"),
			"send_spawn_player": Callable(self, "_send_spawn_player_rpc"),
			"send_despawn_player_all": Callable(self, "_broadcast_despawn_player_rpc"),
			"send_despawn_player_to_peer": Callable(self, "_send_despawn_player_rpc_to_peer"),
			"send_sync_player_state": Callable(self, "_send_sync_player_state_rpc"),
			"send_sync_player_stats": Callable(self, "_send_sync_player_stats_rpc"),
			"append_log": Callable(self, "_append_log")
		},
		{
			"max_input_packets_per_sec": MAX_INPUT_PACKETS_PER_SEC,
			"max_reported_rtt_ms": MAX_REPORTED_RTT_MS,
			"local_reconcile_snap_distance": LOCAL_RECONCILE_SNAP_DISTANCE,
			"local_reconcile_vertical_snap_distance": LOCAL_RECONCILE_VERTICAL_SNAP_DISTANCE,
			"local_reconcile_pos_blend": LOCAL_RECONCILE_POS_BLEND,
			"local_reconcile_vel_blend": LOCAL_RECONCILE_VEL_BLEND
		}
	)

	hit_damage_resolver.configure(
		{
			"players": players,
			"player_history": player_history
		},
		{
			"get_peer_lobby": Callable(self, "_peer_lobby"),
			"get_lobby_members": Callable(self, "_lobby_members"),
			"register_kill_death": Callable(self, "_server_register_kill_death"),
			"server_respawn_player": Callable(self, "_server_respawn_player"),
			"server_broadcast_player_state": Callable(self, "_server_broadcast_player_state"),
			"get_projectile": Callable(projectile_system, "get_projectile"),
			"get_projectile_damage": Callable(projectile_system, "get_projectile_damage"),
			"play_death_sfx_local": Callable(self, "_play_death_sfx_local"),
			"send_play_death_sfx": Callable(self, "_send_play_death_sfx_rpc"),
			"spawn_blood_particles_local": Callable(combat_effects, "spawn_blood_particles"),
			"send_spawn_blood_particles": Callable(self, "_send_spawn_blood_particles_rpc"),
			"can_damage_peer": Callable(self, "_can_damage_peer")
		},
		{
			"player_history_ms": PLAYER_HISTORY_MS
		}
	)

	dropped_mag_service.configure(
		{
			"world_root": world_root,
			"players": players,
			"multiplayer": multiplayer
		},
		{
			"normalize_weapon_id": Callable(self, "_normalize_weapon_id"),
			"get_peer_lobby": Callable(self, "_peer_lobby"),
			"get_lobby_members": Callable(self, "_lobby_members"),
			"resolve_mag_color": Callable(self, "_projectile_color"),
			"send_spawn_dropped_mag": Callable(self, "_send_spawn_dropped_mag_rpc"),
			"send_sync_dropped_mag": Callable(self, "_send_sync_dropped_mag_rpc"),
			"send_despawn_dropped_mag": Callable(self, "_send_despawn_dropped_mag_rpc")
		},
		{
			"ak47_mag_spawn_delay_sec": 0.16,
			"grenade_mag_spawn_delay_sec": 0.28
		}
	)

	for index in range(bot_controllers.size()):
		var controller := bot_controllers[index]
		if controller == null:
			continue
		controller.configure(
			{
				"players": players,
				"input_states": input_states,
				"peer_weapon_ids": peer_weapon_ids,
				"peer_weapon_skin_indices_by_peer": peer_weapon_skin_indices_by_peer,
				"players_root": players_root,
				"multiplayer": multiplayer,
				"spawn_flow_service": spawn_flow_service
			},
			{
				"get_world_2d": Callable(self, "_get_world_2d_ref"),
				"random_spawn_position": Callable(self, "_random_spawn_position"),
				"weapon_visual_for_peer": Callable(self, "_weapon_visual_for_peer"),
				"weapon_shot_sfx": Callable(self, "_weapon_shot_sfx"),
				"weapon_reload_sfx": Callable(self, "_weapon_reload_sfx"),
				"broadcast_spawn": Callable(self, "_broadcast_target_dummy_spawn"),
				"record_player_history": Callable(combat_flow_service, "record_player_history"),
				"get_peer_lobby": Callable(self, "_peer_lobby"),
				"default_input_state": Callable(self, "_default_input_state"),
				"server_cast_skill": Callable(combat_flow_service, "server_cast_skill"),
				"can_cast_skill": Callable(combat_flow_service, "can_cast_skill_for_peer"),
				"get_play_bounds": Callable(self, "_play_bounds_rect"),
				"get_ground_tiles": Callable(self, "_ground_tiles_ref"),
				"is_enemy_target": Callable(self, "_is_enemy_target"),
				"movement_goal_position": Callable(self, "_bot_movement_goal_position")
			},
			{
				"spawn_points": spawn_points,
				"bot_peer_id": -1001 - index,
				"bot_name": "BOT %d" % (index + 1),
				"bot_color": Color(1.0, 0.48 + 0.12 * float(index), 0.48, 1.0),
				"spawn_point_index": mini(index + 1, 3)
			}
		)

	combat_flow_service.configure(
		{
			"players": players,
			"input_states": input_states,
			"fire_cooldowns": fire_cooldowns,
			"ammo_by_peer": ammo_by_peer,
			"reload_remaining_by_peer": reload_remaining_by_peer,
			"pending_reload_delay_by_peer": pending_reload_delay_by_peer,
			"peer_weapon_ids": peer_weapon_ids,
			"multiplayer": multiplayer,
			"projectile_system": projectile_system,
			"combat_effects": combat_effects,
			"camera_shake": camera_shake,
			"hit_damage_resolver": hit_damage_resolver,
			"player_replication": player_replication
		},
		{
			"get_world_2d": Callable(self, "_get_world_2d_ref"),
			"get_peer_lobby": Callable(self, "_peer_lobby"),
			"get_lobby_members": Callable(self, "_lobby_members"),
			"weapon_profile_for_id": Callable(self, "_weapon_profile_for_id"),
			"weapon_profile_for_peer": Callable(self, "_weapon_profile_for_peer"),
			"weapon_id_for_peer": Callable(self, "_weapon_id_for_peer"),
			"weapon_shot_sfx": Callable(self, "_weapon_shot_sfx"),
			"weapon_reload_sfx": Callable(self, "_weapon_reload_sfx"),
			"schedule_reload_mag_spawn": Callable(dropped_mag_service, "schedule_reload_mag_spawn"),
			"clear_reload_mag_spawn": Callable(dropped_mag_service, "clear_pending_reload_mag_spawn"),
			"send_player_ammo": Callable(self, "_send_player_ammo_rpc"),
			"send_reload_sfx": Callable(self, "_send_reload_sfx_rpc"),
			"send_spawn_projectile": Callable(self, "_send_spawn_projectile_rpc"),
			"send_spawn_blood_particles": Callable(self, "_send_spawn_blood_particles_rpc"),
			"send_spawn_surface_particles": Callable(self, "_send_spawn_surface_particles_rpc"),
			"send_projectile_impact": Callable(self, "_send_projectile_impact_rpc"),
			"send_despawn_projectile": Callable(self, "_send_despawn_projectile_rpc"),
			"broadcast_player_state": Callable(self, "_server_broadcast_player_state"),
			"send_skill_cast": Callable(self, "_send_skill_cast_rpc"),
			"warrior_id_for_peer": Callable(self, "_warrior_id_for_peer")
		},
		{
			"max_reported_rtt_ms": MAX_REPORTED_RTT_MS,
			"snapshot_rate": SNAPSHOT_RATE,
			"weapon_id_ak47": WEAPON_ID_AK47,
			"max_input_stale_ms": MAX_INPUT_STALE_MS
		}
	)

	client_rpc_flow_service.configure(
		{
			"players": players,
			"multiplayer": multiplayer,
			"projectile_system": projectile_system,
			"combat_effects": combat_effects,
			"camera_shake": camera_shake,
			"ammo_by_peer": ammo_by_peer,
			"reload_remaining_by_peer": reload_remaining_by_peer
		},
		{
			"weapon_profile_for_id": Callable(self, "_weapon_profile_for_id"),
			"weapon_shot_sfx": Callable(self, "_weapon_shot_sfx"),
			"weapon_reload_sfx": Callable(self, "_weapon_reload_sfx"),
			"weapon_impact_sfx": Callable(self, "_weapon_impact_sfx"),
			"weapon_visual_for_id": Callable(self, "_weapon_visual_for_id"),
			"weapon_visual_for_peer": Callable(self, "_weapon_visual_for_peer")
		}
	)

	client_input_controller.configure(
		{
			"players": players,
			"multiplayer": multiplayer,
			"main_camera": main_camera,
			"camera_shake": camera_shake
		},
		{
			"submit_input": Callable(self, "_send_input_rpc")
		},
		{
			"input_send_rate": INPUT_SEND_RATE
		}
	)

	ui_controller.configure(
		{
			"start_server_button": start_server_button,
			"stop_button": stop_button,
			"connect_button": connect_button,
			"disconnect_button": disconnect_button,
			"port_spin": port_spin,
			"host_input": host_input,
			"peers_label": peers_label,
			"ping_label": ping_label,
			"kd_label": kd_label,
			"cooldown_label": cooldown_label,
			"cooldown_q_label": cooldown_q_label,
			"cooldown_e_label": cooldown_e_label,
			"scoreboard_label": scoreboard_label,
			"ui_panel": ui_panel,
			"world_root": world_root,
			"lobby_panel": lobby_panel,
			"lobby_list": lobby_list,
			"lobby_status_label": lobby_status_label,
			"lobby_create_button": lobby_create_button,
			"lobby_join_button": lobby_join_button,
			"lobby_refresh_button": lobby_refresh_button,
			"lobby_leave_button": lobby_leave_button,
			"lobby_room_bg": lobby_room_bg,
			"lobby_room_title": lobby_room_title
		}
	)
	ui_controller.set_ctf_room_callbacks(
		Callable(self, "_request_ctf_team").bind(0),
		Callable(self, "_request_ctf_team").bind(1),
		Callable(self, "_request_ctf_start_match")
	)

	if ctf_match_controller != null:
		ctf_match_controller.configure(
			{
				"players": players,
				"player_display_names": player_display_names,
				"peer_team_by_peer": peer_team_by_peer,
				"world_root": world_root
			},
			{
				"get_play_bounds": Callable(self, "_play_bounds_rect"),
				"on_score_changed": Callable(self, "_update_score_labels")
			}
		)

	session_controller.configure(
		{
			"multiplayer": multiplayer,
			"status_label": status_label,
			"host_input": host_input,
			"port_spin": port_spin,
			"connect_retry": connect_retry
		},
		{
			"get_role": Callable(self, "_get_role"),
			"set_role": Callable(self, "_set_role"),
			"reset_runtime_state": Callable(self, "_reset_runtime_state"),
			"reset_ping_state": Callable(self, "_reset_ping_state"),
			"reset_spawn_request_state": Callable(self, "_reset_spawn_request_state"),
			"set_client_lobby_id": Callable(self, "_set_client_lobby_id"),
			"set_lobby_auto_action_inflight": Callable(self, "_set_lobby_auto_action_inflight"),
			"clear_lobby_list": Callable(self, "_clear_lobby_list"),
			"set_lobby_status": Callable(self, "_set_lobby_status"),
			"update_peer_labels": Callable(self, "_update_peer_labels"),
			"update_buttons": Callable(self, "_update_buttons"),
			"update_ping_label": Callable(self, "_update_ping_label"),
			"update_ui_visibility": Callable(self, "_update_ui_visibility"),
			"append_log": Callable(self, "_append_log"),
			"request_lobby_list": Callable(self, "_request_lobby_list")
		},
		{
			"default_host": DEFAULT_HOST,
			"max_clients": MAX_CLIENTS,
			"role_none": Role.NONE,
			"role_server": Role.SERVER,
			"role_client": Role.CLIENT,
			"arg_mode_prefix": ARG_MODE_PREFIX,
			"arg_host_prefix": ARG_HOST_PREFIX,
			"arg_port_prefix": ARG_PORT_PREFIX,
			"arg_no_autostart": ARG_NO_AUTOSTART,
			"is_editor": OS.has_feature("editor"),
			"first_private_ipv4": _first_private_ipv4(),
			"lobby_scene_mode": _uses_lobby_scene_flow()
		}
	)

	lobby_flow_controller.configure(
		{
			"multiplayer": multiplayer,
			"lobby_service": lobby_service,
			"players": players
		},
		{
			"server_remove_player": Callable(self, "_server_remove_player"),
			"server_sync_player_stats": Callable(self, "_server_sync_player_stats"),
			"server_spawn_peer_if_needed": Callable(self, "_server_spawn_peer_if_needed"),
			"server_send_lobby_list_to_peer": Callable(self, "_server_send_lobby_list_to_peer"),
			"server_broadcast_lobby_list": Callable(self, "_server_broadcast_lobby_list"),
			"server_broadcast_lobby_room_state": Callable(self, "_server_broadcast_lobby_room_state"),
			"send_lobby_action_result": Callable(self, "_server_send_lobby_action_result"),
			"refresh_lobby_list_ui": Callable(self, "_refresh_lobby_list_ui"),
			"update_ui_visibility": Callable(self, "_update_ui_visibility"),
			"set_client_lobby_id": Callable(self, "_set_client_lobby_id"),
			"set_lobby_auto_action_inflight": Callable(self, "_set_lobby_auto_action_inflight"),
			"set_lobby_status": Callable(self, "_set_lobby_status"),
			"append_log": Callable(self, "_append_log"),
			"is_client_connected": Callable(self, "_is_client_connected"),
			"request_lobby_list": Callable(self, "_request_lobby_list")
		}
	)


func _ensure_input_actions() -> void:
	_ensure_action_with_keys("move_left", [KEY_A, KEY_LEFT])
	_ensure_action_with_keys("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action_with_keys("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_ensure_action_with_mouse_button("shoot", MOUSE_BUTTON_LEFT)

func _ensure_action_with_keys(action: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if not InputMap.action_get_events(action).is_empty():
		return
	for keycode in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action, event)

func _ensure_action_with_mouse_button(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing_event in InputMap.action_get_events(action):
		var mouse_event := existing_event as InputEventMouseButton
		if mouse_event != null and mouse_event.button_index == button:
			return
	var new_mouse_event := InputEventMouseButton.new()
	new_mouse_event.button_index = button
	InputMap.action_add_event(action, new_mouse_event)
