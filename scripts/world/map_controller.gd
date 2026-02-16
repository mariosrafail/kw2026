extends Node
class_name MapController

@export var map_id := "classic"
@export var map_label := "Classic"
@export var scene_path := ""
@export_range(1, 64, 1) var max_players := 2
@export var spawn_points: Array[Vector2] = []
@export var play_bounds: Rect2i = Rect2i(0, 0, 1280, 720)
@export var camera_limits_rect: Rect2i = Rect2i(128, 104, 1024, 512)
var _runtime_play_bounds: Rect2i = Rect2i()

func normalized_map_id() -> String:
	var normalized := map_id.strip_edges().to_lower()
	if normalized.is_empty():
		return "classic"
	return normalized

func display_label() -> String:
	var trimmed := map_label.strip_edges()
	if trimmed.is_empty():
		return normalized_map_id().capitalize()
	return trimmed

func configured_scene_path() -> String:
	var trimmed := scene_path.strip_edges()
	if trimmed.is_empty():
		return ""
	return trimmed

func configured_max_players() -> int:
	return maxi(1, max_players)

func configured_spawn_points() -> Array:
	return spawn_points.duplicate()

func configured_play_bounds_rect() -> Rect2i:
	return Rect2i(
		play_bounds.position,
		Vector2i(maxi(1, play_bounds.size.x), maxi(1, play_bounds.size.y))
	)

func configured_camera_limits_rect() -> Rect2i:
	return Rect2i(
		camera_limits_rect.position,
		Vector2i(maxi(1, camera_limits_rect.size.x), maxi(1, camera_limits_rect.size.y))
	)

func runtime_play_bounds_rect() -> Rect2i:
	if _runtime_play_bounds.size.x > 0 and _runtime_play_bounds.size.y > 0:
		return _runtime_play_bounds
	return configured_play_bounds_rect()

func apply_runtime_bounds(
	main_camera: Camera2D,
	border_nodes: Dictionary,
	_map_front_sprite: Sprite2D = null
) -> void:
	_runtime_play_bounds = configured_play_bounds_rect()
	_apply_camera_limits(main_camera, configured_camera_limits_rect())
	_apply_border_bodies(_runtime_play_bounds, border_nodes)

func _apply_camera_limits(main_camera: Camera2D, camera_rect: Rect2i) -> void:
	if main_camera == null:
		return
	main_camera.limit_left = camera_rect.position.x
	main_camera.limit_top = camera_rect.position.y
	main_camera.limit_right = camera_rect.position.x + camera_rect.size.x
	main_camera.limit_bottom = camera_rect.position.y + camera_rect.size.y

func _apply_border_bodies(play_rect: Rect2i, border_nodes: Dictionary) -> void:
	var border_top := border_nodes.get("top", null) as StaticBody2D
	var border_bottom := border_nodes.get("bottom", null) as StaticBody2D
	var border_left := border_nodes.get("left", null) as StaticBody2D
	var border_right := border_nodes.get("right", null) as StaticBody2D
	var border_top_shape := border_nodes.get("top_shape", null) as CollisionShape2D
	var border_bottom_shape := border_nodes.get("bottom_shape", null) as CollisionShape2D
	var border_left_shape := border_nodes.get("left_shape", null) as CollisionShape2D
	var border_right_shape := border_nodes.get("right_shape", null) as CollisionShape2D
	if border_top == null or border_bottom == null or border_left == null or border_right == null:
		return
	if border_top_shape == null or border_bottom_shape == null or border_left_shape == null or border_right_shape == null:
		return

	var top_rect := border_top_shape.shape as RectangleShape2D
	var bottom_rect := border_bottom_shape.shape as RectangleShape2D
	var left_rect := border_left_shape.shape as RectangleShape2D
	var right_rect := border_right_shape.shape as RectangleShape2D
	if top_rect == null or bottom_rect == null or left_rect == null or right_rect == null:
		return

	var left := float(play_rect.position.x)
	var top := float(play_rect.position.y)
	var right := float(play_rect.position.x + play_rect.size.x)
	var bottom := float(play_rect.position.y + play_rect.size.y)
	var width := maxf(1.0, right - left)
	var height := maxf(1.0, bottom - top)

	border_top.scale = Vector2.ONE
	border_bottom.scale = Vector2.ONE
	border_left.scale = Vector2.ONE
	border_right.scale = Vector2.ONE

	top_rect.size = Vector2(width, top_rect.size.y)
	bottom_rect.size = Vector2(width, bottom_rect.size.y)
	left_rect.size = Vector2(left_rect.size.x, height)
	right_rect.size = Vector2(right_rect.size.x, height)

	var half_h := top_rect.size.y * 0.5
	var half_v := left_rect.size.x * 0.5
	var x_center := (left + right) * 0.5
	var y_center := (top + bottom) * 0.5

	border_top.global_position = Vector2(x_center, top - half_h)
	border_bottom.global_position = Vector2(x_center, bottom + half_h)
	border_left.global_position = Vector2(left - half_v, y_center)
	border_right.global_position = Vector2(right + half_v, y_center)
