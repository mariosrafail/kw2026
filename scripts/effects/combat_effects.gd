extends RefCounted
class_name CombatEffects

const BLOOD_PARTICLES_AMOUNT := 22
const BLOOD_PARTICLES_LIFETIME := 0.36
const BLOOD_PARTICLES_CLEANUP_DELAY := 1.2
const BLOOD_PARTICLES_GRAVITY := Vector2(0.0, 860.0)
const BLOOD_PARTICLES_COLOR := Color(0.98, 0.02, 0.07, 1.0)
const BLOOD_CHUNK_MIN_SIZE := 2.0
const BLOOD_CHUNK_MAX_SIZE := 5.0
const BLOOD_CHUNK_SPEED_MIN := 42.0
const BLOOD_CHUNK_SPEED_MAX := 145.0
const BLOOD_CHUNK_GRAVITY_SCALE := 1.1
const BLOOD_CHUNK_LINEAR_DAMP := 2.6
const BLOOD_CHUNK_ANGULAR_DAMP := 1.4
const BLOOD_CHUNK_BOUNCE := 0.02
const BLOOD_CHUNK_FRICTION := 0.92
const BLOOD_CHUNK_SPREAD_RADIANS := 0.95
const SURFACE_PARTICLES_AMOUNT := 18
const SURFACE_PARTICLES_LIFETIME := 0.58
const SURFACE_PARTICLES_CLEANUP_DELAY := 1.45
const SURFACE_PARTICLES_GRAVITY := Vector2(0.0, 980.0)
const SURFACE_COLOR_ALPHA_MIN := 0.35
const SURFACE_CHUNK_MIN_SIZE := 1.45
const SURFACE_CHUNK_MAX_SIZE := 3.7
const SURFACE_CHUNK_SPEED_MIN := 16.0
const SURFACE_CHUNK_SPEED_MAX := 86.0
const SURFACE_CHUNK_GRAVITY_SCALE := 1.25
const SURFACE_CHUNK_LINEAR_DAMP := 1.9
const SURFACE_CHUNK_ANGULAR_DAMP := 1.1
const SURFACE_CHUNK_BOUNCE := 0.04
const SURFACE_CHUNK_FRICTION := 0.9
const SURFACE_CHUNK_COLLISION_LAYER := 32
const SURFACE_CHUNK_COLLISION_MASK := 1
const SURFACE_IMPACT_SAMPLE_RADIUS := 10
const SURFACE_SPAWN_OFFSET := 1.5
const SPLASH_HIT_VOLUME_DB := 4.0
const SURFACE_IMPACT_VOLUME_DB := 0.0
const EXPLOSION_FRAME_SIZE := Vector2(120.0, 120.0)
const EXPLOSION_FRAME_COUNT := 8
const EXPLOSION_FRAME_SEC := 0.035
const EXPLOSION_Y_OFFSET := 10.0
const HIT_FLASH_LIFETIME := 0.08
const BLOOD_EFFECTS_Z_INDEX := 1000
const SURFACE_ID_WOOD := "wood"
const SURFACE_ID_GRASS := "grass"

const SURFACE_IMPACT_STREAMS := {
	SURFACE_ID_GRASS: [
		preload("res://assets/sounds/sfx/ground/grass/grass_step_1.wav"),
		preload("res://assets/sounds/sfx/ground/grass/grass_step_2.wav"),
		preload("res://assets/sounds/sfx/ground/grass/grass_step_3.wav"),
	],
	SURFACE_ID_WOOD: [
		preload("res://assets/sounds/sfx/ground/wood/wood_step_1.wav"),
		preload("res://assets/sounds/sfx/ground/wood/wood_step_2.wav"),
		preload("res://assets/sounds/sfx/ground/wood/wood_step_3.wav"),
		preload("res://assets/sounds/sfx/ground/wood/wood_step_4.wav"),
		preload("res://assets/sounds/sfx/ground/wood/wood_step_5.wav"),
		preload("res://assets/sounds/sfx/ground/wood/wood_step_6.wav"),
		preload("res://assets/sounds/sfx/ground/wood/wood_step_7.wav"),
	],
}

var projectiles_root: Node2D
var map_front_sprite: Sprite2D
var splash_hit_sfx: AudioStream
var death_hit_sfx: AudioStream
var bullet_touch_sfx: AudioStream
var explosion_texture: Texture2D
var hit_texture: Texture2D
var map_front_image: Image = null
var explosion_frames: SpriteFrames = null

