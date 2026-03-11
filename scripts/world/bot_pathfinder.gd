extends RefCounted
class_name BotPathfinder

const COLLISION_MASK := 1
const BOT_HALF_HEIGHT := 22.0
const SAMPLE_STEP_X := 48.0
const SAMPLE_STEP_Y := 72.0
const SAMPLE_RAY_DEPTH := 112.0
const FLOOR_DUP_Y_EPSILON := 18.0
const FLOOR_DUP_X_EPSILON := 20.0
const WALK_LINK_MAX_DX := 64.0
const WALK_LINK_MAX_DY := 16.0
const JUMP_LINK_MAX_DX := 124.0
const JUMP_LINK_MAX_UP := 118.0
const DROP_LINK_MAX_DOWN := 196.0
const DIRECT_WALL_CHECK_Y := -10.0
const TRAVERSE_CLEARANCE_TOP := -28.0
const TRAVERSE_CLEARANCE_BOTTOM := 8.0
const NODE_REBUILD_INTERVAL_SEC := 1.5

var _get_world_2d_cb: Callable = Callable()
var _get_play_bounds_cb: Callable = Callable()
var _get_ground_tiles_cb: Callable = Callable()

var _astar: AStar2D = AStar2D.new()
var _next_point_id := 1
var _node_positions: Dictionary = {}
var _last_build_msec := 0

func configure(callbacks: Dictionary) -> void:
	_get_world_2d_cb = callbacks.get("get_world_2d", Callable()) as Callable
	_get_play_bounds_cb = callbacks.get("get_play_bounds", Callable()) as Callable
	_get_ground_tiles_cb = callbacks.get("get_ground_tiles", Callable()) as Callable

func invalidate() -> void:
	_astar.clear()
	_node_positions.clear()
	_next_point_id = 1
	_last_build_msec = 0

func waypoint_toward(from_position: Vector2, to_position: Vector2) -> Vector2:
	if to_position == Vector2.ZERO:
		return Vector2.ZERO
	_rebuild_if_needed()
	if _astar.get_point_count() <= 0:
		return to_position
	var start_id: int = _closest_node_id(from_position)
	var goal_id: int = _closest_node_id(to_position)
	if start_id == -1 or goal_id == -1:
		return to_position
	if start_id == goal_id:
		return to_position
	var path: PackedVector2Array = _astar.get_point_path(start_id, goal_id)
	if path.size() >= 2:
		return path[1]
	var fallback_id: int = _best_neighbor_toward(start_id, to_position)
	if fallback_id != -1 and _node_positions.has(fallback_id):
		return _node_positions[fallback_id] as Vector2
	return to_position

func _rebuild_if_needed(force: bool = false) -> void:
	var now_msec: int = Time.get_ticks_msec()
	if not force and _astar.get_point_count() > 0 and now_msec - _last_build_msec < int(NODE_REBUILD_INTERVAL_SEC * 1000.0):
		return
	_rebuild_graph()
	_last_build_msec = now_msec

func _rebuild_graph() -> void:
	invalidate()
	var world_2d: World2D = _world_2d()
	var play_bounds: Rect2i = _play_bounds()
	if world_2d == null or play_bounds.size.x <= 0 or play_bounds.size.y <= 0:
		return
	var nodes: Array[Vector2] = _sample_floor_nodes_from_tilemap()
	if nodes.is_empty():
		nodes = _sample_floor_nodes(world_2d, play_bounds)
	for node_position in nodes:
		_add_node(node_position)
	_connect_nodes(world_2d)

func _sample_floor_nodes_from_tilemap() -> Array[Vector2]:
	var tilemap := _ground_tiles()
	if tilemap == null:
		return []
	var nodes: Array[Vector2] = []
	var tile_size: Vector2 = Vector2(tilemap.tile_set.tile_size) if tilemap.tile_set != null else Vector2(8.0, 8.0)
	var used_cells: Array[Vector2i] = []
	for cell_value in tilemap.get_used_cells():
		if cell_value is Vector2i:
			used_cells.append(cell_value as Vector2i)
	if used_cells.is_empty():
		return []
	var used_lookup: Dictionary = {}
	for cell in used_cells:
		used_lookup[_cell_key(cell)] = true
	for cell in used_cells:
		var above := cell + Vector2i.UP
		if used_lookup.has(_cell_key(above)):
			continue
		var cell_center: Vector2 = tilemap.to_global(tilemap.map_to_local(cell))
		var stand_position := Vector2(cell_center.x, cell_center.y - tile_size.y * 0.5 - BOT_HALF_HEIGHT)
		if not _contains_near(nodes, stand_position):
			nodes.append(stand_position)
	return nodes

