extends RefCounted
## Runtime skins plus the detached blocky hand rigs used by Outrage.
## The source Blockbench body stays untouched; small hands are added to every 3D instance.

const HAND_STYLE := preload("res://scripts/prototypes/warrior_hand_style.gd")

const SKIN_NAMES := [
	"CLASSIC",
	"VOID",
	"NEON",
	"HEART",
	"VOLT",
]

const VOID_BODY := Color("292a31")
const VOID_PANEL := Color("17181d")
const VOID_HORN := Color("b31cff")
const VOID_EYE := Color("ffffff")
const NEON_BODY := Color("20ff00")
const NEON_PANEL := Color("12b800")
const NEON_HORN := Color("f4ff00")
const NEON_EYE := Color("050505")
const HEART_BODY := Color("a126ff")
const HEART_PANEL := Color("58118a")
const HEART_HORN := Color("ff2948")
const HEART_EYE := Color("050505")
const VOLT_BODY := Color("005bff")
const VOLT_PANEL := Color("0036b8")
const VOLT_CORE := Color("00c2ff")
const VOLT_HORN := Color("ffe600")
const VOLT_EYE := Color("050505")
const HORN_RAISE_3PX := 0.21

const HEART_HORN_POSITIONS := {
	"Horn_Left_Root": Vector3(-0.56, 0.10, 0.0),
	"Horn_Left_Lower": Vector3(-0.72, 0.27, 0.0),
	"Horn_Left_Middle": Vector3(-0.72, 0.48, 0.0),
	"Horn_Left_Upper": Vector3(-0.48, 0.69, 0.0),
	"Horn_Left_Tip": Vector3(-0.07, 0.57, 0.0),
	"Horn_Right_Root": Vector3(0.56, 0.10, 0.0),
	"Horn_Right_Lower": Vector3(0.72, 0.27, 0.0),
	"Horn_Right_Middle": Vector3(0.72, 0.48, 0.0),
	"Horn_Right_Upper": Vector3(0.48, 0.69, 0.0),
	"Horn_Right_Tip": Vector3(0.07, 0.57, 0.0),
}

const VOLT_HORN_POSITIONS := {
	"Horn_Left_Root": Vector3(-0.66, 0.07, 0.0),
	"Horn_Left_Lower": Vector3(-0.66, 0.21, 0.0),
	"Horn_Left_Middle": Vector3(-0.66, 0.35, 0.0),
	"Horn_Left_Upper": Vector3(-0.66, 0.49, 0.0),
	"Horn_Left_Tip": Vector3(-0.66, 0.63, 0.0),
	"Horn_Right_Root": Vector3(0.66, 0.07, 0.0),
	"Horn_Right_Lower": Vector3(0.66, 0.21, 0.0),
	"Horn_Right_Middle": Vector3(0.66, 0.35, 0.0),
	"Horn_Right_Upper": Vector3(0.66, 0.49, 0.0),
	"Horn_Right_Tip": Vector3(0.66, 0.63, 0.0),
}


static func skin_count() -> int:
	return SKIN_NAMES.size()


static func skin_name(skin_id: int) -> String:
	return SKIN_NAMES[clampi(skin_id, 0, SKIN_NAMES.size() - 1)]


static func skin_accent(skin_id: int) -> Color:
	match clampi(skin_id, 0, SKIN_NAMES.size() - 1):
		1: return VOID_HORN
		2: return NEON_HORN
		3: return HEART_HORN
		4: return VOLT_HORN
		_: return Color("9b2635")


static func main_color(skin_id: int) -> Color:
	match clampi(skin_id, 0, SKIN_NAMES.size() - 1):
		1: return VOID_BODY
		2: return NEON_BODY
		3: return HEART_BODY
		4: return VOLT_BODY
		_: return Color("8f1d27")


static func apply(model: Node3D, skin_id: int, glow_scale: float = 1.0) -> void:
	var resolved := clampi(skin_id, 0, SKIN_NAMES.size() - 1)
	HAND_STYLE.ensure_hands(model)
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
		elif resolved == 3 and part_name.begins_with("Horn_"):
			_apply_heart_horn_shape(mesh, part_name)
		elif resolved == 4 and part_name.begins_with("Horn_"):
			_apply_volt_horn_shape(mesh, part_name)
	if resolved == 2:
		_add_neon_lights(model, glow_scale)
	elif resolved == 4:
		_add_volt_lights(model, glow_scale)


