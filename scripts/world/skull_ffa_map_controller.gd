extends MapController
class_name SkullFfaMapController

func _init() -> void:
	map_id = "skull_ffa"
	map_label = "Skull FFA"
	scene_path = "res://scenes/skull_ffa.tscn"
	max_players = 5
	supported_modes = ["deathmatch"]
	mode_max_players = {
		"deathmatch": 5
	}
	spawn_points = [
		Vector2(180.0, 480.0),
		Vector2(264.0, 285.0),
		Vector2(536.0, 368.0),
		Vector2(833.0, 422.0),
		Vector2(1100.0, 400.0)
	]
	play_bounds = Rect2i(0, 0, 1280, 720)
	camera_limits_rect = Rect2i(128, 104, 1024, 512)
