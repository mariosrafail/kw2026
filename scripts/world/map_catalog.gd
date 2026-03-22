extends RefCounted
class_name MapCatalog

const MAIN_FFA_MAP_CONTROLLER := preload("res://scripts/world/main_ffa_map_controller.gd")
const MAIN_TDTH_MAP_CONTROLLER := preload("res://scripts/world/main_tdth_map_controller.gd")
const MAIN_CTF_MAP_CONTROLLER := preload("res://scripts/world/main_ctf_map_controller.gd")

var _maps_by_id: Dictionary = {}
var _ordered_map_ids: Array[String] = []
var _default_map_id := "main_ffa"

func _init() -> void:
	_register_controller(MAIN_FFA_MAP_CONTROLLER.new())
	_register_controller(MAIN_TDTH_MAP_CONTROLLER.new())
	_register_controller(MAIN_CTF_MAP_CONTROLLER.new())
	if _ordered_map_ids.is_empty():
		_ordered_map_ids.append(_default_map_id)
		_maps_by_id[_default_map_id] = {
			"id": _default_map_id,
			"label": "Main Map FFA",
			"scene_path": "res://scenes/main_ffa.tscn",
			"max_players": 2,
			"spawn_points": [],
			"supported_modes": ["deathmatch"],
			"mode_max_players": {}
		}
	if not _maps_by_id.has(_default_map_id):
		_default_map_id = _ordered_map_ids[0]

func default_map_id() -> String:
	return _default_map_id

func all_map_ids() -> Array[String]:
	return _ordered_map_ids.duplicate()

func normalize_map_id(map_id: String) -> String:
	var normalized := map_id.strip_edges().to_lower()
	if _maps_by_id.has(normalized):
		return normalized
	return _default_map_id

func label_for_id(map_id: String) -> String:
	var map_entry := _map_entry(map_id)
	return str(map_entry.get("label", normalize_map_id(map_id).capitalize()))

func scene_path_for_id(map_id: String) -> String:
	var map_entry := _map_entry(map_id)
	return str(map_entry.get("scene_path", ""))

func max_players_for_id(map_id: String) -> int:
	var map_entry := _map_entry(map_id)
	return maxi(1, int(map_entry.get("max_players", 2)))

func spawn_points_for_id(map_id: String) -> Array:
	var map_entry := _map_entry(map_id)
	var points := map_entry.get("spawn_points", []) as Array
	return points.duplicate()

func map_id_for_scene_path(scene_path: String) -> String:
	var normalized_scene_path := scene_path.strip_edges()
	for map_id in _ordered_map_ids:
		var map_entry := _maps_by_id.get(map_id, {}) as Dictionary
		if str(map_entry.get("scene_path", "")) == normalized_scene_path:
			return map_id
	return _default_map_id

func _register_controller(controller: MapController) -> void:
	if controller == null:
		return
	var map_id := controller.normalized_map_id()
	if map_id.is_empty():
		return
	if _maps_by_id.has(map_id):
		return
	if _ordered_map_ids.is_empty():
		_default_map_id = map_id
	_ordered_map_ids.append(map_id)
	_maps_by_id[map_id] = {
		"id": map_id,
		"label": controller.display_label(),
		"scene_path": controller.configured_scene_path(),
		"max_players": controller.configured_max_players(),
		"spawn_points": controller.configured_spawn_points(),
		"supported_modes": controller.configured_supported_modes(),
		"mode_max_players": controller.configured_mode_max_players()
	}

func _map_entry(map_id: String) -> Dictionary:
	var normalized := normalize_map_id(map_id)
	return _maps_by_id.get(normalized, {}) as Dictionary

func supported_modes_for_id(map_id: String) -> Array[String]:
	var map_entry := _map_entry(map_id)
	var raw_modes := map_entry.get("supported_modes", []) as Array
	var modes: Array[String] = []
	for mode_value in raw_modes:
		var mode_id := str(mode_value).strip_edges().to_lower()
		if mode_id.is_empty():
			continue
		if not modes.has(mode_id):
			modes.append(mode_id)
	if modes.is_empty():
		modes.append("deathmatch")
	return modes

func max_players_for_mode(map_id: String, mode_id: String) -> int:
	var map_entry := _map_entry(map_id)
	var per_mode := map_entry.get("mode_max_players", {}) as Dictionary
	var normalized_mode := str(mode_id).strip_edges().to_lower()
	if per_mode.has(normalized_mode):
		return maxi(1, int(per_mode.get(normalized_mode, max_players_for_id(map_id))))
	return max_players_for_id(map_id)
