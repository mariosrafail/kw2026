extends RefCounted

class_name PlayerDeathChunks

const CHUNK_LIFETIME_SEC := 2.8
const CHUNK_FADE_DELAY_SEC := 2.1
const CHUNK_FADE_DURATION_SEC := 0.7
const CHUNK_BASE_UP_IMPULSE := -92.0
const CHUNK_DIRECTIONAL_X_IMPULSE := 220.0
const CHUNK_DIRECTIONAL_Y_IMPULSE := 95.0
const CHUNK_RANDOM_X_IMPULSE := 95.0
const CHUNK_RANDOM_Y_IMPULSE := 45.0
const CHUNK_BASE_ANGULAR_IMPULSE := 2.8
const CHUNK_RANDOM_ANGULAR_IMPULSE := 2.4
const CHUNK_BASE_ANGULAR_VELOCITY := 5.8
const CHUNK_RANDOM_ANGULAR_VELOCITY := 4.6
const CHUNK_Z_INDEX := 40
const CHUNK_BOUNCE := 0.24
const CHUNK_FRICTION := 0.08
const CHUNK_LINEAR_DAMP := 0.22
const CHUNK_ANGULAR_DAMP := 0.06

var _host: Node = null
var _parts: Array = []
var _active_chunks: Array[RigidBody2D] = []

func configure(host: Node, parts: Array) -> void:
	_host = host
	_parts = parts.duplicate()

func spawn_chunks(base_impulse: Vector2 = Vector2.ZERO, visibility_layer_value: int = 1) -> void:
	_spawn_chunks_internal(false, Vector2.ZERO, base_impulse, visibility_layer_value)

func spawn_chunks_at(world_origin: Vector2, base_impulse: Vector2 = Vector2.ZERO, visibility_layer_value: int = 1) -> void:
	_spawn_chunks_internal(true, world_origin, base_impulse, visibility_layer_value)

func _spawn_chunks_internal(use_world_origin: bool, world_origin: Vector2, base_impulse: Vector2, visibility_layer_value: int) -> void:
	if _host == null or _parts.is_empty():
		return
	var parent := _host.get_parent()
	if parent == null:
		parent = _host.get_tree().current_scene if _host.get_tree() != null else null
	if parent == null:
		return
	for part_value in _parts:
		var part := part_value as Sprite2D
		if part == null or not part.visible:
			continue
		var chunk := _spawn_chunk_for_part(parent, part, use_world_origin, world_origin, base_impulse, visibility_layer_value)
		if chunk != null:
			_active_chunks.append(chunk)
	_prune_invalid_chunks()

func clear_active_chunks() -> void:
	for chunk in _active_chunks:
		if chunk != null and is_instance_valid(chunk):
			chunk.queue_free()
	_active_chunks.clear()

