extends Control

const DEFAULT_PORT := 8080
const MAX_CLIENTS := 8
const DEFAULT_HOST := "127.0.0.1"
const SNAPSHOT_RATE := 30.0
const INPUT_SEND_RATE := 60.0
const PING_INTERVAL := 0.75
const PROJECTILE_SPEED := 8000.0
const PROJECTILE_DAMAGE := 5
const FIRE_INTERVAL := 0.10
const FIRE_SPREAD_DEGREES := 3.5
const PLAYER_HISTORY_MS := 800
const MAX_INPUT_PACKETS_PER_SEC := 120
const MAX_REPORTED_RTT_MS := 300
const MAX_AIM_DISTANCE := 2600.0
const PROJECTILE_SPAWN_WALL_MARGIN := 4.0
const CLIENT_PROJECTILE_VISUAL_ADVANCE_MAX_MS := 220
const LOCAL_RECONCILE_SNAP_DISTANCE := 180.0
const LOCAL_RECONCILE_POS_BLEND := 0.18
const LOCAL_RECONCILE_VEL_BLEND := 0.35

const ARG_MODE_PREFIX := "--mode="
const ARG_HOST_PREFIX := "--host="
const ARG_PORT_PREFIX := "--port="
const ARG_NO_AUTOSTART := "--no-autostart"

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const PROJECTILE_SCENE := preload("res://scenes/entities/bullet.tscn")

@onready var port_spin: SpinBox = %PortSpin
@onready var host_input: LineEdit = %HostInput
@onready var start_server_button: Button = %StartServerButton
@onready var stop_button: Button = %StopButton
@onready var connect_button: Button = %ConnectButton
@onready var disconnect_button: Button = %DisconnectButton
@onready var status_label: Label = %StatusLabel
@onready var peers_label: Label = %PeersLabel
@onready var log_label: RichTextLabel = %LogLabel
@onready var local_ip_label: Label = %LocalIpLabel
@onready var ping_label: Label = %PingLabel
@onready var ui_panel: PanelContainer = $UiPanel
@onready var projectiles_root: Node2D = %Projectiles
@onready var players_root: Node2D = %Players
@onready var main_camera: Camera2D = %MainCamera

enum Role { NONE, SERVER, CLIENT }

var role: Role = Role.NONE
var startup_mode: Role = Role.NONE
var players: Dictionary = {}
var input_states: Dictionary = {}
var fire_cooldowns: Dictionary = {}
var player_history: Dictionary = {}
var input_rate_window_start_ms: Dictionary = {}
var input_rate_counts: Dictionary = {}
var spawn_slots: Dictionary = {}
var projectiles: Dictionary = {}
var next_spawn_slot: int = 0
var next_projectile_id: int = 1
var snapshot_accumulator := 0.0
var input_send_accumulator := 0.0
var auto_start_enabled := true
var ping_accumulator := 0.0
var last_ping_ms := -1
var cached_local_input_state: Dictionary = {}

