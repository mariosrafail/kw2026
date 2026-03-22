extends RefCounted
class_name CtfObjectiveModule

const CTF_FLAG_STATE_SCRIPT := preload("res://scripts/world/modes/ctf_flag_state.gd")
const CTF_CAPTURE_AREAS_SCRIPT := preload("res://scripts/world/modes/ctf_capture_areas.gd")
const CTF_VISUALS_SCRIPT := preload("res://scripts/world/modes/ctf_visuals.gd")
const CTF_MARKER_TEXTURE := preload("res://assets/textures/flag.png")

const TEAM_RED := 0
const TEAM_BLUE := 1
const CARRIER_SPEED_MULTIPLIER := 0.82
const FLAG_PICKUP_RADIUS := 44.0
const BASE_CAPTURE_RADIUS := 46.0
const CAPTURE_GOAL_RADIUS := 92.0
const FLAG_DROP_RESET_SEC := 12.0

var teams_by_id: Dictionary = {}
var players: Dictionary = {}
var world_root: Node2D

var team_for_peer_cb: Callable = Callable()
var on_score_changed_cb: Callable = Callable()

var neutral_flag: CtfFlagState
var _capture_areas: CtfCaptureAreas
var _visuals: CtfVisuals

func configure(refs: Dictionary, callbacks: Dictionary) -> void:
	teams_by_id = refs.get("teams_by_id", {}) as Dictionary
	players = refs.get("players", {}) as Dictionary
	world_root = refs.get("world_root", null) as Node2D
	team_for_peer_cb = callbacks.get("team_for_peer", Callable()) as Callable
	on_score_changed_cb = callbacks.get("on_score_changed", Callable()) as Callable
	if _capture_areas == null:
		_capture_areas = CTF_CAPTURE_AREAS_SCRIPT.new()
	if _visuals == null:
		_visuals = CTF_VISUALS_SCRIPT.new()
	_visuals.configure(world_root, CTF_MARKER_TEXTURE)

func reset() -> void:
	neutral_flag = null
	if _visuals != null:
		_visuals.reset()
	if _capture_areas != null:
		_capture_areas.reset()

func refresh_layout(flag_home: Vector2) -> void:
	if _capture_areas != null:
		_capture_areas.refresh(world_root)
	if neutral_flag == null:
		neutral_flag = CTF_FLAG_STATE_SCRIPT.new()
		neutral_flag.configure(-1, flag_home)
	else:
		var was_carried := neutral_flag.carrier_peer_id != 0
		var was_dropped := neutral_flag.is_dropped()
		neutral_flag.home_position = flag_home
		if not was_carried and not was_dropped:
			neutral_flag.reset_to_home()
	_rebuild_visuals()
	_update_visuals()

func server_tick(enabled: bool, delta: float) -> bool:
	if not enabled:
		_set_visuals_visible(false)
		return false
	_set_visuals_visible(true)

	var dirty := false
	if neutral_flag != null:
		if neutral_flag.carrier_peer_id != 0:
			var carrier := players.get(neutral_flag.carrier_peer_id, null) as NetPlayer
			if carrier == null or carrier.get_health() <= 0:
				drop_flag_for_peer(neutral_flag.carrier_peer_id, neutral_flag.world_position)
				dirty = true
			else:
				neutral_flag.world_position = carrier.global_position + Vector2(0.0, -26.0)
		elif neutral_flag.is_dropped():
			neutral_flag.dropped_time_sec += delta
			if neutral_flag.dropped_time_sec >= FLAG_DROP_RESET_SEC:
				neutral_flag.reset_to_home()
				dirty = true

	for peer_value in players.keys():
		var peer_id := int(peer_value)
		var player := players.get(peer_id, null) as NetPlayer
		if player == null or player.get_health() <= 0:
			continue
		var team_id := _team_for_peer(peer_id)
		if team_id < 0:
			continue
		var team := teams_by_id.get(team_id, null) as CtfTeam
		if neutral_flag == null or team == null:
			continue

		if neutral_flag.carrier_peer_id == 0 and player.global_position.distance_to(neutral_flag.world_position) <= FLAG_PICKUP_RADIUS:
			neutral_flag.carrier_peer_id = peer_id
			neutral_flag.dropped_time_sec = 0.0
			neutral_flag.world_position = player.global_position + Vector2(0.0, -26.0)
			dirty = true

		if neutral_flag.carrier_peer_id == peer_id:
			var in_capture_area := _is_inside_team_capture_area(player, team_id)
			var capture_goal := capture_goal_for_team(team_id, team.base_position)
			var near_capture_goal := capture_goal != Vector2.ZERO and player.global_position.distance_to(capture_goal) <= CAPTURE_GOAL_RADIUS
			var near_team_base := player.global_position.distance_to(team.base_position) <= BASE_CAPTURE_RADIUS
			if in_capture_area or near_capture_goal or near_team_base:
				team.score += 1
				neutral_flag.reset_to_home()
				dirty = true
				if on_score_changed_cb.is_valid():
					on_score_changed_cb.call()

	_update_visuals()
	return dirty

