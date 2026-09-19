extends RefCounted
## Prototype-only conversion. Never edits source palettes or the 2D materials.
const SHADER := preload("res://scripts/prototypes/kw_pixel_world.gdshader")

static func from_standard(original: StandardMaterial3D, cell_size: float = 0.07) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("base_color", original.albedo_color)
	mat.set_shader_parameter("use_texture", original.albedo_texture != null)
	if original.albedo_texture != null:
		mat.set_shader_parameter("albedo_texture", original.albedo_texture)
	mat.set_shader_parameter("pixel_cell_size", cell_size)
	if original.emission_enabled:
		mat.set_shader_parameter("glow_color", original.emission)
		mat.set_shader_parameter("glow_energy", minf(original.emission_energy_multiplier, 0.40))
		mat.set_shader_parameter("noise_strength", 0.085)
	return mat

static func solid(color: Color, emissive: bool, energy: float) -> ShaderMaterial:
	var original := StandardMaterial3D.new()
	original.albedo_color = color
	original.emission_enabled = emissive
	original.emission = color
	original.emission_energy_multiplier = energy
	return from_standard(original, 0.16)
