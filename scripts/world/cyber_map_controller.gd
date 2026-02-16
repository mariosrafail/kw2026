extends MapController
class_name CyberMapController

@export var world_local_play_bounds: Rect2i = Rect2i(392, 112, 496, 496)
@export var camera_padding: Vector2i = Vector2i(64, 56)
@export var spawn_padding := 40.0
@export_range(0.0, 1.0, 0.01) var spawn_row_ratio := 0.58

func _init() -> void:
	map_id = "cyber"
	map_label = "Cyber"
	scene_path = "res://scenes/main_cyber.tscn"
	max_players = 2
	spawn_points = []
	play_bounds = Rect2i(64, 80, 512, 512)
	camera_limits_rect = Rect2i(64, 80, 512, 512)

func apply_runtime_bounds(
	main_camera: Camera2D,
	border_nodes: Dictionary,
	_map_front_sprite: Sprite2D = null
) -> void:
	var world := get_parent() as Node2D
	if world == null:
		_runtime_play_bounds = configured_play_bounds_rect()
		_apply_camera_limits(main_camera, configured_camera_limits_rect())
		_apply_border_bodies(_runtime_play_bounds, border_nodes)
		return

	var local_play_rect := _sanitized_local_rect(world_local_play_bounds)
	var global_play_origin := world.to_global(local_play_rect.position)
	_runtime_play_bounds = Rect2i(
		Vector2i(int(round(global_play_origin.x)), int(round(global_play_origin.y))),
		local_play_rect.size
	)

	var local_camera_rect := Rect2i(
		local_play_rect.position + camera_padding,
		local_play_rect.size - camera_padding * 2
	)
	if local_camera_rect.size.x < 8 or local_camera_rect.size.y < 8:
		local_camera_rect = local_play_rect
	var global_camera_origin := world.to_global(local_camera_rect.position)
	var global_camera_rect := Rect2i(
		Vector2i(int(round(global_camera_origin.x)), int(round(global_camera_origin.y))),
		local_camera_rect.size
	)

	_apply_camera_limits(main_camera, global_camera_rect)
	_apply_border_bodies(_runtime_play_bounds, border_nodes)

func configured_spawn_points() -> Array:
	var runtime_rect := runtime_play_bounds_rect()
	if runtime_rect.size.x <= 0 or runtime_rect.size.y <= 0:
		return super.configured_spawn_points()
	var min_x := float(runtime_rect.position.x) + spawn_padding
	var max_x := float(runtime_rect.position.x + runtime_rect.size.x) - spawn_padding
	var min_y := float(runtime_rect.position.y) + spawn_padding
	var max_y := float(runtime_rect.position.y + runtime_rect.size.y) - spawn_padding
	if min_x > max_x or min_y > max_y:
		return super.configured_spawn_points()
	var spawn_y := clampf(
		float(runtime_rect.position.y) + float(runtime_rect.size.y) * spawn_row_ratio,
		min_y,
		max_y
	)
	return [
		Vector2(lerpf(min_x, max_x, 0.25), spawn_y),
		Vector2(lerpf(min_x, max_x, 0.75), spawn_y)
	]

func _sanitized_local_rect(rect: Rect2i) -> Rect2i:
	return Rect2i(
		rect.position,
		Vector2i(maxi(1, rect.size.x), maxi(1, rect.size.y))
	)