func _ready() -> void:
	randomize()
	_ensure_input_actions()

	port_spin.value = DEFAULT_PORT
	host_input.text = DEFAULT_HOST
	startup_mode = Role.SERVER if OS.has_feature("editor") else Role.CLIENT
	auto_start_enabled = true
	_apply_startup_overrides()

	start_server_button.pressed.connect(_on_start_server_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	connect_button.pressed.connect(_on_connect_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_show_local_ip()
	_set_idle_state()
	_append_log("Ready.")
	_append_log("Boot config: mode=%s host=%s port=%d" % [_role_name(startup_mode), host_input.text, int(port_spin.value)])
	_auto_boot_from_environment()

func _physics_process(delta: float) -> void:
	if role == Role.SERVER and multiplayer.multiplayer_peer != null:
		_server_simulate(delta)
		_server_tick_projectiles(delta)

	if role == Role.CLIENT and multiplayer.multiplayer_peer != null:
		_client_predict_local_player(delta)
		_client_send_input(delta)
		_client_ping_tick(delta)
		_client_tick_projectiles(delta)

	_follow_local_player_camera(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif key_event.pressed and not key_event.echo and key_event.keycode == KEY_F4:
			_toggle_fullscreen()

func _toggle_fullscreen() -> void:
	var current_mode := DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _on_start_server_pressed() -> void:
	_start_server(int(port_spin.value))

func _on_connect_pressed() -> void:
	_start_client(host_input.text.strip_edges(), int(port_spin.value))

func _start_server(port: int) -> void:
	_close_peer()

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		_append_log("Server error: %s" % error_string(err))
		return

	multiplayer.multiplayer_peer = peer
	role = Role.SERVER
	_reset_runtime_state()

	status_label.text = "Status: Server running on port %d" % port
	_append_log("Server started on port %d." % port)
	_update_peer_labels()
	_update_buttons()
	_update_ping_label()
	_update_ui_visibility()

func _start_client(host: String, port: int) -> void:
	_close_peer()

	if host.is_empty():
		host = DEFAULT_HOST

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port)
	if err != OK:
		_append_log("Client error: %s" % error_string(err))
		return

	multiplayer.multiplayer_peer = peer
	role = Role.CLIENT
	_reset_runtime_state()

	status_label.text = "Status: Connecting to %s:%d..." % [host, port]
	_append_log("Connecting to %s:%d ..." % [host, port])
	_update_peer_labels()
	_update_buttons()
	_update_ping_label()
	_update_ui_visibility()

func _on_stop_pressed() -> void:
	_close_peer()
	_set_idle_state()
	_append_log("Server stopped.")

func _on_disconnect_pressed() -> void:
	_close_peer()
	_set_idle_state()
	_append_log("Disconnected.")

func _on_connected_to_server() -> void:
	status_label.text = "Status: Connected to server."
	_append_log("Connected to server. Requesting player spawn.")
	_reset_ping_state()
	_update_ping_label()
	_rpc_request_spawn.rpc_id(1)
	_update_peer_labels()
	_update_buttons()

func _on_connection_failed() -> void:
	_close_peer()
	_set_idle_state()
	_append_log("Connection failed.")

func _on_server_disconnected() -> void:
	_close_peer()
	_set_idle_state()
	_append_log("Server disconnected.")

func _on_peer_connected(id: int) -> void:
	_append_log("Peer connected: %d" % id)
	if multiplayer.is_server():
		_send_existing_players_to_peer(id)
	_update_peer_labels()

func _on_peer_disconnected(id: int) -> void:
	_append_log("Peer disconnected: %d" % id)
	if multiplayer.is_server():
		_server_remove_player(id)
	_update_peer_labels()

func _set_idle_state() -> void:
	role = Role.NONE
	status_label.text = "Status: Idle"
	_reset_ping_state()
	_update_peer_labels()
	_update_buttons()
	_update_ping_label()
	_update_ui_visibility()

func _close_peer() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	_reset_runtime_state()

func _reset_runtime_state() -> void:
	snapshot_accumulator = 0.0
	input_send_accumulator = 0.0
	input_states.clear()
	fire_cooldowns.clear()
	player_history.clear()
	input_rate_window_start_ms.clear()
	input_rate_counts.clear()
	spawn_slots.clear()
	next_spawn_slot = 0
	next_projectile_id = 1
	_reset_ping_state()
	_clear_players()
	_clear_projectiles()

func _clear_players() -> void:
	for value in players.values():
		var player := value as NetPlayer
		if is_instance_valid(player):
			player.queue_free()
	players.clear()

func _clear_projectiles() -> void:
	for value in projectiles.values():
		var projectile := value as NetProjectile
		if is_instance_valid(projectile):
			projectile.queue_free()
	projectiles.clear()

func _update_buttons() -> void:
	var has_active_session := role != Role.NONE
	var server_allowed := startup_mode != Role.CLIENT
	var client_allowed := startup_mode != Role.SERVER

	start_server_button.disabled = has_active_session or not server_allowed
	connect_button.disabled = has_active_session or not client_allowed
	stop_button.disabled = role != Role.SERVER
	disconnect_button.disabled = role != Role.CLIENT
	port_spin.editable = not has_active_session
	host_input.editable = not has_active_session and client_allowed

func _update_peer_labels() -> void:
	var net_peers_text := _peer_list_to_text(multiplayer.get_peers())
	var spawned_player_ids := players.keys()
	spawned_player_ids.sort()
	var players_text := "-"
	if not spawned_player_ids.is_empty():
		var player_parts := PackedStringArray()
		for id in spawned_player_ids:
			player_parts.append(str(id))
		players_text = ", ".join(player_parts)
	peers_label.text = "My peer id: %d | Net peers: %s | Players: %s | Ping: %s" % [
		multiplayer.get_unique_id(),
		net_peers_text,
		players_text,
		_local_ping_text()
	]

func _peer_list_to_text(ids: PackedInt32Array) -> String:
	if ids.is_empty():
		return "-"
	var parts := PackedStringArray()
	for id in ids:
		parts.append(str(id))
	return ", ".join(parts)

func _show_local_ip() -> void:
	var ips := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.contains(".") and not address.begins_with("127."):
			ips.append(address)
	if ips.is_empty():
		local_ip_label.text = "Local IP: 127.0.0.1"
	else:
		local_ip_label.text = "Local IP(s): %s" % ", ".join(ips)

func _append_log(message: String) -> void:
	log_label.append_text("%s\n" % message)
	log_label.scroll_to_line(max(log_label.get_line_count() - 1, 0))

func _apply_startup_overrides() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with(ARG_MODE_PREFIX):
			var mode_value := arg.substr(ARG_MODE_PREFIX.length()).to_lower()
			match mode_value:
				"server":
					startup_mode = Role.SERVER
				"client":
					startup_mode = Role.CLIENT
				"manual":
					startup_mode = Role.NONE
					auto_start_enabled = false
		elif arg.begins_with(ARG_HOST_PREFIX):
			var host_value := arg.substr(ARG_HOST_PREFIX.length()).strip_edges()
			if not host_value.is_empty():
				host_input.text = host_value
		elif arg.begins_with(ARG_PORT_PREFIX):
			var port_value := int(arg.substr(ARG_PORT_PREFIX.length()))
			if port_value >= 1 and port_value <= 65535:
				port_spin.value = port_value
		elif arg == ARG_NO_AUTOSTART:
			auto_start_enabled = false

func _auto_boot_from_environment() -> void:
	if not auto_start_enabled:
		_append_log("Autostart disabled. Use Start/Connect manually.")
		return

	if startup_mode == Role.SERVER:
		_append_log("Autostart: server mode.")
		_start_server(int(port_spin.value))
	elif startup_mode == Role.CLIENT:
		_append_log("Autostart: client mode.")
		_start_client(host_input.text.strip_edges(), int(port_spin.value))
	else:
		_append_log("Manual startup mode.")

func _reset_ping_state() -> void:
	ping_accumulator = 0.0
	last_ping_ms = -1

func _client_ping_tick(delta: float) -> void:
	if role != Role.CLIENT:
		return

	ping_accumulator += delta
	if ping_accumulator < PING_INTERVAL:
		return

	ping_accumulator = 0.0
	_rpc_ping_request.rpc_id(1, Time.get_ticks_msec())

func _update_ping_label() -> void:
	if ping_label == null:
		return
	ping_label.text = "Ping: %s" % _local_ping_text()

func _update_ui_visibility() -> void:
	ui_panel.visible = false
	ping_label.visible = role == Role.CLIENT

func _local_ping_text() -> String:
	if role == Role.SERVER:
		return "server"
	if role == Role.CLIENT:
		if last_ping_ms >= 0:
			return "%d ms" % last_ping_ms
		return "..."
	return "-"

func _role_name(value: Role) -> String:
	match value:
		Role.SERVER:
			return "server"
		Role.CLIENT:
			return "client"
		_:
			return "manual"

func _spawn_position_for_peer(peer_id: int) -> Vector2:
	var slot := _get_spawn_slot_for_peer(peer_id)
	return _spawn_position_for_slot(slot)

func _spawn_position_for_slot(slot: int) -> Vector2:
	var row := int(slot / 5)
	var column := int(slot % 5)
	return Vector2(220 + column * 90, 380 - row * 70)

func _get_spawn_slot_for_peer(peer_id: int) -> int:
	if spawn_slots.has(peer_id):
		return int(spawn_slots[peer_id])

	var assigned_slot := next_spawn_slot
	next_spawn_slot += 1
	spawn_slots[peer_id] = assigned_slot
	return assigned_slot

func _player_color(peer_id: int) -> Color:
	var hue := fmod(float(peer_id) * 0.173, 1.0)
	return Color.from_hsv(hue, 0.62, 0.95)

func _spawn_player(peer_id: int, spawn_position: Vector2) -> void:
	if players.has(peer_id):
		return

	var player := PLAYER_SCENE.instantiate() as NetPlayer
	player.global_position = spawn_position
	players_root.add_child(player)
	player.configure(peer_id, _player_color(peer_id))
	player.use_network_smoothing = role == Role.CLIENT and peer_id != multiplayer.get_unique_id()

	players[peer_id] = player
	_record_player_history(peer_id, spawn_position)
	_update_peer_labels()

func _server_fire_projectile(peer_id: int, player: NetPlayer, aim_world: Vector2) -> void:
	var desired_spawn_position := player.get_muzzle_world_position()
	var direction := aim_world - desired_spawn_position
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT.rotated(player.get_aim_angle())
	var shoot_direction := direction.normalized()
	var spread_radians := deg_to_rad(randf_range(-FIRE_SPREAD_DEGREES, FIRE_SPREAD_DEGREES))
	shoot_direction = shoot_direction.rotated(spread_radians)
	var spawn_position := _get_safe_projectile_spawn_position(player, desired_spawn_position, shoot_direction)
	var velocity := shoot_direction * PROJECTILE_SPEED
	var state: Dictionary = input_states.get(peer_id, _default_input_state()) as Dictionary
	var reported_rtt_ms := int(state.get("reported_rtt_ms", 0))
	var lag_comp_ms := int(clampi(reported_rtt_ms / 2, 0, MAX_REPORTED_RTT_MS / 2))
	var projectile_id := next_projectile_id
	next_projectile_id += 1
	_spawn_projectile(projectile_id, peer_id, spawn_position, velocity, lag_comp_ms, desired_spawn_position)
	player.play_shot_recoil()
	_rpc_spawn_projectile.rpc(projectile_id, peer_id, spawn_position, velocity, lag_comp_ms, desired_spawn_position)

func _get_safe_projectile_spawn_position(player: NetPlayer, desired_spawn_position: Vector2, shoot_direction: Vector2) -> Vector2:
	var base_position: Vector2 = player.global_position
	var toward_muzzle: Vector2 = desired_spawn_position - base_position
	if toward_muzzle.length_squared() <= 0.0001:
		toward_muzzle = shoot_direction * 20.0

	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(base_position, desired_spawn_position, 1)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired_spawn_position

	var hit_position: Vector2 = hit.get("position", desired_spawn_position) as Vector2
	var push_back_dir: Vector2 = toward_muzzle.normalized()
	var safe_spawn: Vector2 = hit_position - push_back_dir * PROJECTILE_SPAWN_WALL_MARGIN

	var max_distance_from_player: float = maxf(8.0, toward_muzzle.length() - PROJECTILE_SPAWN_WALL_MARGIN)
	var safe_delta: Vector2 = safe_spawn - base_position
	if safe_delta.length() > max_distance_from_player:
		safe_spawn = base_position + safe_delta.normalized() * max_distance_from_player

	return safe_spawn

func _spawn_projectile(projectile_id: int, owner_peer_id: int, spawn_position: Vector2, velocity: Vector2, lag_comp_ms: int, trail_origin: Vector2) -> NetProjectile:
	if projectiles.has(projectile_id):
		return projectiles[projectile_id] as NetProjectile

	var projectile := PROJECTILE_SCENE.instantiate() as NetProjectile
	if projectile == null:
		return null

	projectile.global_position = spawn_position
	projectiles_root.add_child(projectile)
	projectile.configure(_player_color(owner_peer_id), velocity, projectile_id, owner_peer_id, lag_comp_ms, trail_origin)
	projectiles[projectile_id] = projectile
	return projectile

func _despawn_projectile_local(projectile_id: int) -> void:
	if not projectiles.has(projectile_id):
		return
	var projectile := projectiles[projectile_id] as NetProjectile
	if is_instance_valid(projectile):
		projectile.queue_free()
	projectiles.erase(projectile_id)

func _despawn_projectile(projectile_id: int) -> void:
	_despawn_projectile_local(projectile_id)
	if multiplayer.is_server():
		_rpc_despawn_projectile.rpc(projectile_id)

func _projectile_impact(projectile_id: int, impact_position: Vector2) -> void:
	var projectile := projectiles.get(projectile_id, null) as NetProjectile
	if projectile == null:
		return
	var trail_start_position: Vector2 = projectile.get_trail_origin()
	projectile.mark_impact(impact_position, trail_start_position)
	if multiplayer.is_server():
		_rpc_projectile_impact.rpc(projectile_id, impact_position, trail_start_position)

func _server_tick_projectiles(delta: float) -> void:
	var ids := projectiles.keys()
	ids.sort()
	for id_value in ids:
		var projectile_id := int(id_value)
		var projectile: NetProjectile = projectiles.get(projectile_id, null) as NetProjectile
		if projectile == null:
			continue

		var previous_position := projectile.global_position
		projectile.step(delta)
		if not projectile.can_deal_damage():
			if projectile.is_expired():
				_despawn_projectile(projectile_id)
			continue

		var to_position := projectile.global_position
		var wall_hit: Dictionary = _server_projectile_world_hit(previous_position, to_position)
		var player_hit: Dictionary = _server_projectile_player_hit(projectile, previous_position, to_position)
		var wall_t := 2.0
		var player_t := 2.0
		if not wall_hit.is_empty():
			wall_t = float(wall_hit.get("t", 2.0))
		if not player_hit.is_empty():
			player_t = float(player_hit.get("t", 2.0))

		if not player_hit.is_empty() and player_t <= wall_t:
			var hit_position: Vector2 = player_hit.get("position", to_position) as Vector2
			projectile.global_position = hit_position
			var target_peer_id := int(player_hit.get("peer_id", -1))
			var target_player := players.get(target_peer_id, null) as NetPlayer
			if target_player != null:
				_server_apply_projectile_damage(projectile_id, target_peer_id, target_player)
			_projectile_impact(projectile_id, hit_position)
			continue

		if not wall_hit.is_empty():
			var wall_position: Vector2 = wall_hit.get("position", to_position) as Vector2
			projectile.global_position = wall_position
			_projectile_impact(projectile_id, wall_position)
			continue

		if projectile.is_expired():
			_despawn_projectile(projectile_id)

func _client_tick_projectiles(delta: float) -> void:
	var expired_ids: Array = []
	for value in projectiles.values():
		var projectile := value as NetProjectile
		if projectile == null:
			continue
		projectile.step(delta)
		if projectile.is_expired():
			expired_ids.append(projectile.projectile_id)

	for id_value in expired_ids:
		_despawn_projectile_local(int(id_value))

func _server_projectile_world_hit(from_position: Vector2, to_position: Vector2) -> Dictionary:
	if from_position.distance_squared_to(to_position) <= 0.000001:
		return {}

	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from_position, to_position, 1)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}

	var hit_position: Vector2 = hit.get("position", to_position) as Vector2
	var segment := to_position - from_position
	var segment_len_sq := segment.length_squared()
	var t := 1.0
	if segment_len_sq > 0.000001:
		t = clampf((hit_position - from_position).dot(segment) / segment_len_sq, 0.0, 1.0)
	hit["t"] = t
	return hit

