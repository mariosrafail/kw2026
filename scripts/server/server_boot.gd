extends Node

const DEFAULT_PORT := 8080
const MAX_CLIENTS := 8
const DEFAULT_WEAPON_ID := "ak47"
const LOBBY_CHAT_HISTORY_LIMIT := 60
const MULTIPLAYER_PEER_FACTORY := preload("res://scripts/network/multiplayer_peer_factory.gd")
const MAP_CATALOG_SCRIPT := preload("res://scripts/world/map_catalog.gd")
const MAP_FLOW_SERVICE_SCRIPT := preload("res://scripts/world/map_flow_service.gd")
const LOBBY_CONFIG_SCRIPT := preload("res://scripts/lobby/lobby_config.gd")
const LOBBY_SERVICE_SCRIPT := preload("res://scripts/lobby/lobby_service.gd")
const LOBBY_FLOW_CONTROLLER_SCRIPT := preload("res://scripts/lobby/lobby_flow_controller.gd")

var map_catalog: MapCatalog
var map_flow_service: MapFlowService
var lobby_service: LobbyService
var lobby_flow_controller: LobbyFlowController
var _server_map_scene_switch_pending := false

func _ready() -> void:
	name = "GameRoot"
	map_catalog = MAP_CATALOG_SCRIPT.new()
	map_flow_service = MAP_FLOW_SERVICE_SCRIPT.new()
	lobby_service = LOBBY_SERVICE_SCRIPT.new(LOBBY_CONFIG_SCRIPT.new())
	lobby_service.reset(true)
	lobby_flow_controller = LOBBY_FLOW_CONTROLLER_SCRIPT.new()
	lobby_flow_controller.configure(
		{
			"multiplayer": multiplayer,
			"lobby_service": lobby_service,
			"players": {}
		},
		{
			"server_send_lobby_list_to_peer": Callable(self, "_server_send_lobby_list_to_peer"),
			"server_broadcast_lobby_list": Callable(self, "_server_broadcast_lobby_list"),
			"server_broadcast_lobby_room_state": Callable(self, "_server_broadcast_lobby_room_state"),
			"send_lobby_action_result": Callable(self, "_send_lobby_action_result"),
			"append_log": Callable(self, "_log")
		}
	)
	_bind_multiplayer_signals()
	_start_server(_server_port_from_args())

func _bind_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _start_server(port: int) -> void:
	var target_port := clampi(port, 1, 65535)
	var result := MULTIPLAYER_PEER_FACTORY.create_server_peer(target_port, MAX_CLIENTS)
	var peer := result.get("peer", null) as MultiplayerPeer
	var err := int(result.get("error", FAILED))
	if err != OK or peer == null:
		push_error("Server error: %s (code=%d)" % [error_string(err), err])
		return
	multiplayer.multiplayer_peer = peer
	print("Server started on port %d using %s" % [target_port, MULTIPLAYER_PEER_FACTORY.transport()])

func _server_port_from_args() -> int:
	var env_port := int(OS.get_environment("KW_GAME_PORT"))
	var port := env_port if env_port >= 1 and env_port <= 65535 else DEFAULT_PORT
	for raw_arg in OS.get_cmdline_user_args():
		var arg := str(raw_arg).strip_edges()
		if arg.begins_with("--port="):
			var parsed := int(arg.substr("--port=".length()))
			if parsed >= 1 and parsed <= 65535:
				port = parsed
	return port

