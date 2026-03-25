extends "res://scripts/app/runtime_rpc_logic.gd"

const CURSOR_MANAGER_SCRIPT := preload("res://scripts/ui/cursor_manager.gd")
const SKILL_HUD_SCRIPT := preload("res://scripts/ui/skill_hud.gd")
const SKULL_FFA_INTRO_CONTROLLER_SCRIPT := preload("res://scripts/world/skull_ffa_match_intro_controller.gd")
const CURSOR_MANAGER_NAME := "CursorManager"
const FIGHT_SOUNDTRACK_PATH := "res://assets/sounds/soundtrack/fight_soundtrack.MP3"
const FIGHT_SOUNDTRACK_FALLBACK := preload("res://assets/sounds/soundtrack/fight_soundtrack.MP3")
const MENU_STATE_PATH := "user://main_menu_shop_state.json"
const SKULL_FFA_MAP_ID := "skull_ffa"
const SKULL_FFA_MATCH_INTRO_SEC := 13.0

var _client_skill_cd_q_remaining := 0.0
var _client_skill_cd_e_remaining := 0.0
var _client_skill_cd_q_max := 0.0
var _client_skill_cd_e_max := 0.0
var _skill_hud = null
var _fight_music_player: AudioStreamPlayer = null
var _skull_intro = SKULL_FFA_INTRO_CONTROLLER_SCRIPT.new()
var _gameplay_locked_until_msec := 0
var _skull_match_intro_sent := false

const RPC_ROOT_NODE_NAME := "GameRoot"

func _allows_scene_network_bootstrap() -> bool:
	if _uses_lobby_scene_flow():
		return true
	if _has_cmdline_network_boot_override():
		return true
	return OS.has_feature("editor") and dev_auto_login_on_autostart

func _has_cmdline_network_boot_override() -> bool:
	for raw_arg in OS.get_cmdline_user_args():
		var arg := str(raw_arg).strip_edges().to_lower()
		if arg.begins_with(ARG_MODE_PREFIX):
			var mode := arg.substr(ARG_MODE_PREFIX.length())
			if mode == "server" or mode == "client":
				return true
	return false

func _ready() -> void:
	_ensure_rpc_root_node_name()
	_ensure_cursor_manager()
	if scene_file_path != _lobby_scene_path():
		_start_fight_soundtrack()
	randomize()
	_ensure_input_actions()
	_init_services()
	_init_weapons()
	_init_scene_map_context()
	_refresh_spawn_points()
	_configure_services()
	_connect_local_signals()
	_setup_ui_defaults()
	_ensure_skill_hud()
	_configure_skull_intro_controller()

	var startup_defaults := _load_startup_network_defaults()
	port_spin.value = int(startup_defaults.get("port", DEFAULT_PORT))
	host_input.text = str(startup_defaults.get("host", DEFAULT_HOST))
	session_controller.set_connection_defaults(host_input.text.strip_edges())
	var dev_remote_autostart := _should_dev_auto_create_lobby_on_autostart()
	session_controller.disable_editor_localhost_override = dev_remote_autostart
	session_controller.disable_editor_retry_fallback = dev_remote_autostart
	var startup_autostart := true
	var has_cmdline_network_override := _has_cmdline_network_boot_override()
	if _uses_lobby_scene_flow():
		startup_mode = Role.CLIENT
		startup_autostart = true
	else:
		if OS.has_feature("editor") and dev_auto_login_on_autostart:
			startup_mode = Role.CLIENT
			startup_autostart = true
		else:
			startup_mode = Role.SERVER if OS.has_feature("editor") else Role.NONE
			startup_autostart = has_cmdline_network_override
	session_controller.set_startup(startup_mode, startup_autostart)
	session_controller.apply_startup_overrides()
	session_controller.set_connection_defaults(host_input.text.strip_edges())
	startup_mode = session_controller.get_startup_mode()
	if not _uses_lobby_scene_flow() and _allows_scene_network_bootstrap():
		session_controller.apply_editor_localhost_override()
	if _allows_scene_network_bootstrap():
		session_controller.configure_retry_hosts()

	_show_local_ip()
	_append_log("Scene: %s | node=%s | lobby_mode=%s" % [scene_file_path, name, str(enable_lobby_scene_flow)])

	var peer := multiplayer.multiplayer_peer
	var has_resumable_peer := false
	if peer != null and not (peer is OfflineMultiplayerPeer):
		has_resumable_peer = multiplayer.is_server() or peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED
	var is_lobby_scene := scene_file_path == _lobby_scene_path()

	if has_resumable_peer:
		_set_role(Role.SERVER if multiplayer.is_server() else Role.CLIENT)
		_append_log("Detected active peer after scene load. Session resumed.")
		if role == Role.CLIENT:
			if is_lobby_scene:
				_request_lobby_list()
			else:
				_request_spawn_from_server()
		_update_ui_visibility()
		_update_peer_labels()
		_update_buttons()
		_update_ping_label()
		return
	elif peer != null and not (peer is OfflineMultiplayerPeer):
		# Clear stale/disconnected peer object so normal startup/connect flow can proceed.
		session_controller.close_peer()

	session_controller.set_idle_state()
	_append_log("Ready.")
	_append_log("Boot config: mode=%s host=%s port=%d" % [_role_name(startup_mode), host_input.text, int(port_spin.value)])
	if _allows_scene_network_bootstrap():
		session_controller.auto_boot_from_environment()
	else:
		_append_log("Gameplay scene network bootstrap disabled. Using existing session only.")
	if role == Role.SERVER and not _uses_lobby_scene_flow() and multiplayer.is_server() and _should_spawn_local_server_player():
		_server_spawn_peer_if_needed(multiplayer.get_unique_id(), 1)

