extends MapController
class_name SkullDeathmatchMapController

func _init() -> void:
	map_id = "skull_deathmatch"
	map_label = "Deathmatch"
	scene_path = "res://scenes/skull_deathmatch.tscn"
	max_players = 5
	supported_modes = ["deathmatch"]
	mode_max_players = {
		"deathmatch": 5
	}
	spawn_points = [
		Vector2(58.0, 820.0),
		Vector2(450.0, 850.0),
		Vector2(550.0, 850.0),
		Vector2(1150.0, 850.0),
		Vector2(1500.0, 850.0)
	]
	play_bounds = Rect2i(0, 0, 2048.0, 2048.0)
	camera_limits_rect = Rect2i(0, 0, 2048.0, 2048.0)