func _sample_floor_nodes(world_2d: World2D, play_bounds: Rect2i) -> Array[Vector2]:
	var nodes: Array[Vector2] = []
	var left: float = float(play_bounds.position.x) + 24.0
	var right: float = float(play_bounds.position.x + play_bounds.size.x) - 24.0
	var top: float = float(play_bounds.position.y) + 12.0
	var bottom: float = float(play_bounds.position.y + play_bounds.size.y) - 12.0
	var x: float = left
	while x <= right:
		var y_start: float = top
		while y_start <= bottom:
			var ray_from: Vector2 = Vector2(x, y_start)
			var ray_to: Vector2 = Vector2(x, minf(bottom, y_start + SAMPLE_RAY_DEPTH))
			var hit: Dictionary = _raycast(world_2d, ray_from, ray_to, [])
			if not hit.is_empty():
				var hit_position: Vector2 = hit.get("position", ray_to) as Vector2
				var stand_position: Vector2 = Vector2(x, hit_position.y - BOT_HALF_HEIGHT)
				if _is_standable(world_2d, stand_position) and not _contains_near(nodes, stand_position):
					nodes.append(stand_position)
			y_start += SAMPLE_STEP_Y
		x += SAMPLE_STEP_X
	return nodes

func _contains_near(nodes: Array[Vector2], candidate: Vector2) -> bool:
	for existing in nodes:
		if absf(existing.x - candidate.x) <= FLOOR_DUP_X_EPSILON and absf(existing.y - candidate.y) <= FLOOR_DUP_Y_EPSILON:
			return true
	return false

func _is_standable(world_2d: World2D, position: Vector2) -> bool:
	var foot_from: Vector2 = position + Vector2(0.0, BOT_HALF_HEIGHT - 2.0)
	var foot_to: Vector2 = foot_from + Vector2(0.0, 8.0)
	var floor_hit: Dictionary = _raycast(world_2d, foot_from, foot_to, [])
	if floor_hit.is_empty():
		return false
	var head_from: Vector2 = position + Vector2(0.0, -BOT_HALF_HEIGHT)
	var head_to: Vector2 = head_from + Vector2(0.0, -8.0)
	var ceiling_hit: Dictionary = _raycast(world_2d, head_from, head_to, [])
	return ceiling_hit.is_empty()

func _add_node(position: Vector2) -> void:
	var point_id: int = _next_point_id
	_next_point_id += 1
	_astar.add_point(point_id, position)
	_node_positions[point_id] = position

func _connect_nodes(world_2d: World2D) -> void:
	var ids: Array = _node_positions.keys()
	for i in range(ids.size()):
		var a_id: int = int(ids[i])
		var a: Vector2 = _node_positions[a_id] as Vector2
		for j in range(i + 1, ids.size()):
			var b_id: int = int(ids[j])
			var b: Vector2 = _node_positions[b_id] as Vector2
			if _can_walk_link(world_2d, a, b):
				_astar.connect_points(a_id, b_id, true)
				continue
			var a_to_b := _can_traverse_from_to(world_2d, a, b)
			var b_to_a := _can_traverse_from_to(world_2d, b, a)
			if a_to_b and b_to_a:
				_astar.connect_points(a_id, b_id, true)
			elif a_to_b:
				_astar.connect_points(a_id, b_id, false)
			elif b_to_a:
				_astar.connect_points(b_id, a_id, false)

func _can_walk_link(world_2d: World2D, a: Vector2, b: Vector2) -> bool:
	var dx: float = absf(a.x - b.x)
	var dy: float = b.y - a.y
	if dx > WALK_LINK_MAX_DX or absf(dy) > WALK_LINK_MAX_DY:
		return false
	return not _link_blocked(world_2d, a, b)

