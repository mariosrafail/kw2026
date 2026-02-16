extends RefCounted
class_name CombatEffects

const BLOOD_PARTICLES_AMOUNT := 46
const BLOOD_PARTICLES_LIFETIME := 0.42
const BLOOD_PARTICLES_CLEANUP_DELAY := 1.2
const BLOOD_PARTICLES_GRAVITY := Vector2(0.0, 860.0)
const BLOOD_PARTICLES_COLOR := Color(0.98, 0.02, 0.07, 1.0)
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
const SPLASH_HIT_VOLUME_DB := 4.0

var projectiles_root: Node2D
var map_front_sprite: Sprite2D
var splash_hit_sfx: AudioStream
var death_hit_sfx: AudioStream
var bullet_touch_sfx: AudioStream
var map_front_image: Image = null

func configure(root: Node2D, front_sprite: Sprite2D, splash_sfx: AudioStream, death_sfx: AudioStream, bullet_touch: AudioStream = null) -> void:
	projectiles_root = root
	map_front_sprite = front_sprite
	splash_hit_sfx = splash_sfx
	death_hit_sfx = death_sfx
	bullet_touch_sfx = bullet_touch

func spawn_blood_particles(impact_position: Vector2, incoming_velocity: Vector2) -> void:
	if projectiles_root == null:
		return
	play_splash_hit_sfx(impact_position)

	var particles := CPUParticles2D.new()
	particles.z_index = 40
	particles.global_position = impact_position
	particles.amount = BLOOD_PARTICLES_AMOUNT
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = BLOOD_PARTICLES_LIFETIME
	particles.local_coords = false
	particles.gravity = BLOOD_PARTICLES_GRAVITY
	particles.initial_velocity_min = 220.0
	particles.initial_velocity_max = 520.0
	particles.angular_velocity_min = -1100.0
	particles.angular_velocity_max = 1100.0
	particles.scale_amount_min = 1.15
	particles.scale_amount_max = 2.25
	particles.color = BLOOD_PARTICLES_COLOR
	var spray_direction := Vector2.UP
	if incoming_velocity.length_squared() > 0.0001:
		spray_direction = (-incoming_velocity).normalized()
	particles.direction = spray_direction
	particles.spread = 145.0
	projectiles_root.add_child(particles)
	particles.emitting = true

	_queue_free_with_delay(particles, BLOOD_PARTICLES_CLEANUP_DELAY)

func spawn_surface_particles(impact_position: Vector2, incoming_velocity: Vector2, particle_color: Color) -> void:
	if projectiles_root == null:
		return
	if particle_color.a < SURFACE_COLOR_ALPHA_MIN:
		return

	var spray_direction := Vector2.UP
	if incoming_velocity.length_squared() > 0.0001:
		spray_direction = (-incoming_velocity).normalized()
	for i in range(SURFACE_PARTICLES_AMOUNT):
		var chunk := RigidBody2D.new()
		chunk.z_index = 36
		chunk.global_position = impact_position + Vector2(randf_range(-2.5, 2.5), randf_range(-2.0, 2.0))
		chunk.gravity_scale = SURFACE_CHUNK_GRAVITY_SCALE
		chunk.linear_damp = SURFACE_CHUNK_LINEAR_DAMP
		chunk.angular_damp = SURFACE_CHUNK_ANGULAR_DAMP
		chunk.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
		chunk.collision_layer = SURFACE_CHUNK_COLLISION_LAYER
		chunk.collision_mask = SURFACE_CHUNK_COLLISION_MASK

		var size := randf_range(SURFACE_CHUNK_MIN_SIZE, SURFACE_CHUNK_MAX_SIZE)
		var half := size * 0.5

		var visual := Polygon2D.new()
		visual.color = Color(particle_color.r, particle_color.g, particle_color.b, 1.0)
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

		var dir := spray_direction.rotated(randf_range(-1.6, 1.6))
		var speed := randf_range(SURFACE_CHUNK_SPEED_MIN, SURFACE_CHUNK_SPEED_MAX)
		chunk.linear_velocity = dir * speed + Vector2(randf_range(-24.0, 24.0), randf_range(-18.0, 42.0))
		chunk.angular_velocity = randf_range(-16.0, 16.0)
		projectiles_root.add_child(chunk)

		_queue_free_with_delay(chunk, SURFACE_PARTICLES_CLEANUP_DELAY + randf_range(0.0, 0.55))

	var dust := CPUParticles2D.new()
	dust.z_index = 35
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
	dust.color = Color(particle_color.r, particle_color.g, particle_color.b, 0.55)
	dust.direction = spray_direction
	dust.spread = 160.0
	projectiles_root.add_child(dust)
	dust.emitting = true

	_queue_free_with_delay(dust, 0.85)

func sample_map_front_color(world_position: Vector2) -> Color:
	if map_front_sprite == null or map_front_sprite.texture == null:
		return Color(0.0, 0.0, 0.0, 0.0)

	if map_front_image == null:
		map_front_image = map_front_sprite.texture.get_image()
	if map_front_image == null or map_front_image.is_empty():
		return Color(0.0, 0.0, 0.0, 0.0)

	var region_origin := Vector2.ZERO
	var draw_size := map_front_sprite.texture.get_size()
	if map_front_sprite.region_enabled:
		region_origin = map_front_sprite.region_rect.position
		draw_size = map_front_sprite.region_rect.size
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return Color(0.0, 0.0, 0.0, 0.0)

	var local_hit := map_front_sprite.to_local(world_position)
	local_hit -= map_front_sprite.offset
	if map_front_sprite.centered:
		local_hit += draw_size * 0.5
	if local_hit.x < 0.0 or local_hit.y < 0.0 or local_hit.x >= draw_size.x or local_hit.y >= draw_size.y:
		return Color(0.0, 0.0, 0.0, 0.0)

	var sample_x := int(round(local_hit.x)) + int(region_origin.x)
	var sample_y := int(round(local_hit.y)) + int(region_origin.y)
	if sample_x < 0 or sample_y < 0 or sample_x >= map_front_image.get_width() or sample_y >= map_front_image.get_height():
		return Color(0.0, 0.0, 0.0, 0.0)

	var color := map_front_image.get_pixel(sample_x, sample_y)
	if color.a < SURFACE_COLOR_ALPHA_MIN:
		return Color(0.0, 0.0, 0.0, 0.0)
	return Color(color.r, color.g, color.b, color.a)

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

	var player := AudioStreamPlayer2D.new()
	player.stream = bullet_touch_sfx
	player.global_position = impact_position
	player.volume_db = -2.0
	player.pitch_scale = randf_range(0.95, 1.05)
	player.max_polyphony = 6
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