func _ensure_cursor_manager() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var root := tree.get_root()
	if root == null:
		return
	var existing := root.get_node_or_null(CURSOR_MANAGER_NAME)
	if existing != null:
		if existing.has_method("set_cursor_context"):
			existing.call("set_cursor_context", "game")
		return
	var cm := CURSOR_MANAGER_SCRIPT.new()
	cm.name = CURSOR_MANAGER_NAME
	root.call_deferred("add_child", cm)
	call_deferred("_apply_game_cursor_context")

func _apply_game_cursor_context() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var root := tree.get_root()
	if root == null:
		return
	var cm := root.get_node_or_null(CURSOR_MANAGER_NAME)
	if cm != null and cm.has_method("set_cursor_context"):
		cm.call("set_cursor_context", "game")

func _ensure_rpc_root_node_name() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var root := tree.get_root()
	if root == null:
		return
	if get_parent() != root:
		return
	if name == RPC_ROOT_NODE_NAME:
		return

	var existing := root.get_node_or_null(RPC_ROOT_NODE_NAME)
	if existing != null and existing != self:
		print("[RPC ROOT] Cannot rename %s -> %s; /root already has %s at %s" % [name, RPC_ROOT_NODE_NAME, existing.name, str(existing.get_path())])
		return

	var before := name
	name = RPC_ROOT_NODE_NAME
	var child_names: Array[String] = []
	for child in root.get_children():
		child_names.append(str(child.name))
	print("[RPC ROOT] Renamed scene root %s -> %s (self_path=%s root_children=%s)" % [before, name, str(get_path()), str(child_names)])

func _physics_process(delta: float) -> void:
	if _allows_scene_network_bootstrap():
		session_controller.client_connect_watchdog_tick(delta)

	if role == Role.SERVER and multiplayer.multiplayer_peer != null:
		if not _uses_lobby_scene_flow():
			client_input_controller.local_host_apply_input(delta, damage_boost_enabled, input_states)
		_server_ensure_bots_if_needed()
		_maybe_server_begin_skull_match_intro()
		_server_tick_target_dummy_bot(delta)
		snapshot_accumulator = combat_flow_service.server_simulate(delta, snapshot_accumulator)
		combat_flow_service.server_tick_projectiles(delta)
		if dropped_mag_service != null:
			dropped_mag_service.server_tick(delta)

	if role == Role.CLIENT and multiplayer.multiplayer_peer != null:
		client_input_controller.client_predict_local_player(delta, damage_boost_enabled)
		client_input_controller.client_send_input(delta, last_ping_ms, damage_boost_enabled)
		_client_ping_tick(delta)
		combat_flow_service.client_tick_projectiles(delta)
		_client_tick_skill_cooldowns_hud(delta)

	if ctf_match_controller != null:
		ctf_match_controller.visual_tick(_ctf_objective_enabled())

	if multiplayer.multiplayer_peer != null:
		if _skull_intro != null and _skull_intro.has_method("is_active") and _skull_intro.call("is_active") == true:
			_skull_intro.call("visual_tick", delta)
		else:
			client_input_controller.follow_local_player_camera(delta)

