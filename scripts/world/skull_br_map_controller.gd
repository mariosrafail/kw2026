extends MapController
class_name SkullBrMapController

func _init() -> void:
	map_id = "skull_br"
	map_label = "BR"
	scene_path = "res://scenes/skull_br.tscn"
	max_players = 5
	supported_modes = ["battle_royale"]
	mode_max_players = {
		"battle_royale": 5
	}
	spawn_points = [
		Vector2(58.0, 820.0),
		Vector2(450.0, 850.0),
		Vector2(550.0, 850.0),
		Vector2(1150.0, 850.0),
		Vector2(1500.0, 850.0)
	]
	play_bounds = Rect2i(0, 0, 3104, 3104)
	camera_limits_rect = Rect2i(0, 0, 3104, 3104)
