extends Node

const MAP_CATALOG_SCRIPT := preload("res://scripts/world/map_catalog.gd")
const MAP_FLOW_SERVICE_SCRIPT := preload("res://scripts/world/map_flow_service.gd")
signal connected_to_lobby_server
signal lobby_connection_failed
signal lobby_server_disconnected
signal lobby_list_received(entries: Array, active_lobby_id: int)
signal lobby_action_result_received(success: bool, message: String, active_lobby_id: int, map_id: String)
signal lobby_room_state_received(payload: Dictionary)
signal lobby_chat_received(lobby_id: int, peer_id: int, display_name: String, message: String)

var _is_connected := false
var _last_host := "127.0.0.1"
var _last_port := 8080
var _map_catalog = MAP_CATALOG_SCRIPT.new()
var _map_flow_service = MAP_FLOW_SERVICE_SCRIPT.new()
var _active_lobby_id := 0
var _pending_mode_id := "deathmatch"
var _lobby_mode_by_id: Dictionary = {}
var _rpc_handoff_attempts := 0

func _log(message: String) -> void:
	print("[lobby_rpc_bridge] %s" % message)

func ensure_attached(tree: SceneTree) -> void:
	if tree == null:
		return
	var root := tree.root
	if root == null:
		return
	if get_parent() != root:
		if get_parent() != null:
			get_parent().remove_child(self)
		name = "GameRoot"
		root.add_child(self)
	_log("ensure_attached parent=%s" % str(get_parent()))
	_bind_multiplayer_signals()

func connect_to_server(host: String = "127.0.0.1", port: int = 8080) -> void:
	_last_host = host.strip_edges()
	if _last_host.is_empty():
		_last_host = "127.0.0.1"
	_last_port = clampi(port, 1, 65535)
	_log("connect_to_server host=%s port=%d" % [_last_host, _last_port])

	var mp := multiplayer
	if mp == null:
		_log("connect_to_server failed multiplayer=null")
		lobby_connection_failed.emit()
		return

	if mp.multiplayer_peer != null:
		var status := mp.multiplayer_peer.get_connection_status()
		var local_peer_id := mp.get_unique_id()
		_log("existing peer status=%d local_peer_id=%d" % [status, local_peer_id])
		if status == MultiplayerPeer.CONNECTION_CONNECTED and local_peer_id > 1:
			_is_connected = true
			_log("already connected; emitting connected")
			connected_to_lobby_server.emit()
			return
		mp.multiplayer_peer.close()
		mp.multiplayer_peer = null

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(_last_host, _last_port)
	_log("create_client err=%d" % err)
	if err != OK:
		_log("create_client failed immediately")
		lobby_connection_failed.emit()
		return
	mp.multiplayer_peer = peer
	_log("multiplayer peer assigned")

func disconnect_from_server() -> void:
	var mp := multiplayer
	if mp != null and mp.multiplayer_peer != null:
		_log("disconnect_from_server closing current peer")
		mp.multiplayer_peer.close()
		mp.multiplayer_peer = null
		_is_connected = false

func is_connected_to_server() -> bool:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return false
	return multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func is_connecting_to_server() -> bool:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return false
	return multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING

func request_lobby_list() -> bool:
	if not _can_send_server_rpc():
		_log("request_lobby_list blocked can_send=false")
		return false
	_log("request_lobby_list rpc_id(1)")
	_rpc_request_lobby_list.rpc_id(1)
	return true

