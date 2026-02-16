extends MapController
class_name TestMapController

func _init() -> void:
	map_id = "testlab"
	map_label = "Test Lab"
	scene_path = "res://scenes/main_test.tscn"
	max_players = 2
	spawn_points = [
		Vector2(240.0, 330.0),
		Vector2(850.0, 330.0)
	]
	play_bounds = Rect2i(0, 0, 1280, 720)
	camera_limits_rect = Rect2i(128, 104, 1024, 512)
