extends TileMapLayer

const COLLISION_ROOT_NAME := "_GroundCollision"
const DEFAULT_TILE_SIZE := Vector2i(8, 8)
const DEFAULT_TILE_SOURCE_ID := 0

@export var auto_generate_from_map := false
@export var clear_existing_tiles_on_generate := false
@export var source_sprite_path: NodePath = NodePath("../MapMid")
@export_range(0.0, 1.0, 0.01) var alpha_threshold := 0.15
@export_range(0.0, 1.0, 0.01) var min_solid_ratio := 0.18
@export var ignore_atlas_zero_tile_for_collision := false

var _last_collision_signature := ""

func _ready() -> void:
	call_deferred("_initialize_ground")
	set_physics_process(true)

func _physics_process(_delta: float) -> void:
	var signature := _build_collision_signature()
	if signature == _last_collision_signature:
		return
	_rebuild_collision()
	_last_collision_signature = signature

func _initialize_ground() -> void:
	_ensure_runtime_tile_source()
	if auto_generate_from_map:
		_generate_tiles_from_map_sprite()
	_rebuild_collision()
	_last_collision_signature = _build_collision_signature()

func _ensure_runtime_tile_source() -> void:
	if tile_set == null:
		tile_set = TileSet.new()
		tile_set.tile_size = _resolve_tile_size()

	if tile_set.get_source_count() > 0:
		return

	var tile_size := _resolve_tile_size()
	var image := Image.create(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))
	var texture := ImageTexture.create_from_image(image)

	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = texture
	atlas_source.texture_region_size = tile_size
	atlas_source.create_tile(Vector2i.ZERO)
	tile_set.add_source(atlas_source, DEFAULT_TILE_SOURCE_ID)

func _generate_tiles_from_map_sprite() -> void:
	var source_sprite := get_node_or_null(source_sprite_path) as Sprite2D
	if source_sprite == null or source_sprite.texture == null:
		return

	if clear_existing_tiles_on_generate:
		clear()

	var image := source_sprite.texture.get_image()
	if image == null:
		return
	image.decompress()

	var image_size := image.get_size()
	var tile_size := _resolve_tile_size()
	var world_top_left := source_sprite.global_position - Vector2(image_size) * 0.5

	for y in range(0, image_size.y, tile_size.y):
		for x in range(0, image_size.x, tile_size.x):
			if not _is_block_solid(image, image_size, x, y, tile_size):
				continue

			var block_world_center := world_top_left + Vector2(
				float(x) + float(tile_size.x) * 0.5,
				float(y) + float(tile_size.y) * 0.5
			)
			var cell := local_to_map(to_local(block_world_center))
			set_cell(cell, DEFAULT_TILE_SOURCE_ID, Vector2i.ZERO, 0)

func _is_block_solid(image: Image, image_size: Vector2i, start_x: int, start_y: int, tile_size: Vector2i) -> bool:
	var solid_pixels := 0
	var total_pixels := 0
	var end_x := mini(start_x + tile_size.x, image_size.x)
	var end_y := mini(start_y + tile_size.y, image_size.y)

	for py in range(start_y, end_y):
		for px in range(start_x, end_x):
			total_pixels += 1
			if image.get_pixel(px, py).a >= alpha_threshold:
				solid_pixels += 1

	if total_pixels <= 0:
		return false
	return float(solid_pixels) / float(total_pixels) >= min_solid_ratio

func _rebuild_collision() -> void:
	var collision_root := _ensure_collision_root()
	for child in collision_root.get_children():
		child.queue_free()

	var tile_size := _resolve_tile_size()
	var shape_size := Vector2(float(tile_size.x), float(tile_size.y))
	for cell in get_used_cells():
		if ignore_atlas_zero_tile_for_collision and get_cell_source_id(cell) == DEFAULT_TILE_SOURCE_ID and get_cell_atlas_coords(cell) == Vector2i.ZERO:
			continue
		var collision_shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = shape_size
		collision_shape.shape = rect
		collision_shape.position = map_to_local(cell)
		collision_root.add_child(collision_shape)

func _ensure_collision_root() -> StaticBody2D:
	var collision_root := get_node_or_null(COLLISION_ROOT_NAME) as StaticBody2D
	if collision_root != null:
		return collision_root

	collision_root = StaticBody2D.new()
	collision_root.name = COLLISION_ROOT_NAME
	collision_root.collision_layer = 1
	collision_root.collision_mask = 0
	add_child(collision_root)
	return collision_root

func _resolve_tile_size() -> Vector2i:
	if tile_set != null and tile_set.tile_size.x > 0 and tile_set.tile_size.y > 0:
		return tile_set.tile_size
	return DEFAULT_TILE_SIZE

func _build_collision_signature() -> String:
	var cells := get_used_cells()
	cells.sort()
	var parts := PackedStringArray()
	for cell in cells:
		var source_id := get_cell_source_id(cell)
		var atlas := get_cell_atlas_coords(cell)
		var alternative := get_cell_alternative_tile(cell)
		parts.append("%d,%d:%d:%d,%d:%d" % [cell.x, cell.y, source_id, atlas.x, atlas.y, alternative])
	return "|".join(parts)
