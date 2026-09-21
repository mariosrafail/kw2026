extends RefCounted
## Runtime/material-only skins for the authored Outrage fullbody.
## Geometry, pivots, animation rigs and source Blockbench files stay untouched.

const SKIN_NAMES := [
	"CLASSIC",
	"VOID",
]

const VOID_BODY := Color("292a31")
const VOID_PANEL := Color("17181d")
const VOID_HORN := Color("b31cff")
const VOID_EYE := Color("ffffff")


static func skin_count() -> int:
	return SKIN_NAMES.size()


static func skin_name(skin_id: int) -> String:
	return SKIN_NAMES[clampi(skin_id, 0, SKIN_NAMES.size() - 1)]


static func skin_accent(skin_id: int) -> Color:
	return VOID_HORN if clampi(skin_id, 0, SKIN_NAMES.size() - 1) == 1 else Color("9b2635")


static func main_color(skin_id: int) -> Color:
	return VOID_BODY if clampi(skin_id, 0, SKIN_NAMES.size() - 1) == 1 else Color("8f1d27")


static func apply(model: Node3D, skin_id: int) -> void:
	var resolved := clampi(skin_id, 0, SKIN_NAMES.size() - 1)
	model.set_meta("warrior_skin_id", resolved)
	model.set_meta("warrior_skin_name", skin_name(resolved))
	if resolved == 0:
		return
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or str(mesh.name).contains("Outline"):
			continue
		var color := _color_for_part(str(mesh.name))
		_apply_color(mesh, color)


static func _color_for_part(part_name: String) -> Color:
	if part_name.begins_with("Horn_"):
		return VOID_HORN
	if part_name.begins_with("Eye_"):
		return VOID_EYE
	if part_name in ["Front_Panel", "Back_Panel", "Left_Panel", "Right_Panel", "Torso_Step", "Torso_Tip"]:
		return VOID_PANEL
	return VOID_BODY


static func _apply_color(mesh: MeshInstance3D, color: Color) -> void:
	var source_plain := mesh.get_meta("plain_material", mesh.material_override) as StandardMaterial3D
	var plain := StandardMaterial3D.new()
	if source_plain != null:
		plain = source_plain.duplicate(true) as StandardMaterial3D
	plain.resource_local_to_scene = true
	plain.albedo_texture = null
	plain.albedo_color = color
	plain.metallic = 0.08 if color != VOID_HORN else 0.24
	plain.roughness = 0.84 if color == VOID_BODY or color == VOID_PANEL else 0.56
	if color == VOID_HORN:
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
