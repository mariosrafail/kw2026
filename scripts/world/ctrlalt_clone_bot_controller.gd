extends TargetDummyBotController
class_name CtrlaltCloneBotController

const CTRLALT_CHARACTER_ID := "ctrlalt"
const CLONE_WEAPON_ID := "uzi"
const CLONE_HEALTH := 18
const RANDOM_SHOT_INTERVAL_MIN := 0.24
const RANDOM_SHOT_INTERVAL_MAX := 0.52
const AIM_JITTER_X := 14.0
const AIM_JITTER_Y := 10.0
const WANDER_RADIUS := 112.0
const DIRECTION_HOLD_MIN_SEC := 0.8
const DIRECTION_HOLD_MAX_SEC := 1.75
const RANDOM_AIM_DISTANCE := 110.0
const RANDOM_AIM_VERTICAL_JITTER := 28.0
const RANDOM_JUMP_CHANCE := 0.22

var owner_peer_id := 0
var _rng := RandomNumberGenerator.new()
var _next_shot_delay_sec := 0.0
var _direction_hold_sec := 0.0
var _move_direction := 1.0

func configure(state_refs: Dictionary, callbacks: Dictionary, config: Dictionary = {}) -> void:
	super.configure(state_refs, callbacks, config)
	owner_peer_id = int(config.get("owner_peer_id", 0))
	_rng.seed = int(Time.get_ticks_usec()) ^ bot_peer_id
	_reset_random_fire_delay()
	_reset_direction_hold()

func reset() -> void:
	super.reset()
	_reset_random_fire_delay()
	_reset_direction_hold()

func setup_spawned_player(player: NetPlayer, desired_position: Vector2, allow_smoothing: bool = false) -> void:
	if player == null:
		return
	player.z_as_relative = false
	player.z_index = BOT_Z_INDEX
	player.set_display_name(bot_name)
	player.use_network_smoothing = allow_smoothing
	player.set_target_dummy_mode(true)
	player.set_max_health(CLONE_HEALTH)
	player.set_character_visual(CTRLALT_CHARACTER_ID)
	peer_weapon_ids[bot_peer_id] = CLONE_WEAPON_ID
	peer_weapon_skin_indices_by_peer[bot_peer_id] = 0
	if _weapon_visual_for_peer_cb.is_valid():
		player.set_weapon_visual(_weapon_visual_for_peer_cb.call(bot_peer_id, CLONE_WEAPON_ID) as Dictionary)
	if _weapon_shot_sfx_cb.is_valid():
		player.set_shot_audio_stream(_weapon_shot_sfx_cb.call(CLONE_WEAPON_ID) as AudioStream)
	if _weapon_reload_sfx_cb.is_valid():
		player.set_reload_audio_stream(_weapon_reload_sfx_cb.call(CLONE_WEAPON_ID) as AudioStream)
	player.set_sfx_suppressed(false)
	player.set_aim_world(desired_position + Vector2.LEFT * PATROL_AIM_DISTANCE)
	player.set_health(CLONE_HEALTH)

func should_respawn_on_death() -> bool:
	return false

func _target_spawn_point(anchor_position: Vector2) -> Vector2:
	var target_position := anchor_position
	var owner_player := players.get(owner_peer_id, null) as NetPlayer
	if owner_player != null and owner_player.get_health() > 0:
		target_position = owner_player.global_position
	if target_position == Vector2.ZERO:
		target_position = anchor_position
	if target_position == Vector2.ZERO:
		target_position = spawn_position
	if target_position == Vector2.ZERO:
		target_position = super._target_spawn_point(anchor_position)
	return _sanitize_spawn(target_position)