func create_lobby(lobby_name: String, weapon_id: String, character_id: String, map_id: String = "", mode_id: String = "deathmatch") -> bool:
	if not _can_send_server_rpc():
		_log("create_lobby blocked can_send=false")
		return false
	var normalized_weapon := weapon_id.strip_edges().to_lower()
	if normalized_weapon.is_empty():
		normalized_weapon = "ak47"
	var normalized_character := character_id.strip_edges().to_lower()
	if normalized_character != "erebus" and normalized_character != "tasko":
		normalized_character = "outrage"
	var default_map_id := _map_flow_service.normalize_map_id(_map_catalog, _map_catalog.default_map_id())
	var normalized_map := map_id.strip_edges().to_lower()
	if normalized_map.is_empty():
		normalized_map = default_map_id
	normalized_map = _map_flow_service.normalize_map_id(_map_catalog, normalized_map)
	var normalized_mode := _map_flow_service.select_mode_for_map(_map_catalog, normalized_map, mode_id)
	_pending_mode_id = normalized_mode
	var payload := "%s|%s|%s|%s" % [normalized_weapon, normalized_character, normalized_map, normalized_mode]
	_log("create_lobby path=SERVER_RPC lobby_name=%s payload=%s host=%s port=%d" % [lobby_name.strip_edges(), payload, _last_host, _last_port])
	_rpc_lobby_create.rpc_id(1, lobby_name.strip_edges(), payload)
	return true

func host_local_match(map_id: String = "", mode_id: String = "deathmatch") -> bool:
	var default_map_id := _map_flow_service.normalize_map_id(_map_catalog, _map_catalog.default_map_id())
	var normalized_map := map_id.strip_edges().to_lower()
	if normalized_map.is_empty():
		normalized_map = default_map_id
	normalized_map = _map_flow_service.normalize_map_id(_map_catalog, normalized_map)
	var normalized_mode := _map_flow_service.select_mode_for_map(_map_catalog, normalized_map, mode_id)
	var scene_path := _map_catalog.scene_path_for_id(normalized_map)
	if scene_path.strip_edges().is_empty():
		scene_path = _map_catalog.scene_path_for_id(default_map_id)

	ProjectSettings.set_setting("kw/pending_game_mode", normalized_mode)

	var mp := multiplayer
	if mp == null:
		_log("host_local_match failed multiplayer=null")
		return false
	if mp.multiplayer_peer != null:
		mp.multiplayer_peer.close()
		mp.multiplayer_peer = null

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(_last_port, 8)
	_log("host_local_match path=LOCAL_FALLBACK create_server err=%d port=%d map=%s mode=%s" % [err, _last_port, normalized_map, normalized_mode])
	if err != OK:
		err = peer.create_server(7777, 8)
		_log("host_local_match fallback create_server err=%d port=%d" % [err, 7777])
	if err != OK:
		return false
	_log("host_local_match result=LOCAL_SERVER_STARTED scene=%s mode=%s" % [scene_path, normalized_mode])
	mp.multiplayer_peer = peer

	var tree := get_tree()
	if tree != null:
		_release_game_root_before_scene_change()
		tree.call_deferred("change_scene_to_file", scene_path)
		_begin_rpc_root_handoff()
	return true

func join_lobby(lobby_id: int, weapon_id: String, character_id: String) -> bool:
	if not _can_send_server_rpc():
		_log("join_lobby blocked can_send=false")
		return false
	var normalized_weapon := weapon_id.strip_edges().to_lower()
	if normalized_weapon.is_empty():
		normalized_weapon = "ak47"
	var normalized_character := character_id.strip_edges().to_lower()
	if normalized_character != "erebus" and normalized_character != "tasko":
		normalized_character = "outrage"
	_pending_mode_id = str(_lobby_mode_by_id.get(lobby_id, "deathmatch"))
	_rpc_lobby_join.rpc_id(1, lobby_id, normalized_weapon, normalized_character)
	_log("join_lobby rpc_id(1) lobby_id=%d weapon=%s character=%s" % [lobby_id, normalized_weapon, normalized_character])
	return true

func leave_lobby() -> bool:
	if not _can_send_server_rpc():
		_log("leave_lobby blocked can_send=false")
		return false
	_log("leave_lobby rpc_id(1)")
	_rpc_lobby_leave.rpc_id(1)
	return true

