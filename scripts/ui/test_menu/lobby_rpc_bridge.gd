extends Node

const MAP_CATALOG_SCRIPT := preload("res://scripts/world/map_catalog.gd")

signal connected_to_lobby_server
signal lobby_connection_failed
signal lobby_server_disconnected
signal lobby_list_received(entries: Array, active_lobby_id: int)
signal lobby_action_result_received(success: bool, message: String, active_lobby_id: int, map_id: String)

var _is_connected := false
var _last_host := "127.0.0.1"
var _last_port := 8080
var _map_catalog = MAP_CATALOG_SCRIPT.new()

func ensure_attached(tree: SceneTree) -> void:
	if tree == null:
		return
	var root := tree.root
	if root == null:
		return
	if get_parent() != root:
		if get_parent() != null:
			get_parent().remove_child(self)
		name = "Main3"
		root.add_child(self)
	_bind_multiplayer_signals()

func connect_to_server(host: String = "127.0.0.1", port: int = 8080) -> void:
	_last_host = host.strip_edges()
	if _last_host.is_empty():
		_last_host = "127.0.0.1"
	_last_port = clampi(port, 1, 65535)

	var mp := multiplayer
	if mp == null:
		lobby_connection_failed.emit()
		return

	if mp.multiplayer_peer != null:
		var status := mp.multiplayer_peer.get_connection_status()
		var local_peer_id := mp.get_unique_id()
		if status == MultiplayerPeer.CONNECTION_CONNECTED and local_peer_id > 1:
			_is_connected = true
			connected_to_lobby_server.emit()
			return
		mp.multiplayer_peer.close()
		mp.multiplayer_peer = null

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(_last_host, _last_port)
	if err != OK:
		lobby_connection_failed.emit()
		return
	mp.multiplayer_peer = peer

func disconnect_from_server() -> void:
	var mp := multiplayer
	if mp != null and mp.multiplayer_peer != null:
		mp.multiplayer_peer.close()
		mp.multiplayer_peer = null
	_is_connected = false

func is_connected_to_server() -> bool:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return false
	return multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func request_lobby_list() -> bool:
	if not _can_send_server_rpc():
		return false
	_rpc_request_lobby_list.rpc_id(1)
	return true

func create_lobby(lobby_name: String, weapon_id: String, character_id: String, map_id: String = "classic") -> bool:
	if not _can_send_server_rpc():
		return false
	var normalized_weapon := weapon_id.strip_edges().to_lower()
	if normalized_weapon.is_empty():
		normalized_weapon = "ak47"
	var normalized_character := character_id.strip_edges().to_lower()
	if normalized_character != "erebus" and normalized_character != "tasko":
		normalized_character = "outrage"
	var normalized_map := map_id.strip_edges().to_lower()
	if normalized_map.is_empty():
		normalized_map = "classic"
	var payload := "%s|%s|%s" % [normalized_weapon, normalized_character, normalized_map]
	_rpc_lobby_create.rpc_id(1, lobby_name.strip_edges(), payload)
	return true

func join_lobby(lobby_id: int, weapon_id: String, character_id: String) -> bool:
	if not _can_send_server_rpc():
		return false
	var normalized_weapon := weapon_id.strip_edges().to_lower()
	if normalized_weapon.is_empty():
		normalized_weapon = "ak47"
	var normalized_character := character_id.strip_edges().to_lower()
	if normalized_character != "erebus" and normalized_character != "tasko":
		normalized_character = "outrage"
	_rpc_lobby_join.rpc_id(1, lobby_id, normalized_weapon, normalized_character)
	return true

func leave_lobby() -> bool:
	if not _can_send_server_rpc():
		return false
	_rpc_lobby_leave.rpc_id(1)
	return true

func set_display_name(display_name: String) -> bool:
	if not _can_send_server_rpc():
		return false
	var trimmed := display_name.strip_edges()
	if trimmed.is_empty():
		return false
	_rpc_lobby_set_display_name.rpc_id(1, trimmed)
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
	connected_to_lobby_server.emit()

func _on_connection_failed() -> void:
	_is_connected = false
	lobby_connection_failed.emit()

func _on_server_disconnected() -> void:
	_is_connected = false
	lobby_server_disconnected.emit()

@rpc("any_peer", "reliable")
func _rpc_request_spawn() -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_request_reload() -> void:
	pass

@rpc("authority", "reliable")
func _rpc_spawn_player(_peer_id: int, _spawn_position: Vector2, _display_name: String = "", _weapon_id: String = "", _character_id: String = "", _skin_index: int = 0) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_despawn_player(_peer_id: int) -> void:
	pass

@rpc("authority", "unreliable_ordered")
func _rpc_sync_player_state(_peer_id: int, _new_position: Vector2, _new_velocity: Vector2, _aim_angle: float, _health: int) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_sync_player_stats(_peer_id: int, _kills: int, _deaths: int) -> void:
	pass

@rpc("any_peer", "unreliable_ordered")
func _rpc_submit_input(_axis: float, _jump_pressed: bool, _jump_held: bool, _aim_world: Vector2, _shoot_held: bool, _boost_or_rtt: Variant, _reported_rtt_ms: int = -1) -> void:
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

@rpc("authority", "reliable")
func _rpc_despawn_projectile(_projectile_id: int) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_projectile_impact(_projectile_id: int, _impact_position: Vector2, _legacy_trail_start_position: Vector2 = Vector2.ZERO) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_spawn_blood_particles(_impact_position: Vector2, _incoming_velocity: Vector2) -> void:
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
func _rpc_sync_player_weapon(_peer_id: int, _weapon_id: String) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_play_death_sfx(_impact_position: Vector2) -> void:
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
func _rpc_lobby_set_character(_character_id: String) -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_lobby_set_skin(_skin_index: int) -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_lobby_set_display_name(_display_name: String) -> void:
	pass

@rpc("authority", "reliable")
func _rpc_lobby_list(entries: Array, active_lobby_id: int) -> void:
	lobby_list_received.emit(entries, active_lobby_id)

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
func _rpc_lobby_action_result(success: bool, message: String, active_lobby_id: int, map_id: String, _lobby_scene_mode: bool) -> void:
	lobby_action_result_received.emit(success, message, active_lobby_id, map_id)

@rpc("authority", "reliable")
func _rpc_scene_switch_to_map(map_id: String) -> void:
	var normalized := str(map_id).strip_edges().to_lower()
	if normalized.is_empty():
		normalized = "classic"
	var scene_path := _map_catalog.scene_path_for_id(normalized)
	if scene_path.is_empty():
		scene_path = "res://scenes/main.tscn"
	if name == "Main3":
		name = "LobbyRpcBridge"
	var tree := get_tree()
	if tree != null:
		tree.call_deferred("change_scene_to_file", scene_path)
	call_deferred("queue_free")

@rpc("any_peer", "reliable")
func _rpc_cast_skill1(_target_world: Vector2) -> void:
	pass

@rpc("any_peer", "reliable")
func _rpc_cast_skill2(_target_world: Vector2) -> void:
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