func _ensure_skill_hud() -> void:
	if cooldown_label != null:
		cooldown_label.visible = false
	if cooldown_q_label != null:
		cooldown_q_label.visible = false
	if cooldown_e_label != null:
		cooldown_e_label.visible = false
	var hud_layer := get_node_or_null("ClientHud") as CanvasLayer
	if hud_layer == null:
		return
	var existing := hud_layer.get_node_or_null("SkillHud")
	if existing != null and existing.has_method("set_character_id") and existing.has_method("update_cooldowns"):
		_skill_hud = existing
		return
	if existing != null:
		existing.queue_free()
	_skill_hud = SKILL_HUD_SCRIPT.new()
	_skill_hud.name = "SkillHud"
	hud_layer.add_child(_skill_hud)

func _client_tick_skill_cooldowns_hud(delta: float) -> void:
	if ui_controller == null:
		return
	var local_peer_id := multiplayer.get_unique_id() if multiplayer != null and multiplayer.multiplayer_peer != null else 0
	if local_peer_id <= 0 or not players.has(local_peer_id):
		_update_skill_cooldowns_hud(0.0, 0.0)
		if _skill_hud != null:
			_skill_hud.visible = false
		return

	_client_skill_cd_q_remaining = maxf(0.0, _client_skill_cd_q_remaining - delta)
	_client_skill_cd_e_remaining = maxf(0.0, _client_skill_cd_e_remaining - delta)
	_update_skill_cooldowns_hud(_client_skill_cd_q_remaining, _client_skill_cd_e_remaining)
	var local_player := players.get(local_peer_id, null) as NetPlayer
	if local_player != null and local_player.has_method("set_skill_cooldown_bars"):
		local_player.call("set_skill_cooldown_bars", 1.0, 1.0, false)
	if _skill_hud != null:
		_skill_hud.visible = role == Role.CLIENT and _is_local_player_spawned()
		_skill_hud.set_character_id(_warrior_id_for_peer(local_peer_id))
		if local_player != null and local_player.has_method("get_torso_dominant_color"):
			var torso_color_value: Variant = local_player.call("get_torso_dominant_color")
			if torso_color_value is Color:
				_skill_hud.set_tint(torso_color_value as Color)
		_skill_hud.update_cooldowns(
			_client_skill_cd_q_remaining,
			_client_skill_cd_q_max,
			_client_skill_cd_e_remaining,
			_client_skill_cd_e_max
		)

func _begin_client_skill_cooldown(skill_number: int) -> void:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	var local_peer_id := multiplayer.get_unique_id()
	if local_peer_id <= 0:
		return
	if combat_flow_service == null:
		return
	if skill_number == 1 and _client_skill_cd_q_remaining > 0.0:
		return
	if skill_number == 2 and _client_skill_cd_e_remaining > 0.0:
		return
	var max_cd := combat_flow_service.skill_cooldown_max_for_peer(local_peer_id, skill_number)
	if max_cd <= 0.0:
		return
	if skill_number == 1:
		_client_skill_cd_q_max = max_cd
		_client_skill_cd_q_remaining = max_cd
	elif skill_number == 2:
		_client_skill_cd_e_max = max_cd
		_client_skill_cd_e_remaining = max_cd

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
		elif key_event.pressed and not key_event.echo and key_event.keycode == KEY_R:
			_try_reload()
		elif key_event.keycode == KEY_TAB:
			scoreboard_visible = key_event.pressed
			_update_ui_visibility()

func _try_cast_skill1() -> void:
	if _is_gameplay_locked():
		return
	if role != Role.CLIENT and role != Role.SERVER:
		return
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	if main_camera == null:
		return
	var target_world := main_camera.get_global_mouse_position()
	_begin_client_skill_cooldown(1)
	if role == Role.SERVER:
		combat_flow_service.server_cast_skill(1, multiplayer.get_unique_id(), target_world)
		return
	_rpc_cast_skill1.rpc_id(1, target_world)