func configure(root: Node2D, front_sprite: Sprite2D, splash_sfx: AudioStream, death_sfx: AudioStream, bullet_touch: AudioStream = null, explosion_fx: Texture2D = null, hit_fx: Texture2D = null) -> void:
	projectiles_root = root
	map_front_sprite = front_sprite
	splash_hit_sfx = splash_sfx
	death_hit_sfx = death_sfx
	bullet_touch_sfx = bullet_touch
	explosion_texture = explosion_fx
	hit_texture = hit_fx
	explosion_frames = null

func spawn_blood_particles(impact_position: Vector2, incoming_velocity: Vector2, blood_color: Color = BLOOD_PARTICLES_COLOR, count_multiplier: float = 1.0) -> void:
	if projectiles_root == null:
		return
	play_splash_hit_sfx(impact_position)
	spawn_hit_flash(impact_position)
	var chunk_count := maxi(1, int(round(float(BLOOD_PARTICLES_AMOUNT) * maxf(0.1, count_multiplier))))
	var spray_direction := Vector2.UP
	if incoming_velocity.length_squared() > 0.0001:
		spray_direction = (-incoming_velocity).normalized()
	for i in range(chunk_count):
		var chunk := RigidBody2D.new()
		chunk.z_as_relative = false
		chunk.z_index = BLOOD_EFFECTS_Z_INDEX
		chunk.global_position = impact_position + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
		chunk.gravity_scale = BLOOD_CHUNK_GRAVITY_SCALE
		chunk.linear_damp = BLOOD_CHUNK_LINEAR_DAMP
		chunk.angular_damp = BLOOD_CHUNK_ANGULAR_DAMP
		chunk.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
		chunk.collision_layer = SURFACE_CHUNK_COLLISION_LAYER
		chunk.collision_mask = SURFACE_CHUNK_COLLISION_MASK

		var size := randf_range(BLOOD_CHUNK_MIN_SIZE, BLOOD_CHUNK_MAX_SIZE)
		var half := size * 0.5
		var visual := Polygon2D.new()
		visual.color = _blood_chunk_color(blood_color)
		visual.polygon = PackedVector2Array([
			Vector2(-half, -half),
			Vector2(half, -half),
			Vector2(half, half),
			Vector2(-half, half)
		])
		chunk.add_child(visual)

		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(size, size)
		collider.shape = shape
		chunk.add_child(collider)

		var material := PhysicsMaterial.new()
		material.bounce = BLOOD_CHUNK_BOUNCE
		material.friction = BLOOD_CHUNK_FRICTION
		chunk.physics_material_override = material

		var dir := spray_direction.rotated(randf_range(-BLOOD_CHUNK_SPREAD_RADIANS, BLOOD_CHUNK_SPREAD_RADIANS))
		var speed := randf_range(BLOOD_CHUNK_SPEED_MIN, BLOOD_CHUNK_SPEED_MAX)
		chunk.linear_velocity = dir * speed + Vector2(randf_range(-12.0, 12.0), randf_range(-10.0, 22.0))
		chunk.angular_velocity = randf_range(-13.0, 13.0)
		projectiles_root.add_child(chunk)
		_queue_free_with_delay(chunk, BLOOD_PARTICLES_CLEANUP_DELAY + randf_range(0.0, 0.35))

