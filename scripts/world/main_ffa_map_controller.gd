extends MapController
class_name MainFfaMapController

func _init() -> void:
	map_id = "main_ffa"
	map_label = "Main Map FFA"
	scene_path = "res://scenes/main_ffa.tscn"
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
	camera_limits_rect = Rect2i(128, 128, 1024, 766)