func _server_projectile_player_hit(projectile: NetProjectile, from_position: Vector2, to_position: Vector2) -> Dictionary:
	var best_t := 2.0
	var best_peer_id := -1
	var best_position := to_position
	var segment := to_position - from_position
	var segment_len_sq := segment.length_squared()
	if segment_len_sq <= 0.000001:
		return {}

	for key in players.keys():
		var target_peer_id := int(key)
		if target_peer_id == projectile.owner_peer_id:
			continue

		var target_player := players[target_peer_id] as NetPlayer
		if target_player == null:
			continue

		var rewound_position := _get_player_rewound_position(target_peer_id, projectile.lag_comp_ms)
		var combined_radius := projectile.get_hit_radius() + target_player.get_hit_radius()
		var t := clampf((rewound_position - from_position).dot(segment) / segment_len_sq, 0.0, 1.0)
		var closest := from_position + segment * t
		if rewound_position.distance_squared_to(closest) <= combined_radius * combined_radius and t < best_t:
			best_t = t
			best_peer_id = target_peer_id
			best_position = closest

	if best_peer_id == -1:
		return {}
	return {
		"peer_id": best_peer_id,
		"position": best_position,
		"t": best_t
	}

func _get_player_rewound_position(peer_id: int, rewind_ms: int) -> Vector2:
	var target_player := players.get(peer_id, null) as NetPlayer
	if target_player == null:
		return Vector2.ZERO

	var history: Array = player_history.get(peer_id, [])
	if history.is_empty():
		return target_player.global_position

	var target_time: int = Time.get_ticks_msec() - maxi(0, rewind_ms)
	var older: Dictionary = history[0] as Dictionary
	var newer: Dictionary = history[history.size() - 1] as Dictionary

	for i in range(history.size() - 1):
		var current: Dictionary = history[i] as Dictionary
		var next: Dictionary = history[i + 1] as Dictionary
		var current_t := int(current.get("t", 0))
		var next_t := int(next.get("t", 0))
		if target_time >= current_t and target_time <= next_t:
			older = current
			newer = next
			break
		if target_time < current_t:
			older = current
			newer = current
			break

	var older_pos: Vector2 = older.get("p", target_player.global_position) as Vector2
	var newer_pos: Vector2 = newer.get("p", target_player.global_position) as Vector2
	var older_t := int(older.get("t", 0))
	var newer_t := int(newer.get("t", older_t))
	if newer_t <= older_t:
		return older_pos
	var alpha := clampf(float(target_time - older_t) / float(newer_t - older_t), 0.0, 1.0)
	return older_pos.lerp(newer_pos, alpha)