func spawn_surface_particles(impact_position: Vector2, incoming_velocity: Vector2, particle_color: Color) -> void:
	if projectiles_root == null:
		return
	_play_surface_impact_sfx(impact_position)

	var spray_direction := Vector2.UP
	if incoming_velocity.length_squared() > 0.0001:
		spray_direction = incoming_velocity.normalized()
	var sample_position := impact_position - spray_direction * 2.0
	var chunk_spawn_position := impact_position + spray_direction * SURFACE_SPAWN_OFFSET
	var palette := sample_map_front_palette(sample_position, 6)
	if palette.is_empty():
		palette = sample_map_front_palette(impact_position, 6)
	if palette.is_empty():
		if particle_color.a < SURFACE_COLOR_ALPHA_MIN:
			return
		palette.append(Color(particle_color.r, particle_color.g, particle_color.b, 1.0))
	if palette.is_empty():
		return
	for i in range(SURFACE_PARTICLES_AMOUNT):
		var chunk := RigidBody2D.new()
		chunk.z_as_relative = false
		chunk.z_index = BLOOD_EFFECTS_Z_INDEX - 4
		chunk.global_position = chunk_spawn_position
		chunk.gravity_scale = SURFACE_CHUNK_GRAVITY_SCALE
		chunk.linear_damp = SURFACE_CHUNK_LINEAR_DAMP
		chunk.angular_damp = SURFACE_CHUNK_ANGULAR_DAMP
		chunk.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
		chunk.contact_monitor = true
		chunk.max_contacts_reported = 4
		chunk.collision_layer = SURFACE_CHUNK_COLLISION_LAYER
		chunk.collision_mask = SURFACE_CHUNK_COLLISION_MASK

		var size := randf_range(SURFACE_CHUNK_MIN_SIZE, SURFACE_CHUNK_MAX_SIZE)
		var half := size * 0.5

		var visual := Polygon2D.new()
		var palette_color: Color = palette[i % palette.size()] as Color
		visual.color = Color(palette_color.r, palette_color.g, palette_color.b, 1.0)
		visual.polygon = PackedVector2Array([
			Vector2(-half, -half),
			Vector2(half, -half),
			Vector2(half, half),
			Vector2(-half, half)
		])
		chunk.add_child(visual)

		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(size, size)
		collider.shape = shape
		chunk.add_child(collider)

		var material := PhysicsMaterial.new()
		material.bounce = SURFACE_CHUNK_BOUNCE
		material.friction = SURFACE_CHUNK_FRICTION
		chunk.physics_material_override = material

		var dir := spray_direction.rotated(randf_range(-0.42, 0.42))
		var speed := randf_range(SURFACE_CHUNK_SPEED_MIN, SURFACE_CHUNK_SPEED_MAX)
		chunk.linear_velocity = dir * speed
		chunk.angular_velocity = randf_range(-16.0, 16.0)
		projectiles_root.add_child(chunk)

		_queue_free_with_delay(chunk, SURFACE_PARTICLES_CLEANUP_DELAY + randf_range(0.0, 0.55))

	var dust := CPUParticles2D.new()
	dust.z_as_relative = false
	dust.z_index = BLOOD_EFFECTS_Z_INDEX - 5
	dust.global_position = impact_position
	dust.amount = 8
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.lifetime = minf(0.22, SURFACE_PARTICLES_LIFETIME)
	dust.local_coords = false
	dust.gravity = SURFACE_PARTICLES_GRAVITY
	dust.initial_velocity_min = 12.0
	dust.initial_velocity_max = 44.0
	dust.scale_amount_min = 0.7
	dust.scale_amount_max = 1.2
	var dust_color: Color = palette[0] as Color
	dust.color = Color(dust_color.r, dust_color.g, dust_color.b, 0.55)
	dust.direction = spray_direction
	dust.spread = 40.0
	projectiles_root.add_child(dust)
	dust.emitting = true

	_queue_free_with_delay(dust, 0.85)

func _play_surface_impact_sfx(impact_position: Vector2) -> void:
	if projectiles_root == null:
		return
	var surface_id := _surface_id_at_world_point(impact_position)
	var streams_value: Variant = SURFACE_IMPACT_STREAMS.get(surface_id, SURFACE_IMPACT_STREAMS[SURFACE_ID_WOOD])
	if not (streams_value is Array):
		return
	var streams = streams_value as Array
	if streams.is_empty():
		return
	var chosen_stream = streams[randi() % streams.size()]
	if not (chosen_stream is AudioStream):
		return
	_play_positional_sfx(chosen_stream as AudioStream, impact_position, SURFACE_IMPACT_VOLUME_DB, randf_range(0.93, 1.04), 4)

func _surface_id_at_world_point(world_point: Vector2) -> String:
	var tree := projectiles_root.get_tree()
	if tree == null:
		return SURFACE_ID_WOOD
	var best_zone: Node = null
	var best_priority := -2147483648
	for zone_value in tree.get_nodes_in_group("ground_audio_zones"):
		var zone := zone_value as Node
		if zone == null or not is_instance_valid(zone):
			continue
		if not zone.has_method("contains_world_point") or not bool(zone.call("contains_world_point", world_point)):
			continue
		var zone_priority := 0
		if zone.has_method("get_surface_priority"):
			zone_priority = int(zone.call("get_surface_priority"))
		if best_zone == null or zone_priority > best_priority:
			best_zone = zone
			best_priority = zone_priority
	if best_zone != null and best_zone.has_method("get_surface_id"):
		return str(best_zone.call("get_surface_id")).strip_edges().to_lower()
	return SURFACE_ID_WOOD