func _on_peer_connected(peer_id: int) -> void:
	_log("peer connected id=%d" % peer_id)
	_server_send_lobby_list_to_peer(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	_log("peer disconnected id=%d" % peer_id)
	lobby_flow_controller.server_leave_lobby(peer_id, false, true)

func _log(message: String) -> void:
	print("[SERVER BOOT] %s" % message)

func _normalize_weapon_id(weapon_id: String) -> String:
	var normalized := weapon_id.strip_edges().to_lower()
	return DEFAULT_WEAPON_ID if normalized.is_empty() else normalized

func _lobby_map_id(lobby_id: int) -> String:
	if lobby_id <= 0:
		return ""
	var lobby := lobby_service.get_lobby_data(lobby_id)
	return str(lobby.get("map_id", "")).strip_edges().to_lower()

func _server_send_lobby_list_to_peer(peer_id: int) -> void:
	if peer_id <= 0:
		return
	var entries := lobby_service.pack_lobby_list()
	var packed_entries := map_flow_service.server_pack_lobby_entries(entries, map_catalog)
	var active_lobby_id := lobby_service.get_peer_lobby(peer_id)
	_rpc_lobby_list.rpc_id(peer_id, packed_entries, active_lobby_id)
	if active_lobby_id > 0:
		_rpc_lobby_room_state.rpc_id(peer_id, lobby_service.pack_lobby_room_state(active_lobby_id))

func _server_broadcast_lobby_list() -> void:
	for peer_id in multiplayer.get_peers():
		_server_send_lobby_list_to_peer(int(peer_id))

func _server_broadcast_lobby_room_state(lobby_id: int) -> void:
	if lobby_id <= 0:
		return
	var payload := lobby_service.pack_lobby_room_state(lobby_id)
	for member_value in lobby_service.get_lobby_members(lobby_id):
		var member_id := int(member_value)
		if member_id > 0:
			_rpc_lobby_room_state.rpc_id(member_id, payload)

func _send_lobby_action_result(peer_id: int, success: bool, message: String, active_lobby_id: int, map_id: String = "") -> void:
	if peer_id <= 0:
		return
	_rpc_lobby_action_result.rpc_id(peer_id, success, message, active_lobby_id, map_id, true)

func _broadcast_lobby_chat(lobby_id: int, sender_peer_id: int, display_name: String, message: String) -> void:
	for member_value in lobby_service.get_lobby_members(lobby_id):
		var member_id := int(member_value)
		if member_id > 0:
			_rpc_lobby_chat_message.rpc_id(member_id, lobby_id, sender_peer_id, display_name, message)

@rpc("any_peer", "reliable")
func _rpc_request_spawn() -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	var lobby_id := lobby_service.get_peer_lobby(peer_id)
	_log("spawn request received in server_boot peer_id=%d lobby_id=%d" % [peer_id, lobby_id])
	if lobby_id <= 0 or not lobby_service.has_lobby(lobby_id):
		_log("spawn request ignored in server_boot: missing lobby for peer_id=%d" % peer_id)
		return
	if not lobby_service.lobby_started(lobby_id):
		_log("spawn request ignored in server_boot: lobby not started lobby_id=%d" % lobby_id)
		return
	var lobby := lobby_service.get_lobby_data(lobby_id)
	var map_id := str(lobby.get("map_id", _lobby_map_id(lobby_id))).strip_edges().to_lower()
	var mode_id := map_flow_service.normalize_mode_id(str(lobby.get("mode_id", "deathmatch")))
	_rpc_scene_switch_to_map.rpc_id(peer_id, map_id)
	if _server_map_scene_switch_pending:
		_log("spawn request acknowledged while server map switch is already pending peer_id=%d map=%s" % [peer_id, map_id])
		return
	_switch_server_to_map_scene(map_id, mode_id, lobby)

@rpc("any_peer", "reliable")
func _rpc_request_reload() -> void:
	pass

@rpc("authority", "reliable")
func _rpc_spawn_player(_peer_id: int, _spawn_position: Vector2, _display_name: String = "", _weapon_id: String = "", _character_id: String = "", _skin_index: int = 0, _weapon_skin_index: int = 0) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_despawn_player(_peer_id: int) -> void:
	pass

@rpc("authority", "unreliable_ordered")
func _rpc_sync_player_state(_peer_id: int, _new_position: Vector2, _new_velocity: Vector2, _aim_angle: float, _health: int, _part_animation_state: Dictionary = {}) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_sync_player_stats(_peer_id: int, _kills: int, _deaths: int) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_sync_round_wins(_peer_id: int, _wins: int) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_sync_skill_charge(_peer_id: int, _current_points: int, _required_points: int) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_kill_feed(_attacker_name: String, _victim_name: String) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_match_message(_text: String) -> void:
	pass

@rpc("any_peer", "unreliable_ordered")
func _rpc_submit_input(_axis: float, _jump_pressed: bool, _jump_held: bool, _aim_world: Vector2, _shoot_held: bool, _boost_damage: bool, _reported_rtt_ms: int) -> void:
	pass

@rpc("any_peer", "unreliable")
func _rpc_ping_request(_client_sent_msec: int) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id > 0:
		_rpc_ping_response.rpc_id(peer_id, _client_sent_msec)

@rpc("authority", "unreliable")
func _rpc_ping_response(_client_sent_msec: int) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_spawn_projectile(_projectile_id: int, _owner_peer_id: int, _spawn_position: Vector2, _velocity: Vector2, _lag_comp_ms: int, _trail_origin: Vector2, _weapon_id: String = "") -> void:
	pass

@rpc("authority", "unreliable_ordered")
func _rpc_sync_ctf_flag(_carrier_peer_id: int, _world_position: Vector2, _red_score: int = 0, _blue_score: int = 0) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_despawn_projectile(_projectile_id: int) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_projectile_impact(_projectile_id: int, _impact_position: Vector2, _legacy_trail_start_position: Vector2 = Vector2.ZERO) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_spawn_blood_particles(_impact_position: Vector2, _incoming_velocity: Vector2, _blood_color: Color = Color(0.98, 0.02, 0.07, 1.0), _count_multiplier: float = 1.0) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_spawn_surface_particles(_impact_position: Vector2, _incoming_velocity: Vector2, _particle_color: Color) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_play_reload_sfx(_peer_or_payload: Variant, _weapon_id: String = "") -> void:
	pass

@rpc("authority", "reliable")
func _rpc_sync_player_ammo(_peer_or_payload: Variant, _ammo: int = 0, _is_reloading: bool = false) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_spawn_dropped_mag(_mag_id: int, _texture_path: String, _tint: Color, _spawn_position: Vector2, _linear_velocity: Vector2, _angular_velocity: float = 0.0) -> void:
	pass

@rpc("authority", "unreliable_ordered")
func _rpc_sync_dropped_mag(_mag_id: int, _world_position: Vector2, _world_rotation: float, _linear_velocity: Vector2, _angular_velocity: float) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_despawn_dropped_mag(_mag_id: int) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_sync_player_weapon(_peer_id: int, _weapon_id: String) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_sync_player_weapon_skin(_peer_id: int, _skin_index: int) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_sync_player_character(_peer_id: int, _character_id: String) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_sync_player_skin(_peer_id: int, _skin_index: int) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_sync_player_display_name(_peer_id: int, _display_name: String) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_play_death_sfx(_target_or_impact: Variant, _impact_position: Vector2 = Vector2.ZERO, _incoming_velocity: Vector2 = Vector2.ZERO) -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_request_lobby_list() -> void:
	_server_send_lobby_list_to_peer(multiplayer.get_remote_sender_id())

@rpc("any_peer", "reliable")
func _rpc_lobby_create(_requested_name: String, _payload: String) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	var decoded := map_flow_service.decode_create_lobby_payload(
		map_catalog,
		Callable(self, "_normalize_weapon_id"),
		DEFAULT_WEAPON_ID,
		_payload
	)
	var weapon_id := str(decoded.get("weapon_id", DEFAULT_WEAPON_ID))
	var character_id := str(decoded.get("character_id", "outrage"))
	var map_id := map_flow_service.normalize_map_id(map_catalog, str(decoded.get("map_id", map_catalog.default_map_id())))
	var mode_id := map_flow_service.select_mode_for_map(map_catalog, map_id, str(decoded.get("mode_id", "deathmatch")))
	lobby_service.set_peer_weapon(peer_id, weapon_id)
	lobby_service.set_peer_character(peer_id, character_id)
	lobby_flow_controller.server_create_lobby(peer_id, _requested_name, map_id, map_catalog.max_players_for_mode(map_id, mode_id), mode_id)

@rpc("any_peer", "reliable")
func _rpc_lobby_join(_lobby_id: int, _weapon_id: String, _character_id: String = "") -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	lobby_service.set_peer_weapon(peer_id, _normalize_weapon_id(_weapon_id))
	lobby_service.set_peer_character(peer_id, _character_id)
	lobby_flow_controller.server_join_lobby(peer_id, _lobby_id)
	if _lobby_id > 0 and lobby_service.has_lobby(_lobby_id):
		for item in lobby_service.get_lobby_chat_history(_lobby_id):
			var chat := item as Dictionary
			_rpc_lobby_chat_message.rpc_id(
				peer_id,
				_lobby_id,
				int(chat.get("peer_id", 0)),
				str(chat.get("display_name", "Player")),
				str(chat.get("message", ""))
			)

@rpc("any_peer", "reliable")
func _rpc_lobby_leave(_legacy_a: Variant = null, _legacy_b: Variant = null) -> void:
	lobby_flow_controller.server_leave_lobby_request(multiplayer.get_remote_sender_id())

@rpc("any_peer", "reliable")
func _rpc_lobby_set_weapon(_peer_or_weapon: Variant, _weapon_id: String = "") -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	var weapon_id := str(_peer_or_weapon)
	if not _weapon_id.strip_edges().is_empty():
		weapon_id = _weapon_id
	lobby_service.set_peer_weapon(peer_id, _normalize_weapon_id(weapon_id))

@rpc("any_peer", "reliable")
func _rpc_lobby_set_weapon_skin(_skin_index: int) -> void:
	lobby_service.set_peer_weapon_skin(multiplayer.get_remote_sender_id(), maxi(0, _skin_index))

@rpc("any_peer", "reliable")
func _rpc_lobby_set_character(_character_id: String) -> void:
	lobby_service.set_peer_character(multiplayer.get_remote_sender_id(), _character_id)

@rpc("any_peer", "reliable")
func _rpc_lobby_set_skin(_skin_index: int) -> void:
	lobby_service.set_peer_skin(multiplayer.get_remote_sender_id(), maxi(0, _skin_index))

@rpc("any_peer", "reliable")
func _rpc_lobby_set_display_name(_display_name: String) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	lobby_service.set_peer_display_name(peer_id, _display_name)
	var lobby_id := lobby_service.get_peer_lobby(peer_id)
	if lobby_id > 0:
		_server_broadcast_lobby_room_state(lobby_id)

@rpc("any_peer", "reliable")
func _rpc_lobby_chat_send(_message: String) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	var lobby_id := lobby_service.get_peer_lobby(peer_id)
	if lobby_id <= 0:
		return
	var message := _message.strip_edges()
	if message.is_empty():
		return
	if message.length() > 140:
		message = message.substr(0, 140)
	var display_name := lobby_service.get_peer_display_name(peer_id, "P%d" % peer_id)
	lobby_service.append_lobby_chat_message(lobby_id, peer_id, display_name, message, LOBBY_CHAT_HISTORY_LIMIT)
	_broadcast_lobby_chat(lobby_id, peer_id, display_name, message)

@rpc("authority", "reliable")
func _rpc_lobby_list(_entries: Array, _active_lobby_id: int) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_lobby_action_result(_success: bool, _message: String, _active_lobby_id: int, _map_id: String, _lobby_scene_mode: bool) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_lobby_room_state(_payload: Dictionary) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_lobby_chat_message(_lobby_id: int, _peer_id: int, _display_name: String, _message: String) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_scene_switch_to_map(_map_id: String) -> void:
	pass

@rpc("authority", "unreliable_ordered")
func _rpc_sync_battle_royale_zone(_center: Vector2, _radius: float) -> void:
	pass

@rpc("authority", "unreliable_ordered")
func _rpc_sync_skull_time_remaining(_remaining_sec: float) -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_lobby_set_team(_team_id: int) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	var lobby_id := lobby_service.get_peer_lobby(peer_id)
	if lobby_service.set_peer_team(lobby_id, peer_id, _team_id):
		_server_broadcast_lobby_room_state(lobby_id)

@rpc("any_peer", "reliable")
func _rpc_lobby_set_ready(_ready: bool) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	var lobby_id := lobby_service.get_peer_lobby(peer_id)
	if lobby_service.set_peer_ready(lobby_id, peer_id, _ready):
		_server_broadcast_lobby_room_state(lobby_id)

@rpc("any_peer", "reliable")
func _rpc_lobby_set_add_bots(_enabled: bool) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	var lobby_id := lobby_service.get_peer_lobby(peer_id)
	if lobby_service.set_add_bots_enabled(lobby_id, peer_id, _enabled):
		_server_broadcast_lobby_room_state(lobby_id)

@rpc("any_peer", "reliable")
func _rpc_lobby_set_show_starting_animation(_enabled: bool) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	var lobby_id := lobby_service.get_peer_lobby(peer_id)
	if lobby_service.set_show_starting_animation_enabled(lobby_id, peer_id, _enabled):
		_server_broadcast_lobby_room_state(lobby_id)

@rpc("any_peer", "reliable")
func _rpc_lobby_set_skull_ruleset(_ruleset_id: String) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	var lobby_id := lobby_service.get_peer_lobby(peer_id)
	if lobby_service.set_skull_ruleset(lobby_id, peer_id, _ruleset_id):
		_server_broadcast_lobby_room_state(lobby_id)

@rpc("any_peer", "reliable")
func _rpc_lobby_set_skull_target_score(_target_score: int) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	var lobby_id := lobby_service.get_peer_lobby(peer_id)
	if lobby_service.set_skull_target_score(lobby_id, peer_id, _target_score):
		_server_broadcast_lobby_room_state(lobby_id)

@rpc("any_peer", "reliable")
func _rpc_lobby_set_skull_time_limit_sec(_time_limit_sec: int) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	var lobby_id := lobby_service.get_peer_lobby(peer_id)
	if lobby_service.set_skull_time_limit_sec(lobby_id, peer_id, _time_limit_sec):
		_server_broadcast_lobby_room_state(lobby_id)

@rpc("any_peer", "reliable")
func _rpc_lobby_start_match() -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	var lobby_id := lobby_service.get_peer_lobby(peer_id)
	if lobby_id <= 0 or lobby_service.owner_peer_for_lobby(lobby_id) != peer_id:
		_send_lobby_action_result(peer_id, false, "Only the room owner can start.", lobby_id, _lobby_map_id(lobby_id))
		return
	var map_id := _lobby_map_id(lobby_id)
	var lobby := lobby_service.get_lobby_data(lobby_id)
	var mode_id := map_flow_service.normalize_mode_id(str(lobby.get("mode_id", "deathmatch")))
	lobby_service.set_lobby_started(lobby_id, true)
	_server_broadcast_lobby_room_state(lobby_id)
	for member_value in lobby_service.get_lobby_members(lobby_id):
		var member_id := int(member_value)
		if member_id > 0:
			_rpc_scene_switch_to_map.rpc_id(member_id, map_id)
	_switch_server_to_map_scene(map_id, mode_id, lobby)

func _switch_server_to_map_scene(map_id: String, mode_id: String, lobby: Dictionary) -> void:
	if _server_map_scene_switch_pending:
		_log("server scene_switch ignored; switch already pending")
		return
	var normalized_map := map_flow_service.normalize_map_id(map_catalog, map_id)
	var scene_path := map_catalog.scene_path_for_id(normalized_map)
	if scene_path.strip_edges().is_empty():
		_log("start_match failed missing scene for map=%s" % normalized_map)
		return
	ProjectSettings.set_setting("kw/pending_game_mode", mode_id)
	ProjectSettings.set_setting("kw/pending_skull_ruleset", str(lobby.get("skull_ruleset", "")).strip_edges().to_lower())
	ProjectSettings.set_setting("kw/pending_skull_target_score", int(lobby.get("skull_target_score", -1)))
	ProjectSettings.set_setting("kw/pending_skull_time_limit_sec", int(lobby.get("skull_time_limit_sec", -1)))
	_log("server scene_switch map=%s mode=%s scene=%s" % [normalized_map, mode_id, scene_path])
	var tree := get_tree()
	if tree != null:
		_server_map_scene_switch_pending = true
		tree.call_deferred("change_scene_to_file", scene_path)

@rpc("any_peer", "reliable")
func _rpc_cast_skill1(_target_world: Vector2) -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_cast_skill2(_target_world: Vector2) -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_debug_fill_skill2_charge() -> void:
	pass

@rpc("authority", "reliable")
func _rpc_spawn_outrage_bomb(_caster_peer_id: int, _world_position: Vector2, _fuse_sec: float) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_spawn_outrage_boost(_caster_peer_id: int, _duration_sec: float) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_spawn_erebus_immunity(_caster_peer_id: int, _duration_sec: float) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_spawn_erebus_shield(_caster_peer_id: int, _duration_sec: float) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_spawn_tasko_invis_field(_caster_peer_id: int, _world_position: Vector2) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_spawn_tasko_mine(_caster_peer_id: int, _world_position: Vector2) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_apply_debuff_visual(_target_peer_id: int, _debuff_id: String, _duration_sec: float) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_skull_match_intro(_participant_peer_ids: Array, _duration_sec: float) -> void:
	pass