func _try_cast_skill2() -> void:
	if _is_gameplay_locked():
		return
	if role != Role.CLIENT and role != Role.SERVER:
		return
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	if main_camera == null:
		return
	var target_world := main_camera.get_global_mouse_position()
	_begin_client_skill_cooldown(2)
	if role == Role.SERVER:
		combat_flow_service.server_cast_skill(2, multiplayer.get_unique_id(), target_world)
		return
	_rpc_cast_skill2.rpc_id(1, target_world)

func _try_reload() -> void:
	if _is_gameplay_locked():
		return
	if role != Role.CLIENT and role != Role.SERVER:
		return
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	if role == Role.SERVER:
		var local_peer_id := multiplayer.get_unique_id()
		var player := players.get(local_peer_id, null) as NetPlayer
		var weapon_profile := _weapon_profile_for_peer(local_peer_id)
		if player != null and weapon_profile != null:
			combat_flow_service.server_begin_reload(local_peer_id, weapon_profile)
		return
	_rpc_request_reload.rpc_id(1)

func _handle_escape_pressed() -> void:
	if _uses_lobby_scene_flow():
		var is_lobby_scene := scene_file_path == _lobby_scene_path()
		if is_lobby_scene:
			if has_method("_toggle_escape_menu"):
				call("_toggle_escape_menu")
			else:
				get_tree().quit()
		else:
			_begin_escape_return_to_lobby_menu()
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

func _configure_skull_intro_controller() -> void:
	if _skull_intro == null:
		return
	if _skull_intro.has_method("configure"):
		_skull_intro.call("configure", self, main_camera, players)

func _is_skull_ffa_match_scene() -> bool:
	if map_controller != null and map_controller.normalized_map_id() == SKULL_FFA_MAP_ID:
		return true
	return selected_map_id == SKULL_FFA_MAP_ID

func _is_gameplay_locked() -> bool:
	return _gameplay_locked_until_msec > Time.get_ticks_msec()

func _activate_gameplay_lock(duration_sec: float) -> void:
	_gameplay_locked_until_msec = maxi(_gameplay_locked_until_msec, Time.get_ticks_msec() + int(round(duration_sec * 1000.0)))

func _active_match_lobby_id() -> int:
	for peer_value in players.keys():
		var peer_id := int(peer_value)
		if _is_target_dummy_peer(peer_id):
			continue
		var lobby_id := _peer_lobby(peer_id)
		if lobby_id > 0:
			return lobby_id
	return _target_dummy_lobby_id()

func _ordered_skull_intro_peer_ids(lobby_id: int) -> Array:
	var ordered: Array = []
	for peer_value in players.keys():
		var peer_id := int(peer_value)
		if _is_target_dummy_peer(peer_id):
			var controller := _bot_controller_for_peer(peer_id)
			if controller == null or controller.get_lobby_id() != lobby_id:
				continue
		elif _peer_lobby(peer_id) != lobby_id:
			continue
		var player := players.get(peer_id, null) as NetPlayer
		if player == null:
			continue
		ordered.append({
			"peer_id": peer_id,
			"x": player.global_position.x,
			"y": player.global_position.y
		})
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ax := float(a.get("x", 0.0))
		var bx := float(b.get("x", 0.0))
		if absf(ax - bx) > 0.01:
			return ax < bx
		return float(a.get("y", 0.0)) < float(b.get("y", 0.0))
	)
	var out: Array = []
	for entry_value in ordered:
		var entry := entry_value as Dictionary
		out.append(int(entry.get("peer_id", 0)))
	return out

func _maybe_server_begin_skull_match_intro() -> void:
	if not multiplayer.is_server():
		return
	if _skull_match_intro_sent:
		return
	if not _is_skull_ffa_match_scene():
		return
	var lobby_id := _active_match_lobby_id()
	if lobby_id <= 0:
		return
	var human_member_count := _lobby_members(lobby_id).size()
	if human_member_count <= 0:
		return
	var max_players := human_member_count
	var should_add_bots := false
	if lobby_service != null and lobby_service.has_lobby(lobby_id):
		max_players = lobby_service.max_players_for_lobby(lobby_id)
		should_add_bots = lobby_service.add_bots_enabled(lobby_id)
	var expected_total := human_member_count
	if should_add_bots:
		expected_total = max_players
	if _active_match_participant_count(lobby_id) < expected_total:
		return
	var ordered_peer_ids := _ordered_skull_intro_peer_ids(lobby_id)
	if ordered_peer_ids.is_empty():
		return
	_skull_match_intro_sent = true
	_activate_gameplay_lock(SKULL_FFA_MATCH_INTRO_SEC)
	for member_value in _lobby_members(lobby_id):
		_rpc_skull_match_intro.rpc_id(int(member_value), ordered_peer_ids, SKULL_FFA_MATCH_INTRO_SEC)

