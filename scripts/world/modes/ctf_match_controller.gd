extends RefCounted
class_name CtfMatchController

const CTF_TEAM_SCRIPT := preload("res://scripts/world/modes/ctf_team.gd")
const CTF_FLAG_STATE_SCRIPT := preload("res://scripts/world/modes/ctf_flag_state.gd")
const CTF_MARKER_TEXTURE := preload("res://assets/textures/flag.png")
const RED_CAPTURE_AREA_NAME := "CtfRedCaptureArea"
const BLUE_CAPTURE_AREA_NAME := "CtfBlueCaptureArea"

const TEAM_RED := 0
const TEAM_BLUE := 1
const CARRIER_SPEED_MULTIPLIER := 0.82
const FLAG_PICKUP_RADIUS := 44.0
const BASE_CAPTURE_RADIUS := 46.0
const CAPTURE_GOAL_RADIUS := 92.0
const FLAG_RETURN_RADIUS := 26.0
const FLAG_DROP_RESET_SEC := 12.0

var players: Dictionary = {}
var player_display_names: Dictionary = {}
var peer_team_by_peer: Dictionary = {}
var world_root: Node2D

var get_play_bounds_cb: Callable = Callable()
var on_score_changed_cb: Callable = Callable()

var teams_by_id: Dictionary = {}
var neutral_flag: CtfFlagState
var _visual_root: Node2D
var _base_nodes_by_team: Dictionary = {}
var _neutral_flag_node: Sprite2D
var _neutral_flag_glow_node: Sprite2D
var _capture_areas_by_team: Dictionary = {}
var _last_bounds := Rect2i()

func configure(refs: Dictionary, callbacks: Dictionary) -> void:
	players = refs.get("players", {}) as Dictionary
	player_display_names = refs.get("player_display_names", {}) as Dictionary
	peer_team_by_peer = refs.get("peer_team_by_peer", {}) as Dictionary
	world_root = refs.get("world_root", null) as Node2D

	get_play_bounds_cb = callbacks.get("get_play_bounds", Callable()) as Callable
	on_score_changed_cb = callbacks.get("on_score_changed", Callable()) as Callable

func reset() -> void:
	peer_team_by_peer.clear()
	teams_by_id.clear()
	neutral_flag = null
	_last_bounds = Rect2i()
	if _visual_root != null and is_instance_valid(_visual_root):
		_visual_root.queue_free()
	_visual_root = null
	_base_nodes_by_team.clear()
	_neutral_flag_node = null
	_neutral_flag_glow_node = null
	_capture_areas_by_team.clear()

func assign_teams(participants: Array[int]) -> void:
	_ensure_layout()
	var ordered: Array[int] = []
	for value in participants:
		var peer_id := int(value)
		if peer_id == 0 or ordered.has(peer_id):
			continue
		ordered.append(peer_id)
	ordered.sort()
	for index in range(ordered.size()):
		peer_team_by_peer[ordered[index]] = TEAM_RED if index < 2 else TEAM_BLUE
	_apply_carrier_speed_modifiers()

func team_for_peer(peer_id: int) -> int:
	return int(peer_team_by_peer.get(peer_id, -1))

func is_enemy_target(attacker_peer_id: int, target_peer_id: int) -> bool:
	if attacker_peer_id == target_peer_id:
		return false
	var attacker_team := team_for_peer(attacker_peer_id)
	var target_team := team_for_peer(target_peer_id)
	if attacker_team < 0 or target_team < 0:
		return true
	return attacker_team != target_team

func spawn_position_for_peer(peer_id: int) -> Vector2:
	_ensure_layout()
	var team_id := team_for_peer(peer_id)
	var team := teams_by_id.get(team_id, null) as CtfTeam
	if team == null or team.spawn_points.is_empty():
		return Vector2.ZERO
	var spawn_count: int = int(team.spawn_points.size())
	var team_peers: Array[int] = []
	for peer_value in peer_team_by_peer.keys():
		var candidate_peer_id := int(peer_value)
		if team_for_peer(candidate_peer_id) != team_id:
			continue
		team_peers.append(candidate_peer_id)
	team_peers.sort_custom(func(a: int, b: int) -> bool:
		var a_is_human := a > 0
		var b_is_human := b > 0
		if a_is_human != b_is_human:
			return a_is_human
		return abs(a) < abs(b)
	)
	var index := maxi(team_peers.find(peer_id), 0) % spawn_count
	return team.spawn_points[index]

