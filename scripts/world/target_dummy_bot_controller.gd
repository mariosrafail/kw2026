extends RefCounted
class_name TargetDummyBotController

const BOT_PATHFINDER_SCRIPT := preload("res://scripts/world/bot_pathfinder.gd")

const BOT_PEER_ID := -1001
const BOT_NAME := "TARGET DUMMY"
const BOT_COLOR := Color(1.0, 0.48, 0.48, 1.0)
const BOT_Z_INDEX := 80
const BOT_HALF_HEIGHT := 22.0
const PATROL_DISTANCE := 96.0
const PATROL_AIM_DISTANCE := 160.0
const CHASE_STOP_DISTANCE := 26.0
const TARGET_JUMP_HEIGHT_THRESHOLD := 28.0
const TARGET_JUMP_HORIZONTAL_THRESHOLD := 52.0
const WALL_CHECK_DISTANCE := 22.0
const FLOOR_LOOKAHEAD := 18.0
const FLOOR_DROP_CHECK := 42.0
const BOT_WEAPON_ID := "ak47"
const JUMP_HOLD_MIN_SEC := 0.08
const JUMP_HOLD_MAX_SEC := 0.24
const TARGET_MEMORY_SEC := 2.2
const SEARCH_REACHED_DISTANCE := 14.0
const DROP_TO_TARGET_MIN_VERTICAL := 34.0
const DROP_TO_TARGET_MAX_HORIZONTAL := 220.0
const FIRE_ENGAGE_DISTANCE := 210.0
const FIRE_STOP_DISTANCE := 168.0
const SKILL_Q_CAST_DISTANCE := 118.0
const SKILL_E_CAST_DISTANCE := 196.0
const EDGE_SEEK_VERTICAL_THRESHOLD := 56.0
const EDGE_SEEK_SCAN_STEP := 18.0
const EDGE_SEEK_SCAN_STEPS := 6

var players: Dictionary = {}
var input_states: Dictionary = {}
var peer_weapon_ids: Dictionary = {}
var peer_weapon_skin_indices_by_peer: Dictionary = {}
var players_root: Node2D
var multiplayer: MultiplayerAPI
var spawn_flow_service

var _get_world_2d_cb: Callable = Callable()
var _random_spawn_position_cb: Callable = Callable()
var _weapon_visual_for_peer_cb: Callable = Callable()
var _weapon_shot_sfx_cb: Callable = Callable()
var _weapon_reload_sfx_cb: Callable = Callable()
var _broadcast_spawn_cb: Callable = Callable()
var _record_player_history_cb: Callable = Callable()
var _get_peer_lobby_cb: Callable = Callable()
var _default_input_state_cb: Callable = Callable()
var _server_cast_skill_cb: Callable = Callable()
var _can_cast_skill_cb: Callable = Callable()

var spawn_points: Array = []
var spawn_position := Vector2.ZERO
var lobby_id := 0
var patrol_direction := -1.0
var jump_hold_remaining := 0.0
var last_seen_target_position := Vector2.ZERO
var last_seen_memory_remaining := 0.0
var pathfinder: BotPathfinder