func set_lobby_team(team_id: int) -> bool:
	if not _can_send_server_rpc():
		_log("set_lobby_team blocked can_send=false")
		return false
	_log("set_lobby_team rpc_id(1) team_id=%d" % team_id)
	_rpc_lobby_set_team.rpc_id(1, team_id)
	return true

func set_lobby_ready(ready: bool) -> bool:
	if not _can_send_server_rpc():
		_log("set_lobby_ready blocked can_send=false")
		return false
	_log("set_lobby_ready rpc_id(1) ready=%s" % str(ready))
	_rpc_lobby_set_ready.rpc_id(1, ready)
	return true

func set_lobby_add_bots(enabled: bool) -> bool:
	if not _can_send_server_rpc():
		_log("set_lobby_add_bots blocked can_send=false")
		return false
	_log("set_lobby_add_bots rpc_id(1) enabled=%s" % str(enabled))
	_rpc_lobby_set_add_bots.rpc_id(1, enabled)
	return true

func set_lobby_show_starting_animation(enabled: bool) -> bool:
	if not _can_send_server_rpc():
		_log("set_lobby_show_starting_animation blocked can_send=false")
		return false
	_log("set_lobby_show_starting_animation rpc_id(1) enabled=%s" % str(enabled))
	_rpc_lobby_set_show_starting_animation.rpc_id(1, enabled)
	return true

func set_lobby_skull_ruleset(ruleset_id: String) -> bool:
	if not _can_send_server_rpc():
		_log("set_lobby_skull_ruleset blocked can_send=false")
		return false
	var normalized := ruleset_id.strip_edges().to_lower()
	if normalized.is_empty():
		normalized = "kill_race"
	_log("set_lobby_skull_ruleset rpc_id(1) ruleset=%s" % normalized)
	_rpc_lobby_set_skull_ruleset.rpc_id(1, normalized)
	return true

func set_lobby_skull_target_score(target_score: int) -> bool:
	if not _can_send_server_rpc():
		_log("set_lobby_skull_target_score blocked can_send=false")
		return false
	var resolved := clampi(target_score, 1, 100)
	_log("set_lobby_skull_target_score rpc_id(1) target=%d" % resolved)
	_rpc_lobby_set_skull_target_score.rpc_id(1, resolved)
	return true

func set_lobby_skull_time_limit_sec(time_limit_sec: int) -> bool:
	if not _can_send_server_rpc():
		_log("set_lobby_skull_time_limit_sec blocked can_send=false")
		return false
	var resolved := clampi(time_limit_sec, 30, 3600)
	_log("set_lobby_skull_time_limit_sec rpc_id(1) seconds=%d" % resolved)
	_rpc_lobby_set_skull_time_limit_sec.rpc_id(1, resolved)
	return true

func start_lobby_match() -> bool:
	if not _can_send_server_rpc():
		_log("start_lobby_match blocked can_send=false")
		return false
	_log("start_lobby_match rpc_id(1)")
	_rpc_lobby_start_match.rpc_id(1)
	return true

func set_display_name(display_name: String) -> bool:
	if not _can_send_server_rpc():
		_log("set_display_name blocked can_send=false")
		return false
	var trimmed := display_name.strip_edges()
	if trimmed.is_empty():
		return false
	_log("set_display_name rpc_id(1) name=%s" % trimmed)
	_rpc_lobby_set_display_name.rpc_id(1, trimmed)
	return true

func send_lobby_chat_message(message: String) -> bool:
	if not _can_send_server_rpc():
		_log("send_lobby_chat_message blocked can_send=false")
		return false
	var trimmed := message.strip_edges()
	if trimmed.is_empty():
		return false
	if trimmed.length() > 140:
		trimmed = trimmed.substr(0, 140)
	_log("send_lobby_chat_message rpc_id(1) active_lobby_id=%d chars=%d" % [_active_lobby_id, trimmed.length()])
	_rpc_lobby_chat_send.rpc_id(1, trimmed)
	return true

