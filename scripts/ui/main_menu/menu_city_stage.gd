extends RefCounted
## Lightweight procedural cyberpunk stage for the 3D main-menu viewport.
## Everything is generated at runtime so the menu remains a real 3D scene.

const CITY_DARK := Color("0C111A")
const CITY_BLUE := Color("101D2C")
const CITY_STEEL := Color("172333")
const NEON_CYAN := Color("55DFFF")
const NEON_BLUE := Color("2588FF")
const NEON_RED := Color("FF2749")
const NEON_PINK := Color("FF4F8A")


static func build(parent: Node3D) -> Node3D:
	var city := Node3D.new()
	city.name = "MenuCyberCity"
	city.set_meta("surface_normal", _surface_normal())
	city.set_meta("surface_roughness", _roughness_texture())
	parent.add_child(city)
	_add_floor(city)
	_add_back_wall(city)
	_add_towers(city)
	_add_neon_architecture(city)
	_add_foreground_blocks(city)
	return city


static func _add_floor(parent: Node3D) -> void:
	var floor := MeshInstance3D.new()
	floor.name = "WetFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(24.0, 20.0)
	floor.mesh = plane
	floor.position = Vector3(0.0, -1.78, 3.5)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("080C13")
	material.metallic = 0.58
	material.roughness = 0.17
	material.clearcoat_enabled = true
	material.clearcoat = 0.55
	material.clearcoat_roughness = 0.14
	material.normal_enabled = true
	material.normal_texture = parent.get_meta("surface_normal") as Texture2D
	material.normal_scale = 0.14
	material.roughness_texture = parent.get_meta("surface_roughness") as Texture2D
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	floor.material_override = material
	parent.add_child(floor)

	# Short floor emitters create reflected color pools without looking like debug guides.
	_add_box(parent, Vector3(-3.6, -1.735, 2.2), Vector3(0.16, 0.018, 2.8), NEON_CYAN, true, 1.5)
	_add_box(parent, Vector3(3.9, -1.73, 3.2), Vector3(0.18, 0.020, 2.5), NEON_RED, true, 1.8)
	_add_box(parent, Vector3(0.9, -1.72, 6.5), Vector3(2.8, 0.025, 0.12), NEON_PINK, true, 1.4)


static func _add_back_wall(parent: Node3D) -> void:
	_add_box(parent, Vector3(0.8, 2.4, 9.0), Vector3(14.0, 8.0, 0.7), Color("0A101A"), false)
	_add_box(parent, Vector3(-2.1, 2.0, 8.55), Vector3(0.11, 4.4, 0.10), NEON_CYAN, true, 2.0)
	_add_box(parent, Vector3(3.7, 2.3, 8.54), Vector3(0.12, 4.8, 0.10), NEON_RED, true, 2.2)
	_add_box(parent, Vector3(6.1, 1.7, 8.52), Vector3(0.10, 3.5, 0.10), NEON_PINK, true, 1.8)


static func _add_towers(parent: Node3D) -> void:
	var towers := [
		[Vector3(-5.8, 0.20, 5.8), Vector3(2.0, 4.0, 2.2), CITY_DARK, NEON_BLUE],
		[Vector3(-3.6, 0.85, 7.1), Vector3(1.3, 5.3, 1.5), CITY_STEEL, NEON_RED],
		[Vector3(-1.7, 1.45, 7.8), Vector3(1.5, 6.5, 1.3), CITY_BLUE, NEON_CYAN],
		[Vector3(1.1, 1.85, 8.2), Vector3(1.7, 7.3, 1.1), CITY_STEEL, NEON_RED],
		[Vector3(3.6, 1.25, 7.7), Vector3(1.55, 6.0, 1.4), CITY_BLUE, NEON_CYAN],
		[Vector3(5.7, 0.55, 6.5), Vector3(2.1, 4.6, 2.0), CITY_DARK, NEON_RED],
		[Vector3(7.5, 1.0, 8.3), Vector3(1.5, 5.4, 1.3), CITY_STEEL, NEON_BLUE],
	]
	for item in towers:
		var position: Vector3 = item[0]
		var size: Vector3 = item[1]
		var body_color: Color = item[2]
		var neon: Color = item[3]
		_add_box(parent, position, size, body_color, false)
		# Vertical facade light, offset slightly toward the camera.
		_add_box(
			parent,
			position + Vector3(size.x * 0.36, size.y * 0.02, -size.z * 0.505),
			Vector3(maxf(0.045, size.x * 0.035), size.y * 0.74, 0.035),
			neon,
			true,
			2.1
		)
		# Small roof beacon.
		_add_box(
			parent,
			position + Vector3(-size.x * 0.22, size.y * 0.53, 0.0),
			Vector3(size.x * 0.18, 0.08, size.z * 0.20),
			neon,
			true,
			1.4
		)
		# Small facade windows give each tower readable depth instead of a wireframe look.
		for row in range(3):
			var row_y := position.y - size.y * 0.25 + float(row) * size.y * 0.24
			for side in [-0.24, 0.24]:
				_add_box(
					parent,
					Vector3(position.x + size.x * side, row_y, position.z - size.z * 0.508),
					Vector3(maxf(0.12, size.x * 0.16), 0.055, 0.032),
					Color(neon, 0.70),
					true,
					0.72
				)


