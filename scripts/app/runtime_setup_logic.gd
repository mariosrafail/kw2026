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

func _init_weapons() -> void:
	weapon_profiles = {
		WEAPON_ID_AK47: AK47_SCRIPT.new(),
		WEAPON_ID_UZI: UZI_SCRIPT.new()
	}
	weapon_shot_sfx_by_id = {
		WEAPON_ID_AK47: AK47_SHOT_SFX,
		WEAPON_ID_UZI: UZI_SHOT_SFX
	}
	weapon_reload_sfx_by_id = {
		WEAPON_ID_AK47: AK47_RELOAD_SFX,
		WEAPON_ID_UZI: UZI_RELOAD_SFX
	}
	var startup_weapon_id := default_selected_weapon_id
	var startup_character_id := default_selected_character_id
	if lobby_service != null:
		startup_weapon_id = lobby_service.get_local_selected_weapon(default_selected_weapon_id)
		startup_character_id = lobby_service.get_local_selected_character(default_selected_character_id)
	selected_weapon_id = _normalize_weapon_id(startup_weapon_id)
	selected_character_id = _normalize_character_id(startup_character_id)
	if lobby_service != null:
		lobby_service.set_local_selected_weapon(selected_weapon_id)
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

func _configure_services() -> void:
	projectile_system.configure(projectiles_root, PROJECTILE_SCENE, Callable(self, "_player_color"))
	combat_effects.configure(projectiles_root, map_front_sprite, SPLASH_HIT_SFX, DEATH_HIT_SFX, BULLET_TOUCH_SFX)

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
			"send_play_death_sfx": Callable(self, "_send_play_death_sfx_rpc")
		},
		{
			"player_history_ms": PLAYER_HISTORY_MS
		}
	)

	combat_flow_service.configure(
		{
			"players": players,
			"input_states": input_states,
			"fire_cooldowns": fire_cooldowns,
			"ammo_by_peer": ammo_by_peer,
			"reload_remaining_by_peer": reload_remaining_by_peer,
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
			"send_player_ammo": Callable(self, "_send_player_ammo_rpc"),
			"send_reload_sfx": Callable(self, "_send_reload_sfx_rpc"),
			"send_spawn_projectile": Callable(self, "_send_spawn_projectile_rpc"),
			"send_spawn_blood_particles": Callable(self, "_send_spawn_blood_particles_rpc"),
			"send_spawn_surface_particles": Callable(self, "_send_spawn_surface_particles_rpc"),
			"send_projectile_impact": Callable(self, "_send_projectile_impact_rpc"),
			"send_despawn_projectile": Callable(self, "_send_despawn_projectile_rpc"),
			"broadcast_player_state": Callable(self, "_server_broadcast_player_state"),
			"send_spawn_outrage_bomb": Callable(self, "_send_spawn_outrage_bomb_rpc"),
			"send_spawn_erebus_immunity": Callable(self, "_send_spawn_erebus_immunity_rpc"),
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
			"weapon_visual_for_id": Callable(self, "_weapon_visual_for_id")
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

func _ensure_action_with_mouse_button(action: StringName, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing_event in InputMap.action_get_events(action):
		var mouse_event := existing_event as InputEventMouseButton
		if mouse_event != null and mouse_event.button_index == button:
			return
	var new_mouse_event := InputEventMouseButton.new()
	new_mouse_event.button_index = button
	InputMap.action_add_event(action, new_mouse_event)