func configure(state_refs: Dictionary, callbacks: Dictionary, config: Dictionary = {}) -> void:
	players = state_refs.get("players", {}) as Dictionary
	input_states = state_refs.get("input_states", {}) as Dictionary
	peer_weapon_ids = state_refs.get("peer_weapon_ids", {}) as Dictionary
	peer_weapon_skin_indices_by_peer = state_refs.get("peer_weapon_skin_indices_by_peer", {}) as Dictionary
	players_root = state_refs.get("players_root", null) as Node2D
	multiplayer = state_refs.get("multiplayer", null) as MultiplayerAPI
	spawn_flow_service = state_refs.get("spawn_flow_service", null)
	spawn_points = (config.get("spawn_points", []) as Array).duplicate(true)

	_get_world_2d_cb = callbacks.get("get_world_2d", Callable()) as Callable
	_random_spawn_position_cb = callbacks.get("random_spawn_position", Callable()) as Callable
	_weapon_visual_for_peer_cb = callbacks.get("weapon_visual_for_peer", Callable()) as Callable
	_weapon_shot_sfx_cb = callbacks.get("weapon_shot_sfx", Callable()) as Callable
	_weapon_reload_sfx_cb = callbacks.get("weapon_reload_sfx", Callable()) as Callable
	_broadcast_spawn_cb = callbacks.get("broadcast_spawn", Callable()) as Callable
	_record_player_history_cb = callbacks.get("record_player_history", Callable()) as Callable
	_get_peer_lobby_cb = callbacks.get("get_peer_lobby", Callable()) as Callable
	_default_input_state_cb = callbacks.get("default_input_state", Callable()) as Callable
	_server_cast_skill_cb = callbacks.get("server_cast_skill", Callable()) as Callable
	_can_cast_skill_cb = callbacks.get("can_cast_skill", Callable()) as Callable
	if pathfinder == null:
		pathfinder = BOT_PATHFINDER_SCRIPT.new()
	pathfinder.configure({
		"get_world_2d": _get_world_2d_cb,
		"get_play_bounds": callbacks.get("get_play_bounds", Callable()) as Callable
	})

func reset() -> void:
	spawn_position = Vector2.ZERO
	lobby_id = 0
	patrol_direction = -1.0
	jump_hold_remaining = 0.0
	last_seen_target_position = Vector2.ZERO
	last_seen_memory_remaining = 0.0
	if pathfinder != null:
		pathfinder.invalidate()

func update_spawn_points(value: Array) -> void:
	spawn_points = value.duplicate(true)

func peer_id() -> int:
	return BOT_PEER_ID

func display_name() -> String:
	return BOT_NAME

func is_bot_peer(peer_id: int) -> bool:
	return peer_id == BOT_PEER_ID

func set_lobby_id(value: int) -> void:
	lobby_id = maxi(0, value)

func get_lobby_id() -> int:
	return lobby_id

func get_spawn_position() -> Vector2:
	return spawn_position

func setup_spawned_player(player: NetPlayer, desired_position: Vector2, allow_smoothing: bool = false) -> void:
	if player == null:
		return
	player.z_as_relative = false
	player.z_index = BOT_Z_INDEX
	player.set_display_name(BOT_NAME)
	player.use_network_smoothing = allow_smoothing
	player.set_target_dummy_mode(true)
	player.set_character_visual("outrage")
	peer_weapon_ids[BOT_PEER_ID] = BOT_WEAPON_ID
	peer_weapon_skin_indices_by_peer[BOT_PEER_ID] = 0
	if _weapon_visual_for_peer_cb.is_valid():
		player.set_weapon_visual(_weapon_visual_for_peer_cb.call(BOT_PEER_ID, BOT_WEAPON_ID) as Dictionary)
	if _weapon_shot_sfx_cb.is_valid():
		player.set_shot_audio_stream(_weapon_shot_sfx_cb.call(BOT_WEAPON_ID) as AudioStream)
	if _weapon_reload_sfx_cb.is_valid():
		player.set_reload_audio_stream(_weapon_reload_sfx_cb.call(BOT_WEAPON_ID) as AudioStream)
	player.set_sfx_suppressed(false)
	player.set_aim_world(desired_position + Vector2.LEFT * PATROL_AIM_DISTANCE)

func ensure_spawned(player_scene: PackedScene, anchor_position: Vector2) -> NetPlayer:
	if players_root == null or player_scene == null:
		return null
	var desired_position := _target_spawn_point(anchor_position)
	spawn_position = desired_position
	patrol_direction = -1.0
	jump_hold_remaining = 0.0
	last_seen_target_position = Vector2.ZERO
	last_seen_memory_remaining = 0.0
	var existing := players.get(BOT_PEER_ID, null) as NetPlayer
	if existing != null:
		setup_spawned_player(existing, desired_position, false)
		existing.force_respawn(desired_position)
		_write_bot_input_state(desired_position + Vector2.LEFT * PATROL_AIM_DISTANCE, 0.0, false, false, false)
		_record_history(desired_position)
		_broadcast_spawn(desired_position)
		return existing

	var bot := player_scene.instantiate() as NetPlayer
	if bot == null:
		return null
	bot.global_position = desired_position
	players_root.add_child(bot)
	bot.configure(BOT_PEER_ID, BOT_COLOR)
	setup_spawned_player(bot, desired_position, false)
	players[BOT_PEER_ID] = bot
	_write_bot_input_state(desired_position + Vector2.LEFT * PATROL_AIM_DISTANCE, 0.0, false, false, false)
	_record_history(desired_position)
	_broadcast_spawn(desired_position)
	return bot

