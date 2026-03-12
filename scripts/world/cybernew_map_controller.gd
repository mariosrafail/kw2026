extends MapController
class_name CyberNewMapController

func _init() -> void:
	map_id = "cybernew"
	map_label = "CyberNew"
	scene_path = "res://scenes/cybernew.tscn"
	max_players = 2
	supported_modes = ["deathmatch", "ctf"]
	mode_max_players = {
		"deathmatch": 2,
		"ctf": 4
	}
	spawn_points = [
		Vector2(360.0, 250.0),
		Vector2(1100.0, 480.0)
	]
	play_bounds = Rect2i(0, 0, 1280, 720)
	camera_limits_rect = Rect2i(128, 104, 1024, 512)
