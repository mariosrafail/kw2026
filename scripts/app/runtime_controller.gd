extends "res://scripts/app/runtime_rpc_logic.gd"

const CURSOR_MANAGER_SCRIPT_PATH := "res://scripts/ui/cursor_manager.gd"
const MINIMAP_HUD_SCRIPT_PATH := "res://scripts/ui/minimap/minimap_hud.gd"
const SKILL_HUD_SCRIPT_PATH := "res://scripts/ui/skill_hud.gd"
const SKULL_FFA_INTRO_CONTROLLER_SCRIPT_PATH := "res://scripts/world/skull_ffa_match_intro_controller.gd"
const CURSOR_MANAGER_NAME := "CursorManager"
const FIGHT_SOUNDTRACK_PATH := "res://assets/sounds/soundtrack/fight_soundtrack.MP3"
const FIGHT_SOUNDTRACK_FALLBACK := preload("res://assets/sounds/soundtrack/fight_soundtrack.MP3")
const MENU_STATE_PATH := "user://main_menu_shop_state.json"
const SKULL_FFA_MAP_ID := "skull_ffa"
const SKULL_ROUNDS_MAP_ID := "skull_rounds"
const SKULL_DEATHMATCH_MAP_ID := "skull_deathmatch"
const SKULL_BR_MAP_ID := "skull_br"
const SKULL_ROUNDS_SCENE_PATH := "res://scenes/skull_rounds.tscn"
const SKULL_BR_SCENE_PATH := "res://scenes/skull_br.tscn"
const BATTLE_ROYALE_ZONE_SYNC_INTERVAL_SEC := 0.1
const BATTLE_ROYALE_ZONE_DAMAGE_INTERVAL_SEC := 1.0
const BATTLE_ROYALE_ZONE_DAMAGE := 20
const BATTLE_ROYALE_ZONE_START_DELAY_SEC := 10
const SKULL_RULESET_ROUND_SURVIVAL := "round_survival"
const SKULL_RULESET_KILL_RACE := "kill_race"
const SKULL_RULESET_TIMED_KILLS := "timed_kills"
const PENDING_SKULL_RULESET_SETTING := "kw/pending_skull_ruleset"
const PENDING_SKULL_TARGET_SCORE_SETTING := "kw/pending_skull_target_score"
const PENDING_SKULL_TIME_LIMIT_SEC_SETTING := "kw/pending_skull_time_limit_sec"
const SKULL_RESPAWN_DELAY_SEC := 3.0
const SKULL_ROUND_END_FREEZE_SEC := 2.2
const SKULL_ROUND_RESULT_MESSAGE_PREFIX := "__kw_skull_round_result__|"
const SKULL_MODE_RUNTIME_ROUNDS_SCRIPT := preload("res://scripts/app/runtime/modes/skull_mode_runtime_rounds.gd")
const SKULL_MODE_RUNTIME_BR_SCRIPT := preload("res://scripts/app/runtime/modes/skull_mode_runtime_br.gd")
const SKULL_MODE_RUNTIME_DEATHMATCH_SCRIPT := preload("res://scripts/app/runtime/modes/skull_mode_runtime_deathmatch.gd")
const DEATH_TAUNTS_GREEKLISH := [
	"pe8anes malaka",
	"kurwa",
	"re file ksipna",
	"mpouketo sto kefali",
	"rage quit incoming",
	"ela re noobaki",
	"pali xwma esy",
	"boom ston koura",
	"adios amigo",
	"gg ez re filos"
]
const ROUND_WIN_TAUNTS_GREEKLISH := [
	"nikises malaka",
	"bravo re magka",
	"teleutaio frag diko sou",
	"katharises ton gyro",
	"easy round re file",
	"clutcharas san trelos",
	"pame gia epomeno",
	"auta einai kills",
	"den tous afises anasa",
	"round sto tsepaki sou"
]
var _rt_minimap_hud = null
var _rt_skill_hud = null
var _rt_fight_music_player: AudioStreamPlayer = null
var _rt_skull_intro = null
var _rt_gameplay_locked_until_msec := 0
var _rt_skull_match_intro_sent := false
var _rt_battle_royale_zone_sync_accumulator := 0.0
var _rt_battle_royale_zone_damage_accumulator := 0.0
var _rt_battle_royale_zone_unfreeze_due_msec := 0
var _rt_particles_enabled := true
var _rt_screen_shake_enabled := true
var _rt_particles_listener_bound := false
var _rt_ping_visible := true
var _rt_skull_round_wins_by_peer: Dictionary = {}
var _rt_skull_round_eliminated_by_peer: Dictionary = {}
var _rt_skull_respawn_due_msec_by_peer: Dictionary = {}
var _rt_skull_round_restart_due_msec := 0
var _rt_prev_round_spawn_slots: Dictionary = {}
var _rt_skull_match_locked := false
var _rt_skull_timed_remaining_sec := -1.0
var _rt_skull_time_sync_accumulator := 0.0
var _rt_spectator_target_peer_id := 0
var _rt_spectator_camera_position := Vector2.ZERO
var _rt_local_respawn_countdown_remaining_sec := 0.0
var _rt_local_respawn_countdown_active := false
var _rt_local_respawn_was_dead := false
var _rt_local_death_taunt := ""
var _rt_timer_label: Label = null
var _rt_center_message_label: Label = null
var _rt_winner_return_due_msec := 0
var _rt_winner_screen_active := false
var _rt_center_message_tween: Tween = null
var _rt_timer_label_tween: Tween = null
var _rt_skull_intro_was_active := false
var _rt_priority_center_message_text := ""
var _rt_priority_center_message_until_msec := 0
var _rt_pending_skull_ruleset := ""
var _rt_pending_skull_target_score := -1
var _rt_pending_skull_time_limit_sec := -1
var _rt_skull_round_number := 1
var _rt_round_transition_due_msec := 0
var _rt_round_transition_message := ""
var _rt_skull_mode_rounds = SKULL_MODE_RUNTIME_ROUNDS_SCRIPT.new()
var _rt_skull_mode_br = SKULL_MODE_RUNTIME_BR_SCRIPT.new()
var _rt_skull_mode_deathmatch = SKULL_MODE_RUNTIME_DEATHMATCH_SCRIPT.new()

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
	_capture_pending_skull_match_config()
	_refresh_spawn_points()
	_configure_services()
	_apply_particles_pref_from_menu_state()
	_apply_screen_shake_pref_from_menu_state()
	_connect_local_signals()
	_setup_ui_defaults()
	if ui_controller != null and ui_controller.has_method("set_ping_visible"):
		ui_controller.call("set_ping_visible", _rt_ping_visible)
	_ensure_skill_hud()
	_ensure_minimap_hud()
	_configure_skull_intro_controller()
	_configure_battle_royale_zone_controller()
	_reset_skull_mode_runtime_state()
	_ensure_skull_runtime_hud()
	if multiplayer != null and multiplayer.is_server() and _is_battle_royale_match_scene():
		_schedule_battle_royale_zone_start(BATTLE_ROYALE_ZONE_START_DELAY_SEC)

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
	var cursor_script: GDScript = load(CURSOR_MANAGER_SCRIPT_PATH) as GDScript
	if cursor_script == null:
		return
	var cm: Node = cursor_script.new() as Node
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
	var tab_scoreboard_active := Input.is_action_pressed("show_scoreboard") \
		or Input.is_key_pressed(KEY_TAB) \
		or Input.is_physical_key_pressed(KEY_TAB)
	if scoreboard_visible != tab_scoreboard_active:
		scoreboard_visible = tab_scoreboard_active
		if scoreboard_visible:
			_update_score_labels()
		_update_ui_visibility()
	if Input.is_action_just_pressed("toggle_ping"):
		_rt_ping_visible = not _rt_ping_visible
		if ui_controller != null and ui_controller.has_method("set_ping_visible"):
			ui_controller.call("set_ping_visible", _rt_ping_visible)
		if ui_controller != null and ui_controller.has_method("refresh_ping_visibility"):
			ui_controller.call("refresh_ping_visibility", _is_local_player_spawned(), role == Role.SERVER, role == Role.CLIENT)

	if _allows_scene_network_bootstrap():
		session_controller.client_connect_watchdog_tick(delta)

	if role == Role.SERVER and multiplayer.multiplayer_peer != null:
		if not _uses_lobby_scene_flow():
			client_input_controller.local_host_apply_input(delta, damage_boost_enabled, input_states)
		_server_ensure_bots_if_needed()
		_server_tick_skull_mode(delta)
		_server_tick_battle_royale_zone(delta)
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

	if multiplayer.multiplayer_peer != null and (role == Role.CLIENT or (role == Role.SERVER and not OS.has_feature("dedicated_server"))):
		var intro_active := false
		if _rt_skull_intro != null and _rt_skull_intro.has_method("is_active") and _rt_skull_intro.call("is_active") == true:
			intro_active = true
			_rt_skull_intro.call("visual_tick", delta)
			if _rt_skull_intro != null and _rt_skull_intro.has_method("is_active") and _rt_skull_intro.call("is_active") != true:
				intro_active = false
		elif _should_use_skull_spectator_camera():
			_tick_skull_spectator_camera(delta)
		elif client_input_controller != null:
			client_input_controller.follow_local_player_camera(delta)
		if _rt_skull_intro_was_active and not intro_active and client_input_controller != null and client_input_controller.has_method("snap_camera_to_local_player"):
			client_input_controller.call("snap_camera_to_local_player", true)
		_rt_skull_intro_was_active = intro_active
	_tick_dead_player_visibility()
	_tick_local_dead_visibility()
	_tick_minimap_visibility()
	_tick_skull_runtime_hud(delta)

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
	if existing != null and existing.has_method("set_character_id") and existing.has_method("update_charge"):
		_rt_skill_hud = existing
		return
	if existing != null:
		existing.queue_free()
	var skill_hud_script := load(SKILL_HUD_SCRIPT_PATH)
	if skill_hud_script == null:
		return
	_rt_skill_hud = skill_hud_script.new()
	_rt_skill_hud.name = "SkillHud"
	hud_layer.add_child(_rt_skill_hud)