static func _color_for_part(part_name: String, skin_id: int) -> Color:
	if skin_id == 4:
		if part_name.begins_with("Horn_"):
			return VOLT_HORN
		if part_name.begins_with("Eye_"):
			return VOLT_EYE
		if part_name == "Front_Panel":
			return VOLT_CORE
		if part_name in ["Back_Panel", "Left_Panel", "Right_Panel", "Torso_Step", "Torso_Tip"] or part_name.begins_with("Foot_"):
			return VOLT_PANEL
		return VOLT_BODY
	if skin_id == 3:
		if part_name.begins_with("Horn_"):
			return HEART_HORN
		if part_name.begins_with("Eye_"):
			return HEART_EYE
		if part_name in ["Back_Panel", "Left_Panel", "Right_Panel", "Torso_Step", "Torso_Tip"]:
			return HEART_PANEL
		if part_name.begins_with("Foot_"):
			return HEART_PANEL
		return HEART_BODY
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
	plain.metallic = 0.08 if color not in [VOID_HORN, NEON_HORN, HEART_HORN, VOLT_HORN] else 0.24
	plain.roughness = 0.84 if color in [VOID_BODY, VOID_PANEL, NEON_PANEL, HEART_PANEL, VOLT_PANEL] else 0.52
	if skin_id == 2 and color != NEON_EYE:
		plain.emission_enabled = true
		plain.emission = color
		plain.emission_energy_multiplier = 1.85 if color == NEON_BODY else (1.55 if color == NEON_PANEL else 1.70)
	elif skin_id == 4 and color != VOLT_EYE:
		plain.emission_enabled = true
		plain.emission = color
		if color == VOLT_CORE:
			plain.emission_energy_multiplier = 3.0
		elif color == VOLT_BODY:
			plain.emission_energy_multiplier = 2.35
		elif color == VOLT_PANEL:
			plain.emission_energy_multiplier = 1.85
		else:
			plain.emission_energy_multiplier = 1.55
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
	if skin_id in [2, 4]:
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


static func _apply_heart_horn_shape(mesh: MeshInstance3D, part_name: String) -> void:
	if not HEART_HORN_POSITIONS.has(part_name):
		return
	mesh.position = HEART_HORN_POSITIONS[part_name]
	# Keep the authored blocky look, but lengthen the inner tips so both horn
	# halves visibly join into the centre notch of a heart above the head.
	if part_name.ends_with("_Tip"):
		mesh.scale = Vector3(2.0, 1.0, 1.0)
	elif part_name.ends_with("_Upper"):
		mesh.scale = Vector3(1.35, 1.0, 1.0)


static func _apply_volt_horn_shape(mesh: MeshInstance3D, part_name: String) -> void:
	if not VOLT_HORN_POSITIONS.has(part_name):
		return
	mesh.position = VOLT_HORN_POSITIONS[part_name]
	mesh.scale = Vector3.ONE


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


static func _add_volt_lights(model: Node3D, glow_scale: float) -> void:
	var strength := maxf(0.0, glow_scale)
	var head_light := OmniLight3D.new()
	head_light.name = "VoltHeadGlow"
	head_light.position = Vector3(0.0, 1.02, -0.04)
	head_light.light_color = VOLT_CORE
	head_light.light_energy = 2.20 * strength
	head_light.omni_range = 3.35 * maxf(0.55, strength)
	head_light.shadow_enabled = false
	model.add_child(head_light)

	var body_light := OmniLight3D.new()
	body_light.name = "VoltBodyGlow"
	body_light.position = Vector3(0.0, -0.14, 0.08)
	body_light.light_color = VOLT_BODY
	body_light.light_energy = 2.70 * strength
	body_light.omni_range = 4.35 * maxf(0.55, strength)
	body_light.shadow_enabled = false
	model.add_child(body_light)

	var lower_light := OmniLight3D.new()
	lower_light.name = "VoltLowerGlow"
	lower_light.position = Vector3(0.0, -1.18, 0.10)
	lower_light.light_color = VOLT_BODY
	lower_light.light_energy = 1.55 * strength
	lower_light.omni_range = 2.80 * maxf(0.55, strength)
	lower_light.shadow_enabled = false
	model.add_child(lower_light)

	var horn_light := OmniLight3D.new()
	horn_light.name = "VoltHornGlow"
	horn_light.position = Vector3(0.0, 1.45, 0.0)
	horn_light.light_color = VOLT_HORN
	horn_light.light_energy = 0.95 * strength
	horn_light.omni_range = 2.15 * maxf(0.55, strength)
	horn_light.shadow_enabled = false
	model.add_child(horn_light)
