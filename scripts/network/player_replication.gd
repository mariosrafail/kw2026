extends RefCounted
class_name PlayerReplication

var players: Dictionary = {}
var input_states: Dictionary = {}
var fire_cooldowns: Dictionary = {}
var player_history: Dictionary = {}
var input_rate_window_start_ms: Dictionary = {}
var input_rate_counts: Dictionary = {}
var spawn_slots: Dictionary = {}
var player_stats: Dictionary = {}
var player_display_names: Dictionary = {}

var max_input_packets_per_sec := 120
var max_reported_rtt_ms := 300
var local_reconcile_snap_distance := 180.0
var local_reconcile_vertical_snap_distance := 6.0
var local_reconcile_pos_blend := 0.18
var local_reconcile_vel_blend := 0.35

var get_peer_lobby_cb: Callable = Callable()
var get_lobby_members_cb: Callable = Callable()
var ensure_player_display_name_cb: Callable = Callable()
var spawn_position_for_peer_cb: Callable = Callable()
var random_spawn_position_cb: Callable = Callable()
var default_input_state_cb: Callable = Callable()
var spawn_player_local_cb: Callable = Callable()
var send_spawn_player_cb: Callable = Callable()
var send_despawn_player_all_cb: Callable = Callable()
var send_despawn_player_to_peer_cb: Callable = Callable()
var send_sync_player_state_cb: Callable = Callable()
var send_sync_player_stats_cb: Callable = Callable()
var append_log_cb: Callable = Callable()

func configure(state_refs: Dictionary, callbacks: Dictionary, config: Dictionary = {}) -> void:
	players = state_refs.get("players", {}) as Dictionary
	input_states = state_refs.get("input_states", {}) as Dictionary
	fire_cooldowns = state_refs.get("fire_cooldowns", {}) as Dictionary
	player_history = state_refs.get("player_history", {}) as Dictionary
	input_rate_window_start_ms = state_refs.get("input_rate_window_start_ms", {}) as Dictionary
	input_rate_counts = state_refs.get("input_rate_counts", {}) as Dictionary
	spawn_slots = state_refs.get("spawn_slots", {}) as Dictionary
	player_stats = state_refs.get("player_stats", {}) as Dictionary
	player_display_names = state_refs.get("player_display_names", {}) as Dictionary

	get_peer_lobby_cb = callbacks.get("get_peer_lobby", Callable()) as Callable
	get_lobby_members_cb = callbacks.get("get_lobby_members", Callable()) as Callable
	ensure_player_display_name_cb = callbacks.get("ensure_player_display_name", Callable()) as Callable
	spawn_position_for_peer_cb = callbacks.get("spawn_position_for_peer", Callable()) as Callable
	random_spawn_position_cb = callbacks.get("random_spawn_position", Callable()) as Callable
	default_input_state_cb = callbacks.get("default_input_state", Callable()) as Callable
	spawn_player_local_cb = callbacks.get("spawn_player_local", Callable()) as Callable
	send_spawn_player_cb = callbacks.get("send_spawn_player", Callable()) as Callable
	send_despawn_player_all_cb = callbacks.get("send_despawn_player_all", Callable()) as Callable
	send_despawn_player_to_peer_cb = callbacks.get("send_despawn_player_to_peer", Callable()) as Callable
	send_sync_player_state_cb = callbacks.get("send_sync_player_state", Callable()) as Callable
	send_sync_player_stats_cb = callbacks.get("send_sync_player_stats", Callable()) as Callable
	append_log_cb = callbacks.get("append_log", Callable()) as Callable

	max_input_packets_per_sec = int(config.get("max_input_packets_per_sec", max_input_packets_per_sec))
	max_reported_rtt_ms = int(config.get("max_reported_rtt_ms", max_reported_rtt_ms))
	local_reconcile_snap_distance = float(config.get("local_reconcile_snap_distance", local_reconcile_snap_distance))
	local_reconcile_vertical_snap_distance = float(config.get("local_reconcile_vertical_snap_distance", local_reconcile_vertical_snap_distance))
	local_reconcile_pos_blend = float(config.get("local_reconcile_pos_blend", local_reconcile_pos_blend))
	local_reconcile_vel_blend = float(config.get("local_reconcile_vel_blend", local_reconcile_vel_blend))

func ensure_player_stats(peer_id: int) -> Dictionary:
	if player_stats.has(peer_id):
		return player_stats[peer_id] as Dictionary

	var stats := {
		"kills": 0,
		"deaths": 0
	}
	player_stats[peer_id] = stats
	return stats

func server_sync_player_stats(peer_id: int, target_peer_id: int = 0) -> void:
	if not send_sync_player_stats_cb.is_valid():
		return
	var stats := ensure_player_stats(peer_id)
	var kills := int(stats.get("kills", 0))
	var deaths := int(stats.get("deaths", 0))
	if target_peer_id > 0:
		send_sync_player_stats_cb.call(target_peer_id, peer_id, kills, deaths)
		return
	var lobby_id := _peer_lobby(peer_id)
	for member_value in _lobby_members(lobby_id):
		send_sync_player_stats_cb.call(int(member_value), peer_id, kills, deaths)

