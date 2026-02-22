extends Node2D
class_name FOVDetector

## Field of view detector using 360° raycasting
## Detects visible entities by casting rays in all directions from eye position

const DEFAULT_RAY_COUNT := 64
const DEFAULT_FOV_RANGE := 600.0
const DEFAULT_EYE_OFFSET := Vector2(0, -12)

@export var ray_count := DEFAULT_RAY_COUNT
@export var fov_range := DEFAULT_FOV_RANGE
@export var eye_offset := DEFAULT_EYE_OFFSET
@export var debug_draw := false
@export var collision_mask := 1 | 2  # Layer 1 (ground/walls) | Layer 2 (players)
@export var occluder_mask := 1  # What blocks line-of-sight (typically walls/ground).

var visible_bodies: Array[RID] = []
var _debug_ray_endpoints: Array[Vector2] = []

func get_visibility_polygon_local_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for endpoint in _debug_ray_endpoints:
		points.append(endpoint - global_position)
	return points

func _ready() -> void:
	set_physics_process(true)

func _physics_process(_delta: float) -> void:
	update_visibility()
	if debug_draw:
		queue_redraw()

func update_visibility() -> void:
	visible_bodies.clear()
	_debug_ray_endpoints.clear()
	
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space_state == null:
		return
	
	var eye_position := global_position + eye_offset
	var angle_step := TAU / float(ray_count)
	var seen_rids: Dictionary = {}
	
	for i in range(ray_count):
		var angle := angle_step * float(i)
		var direction := Vector2.RIGHT.rotated(angle)
		var target := eye_position + direction * fov_range
		
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(eye_position, target, collision_mask)
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.exclude = [get_parent().get_rid()] if get_parent() is CharacterBody2D else []
		
		var result: Dictionary = space_state.intersect_ray(query)
		if result.is_empty():
			_debug_ray_endpoints.append(target)
			continue
		
		var hit_position: Vector2 = result.get("position", target) as Vector2
		_debug_ray_endpoints.append(hit_position)
		
		var collider: Node = result.get("collider", null) as Node
		if collider != null and collider is CharacterBody2D:
			var rid: RID = collider.get_rid()
			if not seen_rids.has(rid):
				seen_rids[rid] = true
				visible_bodies.append(rid)

func is_body_visible(body: Node2D) -> bool:
	if body == null:
		return false
	if get_world_2d() == null or get_world_2d().direct_space_state == null:
		return false

	var eye_position := global_position + eye_offset
	var body_position := body.global_position
	if eye_position.distance_to(body_position) > fov_range:
		return false

	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(eye_position, body_position, occluder_mask)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_parent().get_rid()] if get_parent() is CollisionObject2D else []
	var result: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	# If we hit any occluder before reaching the body, it's not visible.
	return result.is_empty()

func is_point_visible(world_point: Vector2) -> bool:
	if get_world_2d() == null or get_world_2d().direct_space_state == null:
		return false
	var eye_position := global_position + eye_offset
	if eye_position.distance_to(world_point) > fov_range:
		return false
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(eye_position, world_point, occluder_mask)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_parent().get_rid()] if get_parent() is CollisionObject2D else []
	var result: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return result.is_empty()

func get_visible_players(all_players: Dictionary) -> Array:
	var result: Array = []
	for peer_id in all_players.keys():
		var player: Node2D = all_players[peer_id] as Node2D
		if player == null:
			continue
		if player == get_parent():
			continue
		if is_body_visible(player):
			result.append(peer_id)
	return result

func _draw() -> void:
	if not debug_draw:
		return
	
	var eye_position := eye_offset
	
	# Draw eye position
	draw_circle(eye_position, 3.0, Color.YELLOW)
	
	# Draw rays
	for endpoint in _debug_ray_endpoints:
		var local_endpoint := endpoint - global_position
		draw_line(eye_position, local_endpoint, Color(0.0, 1.0, 0.0, 0.15), 1.0)
	
	# Draw range circle
	draw_arc(eye_position, fov_range, 0, TAU, 64, Color(0.0, 1.0, 1.0, 0.2), 1.0)
