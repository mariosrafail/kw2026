extends MapController
class_name TestMapController

func _init() -> void:
	map_id = "testlab"
	map_label = "Test Lab"
	scene_path = "res://scenes/main_test.tscn"
	max_players = 2
	spawn_points = [
		Vector2(36.0, 225.0),
		Vector2(470.0, 225.0)
	]
	play_bounds = Rect2i(0, 0, 512, 512)
	camera_limits_rect = Rect2i(0, 0, 512, 512)