static func _add_neon_architecture(parent: Node3D) -> void:
	# Large sign slabs on the right, matching the reference's vertical billboards.
	_add_box(parent, Vector3(5.25, 1.15, 3.9), Vector3(1.45, 4.4, 0.22), Color("0A101B"), false)
	_add_box(parent, Vector3(4.57, 1.15, 3.75), Vector3(0.075, 3.2, 0.07), NEON_RED, true, 2.2)
	_add_box(parent, Vector3(5.94, 1.15, 3.75), Vector3(0.075, 3.2, 0.07), NEON_CYAN, true, 2.0)

	_add_box(parent, Vector3(-4.5, 0.55, 4.2), Vector3(1.85, 3.3, 0.24), Color("09101A"), false)
	_add_box(parent, Vector3(-3.61, 0.55, 4.05), Vector3(0.075, 2.2, 0.07), NEON_PINK, true, 2.0)

	# Elevated bridge/rail behind the hero.
	_add_box(parent, Vector3(1.2, -0.15, 5.0), Vector3(10.0, 0.20, 0.28), Color("111923"), false)
	for x in [-3.2, -1.3, 0.7, 2.7, 4.5]:
		_add_box(parent, Vector3(x, -0.02, 4.80), Vector3(0.07, 0.55, 0.08), Color("24303B"), false)
	for x in [-2.8, -0.6, 1.7, 3.8]:
		_add_box(parent, Vector3(x, 0.20, 4.78), Vector3(1.15, 0.050, 0.055), NEON_RED, true, 1.15)


static func _add_foreground_blocks(parent: Node3D) -> void:
	# Dark out-of-focus-ish geometry near the camera gives the stage more depth.
	_add_box(parent, Vector3(-5.7, -1.10, -0.3), Vector3(2.4, 1.3, 2.1), Color("05070B"), false)
	_add_box(parent, Vector3(6.1, -1.00, -0.1), Vector3(2.6, 1.5, 2.2), Color("05070B"), false)
	_add_box(parent, Vector3(4.9, -0.45, 1.1), Vector3(0.11, 1.35, 0.11), NEON_RED, true, 1.4)


static func _add_box(parent: Node3D, position: Vector3, size: Vector3, color: Color,
		emissive: bool, emission_energy: float = 2.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.28 if not emissive else 0.08
	material.roughness = 0.62 if not emissive else 0.24
	if not emissive:
		material.normal_enabled = true
		material.normal_texture = parent.get_meta("surface_normal") as Texture2D
		material.normal_scale = 0.12
		material.roughness_texture = parent.get_meta("surface_roughness") as Texture2D
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		material.clearcoat_enabled = true
		material.clearcoat = 0.08
		material.clearcoat_roughness = 0.64
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh


static func _surface_normal() -> NoiseTexture2D:
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	var noise := FastNoiseLite.new()
	noise.seed = 2609
	noise.frequency = 0.18
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 4
	texture.noise = noise
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.as_normal_map = true
	texture.bump_strength = 0.55
	return texture


static func _roughness_texture() -> NoiseTexture2D:
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	var noise := FastNoiseLite.new()
	noise.seed = 917
	noise.frequency = 0.11
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 3
	texture.noise = noise
	texture.seamless = true
	texture.generate_mipmaps = true
	return texture
