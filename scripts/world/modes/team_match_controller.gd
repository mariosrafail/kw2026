extends RefCounted
class_name TeamMatchController

const CTF_TEAM_SCRIPT := preload("res://scripts/world/modes/ctf_team.gd")
const CTF_OBJECTIVE_MODULE_SCRIPT := preload("res://scripts/world/modes/ctf_objective_module.gd")

const TEAM_RED := 0
const TEAM_BLUE := 1

var players: Dictionary = {}
var player_display_names: Dictionary = {}
var peer_team_by_peer: Dictionary = {}
var world_root: Node2D

var get_play_bounds_cb: Callable = Callable()
var on_score_changed_cb: Callable = Callable()

var teams_by_id: Dictionary = {}
var _objective: CtfObjectiveModule
var _last_bounds := Rect2i()

func configure(refs: Dictionary, callbacks: Dictionary) -> void:
	players = refs.get("players", {}) as Dictionary
	player_display_names = refs.get("player_display_names", {}) as Dictionary
	peer_team_by_peer = refs.get("peer_team_by_peer", {}) as Dictionary
	world_root = refs.get("world_root", null) as Node2D

	get_play_bounds_cb = callbacks.get("get_play_bounds", Callable()) as Callable
	on_score_changed_cb = callbacks.get("on_score_changed", Callable()) as Callable
	if _objective == null:
		_objective = CTF_OBJECTIVE_MODULE_SCRIPT.new()
	_objective.configure(
		{
			"teams_by_id": teams_by_id,
			"players": players,
			"world_root": world_root
		},
		{
			"team_for_peer": Callable(self, "team_for_peer"),
			"on_score_changed": on_score_changed_cb
		}
	)

func reset() -> void:
	peer_team_by_peer.clear()
	teams_by_id.clear()
	_last_bounds = Rect2i()
	if _objective != null:
		_objective.reset()

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
	_ensure_layout()
	if _objective == null:
		return
	var dirty := _objective.server_tick(enabled, delta)
	if dirty:
		_apply_carrier_speed_modifiers()

func visual_tick(enabled: bool) -> void:
	_ensure_layout()
	if _objective != null:
		_objective.visual_tick(enabled)

func drop_flag_for_peer(peer_id: int, world_position: Vector2) -> void:
	if _objective == null:
		return
	_objective.drop_flag_for_peer(peer_id, world_position)
	_apply_carrier_speed_modifiers()

func movement_speed_multiplier_for_peer(peer_id: int) -> float:
	if _objective == null:
		return 1.0
	return _objective.movement_speed_multiplier_for_peer(peer_id)

func flag_carrier_peer_id() -> int:
	if _objective == null:
		return 0
	return _objective.flag_carrier_peer_id()

func flag_world_position() -> Vector2:
	if _objective == null:
		return _objective_marker_position()
	return _objective.flag_world_position(_objective_marker_position())

func team_score(team_id: int) -> int:
	if _objective == null:
		var team := teams_by_id.get(team_id, null) as CtfTeam
		return team.score if team != null else 0
	return _objective.team_score(team_id)

func base_position_for_team(team_id: int) -> Vector2:
	var team := teams_by_id.get(team_id, null) as CtfTeam
	return team.base_position if team != null else Vector2.ZERO

func capture_goal_for_team(team_id: int) -> Vector2:
	if _objective == null:
		return base_position_for_team(team_id)
	return _objective.capture_goal_for_team(team_id, base_position_for_team(team_id))

func is_peer_carrying_flag(peer_id: int) -> bool:
	if _objective == null:
		return false
	return _objective.is_peer_carrying_flag(peer_id)

func apply_synced_state(carrier_peer_id: int, world_position: Vector2, red_score: int, blue_score: int) -> void:
	_ensure_layout()
	if _objective != null:
		_objective.apply_synced_state(carrier_peer_id, world_position, red_score, blue_score)

func hud_score_text() -> String:
	var red_team := teams_by_id.get(TEAM_RED, null) as CtfTeam
	var blue_team := teams_by_id.get(TEAM_BLUE, null) as CtfTeam
	var red_score: int = red_team.score if red_team != null else 0
	var blue_score: int = blue_team.score if blue_team != null else 0
	return "CTF  RED %d  BLUE %d" % [red_score, blue_score]

func hud_score_text_for_mode(mode_label: String = "CTF") -> String:
	var red_team := teams_by_id.get(TEAM_RED, null) as CtfTeam
	var blue_team := teams_by_id.get(TEAM_BLUE, null) as CtfTeam
	var red_score: int = red_team.score if red_team != null else 0
	var blue_score: int = blue_team.score if blue_team != null else 0
	var label := mode_label.strip_edges().to_upper()
	if label.is_empty():
		label = "TEAM"
	return "%s  RED %d  BLUE %d" % [label, red_score, blue_score]

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

