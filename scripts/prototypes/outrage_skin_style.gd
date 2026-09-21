extends RefCounted
## Runtime/material-only skins for the authored Outrage fullbody.
## Geometry, pivots, animation rigs and source Blockbench files stay untouched.

const SKIN_NAMES := [
	"CLASSIC",
	"VOID",
	"NEON",
]

const VOID_BODY := Color("292a31")
const VOID_PANEL := Color("17181d")
const VOID_HORN := Color("b31cff")
const VOID_EYE := Color("ffffff")
const NEON_BODY := Color("20ff00")
const NEON_PANEL := Color("12b800")
const NEON_HORN := Color("f4ff00")
const NEON_EYE := Color("050505")
const HORN_RAISE_3PX := 0.21


static func skin_count() -> int:
	return SKIN_NAMES.size()


static func skin_name(skin_id: int) -> String:
	return SKIN_NAMES[clampi(skin_id, 0, SKIN_NAMES.size() - 1)]


static func skin_accent(skin_id: int) -> Color:
	match clampi(skin_id, 0, SKIN_NAMES.size() - 1):
		1: return VOID_HORN
		2: return NEON_HORN
		_: return Color("9b2635")


static func main_color(skin_id: int) -> Color:
	match clampi(skin_id, 0, SKIN_NAMES.size() - 1):
		1: return VOID_BODY
		2: return NEON_BODY
		_: return Color("8f1d27")


static func apply(model: Node3D, skin_id: int, glow_scale: float = 1.0) -> void:
	var resolved := clampi(skin_id, 0, SKIN_NAMES.size() - 1)
	model.set_meta("warrior_skin_id", resolved)
	model.set_meta("warrior_skin_name", skin_name(resolved))
	if resolved == 0:
		return
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or str(mesh.name).contains("Outline"):
			continue
		var part_name := str(mesh.name)
		var color := _color_for_part(part_name, resolved)
		_apply_color(mesh, color, resolved)
		if resolved == 2 and part_name.begins_with("Horn_"):
			mesh.position.y += HORN_RAISE_3PX
	if resolved == 2:
		_add_neon_lights(model, glow_scale)


static func _color_for_part(part_name: String, skin_id: int) -> Color:
	if skin_id == 2:
		if part_name.begins_with("Horn_"):
			return NEON_HORN
		if part_name.begins_with("Eye_"):
			return NEON_EYE
		# The head panels make up most of the visible shell.  Keep them bright
		# green so the head never reads as black under the comic/menu lighting.
		if part_name in ["Front_Panel", "Back_Panel", "Left_Panel", "Right_Panel"]:
			return NEON_BODY
		if part_name in ["Torso_Step", "Torso_Tip"]:
			return NEON_PANEL
		return NEON_BODY
	if part_name.begins_with("Horn_"):
		return VOID_HORN
	if part_name.begins_with("Eye_"):
		return VOID_EYE
	if part_name in ["Front_Panel", "Back_Panel", "Left_Panel", "Right_Panel", "Torso_Step", "Torso_Tip"]:
		return VOID_PANEL
	return VOID_BODY


static func _apply_color(mesh: MeshInstance3D, color: Color, skin_id: int) -> void:
	var source_plain := mesh.get_meta("plain_material", mesh.material_override) as StandardMaterial3D
	var plain := StandardMaterial3D.new()
	if source_plain != null:
		plain = source_plain.duplicate(true) as StandardMaterial3D
	plain.resource_local_to_scene = true
	plain.albedo_texture = null
	plain.albedo_color = color
	plain.metallic = 0.08 if color != VOID_HORN and color != NEON_HORN else 0.24
	plain.roughness = 0.84 if color in [VOID_BODY, VOID_PANEL, NEON_PANEL] else 0.52
	if skin_id == 2 and color != NEON_EYE:
		plain.emission_enabled = true
		plain.emission = color
		plain.emission_energy_multiplier = 1.85 if color == NEON_BODY else (1.55 if color == NEON_PANEL else 1.70)
	elif color == VOID_HORN:
		plain.emission_enabled = true
		plain.emission = color
		plain.emission_energy_multiplier = 0.75
	elif color == VOID_EYE:
		plain.emission_enabled = true
		plain.emission = color
		plain.emission_energy_multiplier = 1.8
	else:
		plain.emission_enabled = false
	mesh.set_meta("plain_material", plain)
	if mesh.has_meta("pixel_material"):
		mesh.remove_meta("pixel_material")
	if skin_id == 2:
		mesh.set_meta("force_plain_emissive", true)

	var source_toon := mesh.get_meta("toon_material", null) as ShaderMaterial
	if source_toon != null:
		var toon := source_toon.duplicate(true) as ShaderMaterial
		toon.resource_local_to_scene = true
		toon.set_shader_parameter("use_texture", false)
		toon.set_shader_parameter("albedo_texture", null)
		toon.set_shader_parameter("base_color", color)
		mesh.set_meta("toon_material", toon)
		mesh.material_override = toon
	else:
		mesh.material_override = plain


static func _add_neon_lights(model: Node3D, glow_scale: float) -> void:
	var strength := maxf(0.0, glow_scale)
	var head_light := OmniLight3D.new()
	head_light.name = "NeonHeadGlow"
	head_light.position = Vector3(0.0, 1.02, -0.04)
	head_light.light_color = NEON_BODY
	head_light.light_energy = 1.85 * strength
	head_light.omni_range = 3.15 * maxf(0.55, strength)
	head_light.shadow_enabled = false
	model.add_child(head_light)

	var body_light := OmniLight3D.new()
	body_light.name = "NeonBodyGlow"
	body_light.position = Vector3(0.0, -0.15, 0.08)
	body_light.light_color = NEON_BODY
	body_light.light_energy = 2.35 * strength
	body_light.omni_range = 4.10 * maxf(0.55, strength)
	body_light.shadow_enabled = false
	model.add_child(body_light)

	var lower_light := OmniLight3D.new()
	lower_light.name = "NeonLowerGlow"
	lower_light.position = Vector3(0.0, -1.18, 0.10)
	lower_light.light_color = NEON_BODY
	lower_light.light_energy = 1.30 * strength
	lower_light.omni_range = 2.65 * maxf(0.55, strength)
	lower_light.shadow_enabled = false
	model.add_child(lower_light)

	var horn_light := OmniLight3D.new()
	horn_light.name = "NeonHornGlow"
	horn_light.position = Vector3(0.0, 1.48, 0.0)
	horn_light.light_color = NEON_HORN
	horn_light.light_energy = 0.90 * strength
	horn_light.omni_range = 2.20 * maxf(0.55, strength)
	horn_light.shadow_enabled = false
	model.add_child(horn_light)