func _can_traverse_from_to(world_2d: World2D, from_position: Vector2, to_position: Vector2) -> bool:
	var dx: float = absf(to_position.x - from_position.x)
	var dy: float = to_position.y - from_position.y
	if dx > JUMP_LINK_MAX_DX:
		return false
	if dy < 0.0 and absf(dy) > JUMP_LINK_MAX_UP:
		return false
	if dy > 0.0 and dy > DROP_LINK_MAX_DOWN:
		return false
	if not _is_standable(world_2d, to_position):
		return false
	return not _traverse_blocked(world_2d, from_position, to_position)

func _link_blocked(world_2d: World2D, a: Vector2, b: Vector2) -> bool:
	var from: Vector2 = a + Vector2(0.0, DIRECT_WALL_CHECK_Y)
	var to: Vector2 = b + Vector2(0.0, DIRECT_WALL_CHECK_Y)
	var hit: Dictionary = _raycast(world_2d, from, to, [])
	return not hit.is_empty()

func _traverse_blocked(world_2d: World2D, from_position: Vector2, to_position: Vector2) -> bool:
	var upper_from: Vector2 = from_position + Vector2(0.0, TRAVERSE_CLEARANCE_TOP)
	var upper_to: Vector2 = to_position + Vector2(0.0, TRAVERSE_CLEARANCE_TOP)
	if not _raycast(world_2d, upper_from, upper_to, []).is_empty():
		return true
	var mid_from: Vector2 = from_position + Vector2(0.0, DIRECT_WALL_CHECK_Y)
	var mid_to: Vector2 = to_position + Vector2(0.0, DIRECT_WALL_CHECK_Y)
	if not _raycast(world_2d, mid_from, mid_to, []).is_empty():
		return true
	var lower_from: Vector2 = from_position + Vector2(0.0, TRAVERSE_CLEARANCE_BOTTOM)
	var lower_to: Vector2 = to_position + Vector2(0.0, TRAVERSE_CLEARANCE_BOTTOM)
	if not _raycast(world_2d, lower_from, lower_to, []).is_empty():
		return true
	return false

func _closest_node_id(position: Vector2) -> int:
	var best_id: int = -1
	var best_dist_sq: float = INF
	for point_id_value in _node_positions.keys():
		var point_id: int = int(point_id_value)
		var node_position: Vector2 = _node_positions[point_id] as Vector2
		var dist_sq: float = node_position.distance_squared_to(position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_id = point_id
	return best_id

func _best_neighbor_toward(start_id: int, goal_position: Vector2) -> int:
	if start_id == -1 or not _astar.has_point(start_id):
		return -1
	var best_id: int = -1
	var best_score: float = INF
	var neighbors: PackedInt64Array = _astar.get_point_connections(start_id)
	for neighbor_value in neighbors:
		var neighbor_id: int = int(neighbor_value)
		if not _node_positions.has(neighbor_id):
			continue
		var neighbor_position: Vector2 = _node_positions[neighbor_id] as Vector2
		var score: float = neighbor_position.distance_squared_to(goal_position)
		if score < best_score:
			best_score = score
			best_id = neighbor_id
	return best_id

func _raycast(world_2d: World2D, from: Vector2, to: Vector2, exclude: Array) -> Dictionary:
	if world_2d == null:
		return {}
	var space_state: PhysicsDirectSpaceState2D = world_2d.direct_space_state
	if space_state == null:
		return {}
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, COLLISION_MASK)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = exclude
	return space_state.intersect_ray(query)

func _ground_tiles() -> TileMapLayer:
	if _get_ground_tiles_cb.is_valid():
		return _get_ground_tiles_cb.call() as TileMapLayer
	return null

func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]

func _world_2d() -> World2D:
	if _get_world_2d_cb.is_valid():
		return _get_world_2d_cb.call() as World2D
	return null

func _play_bounds() -> Rect2i:
	if _get_play_bounds_cb.is_valid():
		var value: Variant = _get_play_bounds_cb.call()
		if value is Rect2i:
			return value as Rect2i
	return Rect2i()