func _ensure_minimap_hud() -> void:
	var hud_layer := get_node_or_null("ClientHud") as CanvasLayer
	if hud_layer == null:
		return
	var existing := hud_layer.get_node_or_null("MiniMapHud")
	if existing != null and existing.has_method("configure"):
		_rt_minimap_hud = existing
	else:
		if existing != null:
			existing.queue_free()
		var minimap_hud_script := load(MINIMAP_HUD_SCRIPT_PATH)
		if minimap_hud_script == null:
			return
		_rt_minimap_hud = minimap_hud_script.new()
		_rt_minimap_hud.name = "MiniMapHud"
		hud_layer.add_child(_rt_minimap_hud)
	if _rt_minimap_hud != null and _rt_minimap_hud.has_method("configure"):
		_rt_minimap_hud.call(
			"configure",
			get_world_2d(),
			Callable(self, "_minimap_focus_position"),
			Callable(self, "_play_bounds_rect"),
			Callable(self, "_minimap_camera_limits_rect"),
			Callable(self, "_minimap_marker_payload")
		)

func _minimap_focus_position() -> Vector2:
	var local_peer_id := multiplayer.get_unique_id() if multiplayer != null and multiplayer.multiplayer_peer != null else 0
	if local_peer_id > 0:
		var local_player := players.get(local_peer_id, null) as NetPlayer
		if local_player != null:
			return local_player.global_position
	if main_camera != null:
		return main_camera.global_position
	return Vector2.ZERO

func _minimap_marker_payload() -> Array:
	var out: Array = []
	var local_peer_id := multiplayer.get_unique_id() if multiplayer != null and multiplayer.multiplayer_peer != null else 0
	var local_team := _team_for_peer(local_peer_id) if local_peer_id > 0 else -1
	for peer_value in players.keys():
		var peer_id := int(peer_value)
		var player := players.get(peer_id, null) as NetPlayer
		if player == null:
			continue
		var relation := "enemy"
		if peer_id == local_peer_id:
			relation = "self"
		elif _ctf_enabled() and local_peer_id > 0 and _team_for_peer(peer_id) == local_team:
			relation = "ally"
		if relation == "enemy" and not _is_world_position_visible_in_main_camera(player.global_position):
			continue
		out.append({
			"peer_id": peer_id,
			"world_position": player.global_position,
			"relation": relation
		})
	return out

func _minimap_camera_limits_rect() -> Rect2i:
	if main_camera == null:
		return _play_bounds_rect()
	var left := int(main_camera.limit_left)
	var top := int(main_camera.limit_top)
	var right := int(main_camera.limit_right)
	var bottom := int(main_camera.limit_bottom)
	if right <= left or bottom <= top:
		return _play_bounds_rect()
	return Rect2i(left, top, right - left, bottom - top)

func _is_world_position_visible_in_main_camera(world_position: Vector2) -> bool:
	if main_camera == null:
		return true
	var viewport := main_camera.get_viewport()
	if viewport == null:
		return true
	var viewport_size := viewport.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return true
	var safe_zoom := Vector2(maxf(main_camera.zoom.x, 0.0001), maxf(main_camera.zoom.y, 0.0001))
	var half_extents := Vector2(
		viewport_size.x * 0.5 * safe_zoom.x,
		viewport_size.y * 0.5 * safe_zoom.y
	)
	var camera_rect := Rect2(main_camera.global_position - half_extents, half_extents * 2.0).grow(6.0)
	return camera_rect.has_point(world_position)

func _local_player_is_dead_or_waiting_respawn() -> bool:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return false
	var local_peer_id := multiplayer.get_unique_id()
	if local_peer_id <= 0:
		return false
	var local_player := players.get(local_peer_id, null) as NetPlayer
	if local_player == null:
		return false
	if local_player.get_health() <= 0:
		return true
	if local_player.has_method("is_respawn_hidden"):
		return bool(local_player.call("is_respawn_hidden"))
	return false

func _tick_local_dead_visibility() -> void:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	var local_peer_id := multiplayer.get_unique_id()
	if local_peer_id <= 0:
		return
	var local_player := players.get(local_peer_id, null) as NetPlayer
	if local_player == null:
		return
	var should_hide := _local_player_is_dead_or_waiting_respawn()
	if local_player.has_method("set_forced_hidden"):
		local_player.call("set_forced_hidden", "local_dead_view", should_hide)

func _tick_dead_player_visibility() -> void:
	for player_value in players.values():
		var player := player_value as NetPlayer
		if player == null:
			continue
		var dead_hidden := player.get_health() <= 0
		if player.has_method("set_forced_hidden"):
			player.call("set_forced_hidden", "dead_state", dead_hidden)
		if player.has_method("set_forced_sfx_suppressed"):
			player.call("set_forced_sfx_suppressed", "dead_state", dead_hidden)

func _tick_minimap_visibility() -> void:
	if _rt_minimap_hud == null or not is_instance_valid(_rt_minimap_hud):
		return
	var should_show := _is_local_player_spawned() and not _local_player_is_dead_or_waiting_respawn()
	_rt_minimap_hud.visible = should_show

func _client_tick_skill_cooldowns_hud(delta: float) -> void:
	if ui_controller == null:
		return
	var local_peer_id := multiplayer.get_unique_id() if multiplayer != null and multiplayer.multiplayer_peer != null else 0
	if local_peer_id <= 0 or not players.has(local_peer_id):
		if _rt_skill_hud != null:
			_rt_skill_hud.visible = false
		return

	var local_player := players.get(local_peer_id, null) as NetPlayer
	if local_player != null and local_player.has_method("set_skill_cooldown_bars"):
		local_player.call("set_skill_cooldown_bars", 0.0, 0.0, false)
	if _rt_skill_hud != null:
		_rt_skill_hud.visible = role == Role.CLIENT and _is_local_player_spawned()
		_rt_skill_hud.set_character_id(_warrior_id_for_peer(local_peer_id))
		_rt_skill_hud.set_tint(_authoritative_skill_color_for_peer(local_peer_id))
		var current_points := 0
		if combat_flow_service != null:
			current_points = combat_flow_service.skill_charge_points_for_peer(local_peer_id, 2)
		var required_points := maxi(0, int(skill_charge_required_by_peer.get(local_peer_id, 0)))
		if required_points <= 0 and combat_flow_service != null:
			required_points = combat_flow_service.skill_charge_required_for_peer(local_peer_id, 2)
		_rt_skill_hud.update_charge(current_points, required_points)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed and _should_use_skull_spectator_camera():
			if mouse_button.button_index == MOUSE_BUTTON_LEFT:
				_cycle_skull_spectator_target(-1)
			elif mouse_button.button_index == MOUSE_BUTTON_RIGHT:
				_cycle_skull_spectator_target(1)
			if mouse_button.button_index == MOUSE_BUTTON_LEFT or mouse_button.button_index == MOUSE_BUTTON_RIGHT:
				get_viewport().set_input_as_handled()
				return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			_handle_escape_pressed()
		elif key_event.pressed and not key_event.echo and key_event.keycode == KEY_F4:
			_toggle_fullscreen()
		elif key_event.pressed and not key_event.echo and key_event.keycode == KEY_E:
			_try_cast_skill2()
		elif key_event.pressed and not key_event.echo and key_event.keycode == KEY_T:
			_try_debug_fill_skill2_charge()
		elif key_event.pressed and not key_event.echo and key_event.keycode == KEY_R:
			_try_reload()

