extends RefCounted
class_name SpawnFlowService

func configured_spawn_points(
	map_controller: MapController,
	map_catalog: MapCatalog,
	scene_file_path: String
) -> Array:
	var play_bounds := Rect2i()
	if map_controller != null:
		play_bounds = map_controller.runtime_play_bounds_rect()
		var points := map_controller.configured_spawn_points()
		if not points.is_empty():
			return clamp_spawn_points_to_play_bounds(points, play_bounds)
		if map_catalog != null:
			var fallback_points := map_catalog.spawn_points_for_id(map_controller.normalized_map_id())
			if not fallback_points.is_empty():
				return clamp_spawn_points_to_play_bounds(fallback_points, play_bounds)

	if map_catalog != null:
		var scene_map_id := map_catalog.map_id_for_scene_path(scene_file_path)
		var scene_fallback_points := map_catalog.spawn_points_for_id(scene_map_id)
		if not scene_fallback_points.is_empty():
			return clamp_spawn_points_to_play_bounds(scene_fallback_points, play_bounds)

	if map_controller != null:
		var generated_points := default_spawn_points_for_bounds(play_bounds)
		if not generated_points.is_empty():
			return generated_points

	return [Vector2(640.0, 360.0)]

func sanitize_spawn_position(
	spawn_position: Vector2,
	world_2d: World2D,
	collision_mask: int = 1
) -> Vector2:
	if world_2d == null:
		return spawn_position
	var space_state := world_2d.direct_space_state
	if space_state == null:
		return spawn_position

	var capsule := CapsuleShape2D.new()
	capsule.radius = 6.0
	capsule.height = 32.0

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = capsule
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var test_position := spawn_position
	for _attempt in range(40):
		query.transform = Transform2D(0.0, test_position)
		if space_state.intersect_shape(query, 1).is_empty():
			return test_position
		test_position -= Vector2(0.0, 8.0)
	return spawn_position

func apply_map_controller_bounds(
	map_controller: MapController,
	main_camera: Camera2D,
	map_front_sprite: Sprite2D,
	border_nodes: Dictionary
) -> void:
	if map_controller == null:
		return
	map_controller.apply_runtime_bounds(main_camera, border_nodes, map_front_sprite)

func clamp_spawn_points_to_play_bounds(points: Array, play_bounds: Rect2i) -> Array:
	if points.is_empty():
		return points.duplicate()
	if play_bounds.size.x <= 0 or play_bounds.size.y <= 0:
		return points.duplicate()

	var min_x := float(play_bounds.position.x + 24)
	var max_x := float(play_bounds.position.x + play_bounds.size.x - 24)
	var min_y := float(play_bounds.position.y + 24)
	var max_y := float(play_bounds.position.y + play_bounds.size.y - 24)
	if min_x > max_x:
		var mid_x := (min_x + max_x) * 0.5
		min_x = mid_x
		max_x = mid_x
	if min_y > max_y:
		var mid_y := (min_y + max_y) * 0.5
		min_y = mid_y
		max_y = mid_y

	var clamped_points: Array = []
	for point_value in points:
		if not (point_value is Vector2):
			continue
		var point := point_value as Vector2
		clamped_points.append(Vector2(clampf(point.x, min_x, max_x), clampf(point.y, min_y, max_y)))
	return clamped_points

func default_spawn_points_for_bounds(play_bounds: Rect2i) -> Array:
	if play_bounds.size.x <= 0 or play_bounds.size.y <= 0:
		return []
	var min_x := float(play_bounds.position.x + 24)
	var max_x := float(play_bounds.position.x + play_bounds.size.x - 24)
	var min_y := float(play_bounds.position.y + 24)
	var max_y := float(play_bounds.position.y + play_bounds.size.y - 24)
	if min_x > max_x or min_y > max_y:
		return []
	var y := clampf(float(play_bounds.position.y) + float(play_bounds.size.y) * 0.55, min_y, max_y)
	var x1 := lerpf(min_x, max_x, 0.25)
	var x2 := lerpf(min_x, max_x, 0.75)
	return [Vector2(x1, y), Vector2(x2, y)]
