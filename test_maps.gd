extends SceneTree

func _init() -> void:
	var map_catalog = preload("res://scripts/world/map_catalog.gd").new()
	print("=== MAP CATALOG DIAGNOSTIC ===")
	print("All map IDs: ", map_catalog.all_map_ids())
	print("")
	for map_id in map_catalog.all_map_ids():
		var label = map_catalog.label_for_id(map_id)
		var scene = map_catalog.scene_path_for_id(map_id)
		var max_players = map_catalog.max_players_for_id(map_id)
		print("MAP: %s | LABEL: %s | SCENE: %s | MAX: %d" % [map_id, label, scene, max_players])
	quit()
