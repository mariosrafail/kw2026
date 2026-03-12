extends RefCounted
class_name CtfCaptureAreas

const TEAM_RED := 0
const TEAM_BLUE := 1
const RED_CAPTURE_AREA_NAME := "CtfRedCaptureArea"
const BLUE_CAPTURE_AREA_NAME := "CtfBlueCaptureArea"

var _areas_by_team: Dictionary = {}

func reset() -> void:
	_areas_by_team.clear()

func refresh(world_root: Node2D) -> void:
	_areas_by_team[TEAM_RED] = _find_capture_area(world_root, RED_CAPTURE_AREA_NAME)
	_areas_by_team[TEAM_BLUE] = _find_capture_area(world_root, BLUE_CAPTURE_AREA_NAME)

func goal_for_team(team_id: int, fallback_position: Vector2) -> Vector2:
	var area := _areas_by_team.get(team_id, null) as Area2D
	if area != null and is_instance_valid(area):
		return area.global_position
	return fallback_position

func contains_player(team_id: int, player: NetPlayer) -> bool:
	var area := _areas_by_team.get(team_id, null) as Area2D
	if area == null or not is_instance_valid(area) or player == null:
		return false
	return _area_contains_point(area, player.global_position)

func _find_capture_area(world_root: Node2D, area_name: String) -> Area2D:
	if world_root == null:
		return null
	var direct := world_root.get_node_or_null(area_name) as Area2D
	if direct != null:
		return direct
	var nested := world_root.find_child(area_name, true, false) as Area2D
	if nested != null:
		return nested
	var scene_root := world_root.get_parent()
	if scene_root != null:
		return scene_root.find_child(area_name, true, false) as Area2D
	return null

func _area_contains_point(area: Area2D, world_position: Vector2) -> bool:
	for child in area.get_children():
		if child is CollisionShape2D:
			var shape_node := child as CollisionShape2D
			if shape_node.disabled:
				continue
			var shape := shape_node.shape
			if shape == null:
				continue
			var local_point := shape_node.to_local(world_position)
			if _shape_contains_local_point(shape, local_point):
				return true
		elif child is CollisionPolygon2D:
			var polygon_node := child as CollisionPolygon2D
			if polygon_node.disabled or polygon_node.polygon.is_empty():
				continue
			var local_point := polygon_node.to_local(world_position)
			if Geometry2D.is_point_in_polygon(local_point, polygon_node.polygon):
				return true
	return false

func _shape_contains_local_point(shape: Shape2D, local_point: Vector2) -> bool:
	if shape is RectangleShape2D:
		var rect := shape as RectangleShape2D
		var half_size := rect.size * 0.5
		return absf(local_point.x) <= half_size.x and absf(local_point.y) <= half_size.y
	if shape is CircleShape2D:
		var circle := shape as CircleShape2D
		return local_point.length_squared() <= circle.radius * circle.radius
	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		var radius := capsule.radius
		var straight_half := maxf(0.0, (capsule.height * 0.5) - radius)
		if absf(local_point.x) <= radius and absf(local_point.y) <= straight_half:
			return true
		var top_center := Vector2(0.0, -straight_half)
		var bottom_center := Vector2(0.0, straight_half)
		return local_point.distance_squared_to(top_center) <= radius * radius or local_point.distance_squared_to(bottom_center) <= radius * radius
	return false
