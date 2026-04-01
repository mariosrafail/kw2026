extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/skull_rounds.tscn") as PackedScene
	if packed == null:
		push_error("scene load failed")
		quit(1)
		return
	var root := packed.instantiate()
	if root == null:
		push_error("instantiate failed")
		quit(1)
		return
	var map_controller := root.get_node_or_null("World/MapController")
	if map_controller == null:
		push_error("map controller missing")
		quit(1)
		return
	print("scene=", root.scene_file_path)
	print("map_script=", map_controller.get_script())
	if map_controller.has_method("normalized_map_id"):
		print("map_id=", map_controller.call("normalized_map_id"))
	quit(0)
