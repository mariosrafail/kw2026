extends RefCounted
## Small reusable flame emitters for the Inferno AK and its projectiles.

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
		gravity_value: Vector3
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
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 42.0
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

	var quad := QuadMesh.new()
	quad.size = quad_size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color.WHITE
	material.emission_enabled = true
	material.emission = hot_color
	material.emission_energy_multiplier = 3.2
	quad.material = material
	particles.draw_pass_1 = quad
	return particles
