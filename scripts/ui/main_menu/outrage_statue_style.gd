extends RefCounted
## Menu-only Outrage presentation inspired by an aged metal / stone statue.
## Gameplay materials and the warrior skin showroom stay untouched.

static var _albedo_noise: NoiseTexture2D
static var _normal_noise: NoiseTexture2D


static func apply_to(hero: Node3D) -> void:
	if hero == null:
		return
	_remove_skin_glows(hero)
	var albedo_noise := _statue_albedo_noise()
	var normal_noise := _statue_normal_noise()
	for node in hero.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null:
			continue
		var part := str(mesh.name)
		if part.contains("Outline"):
			if mesh.get_parent() != null:
				mesh.get_parent().remove_child(mesh)
			mesh.free()
			continue
		var material := _material_for_part(part, albedo_noise, normal_noise)
		mesh.material_overlay = null
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for key in ["plain_material", "toon_material", "pixel_material", "force_plain_emissive"]:
			if mesh.has_meta(key):
				mesh.remove_meta(key)
	hero.set_meta("kw_menu_statue", true)


static func _material_for_part(part: String, albedo_noise: Texture2D, normal_noise: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "Outrage Statue %s" % part
	material.resource_local_to_scene = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.albedo_texture = albedo_noise
	material.normal_enabled = true
	material.normal_texture = normal_noise
	material.normal_scale = 0.22
	material.clearcoat_enabled = true
	material.clearcoat = 0.12
	material.clearcoat_roughness = 0.38
	material.metallic = 0.58
	material.roughness = 0.58

	if part.begins_with("Eye_"):
		# Keep the face readable: dark polished eye insets against the pale statue shell.
		material.albedo_texture = null
		material.albedo_color = Color("242321")
		material.metallic = 0.72
		material.roughness = 0.24
		material.normal_enabled = false
		material.clearcoat = 0.30
	elif part.begins_with("Horn_"):
		# Slight warm tarnish on the horns, like aged bronze under silver oxidation.
		material.albedo_color = Color("c6baa2")
		material.metallic = 0.70
		material.roughness = 0.46
		material.normal_scale = 0.18
	elif part.begins_with("Foot_") or part.begins_with("Torso_") or part in ["Back_Panel", "Left_Panel", "Right_Panel"]:
		material.albedo_color = Color("b0b2ad")
		material.metallic = 0.52
		material.roughness = 0.66
		material.normal_scale = 0.26
	else:
		# Head / front surfaces stay a little brighter so the sculpted planes catch the menu key light.
		material.albedo_color = Color("d2d3cc")
	return material


static func _statue_albedo_noise() -> NoiseTexture2D:
	if _albedo_noise != null:
		return _albedo_noise
	var noise := FastNoiseLite.new()
	noise.seed = 4117
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.17
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.15
	noise.fractal_gain = 0.48
	var gradient := Gradient.new()
	gradient.set_color(0, Color("3b3833"))
	gradient.add_point(0.28, Color("66665f"))
	gradient.add_point(0.52, Color("9b9d98"))
	gradient.add_point(0.74, Color("c6c8c2"))
	gradient.set_color(gradient.get_point_count() - 1, Color("e1e1da"))
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.noise = noise
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.color_ramp = gradient
	_albedo_noise = texture
	return _albedo_noise


static func _statue_normal_noise() -> NoiseTexture2D:
	if _normal_noise != null:
		return _normal_noise
	var noise := FastNoiseLite.new()
	noise.seed = 9083
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.34
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.42
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.noise = noise
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.as_normal_map = true
	texture.bump_strength = 0.85
	_normal_noise = texture
	return _normal_noise


static func _remove_skin_glows(hero: Node3D) -> void:
	for node in hero.find_children("*", "OmniLight3D", true, false):
		var light := node as OmniLight3D
		if light == null:
			continue
		if light.get_parent() != null:
			light.get_parent().remove_child(light)
		light.free()