func respawn_player(player: NetPlayer) -> void:
	if player == null:
		return
	var respawn_position := spawn_position
	if respawn_position == Vector2.ZERO:
		respawn_position = _sanitize_spawn(_random_spawn_position())
	spawn_position = respawn_position
	patrol_direction = -1.0
	jump_hold_remaining = 0.0
	last_seen_target_position = Vector2.ZERO
	last_seen_memory_remaining = 0.0
	setup_spawned_player(player, respawn_position, false)
	player.force_respawn(respawn_position)
	_write_bot_input_state(respawn_position + Vector2.RIGHT * PATROL_AIM_DISTANCE, 0.0, false, false, false)
	_record_history(respawn_position)

func tick(delta: float) -> void:
	var bot := players.get(BOT_PEER_ID, null) as NetPlayer
	if bot == null:
		return
	if bot.get_health() <= 0:
		return
	jump_hold_remaining = maxf(0.0, jump_hold_remaining - delta)
	last_seen_memory_remaining = maxf(0.0, last_seen_memory_remaining - delta)
	var target := _nearest_target(bot)
	var has_target_los := _has_weapon_los(bot, target)
	var distance_to_target := bot.global_position.distance_to(target.global_position) if target != null else INF
	_try_cast_skills(bot, target, has_target_los, distance_to_target)
	if target != null and has_target_los:
		last_seen_target_position = target.global_position
		last_seen_memory_remaining = TARGET_MEMORY_SEC
	var search_target := _resolve_search_target(bot, target, has_target_los)
	var move_target := _movement_target(bot, search_target)
	var aim_world := _aim_point_for_position(search_target) if search_target != Vector2.ZERO else bot.global_position + Vector2(patrol_direction * PATROL_AIM_DISTANCE, 0.0)
	bot.set_aim_world(aim_world)
	var move_axis := _move_axis_for_target_position(bot, move_target)
	var obstacle_probe_axis := _probe_axis(bot, move_target, search_target, move_axis)
	if _should_seek_edge(bot, search_target, has_target_los):
		var edge_seek_axis := _edge_seek_axis(bot, search_target)
		if absf(edge_seek_axis) > 0.001:
			move_axis = edge_seek_axis
			obstacle_probe_axis = edge_seek_axis
	var in_fire_range := target != null and has_target_los and distance_to_target <= FIRE_ENGAGE_DISTANCE
	if target != null and has_target_los and distance_to_target <= FIRE_STOP_DISTANCE:
		move_axis = 0.0
	elif search_target != Vector2.ZERO and bot.global_position.distance_to(search_target) <= SEARCH_REACHED_DISTANCE:
		move_axis = patrol_direction
	var jump_pressed := false
	if absf(move_axis) > 0.001:
		patrol_direction = signf(move_axis)
	else:
		var center := spawn_position if spawn_position != Vector2.ZERO else bot.global_position
		var left_limit := center.x - PATROL_DISTANCE
		var right_limit := center.x + PATROL_DISTANCE
		if bot.global_position.x <= left_limit:
			patrol_direction = 1.0
		elif bot.global_position.x >= right_limit:
			patrol_direction = -1.0
		move_axis = patrol_direction

	var wall_ahead := _has_wall_ahead(bot, obstacle_probe_axis)
	var floor_ahead := _has_floor_ahead(bot, obstacle_probe_axis)
	var should_drop_to_target := _should_drop_to_target(bot, search_target, move_axis)
	var knows_target_position := search_target != Vector2.ZERO
	var pursuing_without_los := knows_target_position and not has_target_los
	var stuck_at_gap := not floor_ahead and absf(move_axis) <= 0.001 and knows_target_position
	if wall_ahead and bot.is_on_floor():
		jump_pressed = true
	elif _should_jump_toward_target(bot, target) and bot.is_on_floor():
		jump_pressed = true
	elif stuck_at_gap and bot.is_on_floor():
		jump_pressed = true
		move_axis = signf(search_target.x - bot.global_position.x)
		if absf(move_axis) > 0.001:
			patrol_direction = move_axis
	elif not floor_ahead:
		if should_drop_to_target:
			pass
		elif pursuing_without_los and bot.is_on_floor():
			jump_pressed = true
		elif target != null or search_target != Vector2.ZERO:
			move_axis = signf(search_target.x - bot.global_position.x)
			if absf(move_axis) > 0.001:
				patrol_direction = move_axis
		else:
			patrol_direction *= -1.0
			move_axis = patrol_direction

	if target == null and search_target == Vector2.ZERO and _should_turn(bot, move_axis):
		patrol_direction *= -1.0
		move_axis = patrol_direction
	if jump_pressed:
		jump_hold_remaining = _jump_hold_duration(bot, target, wall_ahead)
	var jump_held := jump_pressed or jump_hold_remaining > 0.0
	_write_bot_input_state(aim_world, move_axis, jump_pressed, jump_held, in_fire_range)
	if target == null and (bot.is_on_wall() or _should_turn(bot, move_axis)):
		patrol_direction *= -1.0
		var patrol_aim := bot.global_position + Vector2(patrol_direction * PATROL_AIM_DISTANCE, 0.0)
		bot.set_aim_world(patrol_aim)
		_write_bot_input_state(patrol_aim, move_axis, jump_pressed, jump_held, false)
	_record_history(bot.global_position)

