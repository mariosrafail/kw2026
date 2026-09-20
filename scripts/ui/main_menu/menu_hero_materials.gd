extends RefCounted
## Materials for the menu instance only. Source gameplay assets are never edited.
## Keep the warrior's authored albedo/UV colors, then add a subtler portrait finish on top.


static func apply_to(hero: Node3D) -> void:
	var normal := _surface_normal()
	for node in hero.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var part := str(mesh.name)
		if part.contains("Outline"):
			# Remove only the instantiated ink shell, never its PackedScene resource.
			mesh.get_parent().remove_child(mesh)
			mesh.free()
			continue
		var source := mesh.get_meta("plain_material", mesh.material_override) as StandardMaterial3D
		if source == null:
			continue
		var material := source.duplicate(true) as StandardMaterial3D
		material.resource_name = "Portrait %s" % part
		material.resource_local_to_scene = true
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.normal_enabled = true
		material.normal_texture = normal
		material.normal_scale = 0.08
		material.clearcoat_enabled = true
		material.clearcoat = 0.14
		material.clearcoat_roughness = 0.42
		if part.begins_with("Eye_"):
			# Preserve the authored black eyes; only give their surface a tighter reflection.
			material.metallic = 0.18
			material.roughness = 0.22
			material.clearcoat = 0.32
		elif part.begins_with("Horn_"):
			# Horn color comes from the original red texture atlas.
			material.metallic = 0.12
			material.roughness = 0.34
		elif part.begins_with("Torso_") or part.begins_with("Foot_"):
			material.metallic = 0.16
			material.roughness = 0.52
		else:
			material.metallic = 0.10
			material.roughness = 0.44
		mesh.material_overlay = null
		mesh.material_override = material
		# No callback should be able to restore the source's toon materials here.
		for key in ["plain_material", "toon_material", "pixel_material"]:
			if mesh.has_meta(key):
				mesh.remove_meta(key)


static func _surface_normal() -> NoiseTexture2D:
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.noise = _noise(113, 0.25)
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.as_normal_map = true
	texture.bump_strength = 0.8
	return texture


static func _noise(noise_seed: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 3
	return noise
