extends MapController
class_name MainDthMapController

func _init() -> void:
	map_id = "main_deathmatch"
	map_label = "Main Map Deathmatch"
	scene_path = "res://scenes/main_dth.tscn"
	max_players = 2
	supported_modes = ["deathmatch"]
	mode_max_players = {
		"deathmatch": 2
	}
	spawn_points = [
		Vector2(180.0, 480.0),
		Vector2(260.0, 480.0),
		Vector2(1020.0, 480.0),
		Vector2(1100.0, 480.0)
	]
	play_bounds = Rect2i(0, 0, 1280, 720)
	camera_limits_rect = Rect2i(128, -150, 1024, 766)