func _blood_chunk_color(base_color: Color) -> Color:
	var hsv_h := base_color.h
	var hsv_s := clampf(maxf(0.72, base_color.s), 0.0, 1.0)
	var hsv_v := clampf(base_color.v * randf_range(0.72, 1.08), 0.0, 1.0)
	return Color.from_hsv(hsv_h, hsv_s, hsv_v, 1.0)

func sample_map_front_color(world_position: Vector2) -> Color:
	var palette := sample_map_front_palette(world_position, 1)
	if palette.is_empty():
		return Color(0.0, 0.0, 0.0, 0.0)
	return palette[0] as Color

func sample_map_front_palette(world_position: Vector2, max_colors: int = 6) -> Array:
	if map_front_sprite == null or map_front_sprite.texture == null:
		return []

	if map_front_image == null:
		map_front_image = map_front_sprite.texture.get_image()
	if map_front_image == null or map_front_image.is_empty():
		return []

	var region_origin := Vector2.ZERO
	var draw_size := map_front_sprite.texture.get_size()
	if map_front_sprite.region_enabled:
		region_origin = map_front_sprite.region_rect.position
		draw_size = map_front_sprite.region_rect.size
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return []

	var local_hit := map_front_sprite.to_local(world_position)
	local_hit -= map_front_sprite.offset
	if map_front_sprite.centered:
		local_hit += draw_size * 0.5
	if local_hit.x < 0.0 or local_hit.y < 0.0 or local_hit.x >= draw_size.x or local_hit.y >= draw_size.y:
		return []

	var sample_x := int(round(local_hit.x)) + int(region_origin.x)
	var sample_y := int(round(local_hit.y)) + int(region_origin.y)
	return _sample_surface_palette_near(sample_x, sample_y, max_colors)

func play_splash_hit_sfx(impact_position: Vector2) -> void:
	if projectiles_root == null or splash_hit_sfx == null:
		return

	var player := AudioStreamPlayer2D.new()
	player.stream = splash_hit_sfx
	player.global_position = impact_position
	player.volume_db = SPLASH_HIT_VOLUME_DB
	player.pitch_scale = randf_range(0.94, 1.05)
	player.max_polyphony = 2
	projectiles_root.add_child(player)
	player.finished.connect(Callable(self, "_queue_free_from_weak_ref").bind(weakref(player)))
	player.play()

func play_death_sfx(impact_position: Vector2) -> void:
	if projectiles_root == null or death_hit_sfx == null:
		return

	var player := AudioStreamPlayer2D.new()
	player.stream = death_hit_sfx
	player.global_position = impact_position
	player.volume_db = 5.0
	player.pitch_scale = randf_range(0.98, 1.04)
	player.max_polyphony = 2
	projectiles_root.add_child(player)
	player.finished.connect(Callable(self, "_queue_free_from_weak_ref").bind(weakref(player)))
	player.play()

func play_bullet_touch_sfx(impact_position: Vector2) -> void:
	if projectiles_root == null or bullet_touch_sfx == null:
		return
	_play_positional_sfx(bullet_touch_sfx, impact_position, -2.0, randf_range(0.95, 1.05), 6)

func play_weapon_impact_sfx(stream: AudioStream, impact_position: Vector2, volume_db: float = 0.0, pitch_scale: float = 1.0, max_polyphony: int = 2) -> void:
	if projectiles_root == null or stream == null:
		return
	_play_positional_sfx(stream, impact_position, volume_db, pitch_scale, max_polyphony)

func spawn_explosion_effect(world_position: Vector2) -> void:
	if projectiles_root == null or explosion_texture == null:
		return
	var sprite := AnimatedSprite2D.new()
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.global_position = world_position + Vector2(0.0, EXPLOSION_Y_OFFSET)
	sprite.z_as_relative = false
	sprite.z_index = 1000
	sprite.scale = Vector2.ONE * 1.85
	sprite.sprite_frames = _explosion_sprite_frames()
	sprite.animation = "default"
	sprite.speed_scale = 1.0
	projectiles_root.add_child(sprite)
	sprite.animation_finished.connect(Callable(self, "_queue_free_from_weak_ref").bind(weakref(sprite)))
	sprite.play("default")

