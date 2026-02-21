extends "res://scripts/app/runtime_rpc_logic.gd"

func _ready() -> void:
	randomize()
	_ensure_input_actions()
	_init_services()
	_init_weapons()
	_init_scene_map_context()
	_refresh_spawn_points()
	_configure_services()
	_connect_local_signals()
	_setup_ui_defaults()

	var startup_defaults := _load_startup_network_defaults()
	port_spin.value = int(startup_defaults.get("port", DEFAULT_PORT))
	host_input.text = str(startup_defaults.get("host", DEFAULT_HOST))
	session_controller.set_connection_defaults(host_input.text.strip_edges())
	var startup_autostart := true
	if _uses_lobby_scene_flow():
		startup_mode = Role.CLIENT
		startup_autostart = true
	else:
		startup_mode = Role.SERVER if OS.has_feature("editor") else Role.CLIENT
	session_controller.set_startup(startup_mode, startup_autostart)
	session_controller.apply_startup_overrides()
	session_controller.set_connection_defaults(host_input.text.strip_edges())
	startup_mode = session_controller.get_startup_mode()
	if not _uses_lobby_scene_flow():
		session_controller.apply_editor_localhost_override()
	session_controller.configure_retry_hosts()

	_show_local_ip()
	_append_log("Scene: %s | node=%s | lobby_mode=%s" % [scene_file_path, name, str(enable_lobby_scene_flow)])

	var peer := multiplayer.multiplayer_peer
	var has_resumable_peer := false
	if peer != null and not (peer is OfflineMultiplayerPeer):
		has_resumable_peer = multiplayer.is_server() or peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED

	if has_resumable_peer and not _uses_lobby_scene_flow():
		_reset_runtime_state()
		_set_role(Role.SERVER if multiplayer.is_server() else Role.CLIENT)
		_append_log("Detected active peer after scene load. Session resumed.")
		if role == Role.CLIENT and not _uses_lobby_scene_flow():
			_request_spawn_from_server()
		_update_ui_visibility()
		_update_peer_labels()
		_update_buttons()
		_update_ping_label()
		return
	elif has_resumable_peer and _uses_lobby_scene_flow():
		_append_log("Lobby startup: clearing stale peer and continuing normal connect flow.")
		session_controller.close_peer()
	elif peer != null and not (peer is OfflineMultiplayerPeer):
		# Clear stale/disconnected peer object so normal startup/connect flow can proceed.
		session_controller.close_peer()

	session_controller.set_idle_state()
	_append_log("Ready.")
	_append_log("Boot config: mode=%s host=%s port=%d" % [_role_name(startup_mode), host_input.text, int(port_spin.value)])
	session_controller.auto_boot_from_environment()

func _physics_process(delta: float) -> void:
	session_controller.client_connect_watchdog_tick(delta)

	if role == Role.SERVER and multiplayer.multiplayer_peer != null:
		snapshot_accumulator = combat_flow_service.server_simulate(delta, snapshot_accumulator)
		combat_flow_service.server_tick_projectiles(delta)

	if role == Role.CLIENT and multiplayer.multiplayer_peer != null:
		client_input_controller.client_predict_local_player(delta, damage_boost_enabled)
		client_input_controller.client_send_input(delta, last_ping_ms, damage_boost_enabled)
		_client_ping_tick(delta)
		combat_flow_service.client_tick_projectiles(delta)

	client_input_controller.follow_local_player_camera(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			_handle_escape_pressed()
		elif key_event.pressed and not key_event.echo and key_event.keycode == KEY_F4:
			_toggle_fullscreen()
		elif key_event.pressed and not key_event.echo and key_event.keycode == KEY_Q:
			_try_cast_skill1()
		elif key_event.pressed and not key_event.echo and key_event.keycode == KEY_E:
			_try_cast_skill2()
		elif key_event.keycode == KEY_TAB:
			scoreboard_visible = key_event.pressed
			_update_ui_visibility()

func _try_cast_skill1() -> void:
	if role != Role.CLIENT:
		return
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	if main_camera == null:
		return
	var target_world := main_camera.get_global_mouse_position()
	_rpc_cast_skill1.rpc_id(1, target_world)

func _try_cast_skill2() -> void:
	if role != Role.CLIENT:
		return
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	if main_camera == null:
		return
	var target_world := main_camera.get_global_mouse_position()
	_rpc_cast_skill2.rpc_id(1, target_world)

func _handle_escape_pressed() -> void:
	if _uses_lobby_scene_flow():
		get_tree().quit()
		return
	_begin_escape_return_to_lobby_menu()

func _toggle_fullscreen() -> void:
	var current_mode := DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _load_startup_network_defaults() -> Dictionary:
	var defaults := {
		"host": DEFAULT_HOST,
		"port": DEFAULT_PORT
	}
	var config_result := _read_launcher_config_defaults()
	if config_result.get("found", false):
		var config_host := str(config_result.get("host", "")).strip_edges()
		var config_port := int(config_result.get("port", DEFAULT_PORT))
		if not config_host.is_empty():
			defaults["host"] = config_host
		if config_port >= 1 and config_port <= 65535:
			defaults["port"] = config_port
		_append_log("Launcher defaults loaded: host=%s port=%d" % [str(defaults["host"]), int(defaults["port"])])
	return defaults

func _read_launcher_config_defaults() -> Dictionary:
	var candidate_paths := PackedStringArray()
	var executable_config := OS.get_executable_path().get_base_dir().path_join("launcher_config.json")
	candidate_paths.append(executable_config)
	candidate_paths.append("res://launcher/launcher_config.json")
	candidate_paths.append("res://build/release/launcher_config.json")
	candidate_paths.append("res://build/launcher/launcher_config.json")

	for path in candidate_paths:
		if not FileAccess.file_exists(path):
			continue
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not (parsed is Dictionary):
			continue
		var payload: Dictionary = parsed as Dictionary
		return {
			"found": true,
			"path": path,
			"host": str(payload.get("default_host", "")).strip_edges(),
			"port": int(payload.get("default_port", DEFAULT_PORT))
		}

	return {"found": false}