func _try_cast_skill1() -> void:
	return

func _try_cast_skill2() -> void:
	if _is_gameplay_locked():
		return
	if role != Role.CLIENT and role != Role.SERVER:
		return
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	if main_camera == null:
		return
	var local_peer_id := multiplayer.get_unique_id()
	if local_peer_id <= 0 or combat_flow_service == null:
		return
	if not combat_flow_service.can_cast_skill_for_peer(local_peer_id, 2):
		return
	var target_world := main_camera.get_global_mouse_position()
	if role == Role.SERVER:
		combat_flow_service.server_cast_skill(2, local_peer_id, target_world)
		return
	_rpc_cast_skill2.rpc_id(1, target_world)

func _try_debug_fill_skill2_charge() -> void:
	if role != Role.CLIENT and role != Role.SERVER:
		return
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	if combat_flow_service == null:
		return
	var local_peer_id := multiplayer.get_unique_id()
	if local_peer_id <= 0:
		return
	if role == Role.SERVER:
		combat_flow_service.server_fill_skill_charge_for_peer(local_peer_id, 2)
		return
	_rpc_debug_fill_skill2_charge.rpc_id(1)

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
	if _rt_skull_intro == null:
		var intro_script := load(SKULL_FFA_INTRO_CONTROLLER_SCRIPT_PATH)
		if intro_script != null:
			_rt_skull_intro = intro_script.new()
	if _rt_skull_intro == null:
		return
	if _rt_skull_intro.has_method("configure"):
		_rt_skull_intro.call("configure", self, main_camera, players)

func _configure_battle_royale_zone_controller() -> void:
	if battle_royale_zone_controller == null:
		return
	if battle_royale_zone_controller.has_method("reset_match"):
		battle_royale_zone_controller.call("reset_match")

func _is_skull_intro_match_scene() -> bool:
	if map_controller != null:
		var map_id := map_controller.normalized_map_id()
		if map_id == SKULL_FFA_MAP_ID or map_id == SKULL_ROUNDS_MAP_ID or map_id == SKULL_DEATHMATCH_MAP_ID or map_id == SKULL_BR_MAP_ID:
			return true
	if selected_map_id == SKULL_FFA_MAP_ID or selected_map_id == SKULL_ROUNDS_MAP_ID or selected_map_id == SKULL_DEATHMATCH_MAP_ID or selected_map_id == SKULL_BR_MAP_ID:
		return true
	return false

func _is_skull_ffa_match_scene() -> bool:
	var map_id := selected_map_id
	if map_controller != null:
		map_id = map_controller.normalized_map_id()
	return map_id == SKULL_FFA_MAP_ID \
		or map_id == SKULL_ROUNDS_MAP_ID \
		or map_id == SKULL_DEATHMATCH_MAP_ID \
		or map_id == SKULL_BR_MAP_ID

func _is_battle_royale_match_scene() -> bool:
	if map_controller != null and map_controller.normalized_map_id() == SKULL_BR_MAP_ID:
		return true
	if selected_map_id == SKULL_BR_MAP_ID:
		return true
	return _active_game_mode() == GAME_MODE_BATTLE_ROYALE

func _is_gameplay_locked() -> bool:
	return _rt_gameplay_locked_until_msec > Time.get_ticks_msec()

func _activate_gameplay_lock(duration_sec: float) -> void:
	_rt_gameplay_locked_until_msec = maxi(_rt_gameplay_locked_until_msec, Time.get_ticks_msec() + int(round(duration_sec * 1000.0)))

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
		var entry: Dictionary = entry_value as Dictionary
		out.append(int(entry.get("peer_id", 0)))
	return out