func server_register_kill_death(attacker_peer_id: int, target_peer_id: int) -> void:
	var target_stats := ensure_player_stats(target_peer_id)
	target_stats["deaths"] = int(target_stats.get("deaths", 0)) + 1
	player_stats[target_peer_id] = target_stats
	server_sync_player_stats(target_peer_id)

	if attacker_peer_id > 0 and attacker_peer_id != target_peer_id:
		var attacker_stats := ensure_player_stats(attacker_peer_id)
		attacker_stats["kills"] = int(attacker_stats.get("kills", 0)) + 1
		player_stats[attacker_peer_id] = attacker_stats
		server_sync_player_stats(attacker_peer_id)

func server_broadcast_player_state(peer_id: int, player: NetPlayer) -> void:
	if not send_sync_player_state_cb.is_valid():
		return
	var lobby_id := _peer_lobby(peer_id)
	if lobby_id <= 0:
		return
	for member_value in _lobby_members(lobby_id):
		send_sync_player_state_cb.call(
			int(member_value),
			peer_id,
			player.global_position,
			player.velocity,
			player.get_aim_angle(),
			player.get_health()
		)

func server_respawn_player(peer_id: int, player: NetPlayer) -> void:
	var respawn_position := _random_spawn_position()
	player.force_respawn(respawn_position)
	player.set_health(100)
	var state: Dictionary = _default_input_state()
	state["aim_world"] = respawn_position + Vector2.RIGHT * 160.0
	input_states[peer_id] = state
	fire_cooldowns[peer_id] = 0.0
	player.set_aim_world(state["aim_world"] as Vector2)

func server_remove_player(peer_id: int, target_peers: Array, connected_peers: PackedInt32Array, server_peer_id: int) -> void:
	if not players.has(peer_id):
		return

	var player := players[peer_id] as NetPlayer
	if is_instance_valid(player):
		player.queue_free()
	players.erase(peer_id)
	input_states.erase(peer_id)
	fire_cooldowns.erase(peer_id)
	player_history.erase(peer_id)
	input_rate_window_start_ms.erase(peer_id)
	input_rate_counts.erase(peer_id)
	spawn_slots.erase(peer_id)
	player_stats.erase(peer_id)
	player_display_names.erase(peer_id)

	if target_peers.is_empty():
		if send_despawn_player_all_cb.is_valid():
			send_despawn_player_all_cb.call(peer_id)
		return

	if not send_despawn_player_to_peer_cb.is_valid():
		return
	for target_value in target_peers:
		var target_id := int(target_value)
		if target_id != server_peer_id and not connected_peers.has(target_id):
			continue
		send_despawn_player_to_peer_cb.call(target_id, peer_id)

func server_send_existing_lobby_players_to_peer(peer_id: int, lobby_id: int) -> void:
	if not send_spawn_player_cb.is_valid():
		return
	for member_value in _lobby_members(lobby_id):
		var member_id := int(member_value)
		if member_id == peer_id:
			continue
		var player := players.get(member_id, null) as NetPlayer
		if player == null:
			continue
		send_spawn_player_cb.call(peer_id, member_id, player.global_position, _player_display_name(member_id))

func server_send_lobby_stats_to_peer(peer_id: int, lobby_id: int) -> void:
	for member_value in _lobby_members(lobby_id):
		var member_id := int(member_value)
		if player_stats.has(member_id):
			server_sync_player_stats(member_id, peer_id)

func server_spawn_peer_if_needed(peer_id: int, lobby_id: int) -> void:
	if lobby_id <= 0:
		return
	var members := _lobby_members(lobby_id)
	if players.has(peer_id):
		var existing_player := players[peer_id] as NetPlayer
		if existing_player != null:
			var display_name_resync := _player_display_name(peer_id)
			for member_value in members:
				if send_spawn_player_cb.is_valid():
					send_spawn_player_cb.call(int(member_value), peer_id, existing_player.global_position, display_name_resync)
			server_send_existing_lobby_players_to_peer(peer_id, lobby_id)
			server_send_lobby_stats_to_peer(peer_id, lobby_id)
		return

	var spawn_position := _spawn_position_for_peer(peer_id)
	if spawn_player_local_cb.is_valid():
		spawn_player_local_cb.call(peer_id, spawn_position)
	var display_name := _player_display_name(peer_id)
	ensure_player_stats(peer_id)
	var state: Dictionary = _default_input_state()
	state["aim_world"] = spawn_position + Vector2.RIGHT * 160.0
	input_states[peer_id] = state
	fire_cooldowns[peer_id] = 0.0
	for member_value in members:
		if send_spawn_player_cb.is_valid():
			send_spawn_player_cb.call(int(member_value), peer_id, spawn_position, display_name)
	server_send_existing_lobby_players_to_peer(peer_id, lobby_id)
	server_send_lobby_stats_to_peer(peer_id, lobby_id)
	for member_value in members:
		var member_id := int(member_value)
		if member_id != peer_id:
			server_sync_player_stats(peer_id, member_id)
	server_sync_player_stats(peer_id)
	if append_log_cb.is_valid():
		append_log_cb.call("Spawned player %d in lobby %d." % [peer_id, lobby_id])