func set_warrior_skin(skin_index: int) -> bool:
	if not _can_send_server_rpc():
		_log("set_warrior_skin blocked can_send=false")
		return false
	var resolved := maxi(0, skin_index)
	_log("set_warrior_skin rpc_id(1) skin_index=%d" % resolved)
	_rpc_lobby_set_skin.rpc_id(1, resolved)
	return true

func set_weapon_skin(skin_index: int) -> bool:
	if not _can_send_server_rpc():
		_log("set_weapon_skin blocked can_send=false")
		return false
	var resolved := maxi(0, skin_index)
	_log("set_weapon_skin rpc_id(1) skin_index=%d" % resolved)
	_rpc_lobby_set_weapon_skin.rpc_id(1, resolved)
	return true

func can_send_lobby_rpc() -> bool:
	return _can_send_server_rpc()

func _can_send_server_rpc() -> bool:
	if not is_connected_to_server():
		return false
	var mp := multiplayer
	if mp == null:
		return false
	var local_peer_id := mp.get_unique_id()
	if local_peer_id <= 0:
		return false
	if local_peer_id == 1:
		return false
	return true

func _bind_multiplayer_signals() -> void:
	var mp := multiplayer
	if mp == null:
		return
	if not mp.connected_to_server.is_connected(_on_connected_to_server):
		mp.connected_to_server.connect(_on_connected_to_server)
	if not mp.connection_failed.is_connected(_on_connection_failed):
		mp.connection_failed.connect(_on_connection_failed)
	if not mp.server_disconnected.is_connected(_on_server_disconnected):
		mp.server_disconnected.connect(_on_server_disconnected)

func _on_connected_to_server() -> void:
	_is_connected = true
	_log("signal connected_to_server local_peer_id=%d host=%s port=%d" % [multiplayer.get_unique_id(), _last_host, _last_port])
	connected_to_lobby_server.emit()

func _on_connection_failed() -> void:
	_is_connected = false
	_log("signal connection_failed host=%s port=%d" % [_last_host, _last_port])
	lobby_connection_failed.emit()

func _on_server_disconnected() -> void:
	_is_connected = false
	_log("signal server_disconnected host=%s port=%d" % [_last_host, _last_port])
	lobby_server_disconnected.emit()

@rpc("any_peer", "reliable")
func _rpc_request_spawn() -> void:
	pass

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
	pass

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
	pass

@rpc("any_peer", "reliable")
func _rpc_lobby_create(_requested_name: String, _payload: String) -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_lobby_join(_lobby_id: int, _weapon_id: String, _character_id: String = "") -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_lobby_leave(_legacy_a: Variant = null, _legacy_b: Variant = null) -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_lobby_set_weapon(_peer_or_weapon: Variant, _weapon_id: String = "") -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_lobby_set_weapon_skin(_skin_index: int) -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_lobby_set_character(_character_id: String) -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_lobby_set_skin(_skin_index: int) -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_lobby_set_display_name(_display_name: String) -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_lobby_chat_send(_message: String) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_lobby_list(_entries: Array, _active_lobby_id: int) -> void:
	_log("rpc lobby_list entries=%d active_lobby_id=%d" % [_entries.size(), _active_lobby_id])
	self._active_lobby_id = _active_lobby_id
	_lobby_mode_by_id.clear()
	for entry_value in _entries:
		if not (entry_value is Dictionary):
			continue
		var entry := entry_value as Dictionary
		var lobby_id := int(entry.get("id", 0))
		if lobby_id <= 0:
			continue
		_lobby_mode_by_id[lobby_id] = _map_flow_service.normalize_mode_id(str(entry.get("mode_id", "deathmatch")))
		if lobby_id == _active_lobby_id:
			_log("rpc lobby_list active_lobby_mode=%s raw_entry=%s" % [str(_lobby_mode_by_id[lobby_id]), str(entry)])
	lobby_list_received.emit(_entries, _active_lobby_id)