func _record_history(world_position: Vector2) -> void:
	if _record_player_history_cb.is_valid():
		_record_player_history_cb.call(BOT_PEER_ID, world_position)

func _broadcast_spawn(world_position: Vector2) -> void:
	if _broadcast_spawn_cb.is_valid():
		_broadcast_spawn_cb.call(world_position)

func _target_spawn_point(anchor_position: Vector2) -> Vector2:
	if spawn_points.size() >= 2:
		var second_spawn = spawn_points[1]
		if second_spawn is Vector2:
			return _snap_to_ground(second_spawn as Vector2)
	if spawn_points.size() == 1:
		var first_spawn = spawn_points[0]
		if first_spawn is Vector2:
			return _snap_to_ground(first_spawn as Vector2)
	if anchor_position != Vector2.ZERO:
		return _snap_to_ground(anchor_position)
	return _snap_to_ground(_random_spawn_position())

func _snap_to_ground(world_position: Vector2) -> Vector2:
	var snapped := _sanitize_spawn(world_position)
	var world_2d := _world_2d()
	if world_2d == null:
		return snapped
	var space_state := world_2d.direct_space_state
	if space_state == null:
		return snapped
	var ray_from := snapped + Vector2(0.0, -64.0)
	var ray_to := snapped + Vector2(0.0, 160.0)
	var query := PhysicsRayQueryParameters2D.create(ray_from, ray_to, 1)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return snapped
	var hit_position := hit.get("position", snapped) as Vector2
	var grounded := Vector2(snapped.x, hit_position.y - BOT_HALF_HEIGHT)
	return _sanitize_spawn(grounded)

func _sanitize_spawn(world_position: Vector2) -> Vector2:
	if spawn_flow_service != null and spawn_flow_service.has_method("sanitize_spawn_position"):
		return spawn_flow_service.call("sanitize_spawn_position", world_position, _world_2d(), 1) as Vector2
	return world_position

func _should_turn(bot: NetPlayer, direction: float) -> bool:
	return _has_wall_ahead(bot, direction) or not _has_floor_ahead(bot, direction)

