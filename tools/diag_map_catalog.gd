extends SceneTree

func _init() -> void:
	var map_catalog := preload("res://scripts/world/map_catalog.gd").new()
	print("MAP_IDS:", map_catalog.all_map_ids())
	for map_id in map_catalog.all_map_ids():
		print("MAP:", map_id, " LABEL:", map_catalog.label_for_id(map_id), " SCENE:", map_catalog.scene_path_for_id(map_id))
	print("NORMALIZE testlab -> ", map_catalog.normalize_map_id("testlab"))
	print("SCENE testlab -> ", map_catalog.scene_path_for_id("testlab"))
	quit()
