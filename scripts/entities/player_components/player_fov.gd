extends RefCounted

class_name PlayerFov

var _fov_detector: Node
var _fov_light: PointLight2D

func configure(fov_detector: Node, fov_light: PointLight2D) -> void:
	_fov_detector = fov_detector
	_fov_light = fov_light

func set_fov_debug(enabled: bool) -> void:
	if _fov_detector != null:
		_fov_detector.set("debug_draw", enabled)

func get_visible_players(all_players: Dictionary) -> Array:
	if _fov_detector == null or not _fov_detector.has_method("get_visible_players"):
		return []
	return _fov_detector.call("get_visible_players", all_players) as Array

func is_player_visible(player: Node) -> bool:
	if _fov_detector == null or not _fov_detector.has_method("is_body_visible"):
		return false
	return bool(_fov_detector.call("is_body_visible", player))

func set_fov_light_enabled(enabled: bool) -> void:
	if _fov_light == null:
		return
	_fov_light.enabled = enabled