func _has_wall_ahead(bot: NetPlayer, direction: float) -> bool:
	var world_2d := _world_2d()
	if bot == null or world_2d == null:
		return false
	var space_state := world_2d.direct_space_state
	if space_state == null:
		return false
	var dir := signf(direction)
	if absf(dir) < 0.001:
		dir = -1.0
	var exclude := [bot]

	var wall_from := bot.global_position + Vector2(0.0, -12.0)
	var wall_to := wall_from + Vector2(dir * WALL_CHECK_DISTANCE, 0.0)
	var wall_query := PhysicsRayQueryParameters2D.create(wall_from, wall_to, 1)
	wall_query.collide_with_bodies = true
	wall_query.collide_with_areas = false
	wall_query.exclude = exclude
	var wall_hit := space_state.intersect_ray(wall_query)
	return not wall_hit.is_empty()

func _has_floor_ahead(bot: NetPlayer, direction: float) -> bool:
	var world_2d := _world_2d()
	if bot == null or world_2d == null:
		return true
	var space_state := world_2d.direct_space_state
	if space_state == null:
		return true
	var dir := signf(direction)
	if absf(dir) < 0.001:
		dir = patrol_direction
	if absf(dir) < 0.001:
		dir = -1.0
	var exclude := [bot]
	var floor_from := bot.global_position + Vector2(dir * FLOOR_LOOKAHEAD, 0.0)
	var floor_to := floor_from + Vector2(0.0, FLOOR_DROP_CHECK)
	var floor_query := PhysicsRayQueryParameters2D.create(floor_from, floor_to, 1)
	floor_query.collide_with_bodies = true
	floor_query.collide_with_areas = false
	floor_query.exclude = exclude
	var floor_hit := space_state.intersect_ray(floor_query)
	return not floor_hit.is_empty()