func _spawn_chunk_for_part(parent: Node, source_part: Sprite2D, use_world_origin: bool, world_origin: Vector2, base_impulse: Vector2, visibility_layer_value: int) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.name = "DeathChunk"
	body.global_position = _resolved_chunk_position(source_part, use_world_origin, world_origin)
	body.global_rotation = source_part.global_rotation
	body.z_as_relative = false
	body.z_index = CHUNK_Z_INDEX
	body.gravity_scale = 1.0
	body.linear_damp = CHUNK_LINEAR_DAMP
	body.angular_damp = CHUNK_ANGULAR_DAMP
	body.mass = 0.35
	body.collision_layer = 4
	body.collision_mask = 1
	body.contact_monitor = false
	body.max_contacts_reported = 0
	body.lock_rotation = false
	body.visibility_layer = 1 | visibility_layer_value
	var body_material := PhysicsMaterial.new()
	body_material.friction = CHUNK_FRICTION
	body_material.bounce = CHUNK_BOUNCE
	body.physics_material_override = body_material
	parent.add_child(body)

	var sprite := Sprite2D.new()
	sprite.texture = source_part.texture
	sprite.texture_filter = source_part.texture_filter
	sprite.centered = source_part.centered
	sprite.offset = source_part.offset
	sprite.flip_h = source_part.flip_h
	sprite.flip_v = source_part.flip_v
	sprite.scale = source_part.global_scale
	sprite.skew = source_part.skew
	sprite.region_enabled = source_part.region_enabled
	sprite.region_rect = source_part.region_rect
	sprite.hframes = source_part.hframes
	sprite.vframes = source_part.vframes
	sprite.frame = source_part.frame
	sprite.frame_coords = source_part.frame_coords
	sprite.modulate = source_part.modulate
	sprite.z_as_relative = false
	sprite.z_index = CHUNK_Z_INDEX + 1
	sprite.visibility_layer = 1 | visibility_layer_value
	body.add_child(sprite)
	_add_fun_sprite_wobble(sprite, body)

	var shape := RectangleShape2D.new()
	shape.size = _collision_size_for_part(source_part)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	body.add_child(collider)

	var directional_impulse := _resolved_directional_impulse(base_impulse)
	var impulse := Vector2(
		directional_impulse.x + randf_range(-CHUNK_RANDOM_X_IMPULSE, CHUNK_RANDOM_X_IMPULSE),
		directional_impulse.y + CHUNK_BASE_UP_IMPULSE + randf_range(-CHUNK_RANDOM_Y_IMPULSE, CHUNK_RANDOM_Y_IMPULSE)
	)
	body.apply_central_impulse(impulse)

	var angular_impulse := CHUNK_BASE_ANGULAR_IMPULSE + randf_range(-CHUNK_RANDOM_ANGULAR_IMPULSE, CHUNK_RANDOM_ANGULAR_IMPULSE)
	if randf() < 0.5:
		angular_impulse = -angular_impulse
	body.apply_torque_impulse(angular_impulse)
	var angular_velocity_sign := -1.0 if randf() < 0.5 else 1.0
	body.angular_velocity = angular_velocity_sign * (CHUNK_BASE_ANGULAR_VELOCITY + randf_range(0.0, CHUNK_RANDOM_ANGULAR_VELOCITY))

	var fade_tween := body.create_tween()
	fade_tween.bind_node(body)
	fade_tween.tween_interval(CHUNK_FADE_DELAY_SEC)
	var fade := fade_tween.tween_property(sprite, "modulate:a", 0.0, CHUNK_FADE_DURATION_SEC)
	fade.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade_tween.finished.connect(body.queue_free, CONNECT_ONE_SHOT)

	var life_timer := Timer.new()
	life_timer.one_shot = true
	life_timer.wait_time = CHUNK_LIFETIME_SEC
	body.add_child(life_timer)
	life_timer.timeout.connect(body.queue_free, CONNECT_ONE_SHOT)
	life_timer.start()
	return body

func _resolved_chunk_position(source_part: Sprite2D, use_world_origin: bool, world_origin: Vector2) -> Vector2:
	if not use_world_origin:
		return source_part.global_position
	var host_node := _host as Node2D
	if host_node == null:
		return source_part.global_position
	var local_offset := source_part.global_position - host_node.global_position
	return world_origin + local_offset

func _resolved_directional_impulse(base_impulse: Vector2) -> Vector2:
	if base_impulse.length_squared() <= 0.0001:
		return Vector2(randf_range(-55.0, 55.0), randf_range(-22.0, 18.0))
	var dir := base_impulse.normalized()
	return Vector2(dir.x * CHUNK_DIRECTIONAL_X_IMPULSE, dir.y * CHUNK_DIRECTIONAL_Y_IMPULSE)

func _collision_size_for_part(part: Sprite2D) -> Vector2:
	var source_size := Vector2(14.0, 14.0)
	if part.region_enabled and part.region_rect.size.x > 0.0 and part.region_rect.size.y > 0.0:
		source_size = part.region_rect.size
	elif part.texture != null:
		source_size = part.texture.get_size()
	var scale_abs := part.global_scale.abs()
	var scaled := Vector2(source_size.x * scale_abs.x, source_size.y * scale_abs.y)
	return Vector2(maxf(1.5, scaled.x * 0.10), maxf(1.0, scaled.y * 0.08))

func _add_fun_sprite_wobble(sprite: Sprite2D, body: RigidBody2D) -> void:
	if sprite == null or body == null:
		return
	var base_scale := sprite.scale
	var wobble_tween := body.create_tween()
	wobble_tween.bind_node(body)
	for _i in range(4):
		var up_scale := base_scale * randf_range(1.04, 1.1)
		var down_scale := base_scale * randf_range(0.92, 0.98)
		var up := wobble_tween.tween_property(sprite, "scale", up_scale, randf_range(0.07, 0.11))
		up.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var down := wobble_tween.tween_property(sprite, "scale", down_scale, randf_range(0.08, 0.12))
		down.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	wobble_tween.tween_property(sprite, "scale", base_scale, 0.1)

func _prune_invalid_chunks() -> void:
	var next_chunks: Array[RigidBody2D] = []
	for chunk in _active_chunks:
		if chunk != null and is_instance_valid(chunk):
			next_chunks.append(chunk)
	_active_chunks = next_chunks