@rpc("authority", "reliable")
func _rpc_lobby_action_result(_success: bool, _message: String, _active_lobby_id: int, _map_id: String, _lobby_scene_mode: bool) -> void:
	_log("rpc lobby_action_result success=%s active_lobby_id=%d map_id=%s pending_mode=%s known_active_mode=%s message=%s" % [
		str(_success),
		_active_lobby_id,
		_map_id,
		_pending_mode_id,
		str(_lobby_mode_by_id.get(_active_lobby_id, "unknown")),
		_message
	])
	self._active_lobby_id = _active_lobby_id
	lobby_action_result_received.emit(_success, _message, _active_lobby_id, _map_id)

@rpc("authority", "reliable")
func _rpc_lobby_room_state(_payload: Dictionary) -> void:
	_log("rpc lobby_room_state payload=%s" % str(_payload))
	lobby_room_state_received.emit(_payload)

@rpc("authority", "reliable")
func _rpc_lobby_chat_message(_lobby_id: int, _peer_id: int, _display_name: String, _message: String) -> void:
	lobby_chat_received.emit(_lobby_id, _peer_id, _display_name, _message)

@rpc("authority", "reliable")
func _rpc_scene_switch_to_map(_map_id: String) -> void:
	var tree := get_tree()
	var default_map_id := _map_flow_service.normalize_map_id(_map_catalog, _map_catalog.default_map_id())
	var normalized := str(_map_id).strip_edges().to_lower()
	if normalized.is_empty():
		normalized = default_map_id
	normalized = _map_flow_service.normalize_map_id(_map_catalog, normalized)
	var scene_path := _map_catalog.scene_path_for_id(normalized)
	if scene_path.is_empty():
		scene_path = _map_catalog.scene_path_for_id(default_map_id)
	var mode_id := _map_flow_service.normalize_mode_id(str(_lobby_mode_by_id.get(_active_lobby_id, _pending_mode_id)))
	ProjectSettings.set_setting("kw/pending_game_mode", mode_id)
	_log("scene_switch source=SERVER_LOBBY map_id=%s mode=%s scene=%s" % [normalized, mode_id, scene_path])
	if tree != null:
		_release_game_root_before_scene_change()
		tree.call_deferred("change_scene_to_file", scene_path)
		_begin_rpc_root_handoff()

@rpc("authority", "unreliable_ordered")
func _rpc_sync_battle_royale_zone(_center: Vector2, _radius: float) -> void:
	pass

@rpc("authority", "unreliable_ordered")
func _rpc_sync_skull_time_remaining(_remaining_sec: float) -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_lobby_set_team(_team_id: int) -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_lobby_set_ready(_ready: bool) -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_lobby_set_add_bots(_enabled: bool) -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_lobby_set_show_starting_animation(_enabled: bool) -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_lobby_set_skull_ruleset(_ruleset_id: String) -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_lobby_set_skull_target_score(_target_score: int) -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_lobby_set_skull_time_limit_sec(_time_limit_sec: int) -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_lobby_start_match() -> void:
	pass

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
func _rpc_skull_match_intro(_participant_peer_ids: Array, _duration_sec: float) -> void:
	pass

func _begin_rpc_root_handoff() -> void:
	var tree := get_tree()
	if tree == null:
		call_deferred("queue_free")
		return
	_rpc_handoff_attempts = 0
	tree.process_frame.connect(Callable(self, "_complete_rpc_root_handoff"), CONNECT_ONE_SHOT)

func _release_game_root_before_scene_change() -> void:
	if name == "GameRoot":
		name = "LobbyRpcBridge"

func _complete_rpc_root_handoff() -> void:
	var tree := get_tree()
	if tree == null:
		queue_free()
		return
	var root := tree.root
	var current := tree.current_scene
	if root == null or current == null or current == self or current.get_parent() != root:
		_rpc_handoff_attempts += 1
		if _rpc_handoff_attempts >= 30:
			queue_free()
			return
		tree.process_frame.connect(Callable(self, "_complete_rpc_root_handoff"), CONNECT_ONE_SHOT)
		return
	queue_free()