func _nearest_target(bot: NetPlayer) -> NetPlayer:
	var best: NetPlayer = null
	var best_dist_sq := INF
	for peer_value in players.keys():
		var peer_id := int(peer_value)
		if is_bot_peer(peer_id):
			continue
		if lobby_id > 0 and _peer_lobby(peer_id) != lobby_id:
			continue
		var candidate := players.get(peer_id, null) as NetPlayer
		if candidate == null:
			continue
		if candidate.get_health() <= 0:
			continue
		var dist_sq := bot.global_position.distance_squared_to(candidate.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = candidate
	return best

func _move_axis_for_target(bot: NetPlayer, target: NetPlayer) -> float:
	if bot == null or target == null:
		return 0.0
	var dx := target.global_position.x - bot.global_position.x
	var abs_dx := absf(dx)
	if abs_dx > CHASE_STOP_DISTANCE:
		return signf(dx)
	return 0.0

func _move_axis_for_target_position(bot: NetPlayer, target_position: Vector2) -> float:
	if bot == null or target_position == Vector2.ZERO:
		return 0.0
	var dx := target_position.x - bot.global_position.x
	if absf(dx) > CHASE_STOP_DISTANCE:
		return signf(dx)
	return 0.0

func _should_jump_toward_target(bot: NetPlayer, target: NetPlayer) -> bool:
	if bot == null or target == null:
		return false
	var dx := target.global_position.x - bot.global_position.x
	var dy := target.global_position.y - bot.global_position.y
	if absf(dx) > TARGET_JUMP_HORIZONTAL_THRESHOLD:
		return false
	return dy < -TARGET_JUMP_HEIGHT_THRESHOLD

func _jump_hold_duration(bot: NetPlayer, target: NetPlayer, wall_ahead: bool) -> float:
	if bot == null:
		return JUMP_HOLD_MIN_SEC
	var desired_height := 0.0
	if target != null:
		desired_height = maxf(0.0, bot.global_position.y - target.global_position.y)
	if wall_ahead:
		desired_height = maxf(desired_height, 72.0)
	var t := clampf((desired_height - TARGET_JUMP_HEIGHT_THRESHOLD) / 140.0, 0.0, 1.0)
	return lerpf(JUMP_HOLD_MIN_SEC, JUMP_HOLD_MAX_SEC, t)

func _should_drop_to_target(bot: NetPlayer, target_position: Vector2, move_axis: float) -> bool:
	if bot == null or target_position == Vector2.ZERO:
		return false
	if absf(move_axis) < 0.001:
		return false
	var dx := target_position.x - bot.global_position.x
	var dy := target_position.y - bot.global_position.y
	if absf(dx) > DROP_TO_TARGET_MAX_HORIZONTAL:
		return false
	if dy < DROP_TO_TARGET_MIN_VERTICAL:
		return false
	return signf(dx) == signf(move_axis)

func _should_seek_edge(bot: NetPlayer, target_position: Vector2, has_target_los: bool) -> bool:
	if bot == null or target_position == Vector2.ZERO:
		return false
	if has_target_los:
		return false
	return absf(target_position.y - bot.global_position.y) >= EDGE_SEEK_VERTICAL_THRESHOLD

func _edge_seek_axis(bot: NetPlayer, target_position: Vector2) -> float:
	if bot == null or target_position == Vector2.ZERO:
		return 0.0
	var target_dir := signf(target_position.x - bot.global_position.x)
	var preferred_dir := target_dir if absf(target_dir) > 0.001 else patrol_direction
	var preferred_score := _edge_distance_score(bot, preferred_dir)
	var opposite_score := _edge_distance_score(bot, -preferred_dir)
	if preferred_score < INF and (opposite_score >= INF or preferred_score <= opposite_score + 12.0):
		return preferred_dir
	if opposite_score < INF:
		return -preferred_dir
	return preferred_dir

func _edge_distance_score(bot: NetPlayer, direction: float) -> float:
	if bot == null or absf(direction) < 0.001:
		return INF
	for step in range(1, EDGE_SEEK_SCAN_STEPS + 1):
		var sample_distance := EDGE_SEEK_SCAN_STEP * float(step)
		if not _has_floor_ahead_at_distance(bot, direction, sample_distance):
			return sample_distance
	return INF

func _has_floor_ahead_at_distance(bot: NetPlayer, direction: float, lookahead_distance: float) -> bool:
	var world_2d := _world_2d()
	if bot == null or world_2d == null:
		return true
	var space_state := world_2d.direct_space_state
	if space_state == null:
		return true
	var dir := signf(direction)
	if absf(dir) < 0.001:
		dir = patrol_direction
	if absf(dir) < 0.001:
		dir = -1.0
	var exclude := [bot]
	var floor_from := bot.global_position + Vector2(dir * lookahead_distance, 0.0)
	var floor_to := floor_from + Vector2(0.0, FLOOR_DROP_CHECK)
	var floor_query := PhysicsRayQueryParameters2D.create(floor_from, floor_to, 1)
	floor_query.collide_with_bodies = true
	floor_query.collide_with_areas = false
	floor_query.exclude = exclude
	var floor_hit := space_state.intersect_ray(floor_query)
	return not floor_hit.is_empty()

func _should_idle_with_los(bot: NetPlayer, target: NetPlayer) -> bool:
	if bot == null or target == null:
		return false
	return _has_weapon_los(bot, target)

func _has_weapon_los(bot: NetPlayer, target: NetPlayer) -> bool:
	var world_2d := _world_2d()
	if bot == null or target == null or world_2d == null:
		return false
	var space_state := world_2d.direct_space_state
	if space_state == null:
		return false
	var muzzle := bot.get_muzzle_world_position()
	for point in _target_aim_points(target):
		var query := PhysicsRayQueryParameters2D.create(muzzle, point, 1)
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.exclude = [bot, target]
		var hit := space_state.intersect_ray(query)
		if hit.is_empty():
			return true
	return false

func _aim_point_for_target(target: NetPlayer) -> Vector2:
	if target == null:
		return Vector2.ZERO
	return target.global_position + Vector2(0.0, -10.0)

func _aim_point_for_position(world_position: Vector2) -> Vector2:
	if world_position == Vector2.ZERO:
		return Vector2.ZERO
	return world_position + Vector2(0.0, -10.0)

func _target_aim_points(target: NetPlayer) -> Array[Vector2]:
	if target == null:
		return []
	return [
		target.global_position + Vector2(0.0, -14.0),
		target.global_position + Vector2(0.0, -8.0),
		target.global_position + Vector2(0.0, -2.0)
	]

func _write_bot_input_state(aim_world: Vector2, move_axis: float, jump_pressed: bool, jump_held: bool, shoot_held: bool) -> void:
	var state := _default_input_state()
	state["axis"] = clampf(move_axis, -1.0, 1.0)
	state["jump_pressed"] = jump_pressed
	state["jump_held"] = jump_held
	state["aim_world"] = aim_world
	state["shoot_held"] = shoot_held
	state["boost_damage"] = false
	state["reported_rtt_ms"] = 0
	state["last_packet_msec"] = Time.get_ticks_msec()
	input_states[BOT_PEER_ID] = state

func _resolve_search_target(bot: NetPlayer, target: NetPlayer, has_target_los: bool) -> Vector2:
	if bot != null and target != null and has_target_los:
		return target.global_position
	if last_seen_memory_remaining > 0.0 and last_seen_target_position != Vector2.ZERO:
		return last_seen_target_position
	if target != null:
		return target.global_position
	return Vector2.ZERO

func _movement_target(bot: NetPlayer, search_target: Vector2) -> Vector2:
	if bot == null or search_target == Vector2.ZERO:
		return search_target
	if pathfinder == null:
		return search_target
	var waypoint := pathfinder.waypoint_toward(bot.global_position, search_target)
	if waypoint == Vector2.ZERO:
		return search_target
	return waypoint

func _probe_axis(bot: NetPlayer, move_target: Vector2, search_target: Vector2, move_axis: float) -> float:
	if bot == null:
		return move_axis
	if absf(move_axis) > 0.001:
		return move_axis
	if move_target != Vector2.ZERO:
		var move_target_axis := signf(move_target.x - bot.global_position.x)
		if absf(move_target_axis) > 0.001:
			return move_target_axis
	if search_target != Vector2.ZERO:
		var search_axis := signf(search_target.x - bot.global_position.x)
		if absf(search_axis) > 0.001:
			return search_axis
	return patrol_direction

func _try_cast_skills(bot: NetPlayer, target: NetPlayer, has_target_los: bool, distance_to_target: float) -> void:
	if bot == null or target == null:
		return
	if distance_to_target <= SKILL_E_CAST_DISTANCE and _can_cast_skill(2):
		_cast_skill(2, bot.global_position)
	if has_target_los and distance_to_target <= SKILL_Q_CAST_DISTANCE and _can_cast_skill(1):
		_cast_skill(1, target.global_position)

func _cast_skill(skill_number: int, target_world: Vector2) -> void:
	if _server_cast_skill_cb.is_valid():
		_server_cast_skill_cb.call(skill_number, BOT_PEER_ID, target_world)

func _can_cast_skill(skill_number: int) -> bool:
	if _can_cast_skill_cb.is_valid():
		return bool(_can_cast_skill_cb.call(BOT_PEER_ID, skill_number))
	return false

func _default_input_state() -> Dictionary:
	if _default_input_state_cb.is_valid():
		return (_default_input_state_cb.call() as Dictionary).duplicate(true)
	return {
		"axis": 0.0,
		"jump_pressed": false,
		"jump_held": false,
		"aim_world": Vector2.ZERO,
		"shoot_held": false,
		"boost_damage": false,
		"boost_damage_multiplier": 1.0,
		"reported_rtt_ms": 0,
		"last_packet_msec": 0
	}

func _world_2d() -> World2D:
	if _get_world_2d_cb.is_valid():
		return _get_world_2d_cb.call() as World2D
	return null

func _random_spawn_position() -> Vector2:
	if _random_spawn_position_cb.is_valid():
		return _random_spawn_position_cb.call() as Vector2
	return Vector2.ZERO

func _peer_lobby(peer_id: int) -> int:
	if _get_peer_lobby_cb.is_valid():
		return int(_get_peer_lobby_cb.call(peer_id))
	return 0