func spawn_hit_flash(world_position: Vector2) -> void:
	if projectiles_root == null or hit_texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = hit_texture
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.global_position = world_position
	sprite.rotation = randf_range(0.0, TAU)
	sprite.z_as_relative = false
	sprite.z_index = 1000
	sprite.scale = Vector2.ONE * 0.85
	projectiles_root.add_child(sprite)

	var tw := sprite.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sprite, "scale", Vector2.ONE * 1.2, HIT_FLASH_LIFETIME)
	tw.parallel().tween_property(sprite, "modulate:a", 0.0, HIT_FLASH_LIFETIME)
	tw.tween_callback(Callable(self, "_queue_free_from_weak_ref").bind(weakref(sprite)))

func _play_positional_sfx(stream: AudioStream, world_position: Vector2, volume_db: float, pitch_scale: float, max_polyphony: int) -> void:
	if projectiles_root == null or stream == null:
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.global_position = world_position
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.max_polyphony = max_polyphony
	projectiles_root.add_child(player)
	player.finished.connect(Callable(self, "_queue_free_from_weak_ref").bind(weakref(player)))
	player.play()

func _queue_free_with_delay(target: Node, delay_seconds: float) -> void:
	if target == null:
		return
	var tree := target.get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(delay_seconds)
	timer.timeout.connect(Callable(self, "_queue_free_from_weak_ref").bind(weakref(target)))

func _queue_free_from_weak_ref(target_ref: WeakRef) -> void:
	if target_ref == null:
		return
	var target := target_ref.get_ref() as Node
	if target != null and is_instance_valid(target):
		target.queue_free()

func _sample_surface_color_near(sample_x: int, sample_y: int) -> Color:
	var palette := _sample_surface_palette_near(sample_x, sample_y, 1)
	if palette.is_empty():
		return Color(0.0, 0.0, 0.0, 0.0)
	return palette[0] as Color

func _sample_surface_palette_near(sample_x: int, sample_y: int, max_colors: int) -> Array:
	if map_front_image == null:
		return []
	var width := map_front_image.get_width()
	var height := map_front_image.get_height()
	if sample_x < 0 or sample_y < 0 or sample_x >= width or sample_y >= height:
		return []
	var result: Array = []
	var candidates: Array = []
	var desired_count := maxi(1, max_colors)

	for radius in range(0, SURFACE_IMPACT_SAMPLE_RADIUS + 1):
		for y in range(sample_y - radius, sample_y + radius + 1):
			for x in range(sample_x - radius, sample_x + radius + 1):
				if x < 0 or y < 0 or x >= width or y >= height:
					continue
				if radius > 0 and abs(x - sample_x) != radius and abs(y - sample_y) != radius:
					continue
				var color := map_front_image.get_pixel(x, y)
				if color.a >= SURFACE_COLOR_ALPHA_MIN:
					candidates.append({
						"dist_sq": float((x - sample_x) * (x - sample_x) + (y - sample_y) * (y - sample_y)),
						"color": Color(color.r, color.g, color.b, 1.0)
					})
	if candidates.is_empty():
		return result
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("dist_sq", 0.0)) < float(b.get("dist_sq", 0.0))
	)
	for candidate_value in candidates:
		if result.size() >= desired_count:
			break
		var candidate := candidate_value as Dictionary
		var color := candidate.get("color", Color(0.0, 0.0, 0.0, 0.0)) as Color
		result.append(color)
	return result

func _explosion_sprite_frames() -> SpriteFrames:
	if explosion_frames != null:
		return explosion_frames
	var frames := SpriteFrames.new()
	if not frames.has_animation("default"):
		frames.add_animation("default")
	frames.set_animation_loop("default", false)
	frames.set_animation_speed("default", 1.0 / maxf(0.001, EXPLOSION_FRAME_SEC))
	for frame_index in range(EXPLOSION_FRAME_COUNT):
		var atlas := AtlasTexture.new()
		atlas.atlas = explosion_texture
		atlas.region = Rect2(EXPLOSION_FRAME_SIZE.x * float(frame_index), 0.0, EXPLOSION_FRAME_SIZE.x, EXPLOSION_FRAME_SIZE.y)
		frames.add_frame("default", atlas)
	explosion_frames = frames
	return explosion_frames
