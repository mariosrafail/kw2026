extends RefCounted
## Small reusable flame emitters for the Inferno AK and its projectiles.

const PIXEL_MATERIALS := preload("res://scripts/prototypes/kw_pixel_materials.gd")

static func add_weapon_flames(parent: Node3D) -> GPUParticles3D:
	var particles := _make_emitter(
		"InfernoWeaponParticles",
		Color("ff9d20"),
		Color("fff176"),
		24,
		0.34,
		Vector3(0.48, 0.035, 0.12),
		Vector2(0.045, 0.085),
		0.12,
		0.40,
		Vector3(0.0, 0.30, 0.0)
	)
	particles.position = Vector3(0.18, 0.38, 0.0)
	particles.preprocess = 0.30
	parent.add_child(particles)
	return particles

static func add_bullet_flames(parent: Node3D, main_color: Color) -> GPUParticles3D:
	var hot := main_color.lightened(0.42)
	var particles := _make_emitter(
		"InfernoBulletParticles",
		main_color,
		hot,
		12,
		0.16,
		Vector3(0.035, 0.035, 0.16),
		Vector2(0.026, 0.050),
		0.18,
		0.48,
		Vector3(0.0, 0.10, 0.28)
	)
	particles.position = Vector3(0.0, 0.0, 0.10)
	particles.preprocess = 0.08
	parent.add_child(particles)
	return particles


static func add_character_fire_aura(parent: Node3D, base_color: Color = Color("ff5a24"), hot_color: Color = Color("ffe06a")) -> GPUParticles3D:
	var particles := _make_emitter(
		"WarriorFireAuraParticles",
		base_color,
		hot_color,
		52,
		0.48,
		Vector3(0.55, 0.90, 0.42),
		Vector2(0.075, 0.14),
		0.55,
		1.65,
		Vector3(0.0, 1.80, 0.0),
		Vector3.UP,
		68.0,
		true
	)
	particles.position = Vector3(0.0, 0.55, 0.0)
	particles.visibility_aabb = AABB(Vector3(-1.6,-1.2,-1.6),Vector3(3.2,4.8,3.2))
	particles.preprocess = 0.45
	parent.add_child(particles)
	return particles


static func add_flame_cone(parent: Node3D) -> GPUParticles3D:
	var particles := _make_emitter(
		"AevilokFlamethrowerParticles",
		Color("ff4b18"),
		Color("fff07a"),
		88,
		0.42,
		Vector3(0.12, 0.10, 0.10),
		Vector2(0.085, 0.17),
		5.0,
		8.7,
		Vector3(0.0, 0.65, 0.0),
		Vector3(0.0, 0.0, -1.0),
		20.0,
		true
	)
	particles.position = Vector3(0.0, 0.0, -0.36)
	# Fast flame particles travel several metres during their lifetime. Keep the
	# bounds deliberately generous or Godot culls the whole emitter from the
	# third-person camera before the flame reaches the visible cone.
	particles.visibility_aabb = AABB(Vector3(-2.0,-2.0,-6.0),Vector3(4.0,4.0,8.0))
	particles.preprocess = 0.18
	parent.add_child(particles)
	return particles

static func _make_emitter(
		name_value: String,
		base_color: Color,
		hot_color: Color,
		amount_value: int,
		lifetime_value: float,
		extents: Vector3,
		quad_size: Vector2,
		velocity_min: float,
		velocity_max: float,
			gravity_value: Vector3,
			direction_value: Vector3 = Vector3.UP,
			spread_value: float = 42.0,
			no_depth_test_value: bool = false
		) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = name_value
	particles.amount = amount_value
	particles.lifetime = lifetime_value
	particles.randomness = 0.55
	particles.local_coords = true
	particles.emitting = true
	particles.visibility_aabb = AABB(-extents * 2.5, extents * 5.0 + Vector3(0.35, 0.65, 0.35))

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extents
	process.direction = direction_value
	process.spread = spread_value
	process.initial_velocity_min = velocity_min
	process.initial_velocity_max = velocity_max
	process.gravity = gravity_value
	process.scale_min = 0.55
	process.scale_max = 1.35
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.38, 0.78, 1.0])
	gradient.colors = PackedColorArray([
		hot_color,
		base_color,
		Color(base_color.r * 0.72, base_color.g * 0.34, base_color.b * 0.14, 0.82),
		Color(base_color.r * 0.40, base_color.g * 0.14, base_color.b * 0.05, 0.0),
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	particles.process_material = process

	var material: Material
	if no_depth_test_value:
		var vfx := PIXEL_MATERIALS.solid(hot_color, true, 0.40)
		vfx.set_shader_parameter("glow_energy", 0.95)
		vfx.set_shader_parameter("comic_enabled", true)
		vfx.set_shader_parameter("pixel_enabled", true)
		material = vfx
		var orb := SphereMesh.new()
		var radius := maxf(0.035, maxf(quad_size.x, quad_size.y) * 0.55)
		orb.radius = radius
		orb.height = radius * 2.0
		orb.material = material
		particles.draw_pass_1 = orb
	else:
		var quad := QuadMesh.new()
		quad.size = quad_size
		var standard := StandardMaterial3D.new()
		standard.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		standard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		standard.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		standard.cull_mode = BaseMaterial3D.CULL_DISABLED
		standard.albedo_color = Color.WHITE
		standard.emission_enabled = true
		standard.emission = hot_color
		standard.emission_energy_multiplier = 3.2
		material = standard
		quad.material = material
		particles.draw_pass_1 = quad
	return particles