func _record_player_history(peer_id: int, position: Vector2) -> void:
	var history: Array = player_history.get(peer_id, [])
	var now := Time.get_ticks_msec()
	history.append({
		"t": now,
		"p": position
	})
	var min_time := now - PLAYER_HISTORY_MS
	while history.size() > 2 and int((history[0] as Dictionary).get("t", 0)) < min_time:
		history.remove_at(0)
	player_history[peer_id] = history

func _server_apply_projectile_damage(projectile_id: int, target_peer_id: int, target_player: NetPlayer) -> void:
	var remaining_health := target_player.apply_damage(PROJECTILE_DAMAGE)
	if remaining_health <= 0:
		_server_respawn_player(target_peer_id, target_player)

	_rpc_sync_player_state.rpc(
		target_peer_id,
		target_player.global_position,
		target_player.velocity,
		target_player.get_aim_angle(),
		target_player.get_health()
	)

func _server_respawn_player(peer_id: int, player: NetPlayer) -> void:
	var respawn_position := _random_spawn_position()
	player.force_respawn(respawn_position)
	player.set_health(100)
	var state: Dictionary = _default_input_state()
	state["aim_world"] = respawn_position + Vector2.RIGHT * 160.0
	input_states[peer_id] = state
	fire_cooldowns[peer_id] = 0.0
	player.set_aim_world(state["aim_world"] as Vector2)