func _server_tick_battle_royale_zone(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if not _is_battle_royale_match_scene():
		return
	if battle_royale_zone_controller == null:
		return
	if _is_battle_royale_zone_frozen():
		return
	if battle_royale_zone_controller.has_method("server_tick"):
		battle_royale_zone_controller.call("server_tick", delta)
	_rt_battle_royale_zone_sync_accumulator += delta
	_rt_battle_royale_zone_damage_accumulator += delta
	if _rt_battle_royale_zone_sync_accumulator >= BATTLE_ROYALE_ZONE_SYNC_INTERVAL_SEC:
		_rt_battle_royale_zone_sync_accumulator = 0.0
		_server_broadcast_battle_royale_zone_state()
	if _rt_battle_royale_zone_damage_accumulator >= BATTLE_ROYALE_ZONE_DAMAGE_INTERVAL_SEC:
		_rt_battle_royale_zone_damage_accumulator = 0.0
		_server_apply_battle_royale_zone_damage()

func _server_broadcast_battle_royale_zone_state() -> void:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	if battle_royale_zone_controller == null:
		return
	var center: Vector2 = Vector2(1552.0, 1552.0)
	if battle_royale_zone_controller.has_method("current_center"):
		center = battle_royale_zone_controller.call("current_center") as Vector2
	var radius: float = 0.0
	if battle_royale_zone_controller.has_method("current_radius"):
		radius = float(battle_royale_zone_controller.call("current_radius"))
	var lobby_id := _active_match_lobby_id()
	var recipients := _lobby_members(lobby_id)
	if recipients.is_empty():
		recipients = multiplayer.get_peers()
	for member_value in recipients:
		var member_id := int(member_value)
		if member_id <= 0 or member_id == multiplayer.get_unique_id():
			continue
		_rpc_sync_battle_royale_zone.rpc_id(member_id, center, radius)

func _server_apply_battle_royale_zone_damage() -> void:
	if _rt_skull_match_locked or _rt_skull_round_restart_due_msec > 0:
		return
	if battle_royale_zone_controller == null or hit_damage_resolver == null:
		return
	var center: Vector2 = Vector2(1552.0, 1552.0)
	if battle_royale_zone_controller.has_method("current_center"):
		center = battle_royale_zone_controller.call("current_center") as Vector2
	for peer_value in players.keys():
		var peer_id := int(peer_value)
		var player := players.get(peer_id, null) as NetPlayer
		if player == null or player.get_health() <= 0:
			continue
		var outside_zone := false
		if battle_royale_zone_controller.has_method("is_outside"):
			outside_zone = bool(battle_royale_zone_controller.call("is_outside", player.global_position))
		if not outside_zone:
			continue
		hit_damage_resolver.server_apply_direct_damage(
			0,
			peer_id,
			player,
			BATTLE_ROYALE_ZONE_DAMAGE,
			player.global_position - center
		)

func _maybe_server_begin_skull_match_intro() -> void:
	if not multiplayer.is_server():
		return
	if _rt_skull_match_intro_sent:
		return
	var lobby_id := _active_match_lobby_id()
	if lobby_id <= 0:
		return
	var human_member_count := _lobby_members(lobby_id).size()
	if human_member_count <= 0:
		return
	var max_players := human_member_count
	var should_add_bots := false
	var should_show_starting_animation := false
	if lobby_service != null and lobby_service.has_lobby(lobby_id):
		max_players = lobby_service.max_players_for_lobby(lobby_id)
		should_add_bots = lobby_service.add_bots_enabled(lobby_id)
		should_show_starting_animation = lobby_service.show_starting_animation_enabled(lobby_id)
	if not should_show_starting_animation:
		return
	var expected_total := human_member_count
	if should_add_bots:
		expected_total = max_players
	if _active_match_participant_count(lobby_id) < expected_total:
		return
	var ordered_peer_ids := _ordered_skull_intro_peer_ids(lobby_id)
	if ordered_peer_ids.is_empty():
		return
	var intro_duration_sec := 13.0
	if _rt_skull_intro != null and _rt_skull_intro.has_method("recommended_duration_sec"):
		intro_duration_sec = float(_rt_skull_intro.call("recommended_duration_sec", ordered_peer_ids.size()))
	_rt_skull_match_intro_sent = true
	_activate_gameplay_lock(intro_duration_sec)
	for member_value in _lobby_members(lobby_id):
		_server_send_skull_match_intro_to_peer(int(member_value), ordered_peer_ids, intro_duration_sec)

func _reset_skull_mode_runtime_state() -> void:
	_rt_skull_round_wins_by_peer.clear()
	_rt_skull_round_eliminated_by_peer.clear()
	_rt_skull_respawn_due_msec_by_peer.clear()
	_rt_skull_round_restart_due_msec = 0
	_rt_battle_royale_zone_sync_accumulator = 0.0
	_rt_battle_royale_zone_damage_accumulator = 0.0
	_rt_battle_royale_zone_unfreeze_due_msec = 0
	_rt_prev_round_spawn_slots.clear()
	_rt_skull_match_locked = false
	_rt_skull_timed_remaining_sec = -1.0
	_rt_skull_time_sync_accumulator = 0.0
	_rt_spectator_target_peer_id = 0
	_rt_spectator_camera_position = Vector2.ZERO
	_rt_local_respawn_countdown_remaining_sec = 0.0
	_rt_local_respawn_countdown_active = false
	_rt_local_respawn_was_dead = false
	_rt_local_death_taunt = ""
	_rt_winner_return_due_msec = 0
	_rt_winner_screen_active = false
	_rt_skull_intro_was_active = false
	_rt_priority_center_message_text = ""
	_rt_priority_center_message_until_msec = 0
	_rt_skull_round_number = 1
	_rt_round_transition_due_msec = 0
	_rt_round_transition_message = ""
	_show_center_message("", false)
	_update_skull_timer_label()

func _ensure_skull_runtime_hud() -> void:
	if client_hud_layer == null:
		return
	if _rt_timer_label == null or not is_instance_valid(_rt_timer_label):
		var timer_label := Label.new()
		timer_label.name = "SkullTimerLabel"
		timer_label.visible = false
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		timer_label.add_theme_font_size_override("font_size", 26)
		timer_label.modulate = Color(1.0, 1.0, 1.0, 0.92)
		timer_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		timer_label.offset_top = 18.0
		timer_label.offset_bottom = 52.0
		_apply_runtime_highlight_label_style(timer_label, 26)
		client_hud_layer.add_child(timer_label)
		_rt_timer_label = timer_label
	if _rt_center_message_label == null or not is_instance_valid(_rt_center_message_label):
		var center_label := Label.new()
		center_label.name = "SkullCenterMessage"
		center_label.visible = false
		center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		center_label.add_theme_font_size_override("font_size", 32)
		center_label.modulate = Color(1.0, 1.0, 1.0, 0.98)
		center_label.set_anchors_preset(Control.PRESET_CENTER)
		center_label.offset_left = -420.0
		center_label.offset_top = -34.0
		center_label.offset_right = 420.0
		center_label.offset_bottom = 34.0
		_apply_runtime_highlight_label_style(center_label, 32)
		client_hud_layer.add_child(center_label)
		_rt_center_message_label = center_label

func _show_center_message(text: String, visible: bool = true) -> void:
	_ensure_skull_runtime_hud()
	if _rt_center_message_label == null:
		return
	var normalized_text := text.strip_edges()
	var should_show := visible and not normalized_text.is_empty()
	_rt_center_message_label.text = normalized_text
	_rt_center_message_label.visible = should_show
	_set_label_pulse(_rt_center_message_label, _rt_center_message_tween, should_show, 1.08, 0.52)

func _update_skull_timer_label() -> void:
	_ensure_skull_runtime_hud()
	if _rt_timer_label == null:
		return
	# Show timer whenever server is syncing timed-mode remaining seconds.
	# This is more reliable than local lobby ruleset inference after scene hops.
	var show_timer := _is_skull_ffa_match_scene() and _rt_skull_timed_remaining_sec >= 0.0
	_rt_timer_label.visible = show_timer
	_set_label_pulse(_rt_timer_label, _rt_timer_label_tween, show_timer, 1.03, 0.72)
	if not show_timer:
		_rt_timer_label.text = ""
		return
	var total_sec := maxi(0, int(ceil(_rt_skull_timed_remaining_sec)))
	var minutes := int(total_sec / 60)
	var seconds := int(total_sec % 60)
	_rt_timer_label.text = "%02d:%02d" % [minutes, seconds]

func _apply_runtime_highlight_label_style(label: Label, font_size: int) -> void:
	if label == null:
		return
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.15, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.18, 0.08, 0.02, 0.96))
	label.add_theme_constant_override("outline_size", 6)
	label.modulate = Color(1.0, 1.0, 1.0, 0.98)

func _set_label_pulse(label: Label, tween_ref: Tween, active: bool, scale_to: float, phase_sec: float) -> void:
	if label == null:
		return
	if tween_ref != null and is_instance_valid(tween_ref):
		tween_ref.kill()
		tween_ref = null
	label.scale = Vector2.ONE
	if not active:
		if label == _rt_center_message_label:
			_rt_center_message_tween = null
		elif label == _rt_timer_label:
			_rt_timer_label_tween = null
		return
	var tw := label.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(label, "scale", Vector2.ONE * scale_to, phase_sec)
	tw.tween_property(label, "scale", Vector2.ONE, phase_sec)
	if label == _rt_center_message_label:
		_rt_center_message_tween = tw
	elif label == _rt_timer_label:
		_rt_timer_label_tween = tw

func _active_skull_lobby_id() -> int:
	return _active_match_lobby_id()

func _active_skull_map_id() -> String:
	if map_controller != null:
		return map_controller.normalized_map_id()
	return selected_map_id

func _is_forced_round_survival_scene() -> bool:
	if scene_file_path == SKULL_ROUNDS_SCENE_PATH or scene_file_path == SKULL_BR_SCENE_PATH:
		return true
	var map_id := _active_skull_map_id()
	if map_id == SKULL_ROUNDS_MAP_ID or map_id == SKULL_BR_MAP_ID:
		return true
	if multiplayer != null and multiplayer.multiplayer_peer != null and multiplayer.is_server():
		var lobby_id := _active_skull_lobby_id()
		if lobby_id > 0:
			var lobby_map_id := _lobby_map_id(lobby_id)
			return lobby_map_id == SKULL_ROUNDS_MAP_ID or lobby_map_id == SKULL_BR_MAP_ID
	return false