func _nearest_target(bot: NetPlayer) -> NetPlayer:
	var best: NetPlayer = null
	var best_dist_sq := INF
	for peer_value in players.keys():
		var peer_id := int(peer_value)
		if is_bot_peer(peer_id) or peer_id == owner_peer_id:
			continue
		if peer_id < 0:
			continue
		if lobby_id > 0 and _peer_lobby(peer_id) != lobby_id:
			continue
		var relation_source_peer_id := owner_peer_id if owner_peer_id != 0 else bot_peer_id
		if _is_enemy_target_cb.is_valid() and not bool(_is_enemy_target_cb.call(relation_source_peer_id, peer_id)):
			continue
		var candidate := players.get(peer_id, null) as NetPlayer
		if candidate == null or candidate.get_health() <= 0:
			continue
		var dist_sq := bot.global_position.distance_squared_to(candidate.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = candidate
	return best

func _resolve_preferred_target() -> NetPlayer:
	if preferred_target_peer_id == owner_peer_id:
		return null
	return super._resolve_preferred_target()

func tick(delta: float) -> void:
	var bot := players.get(bot_peer_id, null) as NetPlayer
	if bot == null or bot.get_health() <= 0:
		return
	_think_accumulator += delta
	var think_interval := 1.0 / maxf(1.0, think_rate_hz)
	if _think_accumulator < think_interval:
		return
	var think_delta := _think_accumulator
	_think_accumulator = 0.0
	jump_hold_remaining = maxf(0.0, jump_hold_remaining - think_delta)
	_next_shot_delay_sec = maxf(0.0, _next_shot_delay_sec - think_delta)
	_direction_hold_sec = maxf(0.0, _direction_hold_sec - think_delta)
	if _direction_hold_sec <= 0.0:
		_reset_direction_hold()

	var anchor_position := spawn_position
	var owner_player := players.get(owner_peer_id, null) as NetPlayer
	if owner_player != null and owner_player.get_health() > 0:
		anchor_position = owner_player.global_position
	if anchor_position == Vector2.ZERO:
		anchor_position = bot.global_position

	var offset_from_anchor := bot.global_position - anchor_position
	if absf(offset_from_anchor.x) > WANDER_RADIUS:
		_move_direction = -signf(offset_from_anchor.x)
		if absf(_move_direction) < 0.001:
			_move_direction = 1.0
		_direction_hold_sec = _rng.randf_range(0.18, 0.42)

	var target := _nearest_target(bot)
	var aim_world := _random_aim_point(bot, target)
	bot.set_aim_world(aim_world)

	var move_axis := _move_direction
	var jump_pressed := false
	var forward_axis := _probe_axis(bot, Vector2.ZERO, anchor_position + Vector2(_move_direction * RANDOM_AIM_DISTANCE, 0.0), move_axis)
	if _has_wall_ahead(bot, forward_axis):
		move_axis = -move_axis
		_move_direction = move_axis
		jump_pressed = bot.is_on_floor()
		_direction_hold_sec = _rng.randf_range(0.18, 0.42)
	elif not _has_floor_ahead(bot, forward_axis):
		move_axis = -move_axis
		_move_direction = move_axis
		_direction_hold_sec = _rng.randf_range(0.18, 0.42)
	elif bot.is_on_floor() and _rng.randf() < RANDOM_JUMP_CHANCE:
		jump_pressed = true

	if target != null:
		var target_axis := signf(target.global_position.x - bot.global_position.x)
		if absf(target_axis) > 0.001 and _rng.randf() < 0.68:
			move_axis = target_axis
			_move_direction = target_axis

	if absf(move_axis) > 0.001:
		patrol_direction = signf(move_axis)
	else:
		move_axis = patrol_direction if absf(patrol_direction) > 0.001 else 1.0

	if jump_pressed:
		jump_hold_remaining = _rng.randf_range(0.1, 0.2)
	var jump_held := jump_pressed or jump_hold_remaining > 0.0

	var final_shoot := false
	if target != null and _next_shot_delay_sec <= 0.0:
		final_shoot = true
		_reset_random_fire_delay()

	_write_bot_input_state(aim_world, move_axis, jump_pressed, jump_held, final_shoot)
	_record_history(bot.global_position)

func _write_bot_input_state(aim_world: Vector2, move_axis: float, jump_pressed: bool, jump_held: bool, shoot_held: bool) -> void:
	var final_aim := aim_world
	var final_shoot := false
	if shoot_held:
		final_shoot = true
		final_aim += Vector2(
			_rng.randf_range(-AIM_JITTER_X, AIM_JITTER_X),
			_rng.randf_range(-AIM_JITTER_Y, AIM_JITTER_Y)
		)
	super._write_bot_input_state(final_aim, move_axis, jump_pressed, jump_held, final_shoot)

func _reset_random_fire_delay() -> void:
	_next_shot_delay_sec = _rng.randf_range(RANDOM_SHOT_INTERVAL_MIN, RANDOM_SHOT_INTERVAL_MAX)

func _reset_direction_hold() -> void:
	var options := [-1.0, 1.0]
	_move_direction = options[_rng.randi_range(0, options.size() - 1)]
	_direction_hold_sec = _rng.randf_range(DIRECTION_HOLD_MIN_SEC, DIRECTION_HOLD_MAX_SEC)

func _random_aim_point(bot: NetPlayer, target: NetPlayer) -> Vector2:
	if bot == null:
		return Vector2.ZERO
	if target != null:
		return target.global_position + Vector2(
			_rng.randf_range(-AIM_JITTER_X, AIM_JITTER_X),
			_rng.randf_range(-AIM_JITTER_Y, AIM_JITTER_Y)
		)
	return bot.global_position + Vector2(
		_move_direction * RANDOM_AIM_DISTANCE,
		_rng.randf_range(-RANDOM_AIM_VERTICAL_JITTER, RANDOM_AIM_VERTICAL_JITTER)
	)