func _random_spawn_position() -> Vector2:
	var slots: Array = spawn_slots.values()
	if slots.is_empty():
		return _spawn_position_for_slot(0)
	var random_index := int(randi() % slots.size())
	var random_slot := int(slots[random_index])
	return _spawn_position_for_slot(random_slot)

func _server_remove_player(peer_id: int) -> void:
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
	_rpc_despawn_player.rpc(peer_id)

func _send_existing_players_to_peer(peer_id: int) -> void:
	var player_ids := players.keys()
	player_ids.sort()
	for existing_id in player_ids:
		var player := players[existing_id] as NetPlayer
		if player == null:
			continue
		_rpc_spawn_player.rpc_id(peer_id, int(existing_id), player.global_position)

func _default_input_state() -> Dictionary:
	return {
		"axis": 0.0,
		"jump_pressed": false,
		"jump_held": false,
		"aim_world": Vector2.ZERO,
		"shoot_held": false,
		"reported_rtt_ms": 0
	}

func _read_local_input_state() -> Dictionary:
	var mouse_world := main_camera.get_global_mouse_position()
	return {
		"axis": Input.get_axis("move_left", "move_right"),
		"jump_pressed": Input.is_action_just_pressed("jump"),
		"jump_held": Input.is_action_pressed("jump"),
		"aim_world": mouse_world,
		"shoot_held": Input.is_action_pressed("shoot")
	}