func scoreboard_table_text(player_stats: Dictionary, names: Dictionary, include_objective: bool = false, mode_label: String = "TEAM") -> String:
	var red_entries := _team_entries_for_scoreboard(TEAM_RED, player_stats, names)
	var blue_entries := _team_entries_for_scoreboard(TEAM_BLUE, player_stats, names)
	var rows := maxi(red_entries.size(), blue_entries.size())
	var unassigned_entries := _unassigned_entries_for_scoreboard(player_stats, names)
	var lines := PackedStringArray()
	lines.append(hud_score_text_for_mode(mode_label))
	if include_objective:
		lines.append(_flag_status_line())
	lines.append("")
	lines.append(_pad_right("RED TEAM", 24) + "BLUE TEAM")
	lines.append(_pad_right("NAME        K/D", 24) + "NAME        K/D")
	for i in range(rows):
		var red_row := red_entries[i] if i < red_entries.size() else ""
		var blue_row := blue_entries[i] if i < blue_entries.size() else ""
		lines.append(_pad_right(red_row, 24) + blue_row)
	if not unassigned_entries.is_empty():
		lines.append("")
		lines.append("UNASSIGNED")
		for row in unassigned_entries:
			lines.append(row)
	return "\n".join(lines)

func _flag_status_line() -> String:
	if _objective == null:
		return "Flag: ?"
	return _objective.flag_status_line()

func _ensure_layout() -> void:
	var bounds: Rect2i = _play_bounds()
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return
	if not teams_by_id.is_empty() and bounds == _last_bounds:
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

	if _objective != null:
		_objective.refresh_layout(_default_objective_home(red_base, blue_base))

	_apply_carrier_speed_modifiers()

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
	var red_team := teams_by_id.get(TEAM_RED, null) as CtfTeam
	var blue_team := teams_by_id.get(TEAM_BLUE, null) as CtfTeam
	if red_team != null and blue_team != null:
		return _default_objective_home(red_team.base_position, blue_team.base_position)
	return Vector2.ZERO

func _default_objective_home(red_base: Vector2, blue_base: Vector2) -> Vector2:
	return red_base.lerp(blue_base, 0.5) + Vector2(0.0, -42.0)

func _team_entries_for_scoreboard(team_id: int, player_stats: Dictionary, names: Dictionary) -> Array[String]:
	var peer_ids := _sorted_known_peer_ids(player_stats, names)
	peer_ids.sort()
	var lines: Array[String] = []
	for peer_id in peer_ids:
		if team_for_peer(peer_id) != team_id:
			continue
		var stats := player_stats.get(peer_id, {"kills": 0, "deaths": 0}) as Dictionary
		var display_name := str(names.get(peer_id, "P%d" % peer_id))
		lines.append("%s %d/%d" % [_truncate_label(display_name, 10), int(stats.get("kills", 0)), int(stats.get("deaths", 0))])
	return lines

func _unassigned_entries_for_scoreboard(player_stats: Dictionary, names: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var peer_ids := _sorted_known_peer_ids(player_stats, names)
	for peer_id in peer_ids:
		if team_for_peer(peer_id) >= 0:
			continue
		var stats := player_stats.get(peer_id, {"kills": 0, "deaths": 0}) as Dictionary
		var display_name := str(names.get(peer_id, "P%d" % peer_id))
		lines.append("%s %d/%d" % [_truncate_label(display_name, 10), int(stats.get("kills", 0)), int(stats.get("deaths", 0))])
	return lines

func _sorted_known_peer_ids(player_stats: Dictionary, names: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for peer_value in peer_team_by_peer.keys():
		var peer_id := int(peer_value)
		if peer_id == 0 or out.has(peer_id):
			continue
		out.append(peer_id)
	for peer_value in players.keys():
		var peer_id := int(peer_value)
		if peer_id == 0 or out.has(peer_id):
			continue
		out.append(peer_id)
	for peer_value in player_stats.keys():
		var peer_id := int(peer_value)
		if peer_id == 0 or out.has(peer_id):
			continue
		out.append(peer_id)
	for peer_value in names.keys():
		var peer_id := int(peer_value)
		if peer_id == 0 or out.has(peer_id):
			continue
		out.append(peer_id)
	out.sort()
	return out

func _truncate_label(value: String, max_len: int) -> String:
	var trimmed := value.strip_edges()
	if trimmed.length() <= max_len:
		return trimmed
	return trimmed.substr(0, max_len)

func _pad_right(value: String, width: int) -> String:
	var out := value
	while out.length() < width:
		out += " "
	return out
