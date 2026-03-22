extends MapController
class_name MainTdthMapController

func _init() -> void:
	map_id = "main_tdth"
	map_label = "Main Map TDTH"
	scene_path = "res://scenes/main_tdth.tscn"
	max_players = 4
	supported_modes = ["tdth"]
	mode_max_players = {
		"tdth": 4
	}
	spawn_points = [
		Vector2(180.0, 480.0),
		Vector2(260.0, 480.0),
		Vector2(1020.0, 480.0),
		Vector2(1100.0, 480.0)
	]
	play_bounds = Rect2i(0, 0, 1280, 720)
	camera_limits_rect = Rect2i(128, -150, 1024, 766)