func _server_simulate(delta: float) -> void:
	for key in players.keys():
		var peer_id := int(key)
		var player := players[peer_id] as NetPlayer
		if player == null:
			continue

		var state: Dictionary = input_states.get(peer_id, _default_input_state()) as Dictionary
		var aim_world: Vector2 = state.get("aim_world", player.global_position + Vector2.RIGHT * 160.0) as Vector2
		player.set_aim_world(aim_world)

		player.simulate_authoritative(
			delta,
			float(state.get("axis", 0.0)),
			bool(state.get("jump_pressed", false)),
			bool(state.get("jump_held", false))
		)
		_record_player_history(peer_id, player.global_position)
		var cooldown: float = float(fire_cooldowns.get(peer_id, 0.0))
		cooldown = maxf(cooldown - delta, 0.0)
		if bool(state.get("shoot_held", false)) and cooldown <= 0.0:
			_server_fire_projectile(peer_id, player, aim_world)
			cooldown = FIRE_INTERVAL
		fire_cooldowns[peer_id] = cooldown

		state["jump_pressed"] = false
		input_states[peer_id] = state

	snapshot_accumulator += delta
	if snapshot_accumulator >= 1.0 / SNAPSHOT_RATE:
		snapshot_accumulator = 0.0
		for key in players.keys():
			var peer_id := int(key)
			var player := players[peer_id] as NetPlayer
			if player == null:
				continue
			_rpc_sync_player_state.rpc(peer_id, player.global_position, player.velocity, player.get_aim_angle(), player.get_health())