func server_tick(enabled: bool, delta: float) -> void:
	if not enabled:
		_set_visuals_visible(false)
		return
	_ensure_layout()
	_set_visuals_visible(true)

	var dirty: bool = false
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
		var team_id := team_for_peer(peer_id)
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
			var capture_goal := capture_goal_for_team(team_id)
			var near_capture_goal := capture_goal != Vector2.ZERO and player.global_position.distance_to(capture_goal) <= CAPTURE_GOAL_RADIUS
			var near_team_base := player.global_position.distance_to(team.base_position) <= BASE_CAPTURE_RADIUS
			if in_capture_area or near_capture_goal or near_team_base:
				print("[CTF CAPTURE] score peer=%d team=%d pos=%s area=%s near_goal=%s near_base=%s goal=%s base=%s" % [
					peer_id,
					team_id,
					str(player.global_position),
					str(in_capture_area),
					str(near_capture_goal),
					str(near_team_base),
					str(capture_goal),
					str(team.base_position)
				])
				team.score += 1
				neutral_flag.reset_to_home()
				dirty = true
				if on_score_changed_cb.is_valid():
					on_score_changed_cb.call()
			elif int(Time.get_ticks_msec()) % 350 < 18:
				print("[CTF CAPTURE] check peer=%d team=%d pos=%s area=%s near_goal=%s near_base=%s goal=%s base=%s" % [
					peer_id,
					team_id,
					str(player.global_position),
					str(in_capture_area),
					str(near_capture_goal),
					str(near_team_base),
					str(capture_goal),
					str(team.base_position)
				])

	_update_visuals()
	if dirty:
		_apply_carrier_speed_modifiers()

func visual_tick(enabled: bool) -> void:
	if not enabled:
		_set_visuals_visible(false)
		return
	_ensure_layout()
	_set_visuals_visible(true)
	_update_visuals()

func drop_flag_for_peer(peer_id: int, world_position: Vector2) -> void:
	if neutral_flag == null or neutral_flag.carrier_peer_id != peer_id:
		return
	neutral_flag.carrier_peer_id = 0
	neutral_flag.world_position = world_position
	neutral_flag.dropped_time_sec = 0.0
	_apply_carrier_speed_modifiers()
	_update_visuals()

func movement_speed_multiplier_for_peer(peer_id: int) -> float:
	if neutral_flag != null and neutral_flag.carrier_peer_id == peer_id:
		return CARRIER_SPEED_MULTIPLIER
	return 1.0

func flag_carrier_peer_id() -> int:
	return neutral_flag.carrier_peer_id if neutral_flag != null else 0

func flag_world_position() -> Vector2:
	return neutral_flag.world_position if neutral_flag != null else _objective_marker_position()

func team_score(team_id: int) -> int:
	var team := teams_by_id.get(team_id, null) as CtfTeam
	return team.score if team != null else 0

func base_position_for_team(team_id: int) -> Vector2:
	var team := teams_by_id.get(team_id, null) as CtfTeam
	return team.base_position if team != null else Vector2.ZERO

func capture_goal_for_team(team_id: int) -> Vector2:
	var area := _capture_areas_by_team.get(team_id, null) as Area2D
	if area != null and is_instance_valid(area):
		return area.global_position
	return base_position_for_team(team_id)

func is_peer_carrying_flag(peer_id: int) -> bool:
	return neutral_flag != null and neutral_flag.carrier_peer_id == peer_id

func apply_synced_state(carrier_peer_id: int, world_position: Vector2, red_score: int, blue_score: int) -> void:
	_ensure_layout()
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

func hud_score_text() -> String:
	var red_team := teams_by_id.get(TEAM_RED, null) as CtfTeam
	var blue_team := teams_by_id.get(TEAM_BLUE, null) as CtfTeam
	var red_score: int = red_team.score if red_team != null else 0
	var blue_score: int = blue_team.score if blue_team != null else 0
	return "CTF  RED %d  BLUE %d" % [red_score, blue_score]