func visual_tick(enabled: bool) -> void:
	if not enabled:
		_set_visuals_visible(false)
		return
	_set_visuals_visible(true)
	_update_visuals()

func drop_flag_for_peer(peer_id: int, world_position: Vector2) -> void:
	if neutral_flag == null or neutral_flag.carrier_peer_id != peer_id:
		return
	neutral_flag.carrier_peer_id = 0
	neutral_flag.world_position = world_position
	neutral_flag.dropped_time_sec = 0.0
	_update_visuals()

func movement_speed_multiplier_for_peer(peer_id: int) -> float:
	if neutral_flag != null and neutral_flag.carrier_peer_id == peer_id:
		return CARRIER_SPEED_MULTIPLIER
	return 1.0

func flag_carrier_peer_id() -> int:
	return neutral_flag.carrier_peer_id if neutral_flag != null else 0

func flag_world_position(default_position: Vector2) -> Vector2:
	return neutral_flag.world_position if neutral_flag != null else default_position

func team_score(team_id: int) -> int:
	var team := teams_by_id.get(team_id, null) as CtfTeam
	return team.score if team != null else 0

func capture_goal_for_team(team_id: int, fallback: Vector2) -> Vector2:
	if _capture_areas == null:
		return fallback
	return _capture_areas.goal_for_team(team_id, fallback)

func is_peer_carrying_flag(peer_id: int) -> bool:
	return neutral_flag != null and neutral_flag.carrier_peer_id == peer_id

func apply_synced_state(carrier_peer_id: int, world_position: Vector2, red_score: int, blue_score: int) -> void:
	if neutral_flag == null:
		return
	neutral_flag.carrier_peer_id = carrier_peer_id
	neutral_flag.world_position = world_position
	neutral_flag.dropped_time_sec = 0.0
	var red_team := teams_by_id.get(TEAM_RED, null) as CtfTeam
	var blue_team := teams_by_id.get(TEAM_BLUE, null) as CtfTeam
	if red_team != null:
		red_team.score = maxi(0, red_score)
	if blue_team != null:
		blue_team.score = maxi(0, blue_score)
	_update_visuals()

func flag_status_line() -> String:
	return "Flag: %s" % _flag_status(neutral_flag)

func _flag_status(flag: CtfFlagState) -> String:
	if flag == null:
		return "?"
	if flag.carrier_peer_id != 0:
		var team_id := _team_for_peer(flag.carrier_peer_id)
		if team_id == TEAM_RED:
			return "carried by Red"
		if team_id == TEAM_BLUE:
			return "carried by Blue"
		return "carried"
	if flag.is_home():
		return "center"
	return "dropped"

func _team_for_peer(peer_id: int) -> int:
	if not team_for_peer_cb.is_valid():
		return -1
	return int(team_for_peer_cb.call(peer_id))

func _objective_marker_position() -> Vector2:
	if neutral_flag != null:
		return neutral_flag.world_position
	var red_team := teams_by_id.get(TEAM_RED, null) as CtfTeam
	var blue_team := teams_by_id.get(TEAM_BLUE, null) as CtfTeam
	if red_team != null and blue_team != null:
		return red_team.base_position.lerp(blue_team.base_position, 0.5) + Vector2(0.0, -42.0)
	return Vector2.ZERO

func _is_inside_team_capture_area(player: NetPlayer, team_id: int) -> bool:
	if _capture_areas == null:
		return false
	return _capture_areas.contains_player(team_id, player)

func _rebuild_visuals() -> void:
	if _visuals == null:
		return
	_visuals.rebuild(teams_by_id, _objective_marker_position())

func _update_visuals() -> void:
	if _visuals == null:
		return
	_visuals.update(teams_by_id, _objective_marker_position())

func _set_visuals_visible(visible: bool) -> void:
	if _visuals != null:
		_visuals.set_visible(visible)