func _client_send_input(delta: float) -> void:
	var local_id := multiplayer.get_unique_id()
	if not players.has(local_id):
		return

	var state: Dictionary = cached_local_input_state if not cached_local_input_state.is_empty() else _read_local_input_state()
	var local_player := players[local_id] as NetPlayer
	if local_player != null:
		local_player.set_aim_world(state.get("aim_world", local_player.global_position + Vector2.RIGHT * 120.0) as Vector2)

	input_send_accumulator += delta
	if input_send_accumulator < 1.0 / INPUT_SEND_RATE:
		return
	input_send_accumulator = 0.0

	_rpc_submit_input.rpc_id(
		1,
		float(state.get("axis", 0.0)),
		bool(state.get("jump_pressed", false)),
		bool(state.get("jump_held", false)),
		state.get("aim_world", Vector2.ZERO) as Vector2,
		bool(state.get("shoot_held", false)),
		last_ping_ms
	)

func _client_predict_local_player(delta: float) -> void:
	var local_id := multiplayer.get_unique_id()
	if local_id <= 0 or not players.has(local_id):
		return

	var local_player := players[local_id] as NetPlayer
	if local_player == null:
		return

	var state: Dictionary = _read_local_input_state()
	cached_local_input_state = state
	local_player.set_aim_world(state.get("aim_world", local_player.global_position + Vector2.RIGHT * 120.0) as Vector2)
	local_player.simulate_authoritative(
		delta,
		float(state.get("axis", 0.0)),
		bool(state.get("jump_pressed", false)),
		bool(state.get("jump_held", false))
	)

func _follow_local_player_camera(delta: float) -> void:
	var local_player: NetPlayer = players.get(multiplayer.get_unique_id(), null) as NetPlayer
	if local_player == null:
		return
	main_camera.global_position = main_camera.global_position.lerp(local_player.global_position, min(1.0, delta * 8.0))

@rpc("any_peer", "reliable")
func _rpc_request_spawn() -> void:
	if not multiplayer.is_server():
		return

	var peer_id := multiplayer.get_remote_sender_id()
	if players.has(peer_id):
		return

	var spawn_position := _spawn_position_for_peer(peer_id)
	_spawn_player(peer_id, spawn_position)
	var state: Dictionary = _default_input_state()
	state["aim_world"] = spawn_position + Vector2.RIGHT * 160.0
	input_states[peer_id] = state
	fire_cooldowns[peer_id] = 0.0
	_rpc_spawn_player.rpc(peer_id, spawn_position)
	_append_log("Spawned player %d." % peer_id)

@rpc("authority", "reliable")
func _rpc_spawn_player(peer_id: int, spawn_position: Vector2) -> void:
	_spawn_player(peer_id, spawn_position)
	_append_log("Spawn sync: player %d" % peer_id)

@rpc("authority", "reliable")
func _rpc_spawn_projectile(projectile_id: int, owner_peer_id: int, spawn_position: Vector2, velocity: Vector2, lag_comp_ms: int, trail_origin: Vector2) -> void:
	if multiplayer.is_server():
		return
	var projectile := _spawn_projectile(projectile_id, owner_peer_id, spawn_position, velocity, lag_comp_ms, trail_origin)
	if projectile == null:
		return
	var owner_player := players.get(owner_peer_id, null) as NetPlayer
	if owner_player != null:
		owner_player.play_shot_recoil()

	var local_visual_advance_ms := clampi(last_ping_ms / 2, 0, CLIENT_PROJECTILE_VISUAL_ADVANCE_MAX_MS)
	if owner_peer_id == multiplayer.get_unique_id():
		local_visual_advance_ms = clampi(local_visual_advance_ms + lag_comp_ms, 0, CLIENT_PROJECTILE_VISUAL_ADVANCE_MAX_MS)

	if local_visual_advance_ms > 0:
		projectile.step(float(local_visual_advance_ms) / 1000.0)