func scoreboard_text(player_stats: Dictionary, names: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append(hud_score_text())
	lines.append(_flag_status_line())
	lines.append("")
	for team_id in [TEAM_RED, TEAM_BLUE]:
		var team := teams_by_id.get(team_id, null) as CtfTeam
		if team == null:
			continue
		lines.append("%s TEAM" % team.team_name.to_upper())
		var peer_ids: Array[int] = []
		for peer_value in peer_team_by_peer.keys():
			var peer_id := int(peer_value)
			if team_for_peer(peer_id) == team_id:
				peer_ids.append(peer_id)
		peer_ids.sort()
		for peer_id in peer_ids:
			var stats := player_stats.get(peer_id, {"kills": 0, "deaths": 0}) as Dictionary
			var display_name := str(names.get(peer_id, "P%d" % peer_id))
			lines.append("%s  %d/%d" % [display_name, int(stats.get("kills", 0)), int(stats.get("deaths", 0))])
		if team_id == TEAM_RED:
			lines.append("")
	return "\n".join(lines)

func _flag_status_line() -> String:
	return "Flag: %s" % _flag_status(neutral_flag)

func _flag_status(flag: CtfFlagState) -> String:
	if flag == null:
		return "?"
	if flag.carrier_peer_id != 0:
		var team_id := team_for_peer(flag.carrier_peer_id)
		if team_id == TEAM_RED:
			return "carried by Red"
		if team_id == TEAM_BLUE:
			return "carried by Blue"
		return "carried"
	if flag.is_home():
		return "center"
	return "dropped"

func _ensure_layout() -> void:
	var bounds: Rect2i = _play_bounds()
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return
	if not teams_by_id.is_empty() and bounds == _last_bounds:
		_ensure_visual_root()
		_update_visuals()
		return
	_last_bounds = bounds
	var base_y: float = float(bounds.position.y) + float(bounds.size.y) * 0.76
	var left_x: float = float(bounds.position.x) + float(bounds.size.x) * 0.16
	var right_x: float = float(bounds.position.x) + float(bounds.size.x) * 0.84
	var red_base: Vector2 = Vector2(left_x, base_y)
	var blue_base: Vector2 = Vector2(right_x, base_y)

	var red_team := CTF_TEAM_SCRIPT.new()
	red_team.configure(TEAM_RED, "Red", Color(0.92, 0.2, 0.18, 1.0), red_base, [
		red_base + Vector2(-42.0, -50.0),
		red_base + Vector2(42.0, -50.0)
	])
	var blue_team := CTF_TEAM_SCRIPT.new()
	blue_team.configure(TEAM_BLUE, "Blue", Color(0.24, 0.54, 0.95, 1.0), blue_base, [
		blue_base + Vector2(-42.0, -50.0),
		blue_base + Vector2(42.0, -50.0)
	])
	if teams_by_id.has(TEAM_RED):
		red_team.score = int((teams_by_id[TEAM_RED] as CtfTeam).score)
	if teams_by_id.has(TEAM_BLUE):
		blue_team.score = int((teams_by_id[TEAM_BLUE] as CtfTeam).score)
	teams_by_id[TEAM_RED] = red_team
	teams_by_id[TEAM_BLUE] = blue_team
	_capture_areas_by_team[TEAM_RED] = _find_capture_area(RED_CAPTURE_AREA_NAME)
	_capture_areas_by_team[TEAM_BLUE] = _find_capture_area(BLUE_CAPTURE_AREA_NAME)

	var flag_home := red_base.lerp(blue_base, 0.5) + Vector2(0.0, -26.0)
	if neutral_flag == null:
		neutral_flag = CTF_FLAG_STATE_SCRIPT.new()
		neutral_flag.configure(-1, flag_home)
	else:
		var was_carried := neutral_flag.carrier_peer_id != 0
		var was_dropped := neutral_flag.is_dropped()
		neutral_flag.home_position = flag_home
		if not was_carried and not was_dropped:
			neutral_flag.reset_to_home()

	_ensure_visual_root()
	_rebuild_visuals()
	_apply_carrier_speed_modifiers()
	_update_visuals()

func _ensure_visual_root() -> void:
	if world_root == null:
		return
	if _visual_root != null and is_instance_valid(_visual_root):
		return
	_visual_root = Node2D.new()
	_visual_root.name = "CtfMode"
	world_root.add_child(_visual_root)

func _rebuild_visuals() -> void:
	if _visual_root == null:
		return
	for child in _visual_root.get_children():
		child.queue_free()
	_base_nodes_by_team.clear()
	_neutral_flag_node = null
	_neutral_flag_glow_node = null
	for team_id in [TEAM_RED, TEAM_BLUE]:
		var team := teams_by_id.get(team_id, null) as CtfTeam
		if team == null:
			continue
		var base_node := Polygon2D.new()
		base_node.polygon = PackedVector2Array([
			Vector2(-38.0, -16.0),
			Vector2(38.0, -16.0),
			Vector2(38.0, 16.0),
			Vector2(-38.0, 16.0)
		])
		base_node.color = Color(team.color.r, team.color.g, team.color.b, 0.28)
		base_node.z_index = 8
		base_node.global_position = team.base_position
		_visual_root.add_child(base_node)
		_base_nodes_by_team[team_id] = base_node

	var objective_position := _objective_marker_position()
	var objective_glow := Sprite2D.new()
	objective_glow.texture = CTF_MARKER_TEXTURE
	objective_glow.centered = true
	objective_glow.modulate = Color(0.14, 0.95, 0.28, 0.18)
	objective_glow.scale = Vector2(1.2, 1.2)
	objective_glow.z_as_relative = false
	objective_glow.z_index = 98
	objective_glow.global_position = objective_position
	_visual_root.add_child(objective_glow)
	_neutral_flag_glow_node = objective_glow
	var objective_node := Sprite2D.new()
	objective_node.texture = CTF_MARKER_TEXTURE
	objective_node.centered = true
	objective_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
	objective_node.scale = Vector2(1, 1)
	objective_node.z_as_relative = false
	objective_node.z_index = 99
	objective_node.global_position = objective_position
	_visual_root.add_child(objective_node)
	_neutral_flag_node = objective_node

func _update_visuals() -> void:
	if _visual_root == null:
		return
	for team_id in [TEAM_RED, TEAM_BLUE]:
		var team := teams_by_id.get(team_id, null) as CtfTeam
		var base_node := _base_nodes_by_team.get(team_id, null) as Polygon2D
		if team != null and base_node != null:
			base_node.global_position = team.base_position
	if _neutral_flag_node != null and is_instance_valid(_neutral_flag_node):
		var objective_position := _objective_marker_position()
		_neutral_flag_node.global_position = objective_position
		if _neutral_flag_glow_node != null and is_instance_valid(_neutral_flag_glow_node):
			_neutral_flag_glow_node.global_position = objective_position

func _set_visuals_visible(visible: bool) -> void:
	if _visual_root != null and is_instance_valid(_visual_root):
		_visual_root.visible = visible

func _play_bounds() -> Rect2i:
	if get_play_bounds_cb.is_valid():
		return get_play_bounds_cb.call() as Rect2i
	return Rect2i(0, 0, 1280, 720)

func _apply_carrier_speed_modifiers() -> void:
	for peer_value in players.keys():
		var peer_id := int(peer_value)
		var player := players.get(peer_id, null) as NetPlayer
		if player == null or not player.has_method("set_external_movement_speed_multiplier"):
			continue
		player.call("set_external_movement_speed_multiplier", movement_speed_multiplier_for_peer(peer_id))

func _objective_marker_position() -> Vector2:
	if neutral_flag != null:
		return neutral_flag.world_position
	var red_team := teams_by_id.get(TEAM_RED, null) as CtfTeam
	var blue_team := teams_by_id.get(TEAM_BLUE, null) as CtfTeam
	if red_team != null and blue_team != null:
		return red_team.base_position.lerp(blue_team.base_position, 0.5) + Vector2(0.0, -26.0)
	return Vector2.ZERO

func _find_capture_area(area_name: String) -> Area2D:
	if world_root == null:
		return null
	var direct := world_root.get_node_or_null(area_name) as Area2D
	if direct != null:
		return direct
	var nested := world_root.find_child(area_name, true, false) as Area2D
	if nested != null:
		return nested
	var scene_root := world_root.get_parent()
	if scene_root != null:
		return scene_root.find_child(area_name, true, false) as Area2D
	return null

func _is_inside_team_capture_area(player: NetPlayer, team_id: int) -> bool:
	var area := _capture_areas_by_team.get(team_id, null) as Area2D
	if area == null or not is_instance_valid(area) or player == null:
		return false
	return _area_contains_point(area, player.global_position)

func _area_contains_point(area: Area2D, world_position: Vector2) -> bool:
	for child in area.get_children():
		if child is CollisionShape2D:
			var shape_node := child as CollisionShape2D
			if shape_node.disabled:
				continue
			var shape := shape_node.shape
			if shape == null:
				continue
			var local_point := shape_node.to_local(world_position)
			if _shape_contains_local_point(shape, local_point):
				return true
		elif child is CollisionPolygon2D:
			var polygon_node := child as CollisionPolygon2D
			if polygon_node.disabled or polygon_node.polygon.is_empty():
				continue
			var local_point := polygon_node.to_local(world_position)
			if Geometry2D.is_point_in_polygon(local_point, polygon_node.polygon):
				return true
	return false

func _shape_contains_local_point(shape: Shape2D, local_point: Vector2) -> bool:
	if shape is RectangleShape2D:
		var rect := shape as RectangleShape2D
		var half_size := rect.size * 0.5
		return absf(local_point.x) <= half_size.x and absf(local_point.y) <= half_size.y
	if shape is CircleShape2D:
		var circle := shape as CircleShape2D
		return local_point.length_squared() <= circle.radius * circle.radius
	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		var radius := capsule.radius
		var straight_half := maxf(0.0, (capsule.height * 0.5) - radius)
		if absf(local_point.x) <= radius and absf(local_point.y) <= straight_half:
			return true
		var top_center := Vector2(0.0, -straight_half)
		var bottom_center := Vector2(0.0, straight_half)
		return local_point.distance_squared_to(top_center) <= radius * radius or local_point.distance_squared_to(bottom_center) <= radius * radius
	return false