func _normalize_skull_ruleset_id(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized == SKULL_RULESET_ROUND_SURVIVAL:
		return SKULL_RULESET_ROUND_SURVIVAL
	if normalized == SKULL_RULESET_KILL_RACE:
		return SKULL_RULESET_KILL_RACE
	if normalized == SKULL_RULESET_TIMED_KILLS:
		return SKULL_RULESET_TIMED_KILLS
	return ""

func _capture_pending_skull_match_config() -> void:
	_rt_pending_skull_ruleset = _normalize_skull_ruleset_id(
		str(ProjectSettings.get_setting(PENDING_SKULL_RULESET_SETTING, ""))
	)
	_rt_pending_skull_target_score = maxi(0, int(ProjectSettings.get_setting(PENDING_SKULL_TARGET_SCORE_SETTING, -1)))
	_rt_pending_skull_time_limit_sec = maxi(0, int(ProjectSettings.get_setting(PENDING_SKULL_TIME_LIMIT_SEC_SETTING, -1)))
	ProjectSettings.set_setting(PENDING_SKULL_RULESET_SETTING, "")
	ProjectSettings.set_setting(PENDING_SKULL_TARGET_SCORE_SETTING, -1)
	ProjectSettings.set_setting(PENDING_SKULL_TIME_LIMIT_SEC_SETTING, -1)

func _active_skull_ruleset() -> String:
	if not _is_skull_ffa_match_scene():
		return ""
	var handler = _active_skull_mode_handler()
	if handler == null:
		return ""
	return str(handler.call("ruleset_id", self))

func _resolve_deathmatch_skull_ruleset() -> String:
	var lobby_id := _active_skull_lobby_id()
	var resolved := ""
	if lobby_id > 0 and lobby_service != null:
		resolved = _normalize_skull_ruleset_id(str(lobby_service.skull_ruleset(lobby_id)))
	elif not active_lobby_room_state.is_empty():
		resolved = _normalize_skull_ruleset_id(str(active_lobby_room_state.get("skull_ruleset", "")))
	elif not _rt_pending_skull_ruleset.is_empty():
		resolved = _rt_pending_skull_ruleset
	elif _rt_skull_timed_remaining_sec >= 0.0:
		resolved = SKULL_RULESET_TIMED_KILLS
	elif not _rt_skull_round_wins_by_peer.is_empty():
		resolved = SKULL_RULESET_ROUND_SURVIVAL
	else:
		resolved = SKULL_RULESET_KILL_RACE
	return resolved

func _active_skull_mode_handler():
	if not _is_skull_ffa_match_scene():
		return null
	var map_id := _active_skull_map_id()
	var ruleset_hint := _normalize_skull_ruleset_id(_rt_pending_skull_ruleset)
	if map_id == SKULL_BR_MAP_ID or scene_file_path == SKULL_BR_SCENE_PATH or _active_game_mode() == GAME_MODE_BATTLE_ROYALE:
		return _rt_skull_mode_br
	if map_id == SKULL_ROUNDS_MAP_ID or scene_file_path == SKULL_ROUNDS_SCENE_PATH:
		return _rt_skull_mode_rounds
	if ruleset_hint == SKULL_RULESET_ROUND_SURVIVAL:
		return _rt_skull_mode_rounds
	if _is_forced_round_survival_scene():
		return _rt_skull_mode_rounds
	return _rt_skull_mode_deathmatch

func _should_show_round_wins_scoreboard() -> bool:
	var handler = _active_skull_mode_handler()
	if handler == null:
		return false
	return bool(handler.call("should_show_round_wins_scoreboard", self))

func _skull_target_score() -> int:
	var lobby_id := _active_skull_lobby_id()
	if lobby_id > 0 and lobby_service != null:
		return int(lobby_service.skull_target_score(lobby_id))
	if not active_lobby_room_state.is_empty():
		return int(active_lobby_room_state.get("skull_target_score", 10))
	if _rt_pending_skull_target_score > 0:
		return _rt_pending_skull_target_score
	return 10

func _skull_time_limit_sec() -> int:
	var lobby_id := _active_skull_lobby_id()
	if lobby_id > 0 and lobby_service != null:
		return int(lobby_service.skull_time_limit_sec(lobby_id))
	if not active_lobby_room_state.is_empty():
		return int(active_lobby_room_state.get("skull_time_limit_sec", 180))
	if _rt_pending_skull_time_limit_sec > 0:
		return _rt_pending_skull_time_limit_sec
	return 180

func _server_handle_special_respawn(peer_id: int, player: NetPlayer) -> bool:
	if not multiplayer.is_server():
		return false
	var handler = _active_skull_mode_handler()
	if handler == null:
		return false
	return bool(handler.call("handle_special_respawn", self, peer_id, player))

func _server_blocks_input_for_peer(peer_id: int) -> bool:
	if _rt_skull_match_locked:
		return true
	if _rt_skull_respawn_due_msec_by_peer.has(peer_id):
		return true
	return bool(_rt_skull_round_eliminated_by_peer.get(peer_id, false))

func _server_handle_skull_kill_event(attacker_peer_id: int, _target_peer_id: int) -> void:
	if not multiplayer.is_server() or _rt_skull_match_locked:
		return
	var handler = _active_skull_mode_handler()
	if handler == null:
		return
	handler.call("handle_kill_event", self, attacker_peer_id, _target_peer_id)

func _server_tick_skull_mode(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var ruleset := _active_skull_ruleset()
	if ruleset.is_empty() or _rt_skull_match_locked:
		return
	if ruleset == SKULL_RULESET_TIMED_KILLS:
		if _rt_skull_timed_remaining_sec < 0.0:
			_rt_skull_timed_remaining_sec = float(_skull_time_limit_sec())
		_rt_skull_timed_remaining_sec = maxf(0.0, _rt_skull_timed_remaining_sec - delta)
		_rt_skull_time_sync_accumulator += delta
		if _rt_skull_time_sync_accumulator >= 0.2:
			_rt_skull_time_sync_accumulator = 0.0
			_server_broadcast_skull_time_remaining()
		if _rt_skull_timed_remaining_sec <= 0.0:
			_server_finish_skull_match(_display_name_for_peer(_top_kills_peer_id()))
			return
	if ruleset != SKULL_RULESET_ROUND_SURVIVAL:
		_server_tick_skull_respawns()
	else:
		_server_tick_skull_round_restart()

func _server_tick_skull_respawns() -> void:
	if _rt_skull_respawn_due_msec_by_peer.is_empty():
		return
	var now := Time.get_ticks_msec()
	var ready_ids: Array[int] = []
	for key in _rt_skull_respawn_due_msec_by_peer.keys():
		var peer_id := int(key)
		var due_msec := int(_rt_skull_respawn_due_msec_by_peer.get(key, 0))
		if due_msec > now:
			continue
		ready_ids.append(peer_id)
	for peer_id in ready_ids:
		_rt_skull_respawn_due_msec_by_peer.erase(peer_id)
		var player := players.get(peer_id, null) as NetPlayer
		if player == null:
			continue
		if _is_target_dummy_peer(peer_id):
			var bot_controller := _bot_controller_for_peer(peer_id)
			if bot_controller != null:
				bot_controller.respawn_player(player)
		else:
			combat_flow_service.server_respawn_player(peer_id, player)
		_server_broadcast_player_state(peer_id, player)

func _server_queue_skull_respawn(peer_id: int, player: NetPlayer, delay_sec: float) -> void:
	if peer_id <= 0:
		return
	_rt_skull_respawn_due_msec_by_peer[peer_id] = Time.get_ticks_msec() + int(round(maxf(0.1, delay_sec) * 1000.0))
	if player != null:
		player.set_forced_hidden("respawn_wait", true)
		player.set_forced_sfx_suppressed("respawn_wait", true)
		player.set_health(0)
		_server_broadcast_player_state(peer_id, player)

func _assign_random_skull_spawn_slot(peer_id: int) -> void:
	if peer_id <= 0 or spawn_points.is_empty():
		return
	spawn_slots[peer_id] = int(randi() % spawn_points.size())

func _server_handle_skull_round_elimination(peer_id: int, player: NetPlayer) -> void:
	if _rt_skull_match_locked or _rt_skull_round_restart_due_msec > 0:
		print("[BR ROUND DBG] elimination ignored peer=%d locked=%s restart_due=%d" % [
			peer_id,
			str(_rt_skull_match_locked),
			_rt_skull_round_restart_due_msec
		])
		return
	_rt_skull_respawn_due_msec_by_peer.erase(peer_id)
	_rt_skull_round_eliminated_by_peer[peer_id] = true
	var lobby_id := _active_skull_lobby_id()
	if player != null:
		player.set_forced_hidden("respawn_wait", true)
		player.set_forced_sfx_suppressed("respawn_wait", true)
		player.set_health(0)
		_server_broadcast_player_state(peer_id, player)
	var alive := _alive_round_participant_peer_ids()
	print("[BR ROUND DBG] eliminated peer=%d scene=%s ruleset=%s alive=%s round=%d lobby=%d" % [
		peer_id,
		scene_file_path,
		_active_skull_ruleset(),
		str(alive),
		_rt_skull_round_number,
		lobby_id
	])
	if alive.size() > 1:
		return
	var winner_peer_id := int(alive[0]) if alive.size() == 1 else 0
	var completed_round_number := _rt_skull_round_number
	if winner_peer_id > 0:
		var wins := int(_rt_skull_round_wins_by_peer.get(winner_peer_id, 0)) + 1
		_rt_skull_round_wins_by_peer[winner_peer_id] = wins
		_server_sync_round_wins(lobby_id, winner_peer_id, wins)
		_server_send_match_message_to_peer(winner_peer_id, _pick_round_winner_taunt())
		var target := _skull_target_score()
		_server_broadcast_match_message(
			lobby_id,
			"%s%s|%d|%.2f" % [
				SKULL_ROUND_RESULT_MESSAGE_PREFIX,
				_display_name_for_peer(winner_peer_id),
				completed_round_number,
				SKULL_ROUND_END_FREEZE_SEC
			]
		)
		if wins >= target:
			_server_finish_skull_match(_display_name_for_peer(winner_peer_id))
			return
	elif lobby_id > 0:
		_server_broadcast_match_message(
			lobby_id,
			"%sRound draw|%d|%.2f" % [
				SKULL_ROUND_RESULT_MESSAGE_PREFIX,
				completed_round_number,
				SKULL_ROUND_END_FREEZE_SEC
			]
		)
	print("[BR ROUND DBG] scheduling round restart winner_peer=%d completed_round=%d due_in=%.2f" % [
		winner_peer_id,
		completed_round_number,
		SKULL_ROUND_END_FREEZE_SEC
	])
	_rt_skull_round_restart_due_msec = Time.get_ticks_msec() + int(round(SKULL_ROUND_END_FREEZE_SEC * 1000.0))
	_activate_gameplay_lock(SKULL_ROUND_END_FREEZE_SEC)

func _server_tick_skull_round_restart() -> void:
	if _rt_skull_round_restart_due_msec <= 0:
		return
	if Time.get_ticks_msec() < _rt_skull_round_restart_due_msec:
		return
	_rt_skull_round_restart_due_msec = 0
	_rt_round_transition_due_msec = 0
	_rt_round_transition_message = ""
	_rt_skull_round_number += 1
	_rt_skull_round_eliminated_by_peer.clear()
	_rt_skull_respawn_due_msec_by_peer.clear()
	print("[BR ROUND DBG] restarting round new_round=%d scene=%s" % [
		_rt_skull_round_number,
		scene_file_path
	])
	_server_randomize_round_spawn_slots()
	if _is_battle_royale_match_scene() and battle_royale_zone_controller != null and battle_royale_zone_controller.has_method("reset_match"):
		battle_royale_zone_controller.call("reset_match")
		_schedule_battle_royale_zone_start(BATTLE_ROYALE_ZONE_START_DELAY_SEC)
		_server_broadcast_battle_royale_zone_state()
	for peer_value in players.keys():
		var peer_id := int(peer_value)
		var player := players.get(peer_id, null) as NetPlayer
		if player == null:
			continue
		if _is_target_dummy_peer(peer_id):
			var bot_controller := _bot_controller_for_peer(peer_id)
			if bot_controller != null:
				bot_controller.respawn_player(player)
		else:
			combat_flow_service.server_respawn_player(peer_id, player)
		_server_broadcast_player_state(peer_id, player)
	var lobby_id := _active_skull_lobby_id()
	if lobby_id > 0:
		_server_broadcast_match_message(lobby_id, "Next round")
		var ordered_peer_ids := _ordered_skull_intro_peer_ids(lobby_id)
		if not ordered_peer_ids.is_empty():
			var intro_duration_sec := 6.0
			if _rt_skull_intro != null and _rt_skull_intro.has_method("recommended_duration_sec"):
				intro_duration_sec = float(_rt_skull_intro.call("recommended_duration_sec", ordered_peer_ids.size()))
			_activate_gameplay_lock(intro_duration_sec)
			for member_value in _lobby_members(lobby_id):
				_server_send_skull_match_intro_to_peer(int(member_value), ordered_peer_ids, intro_duration_sec)

func _server_randomize_round_spawn_slots() -> void:
	if spawn_points.is_empty():
		return
	var lobby_id := _active_skull_lobby_id()
	var ids: Array[int] = []
	for peer_value in players.keys():
		var peer_id := int(peer_value)
		if _is_target_dummy_peer(peer_id):
			var bot_controller := _bot_controller_for_peer(peer_id)
			if bot_controller == null or bot_controller.get_lobby_id() != lobby_id:
				continue
		elif lobby_id > 0 and _peer_lobby(peer_id) != lobby_id:
			continue
		ids.append(peer_id)
	if ids.is_empty():
		return
	var available_slots: Array[int] = []
	for slot in range(spawn_points.size()):
		available_slots.append(slot)
	if available_slots.is_empty():
		return
	var previous_round_slots := _rt_prev_round_spawn_slots.duplicate(true) as Dictionary
	var assigned: Dictionary = {}
	var attempts := 0
	while attempts < 8:
		attempts += 1
		ids.shuffle()
		available_slots.shuffle()
		assigned.clear()
		var slot_index := 0
		for peer_id in ids:
			assigned[peer_id] = int(available_slots[slot_index % available_slots.size()])
			slot_index += 1
		if ids.size() <= 1:
			break
		var changed := false
		for peer_id in ids:
			if int(previous_round_slots.get(peer_id, -999)) != int(assigned.get(peer_id, -998)):
				changed = true
				break
		if changed:
			break
	for peer_id in ids:
		var slot := int(assigned.get(peer_id, 0))
		spawn_slots[peer_id] = slot
		_rt_prev_round_spawn_slots[peer_id] = slot

func _schedule_battle_royale_zone_start(delay_sec: float) -> void:
	var due_msec := Time.get_ticks_msec() + int(round(maxf(0.0, delay_sec) * 1000.0))
	_rt_battle_royale_zone_unfreeze_due_msec = maxi(_rt_battle_royale_zone_unfreeze_due_msec, due_msec)

func _is_battle_royale_zone_frozen() -> bool:
	if _is_gameplay_locked():
		return true
	return _rt_battle_royale_zone_unfreeze_due_msec > Time.get_ticks_msec()

func _alive_round_participant_peer_ids() -> Array:
	var out: Array = []
	for peer_value in players.keys():
		var peer_id := int(peer_value)
		if bool(_rt_skull_round_eliminated_by_peer.get(peer_id, false)):
			continue
		var player := players.get(peer_id, null) as NetPlayer
		if player == null:
			continue
		if player.get_health() <= 0:
			continue
		out.append(peer_id)
	return out

func _display_name_for_peer(peer_id: int) -> String:
	var name := str(player_display_names.get(peer_id, "")).strip_edges()
	if name.is_empty() and lobby_service != null:
		name = lobby_service.get_peer_display_name(peer_id, "P%d" % peer_id)
	if name.is_empty():
		return "P%d" % peer_id
	return name

func _top_kills_peer_id() -> int:
	var best_peer_id := 0
	var best_kills := -1
	for peer_value in player_stats.keys():
		var peer_id := int(peer_value)
		var stats := player_stats.get(peer_id, {}) as Dictionary
		var kills := int(stats.get("kills", 0))
		if kills > best_kills:
			best_kills = kills
			best_peer_id = peer_id
	return best_peer_id

func _server_sync_round_wins(lobby_id: int, peer_id: int, wins: int) -> void:
	if not multiplayer.is_server():
		return
	_set_round_wins_for_peer(peer_id, wins)
	var recipients := _lobby_members(lobby_id)
	for member_value in recipients:
		var member_id := int(member_value)
		if member_id <= 0:
			continue
		_rpc_sync_round_wins.rpc_id(member_id, peer_id, wins)

func _set_round_wins_for_peer(peer_id: int, wins: int) -> void:
	if peer_id <= 0:
		return
	_rt_skull_round_wins_by_peer[peer_id] = maxi(0, wins)

func _set_skull_time_remaining(remaining_sec: float) -> void:
	_rt_skull_timed_remaining_sec = maxf(0.0, remaining_sec)
	_update_skull_timer_label()

func _server_broadcast_skull_time_remaining() -> void:
	if not multiplayer.is_server():
		return
	var lobby_id := _active_skull_lobby_id()
	if lobby_id <= 0:
		return
	for member_value in _lobby_members(lobby_id):
		var member_id := int(member_value)
		if member_id <= 0:
			continue
		_rpc_sync_skull_time_remaining.rpc_id(member_id, _rt_skull_timed_remaining_sec)

func _server_send_match_message_to_peer(peer_id: int, text: String) -> void:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	if peer_id <= 0:
		return
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return
	if peer_id == multiplayer.get_unique_id():
		_rpc_match_message(trimmed)
		return
	_rpc_match_message.rpc_id(peer_id, trimmed)

func _server_send_skull_match_intro_to_peer(peer_id: int, participant_peer_ids: Array, duration_sec: float) -> void:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	if peer_id <= 0:
		return
	if peer_id == multiplayer.get_unique_id():
		_start_local_skull_match_intro(participant_peer_ids, duration_sec)
		return
	_rpc_skull_match_intro.rpc_id(peer_id, participant_peer_ids, duration_sec)

func _is_round_winner_taunt_text(text: String) -> bool:
	var normalized := text.strip_edges().to_lower()
	if normalized.is_empty():
		return false
	for taunt_value in ROUND_WIN_TAUNTS_GREEKLISH:
		if normalized == str(taunt_value).strip_edges().to_lower():
			return true
	return false

func _show_priority_center_message(text: String, duration_sec: float) -> void:
	var normalized := text.strip_edges()
	if normalized.is_empty():
		return
	_rt_priority_center_message_text = normalized
	_rt_priority_center_message_until_msec = Time.get_ticks_msec() + int(round(maxf(0.2, duration_sec) * 1000.0))
	_show_center_message(_rt_priority_center_message_text, true)

func _handle_match_message_text(text: String) -> void:
	var lowered := text.strip_edges().to_lower()
	if text.begins_with(SKULL_ROUND_RESULT_MESSAGE_PREFIX):
		var payload := text.substr(SKULL_ROUND_RESULT_MESSAGE_PREFIX.length())
		var parts := payload.split("|", false)
		var winner_name := str(parts[0] if parts.size() > 0 else "").strip_edges()
		var round_number := int(str(parts[1] if parts.size() > 1 else "0"))
		var duration_sec := float(str(parts[2] if parts.size() > 2 else str(SKULL_ROUND_END_FREEZE_SEC)))
		var winner_text := "%s won round %d" % [winner_name, round_number] if not winner_name.is_empty() and winner_name.to_lower() != "round draw" else "Round draw"
		_rt_round_transition_message = winner_text
		_rt_round_transition_due_msec = Time.get_ticks_msec() + int(round(maxf(0.2, duration_sec) * 1000.0))
		_show_center_message(winner_text, true)
		return
	if lowered.begins_with("the winner is"):
		_rt_winner_screen_active = true
		_show_center_message(text, true)
		return
	if _is_round_winner_taunt_text(text):
		_show_priority_center_message(text, 2.0)

func _server_finish_skull_match(winner_name: String) -> void:
	var lobby_id := _active_skull_lobby_id()
	_rt_skull_match_locked = true
	_activate_gameplay_lock(3.0)
	_server_broadcast_match_message(lobby_id, "The winner is %s" % winner_name)
	if lobby_service != null and lobby_id > 0:
		var members_snapshot := _lobby_members(lobby_id).duplicate()
		lobby_service.set_lobby_started(lobby_id, false)
		for member_value in members_snapshot:
			lobby_service.set_peer_ready(lobby_id, int(member_value), false)
			_server_send_lobby_action_result(int(member_value), true, "Match finished.", 0, "")
		_server_broadcast_lobby_room_state(lobby_id)
		# Disband lobby explicitly so next create does not get blocked by stale peer->lobby state.
		for member_value in members_snapshot:
			lobby_service.remove_peer_from_lobby(int(member_value))
		lobby_service.remove_lobby(lobby_id)
		_server_broadcast_lobby_list()

func _should_use_skull_spectator_camera() -> bool:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return false
	if _is_gameplay_locked():
		return false
	if not _is_skull_ffa_match_scene():
		return false
	var local_peer_id := multiplayer.get_unique_id()
	if local_peer_id <= 0:
		return false
	var local_player := players.get(local_peer_id, null) as NetPlayer
	if local_player == null or local_player.get_health() > 0:
		_rt_spectator_target_peer_id = 0
		return false
	return not _alive_spectator_target_ids().is_empty()

func _alive_spectator_target_ids() -> Array:
	var out: Array = []
	if multiplayer == null:
		return out
	var local_peer_id := multiplayer.get_unique_id()
	for peer_value in players.keys():
		var peer_id := int(peer_value)
		if peer_id == local_peer_id:
			continue
		var player := players.get(peer_id, null) as NetPlayer
		if player == null:
			continue
		if player.get_health() <= 0:
			continue
		out.append(peer_id)
	out.sort()
	return out

func _cycle_skull_spectator_target(direction: int) -> void:
	var candidates := _alive_spectator_target_ids()
	if candidates.is_empty():
		_rt_spectator_target_peer_id = 0
		return
	var current_index := candidates.find(_rt_spectator_target_peer_id)
	if current_index < 0:
		_rt_spectator_target_peer_id = int(candidates[0])
		return
	var next_index := posmod(current_index + direction, candidates.size())
	_rt_spectator_target_peer_id = int(candidates[next_index])

func _tick_skull_spectator_camera(delta: float) -> void:
	if main_camera == null:
		return
	var candidates := _alive_spectator_target_ids()
	if candidates.is_empty():
		return
	if not candidates.has(_rt_spectator_target_peer_id):
		_rt_spectator_target_peer_id = int(candidates[0])
	var target_player := players.get(_rt_spectator_target_peer_id, null) as NetPlayer
	if target_player == null:
		return
	var desired := target_player.global_position
	if _rt_spectator_camera_position == Vector2.ZERO:
		_rt_spectator_camera_position = main_camera.global_position
	_rt_spectator_camera_position = _rt_spectator_camera_position.lerp(desired, min(1.0, delta * 7.0))
	if camera_shake == null:
		main_camera.global_position = _rt_spectator_camera_position
	else:
		main_camera.global_position = _rt_spectator_camera_position + camera_shake.step_offset(delta)

func _tick_skull_runtime_hud(delta: float) -> void:
	_ensure_skull_runtime_hud()
	_update_skull_timer_label()
	if _rt_winner_screen_active:
		return
	var local_peer_id := multiplayer.get_unique_id() if multiplayer != null and multiplayer.multiplayer_peer != null else 0
	var local_player := players.get(local_peer_id, null) as NetPlayer
	var ruleset := _active_skull_ruleset()
	var is_kill_style := ruleset == SKULL_RULESET_KILL_RACE or ruleset == SKULL_RULESET_TIMED_KILLS
	var is_round_style := ruleset == SKULL_RULESET_ROUND_SURVIVAL
	var now_msec := Time.get_ticks_msec()
	var has_priority_message := _rt_priority_center_message_until_msec > now_msec and not _rt_priority_center_message_text.is_empty()
	var round_transition_active := is_round_style and _rt_round_transition_due_msec > now_msec and not _rt_round_transition_message.is_empty()
	if not is_kill_style and not is_round_style:
		_rt_local_respawn_countdown_remaining_sec = 0.0
		_rt_local_respawn_countdown_active = false
		_rt_local_respawn_was_dead = false
		_rt_local_death_taunt = ""
		_rt_priority_center_message_text = ""
		_rt_priority_center_message_until_msec = 0
		_show_center_message("", false)
		if _rt_center_message_label != null:
			_rt_center_message_label.visible = false
			_rt_center_message_label.text = ""
		return
	var local_dead := local_player != null and local_player.get_health() <= 0 and (is_kill_style or is_round_style)
	if local_dead and not _rt_local_respawn_was_dead:
		_rt_local_death_taunt = _pick_random_death_taunt()
		if is_kill_style:
			_rt_local_respawn_countdown_remaining_sec = SKULL_RESPAWN_DELAY_SEC
			_rt_local_respawn_countdown_active = true
	if round_transition_active:
		var round_seconds_left := maxi(1, int(ceil(float(_rt_round_transition_due_msec - now_msec) / 1000.0)))
		_show_center_message("%s\nNext round in %d..." % [_rt_round_transition_message, round_seconds_left], true)
		_rt_local_respawn_was_dead = local_dead
		return
	if is_round_style:
		_rt_local_respawn_countdown_remaining_sec = 0.0
		_rt_local_respawn_countdown_active = false
		if local_dead:
			var taunt_only := _rt_local_death_taunt if not _rt_local_death_taunt.is_empty() else "pe8anes malaka"
			_show_center_message(taunt_only, true)
		elif has_priority_message:
			_show_center_message(_rt_priority_center_message_text, true)
		elif not _rt_winner_screen_active:
			_rt_local_death_taunt = ""
			_show_center_message("", false)
		_rt_local_respawn_was_dead = local_dead
		return
	if _rt_local_respawn_countdown_active:
		_rt_local_respawn_countdown_remaining_sec = maxf(0.0, _rt_local_respawn_countdown_remaining_sec - delta)
		var sec_left := maxi(1, int(ceil(_rt_local_respawn_countdown_remaining_sec)))
		var top_line := _rt_local_death_taunt if not _rt_local_death_taunt.is_empty() else "pe8anes malaka"
		_show_center_message("%s\nRespawning in %d..." % [top_line, sec_left], true)
		if _rt_local_respawn_countdown_remaining_sec <= 0.0 and not local_dead:
			_rt_local_respawn_countdown_active = false
			_rt_local_death_taunt = ""
			_show_center_message("", false)
	elif not local_dead and not _rt_winner_screen_active:
		if has_priority_message:
			_show_center_message(_rt_priority_center_message_text, true)
			_rt_local_respawn_was_dead = local_dead
			return
		_rt_local_death_taunt = ""
		_show_center_message("", false)
	_rt_local_respawn_was_dead = local_dead

func _pick_random_death_taunt() -> String:
	if DEATH_TAUNTS_GREEKLISH.is_empty():
		return "pe8anes malaka"
	return str(DEATH_TAUNTS_GREEKLISH[randi() % DEATH_TAUNTS_GREEKLISH.size()])

func _pick_round_winner_taunt() -> String:
	if ROUND_WIN_TAUNTS_GREEKLISH.is_empty():
		return "nikises malaka"
	return str(ROUND_WIN_TAUNTS_GREEKLISH[randi() % ROUND_WIN_TAUNTS_GREEKLISH.size()])

@rpc("authority", "reliable")
func _rpc_skull_match_intro(_participant_peer_ids: Array, _duration_sec: float) -> void:
	if multiplayer.is_server() and role != Role.CLIENT:
		return
	_start_local_skull_match_intro(_participant_peer_ids, _duration_sec)

func _start_local_skull_match_intro(participant_peer_ids: Array, duration_sec: float) -> void:
	_activate_gameplay_lock(duration_sec)
	if _rt_skull_intro != null and _rt_skull_intro.has_method("start") and multiplayer != null:
		_rt_skull_intro.call("start", participant_peer_ids, multiplayer.get_unique_id(), duration_sec)

func _update_score_labels() -> void:
	super._update_score_labels()
	if _ctf_enabled() or ui_controller == null:
		return
	var ruleset := _active_skull_ruleset()
	if _should_show_round_wins_scoreboard():
		if kd_label != null:
			var local_peer_id := multiplayer.get_unique_id() if multiplayer != null and multiplayer.multiplayer_peer != null else 0
			var local_stats := player_stats.get(local_peer_id, {}) as Dictionary
			var wins := int(_rt_skull_round_wins_by_peer.get(local_peer_id, 0))
			kd_label.text = "K/D : %d/%d  |  ROUND WINS: %d/%d" % [
				int(local_stats.get("kills", 0)),
				int(local_stats.get("deaths", 0)),
				wins,
				_skull_target_score()
			]
		if ui_controller.has_method("update_scoreboard_round_wins"):
			var scoreboard_rounds: Dictionary = _rt_skull_round_wins_by_peer.duplicate(true) as Dictionary
			for peer_value in player_stats.keys():
				var peer_id := int(peer_value)
				if not scoreboard_rounds.has(peer_id):
					scoreboard_rounds[peer_id] = 0
			ui_controller.call("update_scoreboard_round_wins", scoreboard_rounds, player_display_names, player_stats)
	elif ruleset == SKULL_RULESET_TIMED_KILLS and _rt_skull_timed_remaining_sec >= 0.0:
		if kd_label != null:
			kd_label.text = "TIME LEFT: %ds" % int(ceil(_rt_skull_timed_remaining_sec))

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
	if _rt_fight_music_player == null:
		return
	if _rt_fight_music_player.stream == null:
		_rt_fight_music_player.stream = _load_fight_soundtrack_stream()
	if _rt_fight_music_player.stream == null:
		return
	var vol_linear := _load_music_volume_linear_from_menu_state()
	_rt_fight_music_player.volume_db = _music_db_from_linear(vol_linear)
	_rt_fight_music_player.stream_paused = false
	_rt_fight_music_player.play(0.0)

func _ensure_fight_music_player() -> void:
	if _rt_fight_music_player != null and is_instance_valid(_rt_fight_music_player):
		return
	var existing := get_node_or_null("FightSoundtrackPlayer") as AudioStreamPlayer
	if existing != null:
		_rt_fight_music_player = existing
	else:
		var p := AudioStreamPlayer.new()
		p.name = "FightSoundtrackPlayer"
		add_child(p)
		_rt_fight_music_player = p
	if _rt_fight_music_player == null:
		return
	_rt_fight_music_player.bus = "Master"
	_rt_fight_music_player.autoplay = false
	_rt_fight_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_rt_fight_music_player.max_polyphony = 1
	if _rt_fight_music_player.stream is AudioStreamWAV:
		(_rt_fight_music_player.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif _rt_fight_music_player.stream is AudioStreamMP3:
		(_rt_fight_music_player.stream as AudioStreamMP3).loop = true

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
	var state: Dictionary = parsed as Dictionary
	return clampf(float(state.get("music_volume", 0.8)), 0.0, 1.0)

func _load_particles_enabled_from_menu_state() -> bool:
	if not FileAccess.file_exists(MENU_STATE_PATH):
		return true
	var raw := FileAccess.get_file_as_string(MENU_STATE_PATH)
	if raw.is_empty():
		return true
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return true
	var state: Dictionary = parsed as Dictionary
	return bool(state.get("particles_enabled", true))

func _load_screen_shake_enabled_from_menu_state() -> bool:
	if not FileAccess.file_exists(MENU_STATE_PATH):
		return true
	var raw := FileAccess.get_file_as_string(MENU_STATE_PATH)
	if raw.is_empty():
		return true
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return true
	var state: Dictionary = parsed as Dictionary
	return bool(state.get("screen_shake_enabled", true))

func _apply_particles_pref_from_menu_state() -> void:
	_rt_particles_enabled = _load_particles_enabled_from_menu_state()
	ProjectSettings.set_setting("kw/particles_enabled", _rt_particles_enabled)
	if combat_effects != null and combat_effects.has_method("set_particles_enabled"):
		combat_effects.call("set_particles_enabled", _rt_particles_enabled)
	_bind_particles_policy_listener()
	_apply_particles_policy_recursive(self)
	var tree := get_tree()
	if tree != null and tree.current_scene != null and tree.current_scene != self:
		_apply_particles_policy_recursive(tree.current_scene)

func _apply_screen_shake_pref_from_menu_state() -> void:
	_rt_screen_shake_enabled = _load_screen_shake_enabled_from_menu_state()
	ProjectSettings.set_setting("kw/screen_shake_enabled", _rt_screen_shake_enabled)
	if camera_shake != null and camera_shake.has_method("set_enabled"):
		camera_shake.call("set_enabled", _rt_screen_shake_enabled)

func _bind_particles_policy_listener() -> void:
	if _rt_particles_listener_bound:
		return
	var tree := get_tree()
	if tree == null:
		return
	var added_cb := Callable(self, "_on_runtime_node_added_for_particles")
	if not tree.node_added.is_connected(added_cb):
		tree.node_added.connect(added_cb)
	_rt_particles_listener_bound = true

func _on_runtime_node_added_for_particles(node: Node) -> void:
	if node == null:
		return
	_apply_particles_policy_recursive(node)

func _apply_particles_policy_recursive(root_node: Node) -> void:
	if root_node == null:
		return
	_apply_particles_policy_to_node(root_node)
	for child in root_node.get_children():
		var child_node := child as Node
		if child_node != null:
			_apply_particles_policy_recursive(child_node)

func _apply_particles_policy_to_node(node: Node) -> void:
	if node is CPUParticles2D:
		var cpu := node as CPUParticles2D
		if _rt_particles_enabled:
			if cpu.has_meta("kw_saved_emitting"):
				cpu.emitting = bool(cpu.get_meta("kw_saved_emitting"))
				cpu.remove_meta("kw_saved_emitting")
		else:
			if not cpu.has_meta("kw_saved_emitting"):
				cpu.set_meta("kw_saved_emitting", cpu.emitting)
			cpu.emitting = false
	elif node is GPUParticles2D:
		var gpu := node as GPUParticles2D
		if _rt_particles_enabled:
			if gpu.has_meta("kw_saved_emitting"):
				gpu.emitting = bool(gpu.get_meta("kw_saved_emitting"))
				gpu.remove_meta("kw_saved_emitting")
		else:
			if not gpu.has_meta("kw_saved_emitting"):
				gpu.set_meta("kw_saved_emitting", gpu.emitting)
			gpu.emitting = false

func _music_db_from_linear(value: float, base_db: float = 0.0) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	if clamped <= 0.001:
		return -80.0
	return clampf(base_db + linear_to_db(clamped), -80.0, 12.0)