@rpc("authority", "reliable")
func _rpc_skull_match_intro(_participant_peer_ids: Array, _duration_sec: float) -> void:
	if multiplayer.is_server() and role != Role.CLIENT:
		return
	if not _is_skull_ffa_match_scene():
		return
	_activate_gameplay_lock(_duration_sec)
	if _skull_intro != null and _skull_intro.has_method("start") and multiplayer != null:
		_skull_intro.call("start", _participant_peer_ids, multiplayer.get_unique_id(), _duration_sec)

func _read_launcher_config_defaults() -> Dictionary:
	var candidate_paths := PackedStringArray()
	var executable_config := OS.get_executable_path().get_base_dir().path_join("launcher_config.json")
	candidate_paths.append(executable_config)
	candidate_paths.append("res://build/release/launcher_config.json")
	candidate_paths.append("res://build/launcher/launcher_config.json")
	candidate_paths.append("res://launcher/launcher_config.json")

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

func _start_fight_soundtrack() -> void:
	_ensure_fight_music_player()
	if _fight_music_player == null:
		return
	if _fight_music_player.stream == null:
		_fight_music_player.stream = _load_fight_soundtrack_stream()
	if _fight_music_player.stream == null:
		return
	var vol_linear := _load_music_volume_linear_from_menu_state()
	_fight_music_player.volume_db = _music_db_from_linear(vol_linear)
	_fight_music_player.stream_paused = false
	_fight_music_player.play(0.0)

func _ensure_fight_music_player() -> void:
	if _fight_music_player != null and is_instance_valid(_fight_music_player):
		return
	var existing := get_node_or_null("FightSoundtrackPlayer") as AudioStreamPlayer
	if existing != null:
		_fight_music_player = existing
	else:
		var p := AudioStreamPlayer.new()
		p.name = "FightSoundtrackPlayer"
		add_child(p)
		_fight_music_player = p
	if _fight_music_player == null:
		return
	_fight_music_player.bus = "Master"
	_fight_music_player.autoplay = false
	_fight_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_fight_music_player.max_polyphony = 1
	if _fight_music_player.stream is AudioStreamWAV:
		(_fight_music_player.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif _fight_music_player.stream is AudioStreamMP3:
		(_fight_music_player.stream as AudioStreamMP3).loop = true

func _load_fight_soundtrack_stream() -> AudioStream:
	var imported := load(FIGHT_SOUNDTRACK_PATH) as AudioStream
	if imported != null:
		if imported is AudioStreamWAV:
			(imported as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		elif imported is AudioStreamMP3:
			(imported as AudioStreamMP3).loop = true
		return imported
	if FileAccess.file_exists(FIGHT_SOUNDTRACK_PATH):
		var data := FileAccess.get_file_as_bytes(FIGHT_SOUNDTRACK_PATH)
		if data.size() > 0:
			var mp3 := AudioStreamMP3.new()
			mp3.data = data
			mp3.loop = true
			return mp3
	var fallback := FIGHT_SOUNDTRACK_FALLBACK.duplicate(true) as AudioStream
	if fallback is AudioStreamMP3:
		(fallback as AudioStreamMP3).loop = true
	elif fallback is AudioStreamWAV:
		(fallback as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return fallback

func _load_music_volume_linear_from_menu_state() -> float:
	if not FileAccess.file_exists(MENU_STATE_PATH):
		return 0.8
	var raw := FileAccess.get_file_as_string(MENU_STATE_PATH)
	if raw.is_empty():
		return 0.8
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return 0.8
	var state := parsed as Dictionary
	return clampf(float(state.get("music_volume", 0.8)), 0.0, 1.0)

func _music_db_from_linear(value: float, base_db: float = 0.0) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	if clamped <= 0.001:
		return -80.0
	return clampf(base_db + linear_to_db(clamped), -80.0, 12.0)