func server_accept_input_packet(peer_id: int) -> bool:
	var now := Time.get_ticks_msec()
	var window_start := int(input_rate_window_start_ms.get(peer_id, 0))
	var count := int(input_rate_counts.get(peer_id, 0))
	if window_start == 0 or now - window_start >= 1000:
		window_start = now
		count = 0

	count += 1
	input_rate_window_start_ms[peer_id] = window_start
	input_rate_counts[peer_id] = count
	return count <= max_input_packets_per_sec

func server_submit_input(
	peer_id: int,
	axis: float,
	jump_pressed: bool,
	jump_held: bool,
	aim_world: Vector2,
	shoot_held: bool,
	boost_damage: bool,
	reported_rtt_ms: int,
	active_weapon: WeaponProfile
) -> bool:
	if not players.has(peer_id):
		return false
	if _peer_lobby(peer_id) <= 0:
		return false
	if not server_accept_input_packet(peer_id):
		return false

	var player := players.get(peer_id, null) as NetPlayer
	if player == null:
		return false
	if active_weapon == null:
		return false

	var state: Dictionary = input_states.get(peer_id, _default_input_state()) as Dictionary
	var previous_jump_held := bool(state.get("jump_held", false))
	var inferred_jump_pressed := jump_held and not previous_jump_held
	state["axis"] = clamp(axis, -1.0, 1.0)
	state["jump_pressed"] = bool(state.get("jump_pressed", false)) or jump_pressed or inferred_jump_pressed
	state["jump_held"] = jump_held
	state["aim_world"] = active_weapon.clamp_aim_world(player.global_position, aim_world)
	state["shoot_held"] = shoot_held
	state["boost_damage"] = boost_damage
	state["reported_rtt_ms"] = clampi(reported_rtt_ms, 0, max_reported_rtt_ms)
	state["last_packet_msec"] = Time.get_ticks_msec()
	input_states[peer_id] = state
	return true

func client_apply_state_snapshot(
	peer_id: int,
	new_position: Vector2,
	new_velocity: Vector2,
	aim_angle: float,
	health: int,
	local_peer_id: int
) -> void:
	var player := players.get(peer_id, null) as NetPlayer
	if player == null:
		if spawn_player_local_cb.is_valid():
			spawn_player_local_cb.call(peer_id, new_position)
		player = players.get(peer_id, null) as NetPlayer
		if player == null:
			return

	if peer_id == local_peer_id:
		player.set_health(health)
		var prev_position := player.global_position
		var delta_pos := new_position - player.global_position
		var vertical_error := absf(delta_pos.y)
		var has_vertical_direction_conflict := (
			absf(player.velocity.y) > 1.0
			and absf(new_velocity.y) > 1.0
			and signf(player.velocity.y) != signf(new_velocity.y)
		)
		var should_hard_snap := (
			delta_pos.length() > local_reconcile_snap_distance
			or vertical_error >= local_reconcile_vertical_snap_distance
			or has_vertical_direction_conflict
		)
		if should_hard_snap:
			player.global_position = new_position
			player.velocity = new_velocity
		else:
			player.global_position = player.global_position.lerp(new_position, local_reconcile_pos_blend)
			player.velocity = player.velocity.lerp(new_velocity, local_reconcile_vel_blend)
		var applied_delta := player.global_position - prev_position
		if applied_delta.length_squared() > 0.0001:
			if new_velocity.y < -1.0:
				applied_delta = Vector2(applied_delta.x, applied_delta.y * 0.3)
			player.apply_visual_correction(-applied_delta)
		return

	player.apply_snapshot(new_position, new_velocity, aim_angle, health)

func _default_input_state() -> Dictionary:
	if default_input_state_cb.is_valid():
		return (default_input_state_cb.call() as Dictionary).duplicate(true)
	return {
		"axis": 0.0,
		"jump_pressed": false,
		"jump_held": false,
		"aim_world": Vector2.ZERO,
		"shoot_held": false,
		"boost_damage": false,
		"reported_rtt_ms": 0,
		"last_packet_msec": 0
	}

func _peer_lobby(peer_id: int) -> int:
	if get_peer_lobby_cb.is_valid():
		return int(get_peer_lobby_cb.call(peer_id))
	return 0

func _lobby_members(lobby_id: int) -> Array:
	if get_lobby_members_cb.is_valid():
		return get_lobby_members_cb.call(lobby_id) as Array
	return []

func _player_display_name(peer_id: int) -> String:
	if ensure_player_display_name_cb.is_valid():
		return str(ensure_player_display_name_cb.call(peer_id))
	return "Player %d" % peer_id

func _spawn_position_for_peer(peer_id: int) -> Vector2:
	if spawn_position_for_peer_cb.is_valid():
		return spawn_position_for_peer_cb.call(peer_id) as Vector2
	return Vector2.ZERO

func _random_spawn_position() -> Vector2:
	if random_spawn_position_cb.is_valid():
		return random_spawn_position_cb.call() as Vector2
	return Vector2.ZERO