@rpc("authority", "reliable")
func _rpc_despawn_projectile(projectile_id: int) -> void:
	if multiplayer.is_server():
		return
	_despawn_projectile_local(projectile_id)

@rpc("authority", "reliable")
func _rpc_projectile_impact(projectile_id: int, impact_position: Vector2, trail_start_position: Vector2) -> void:
	if multiplayer.is_server():
		return
	var projectile := projectiles.get(projectile_id, null) as NetProjectile
	if projectile == null:
		return
	projectile.mark_impact(impact_position, trail_start_position)

@rpc("authority", "reliable")
func _rpc_despawn_player(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	var player := players[peer_id] as NetPlayer
	if is_instance_valid(player):
		player.queue_free()
	players.erase(peer_id)
	_update_peer_labels()

@rpc("any_peer", "unreliable_ordered")
func _rpc_submit_input(axis: float, jump_pressed: bool, jump_held: bool, aim_world: Vector2, shoot_held: bool, reported_rtt_ms: int) -> void:
	if not multiplayer.is_server():
		return

	var peer_id := multiplayer.get_remote_sender_id()
	if not players.has(peer_id):
		return
	if not _server_accept_input_packet(peer_id):
		return

	var player := players[peer_id] as NetPlayer
	if player == null:
		return

	var state: Dictionary = input_states.get(peer_id, _default_input_state()) as Dictionary
	state["axis"] = clamp(axis, -1.0, 1.0)
	state["jump_pressed"] = bool(state.get("jump_pressed", false)) or jump_pressed
	state["jump_held"] = jump_held
	var aim_delta := aim_world - player.global_position
	if aim_delta.length() > MAX_AIM_DISTANCE:
		state["aim_world"] = player.global_position + aim_delta.normalized() * MAX_AIM_DISTANCE
	else:
		state["aim_world"] = aim_world
	state["shoot_held"] = shoot_held
	state["reported_rtt_ms"] = clampi(reported_rtt_ms, 0, MAX_REPORTED_RTT_MS)
	input_states[peer_id] = state

func _server_accept_input_packet(peer_id: int) -> bool:
	var now := Time.get_ticks_msec()
	var window_start := int(input_rate_window_start_ms.get(peer_id, 0))
	var count := int(input_rate_counts.get(peer_id, 0))
	if window_start == 0 or now - window_start >= 1000:
		window_start = now
		count = 0

	count += 1
	input_rate_window_start_ms[peer_id] = window_start
	input_rate_counts[peer_id] = count
	return count <= MAX_INPUT_PACKETS_PER_SEC

@rpc("any_peer", "unreliable")
func _rpc_ping_request(client_sent_msec: int) -> void:
	if not multiplayer.is_server():
		return

	var peer_id := multiplayer.get_remote_sender_id()
	_rpc_ping_response.rpc_id(peer_id, client_sent_msec)

@rpc("authority", "unreliable")
func _rpc_ping_response(client_sent_msec: int) -> void:
	if multiplayer.is_server():
		return

	last_ping_ms = int(max(0, Time.get_ticks_msec() - client_sent_msec))
	_update_ping_label()
	_update_peer_labels()

@rpc("authority", "unreliable_ordered")
func _rpc_sync_player_state(peer_id: int, new_position: Vector2, new_velocity: Vector2, aim_angle: float, health: int) -> void:
	if multiplayer.is_server():
		return

	var player: NetPlayer = players.get(peer_id, null) as NetPlayer
	if player == null:
		return

	if peer_id == multiplayer.get_unique_id():
		player.set_aim_angle(aim_angle)
		player.set_health(health)
		var delta_pos: Vector2 = new_position - player.global_position
		if delta_pos.length() > LOCAL_RECONCILE_SNAP_DISTANCE:
			player.global_position = new_position
			player.velocity = new_velocity
		else:
			player.global_position = player.global_position.lerp(new_position, LOCAL_RECONCILE_POS_BLEND)
			player.velocity = player.velocity.lerp(new_velocity, LOCAL_RECONCILE_VEL_BLEND)
		return

	player.apply_snapshot(new_position, new_velocity, aim_angle, health)

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
