extends RefCounted
## 3D Loker treatment based on the existing authored fullbody rig.
## The long green head is visual-only; gameplay keeps the standard warrior capsule.

const HAND_STYLE := preload("res://scripts/prototypes/warrior_hand_style.gd")

const GREEN := Color("39d143")
const GREEN_LIGHT := Color("58eb5f")
const GREEN_DARK := Color("197b2b")
const GREEN_SHADOW := Color("105622")
const EYE_BLACK := Color("050807")


static func apply(model: Node3D) -> void:
	if model == null:
		return
	if bool(model.get_meta("loker_style_applied", false)):
		return
	model.set_meta("loker_style_applied", true)
	model.set_meta("warrior_id", "loker")
	model.set_meta("warrior_display_name", "Loker")
	model.set_meta("capsule_height", 3.43)
	model.set_meta("hitbox_profile", "standard")
	model.set_meta("long_head_visual_only", true)
	HAND_STYLE.ensure_hands(model)

	var head := model.get_node_or_null("HeadRig") as Node3D
	var torso := model.get_node_or_null("TorsoRig") as Node3D
	var left_leg := model.get_node_or_null("LeftLegRig") as Node3D
	var right_leg := model.get_node_or_null("RightLegRig") as Node3D
	if head != null:
		head.position += Vector3(0.0, 0.18, -0.13)
		head.scale = Vector3.ONE
		_build_long_head(head)
	if torso != null:
		torso.position += Vector3(0.0, -0.10, 0.02)
		torso.scale = Vector3.ONE
		_build_body(torso)
	if left_leg != null:
		left_leg.position += Vector3(0.12, -0.18, 0.01)
		left_leg.scale = Vector3.ONE * 0.62
	if right_leg != null:
		right_leg.position += Vector3(-0.12, -0.18, 0.01)
		right_leg.scale = Vector3.ONE * 0.62

	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or str(mesh.name).contains("Outline"):
			continue
		_apply_color(mesh, _color_for_part(str(mesh.name)))


static func _build_long_head(head: Node3D) -> void:
	if head.get_node_or_null("LokerHeadCore") != null:
		return
	var source := head.get_node_or_null("Head_Core") as MeshInstance3D
	if source == null:
		return
	for part_name in [
		"Head_Core", "Head_Top_Cap", "Head_Bottom_Cap",
		"Eye_Left_Upper", "Eye_Left_Lower", "Eye_Right_Upper", "Eye_Right_Lower",
		"ShaderInkOutline"
	]:
		var part := head.get_node_or_null(part_name) as MeshInstance3D
		if part != null:
			part.visible = false
	# Long lizard/crocodile silhouette: a compact skull at the back and a long,
	# low snout extending forward along -Z.
	_add_box(head, "LokerHeadCore", Vector3(0.0, 0.02, -0.18), Vector3(0.82, 0.48, 0.72), source)
	_add_box(head, "LokerSnoutMid", Vector3(0.0, -0.015, -0.65), Vector3(0.72, 0.38, 0.52), source)
	_add_box(head, "LokerSnoutTip", Vector3(0.0, -0.045, -0.98), Vector3(0.58, 0.30, 0.34), source)
	_add_box(head, "LokerHeadTop", Vector3(0.0, 0.27, -0.27), Vector3(0.72, 0.09, 0.64), source)
	_add_box(head, "LokerEye_Left", Vector3(-0.27, 0.10, -0.72), Vector3(0.12, 0.13, 0.06), source)
	_add_box(head, "LokerEye_Right", Vector3(0.27, 0.10, -0.72), Vector3(0.12, 0.13, 0.06), source)
	_add_box(head, "LokerMouth", Vector3(0.0, -0.15, -1.155), Vector3(0.38, 0.055, 0.035), source)


static func _build_body(torso: Node3D) -> void:
	if torso.get_node_or_null("LokerTorso") != null:
		return
	var source := torso.get_node_or_null("Torso_Upper") as MeshInstance3D
	if source == null:
		return
	for part_name in ["Torso_Upper", "Torso_Step", "Torso_Lower", "Torso_Tip", "ShaderInkOutline"]:
		var part := torso.get_node_or_null(part_name) as MeshInstance3D
		if part != null:
			part.visible = false
	_add_box(torso, "LokerTorso", Vector3(0.0, 0.02, 0.0), Vector3(0.55, 0.82, 0.38), source)
	_add_box(torso, "LokerLowerBody", Vector3(0.0, -0.47, 0.02), Vector3(0.32, 0.28, 0.28), source)
	_add_box(torso, "LokerSpineStripe", Vector3(0.0, -0.12, 0.205), Vector3(0.17, 0.62, 0.045), source)


static func _add_box(parent: Node3D, part_name: String, pos: Vector3, size: Vector3, source: MeshInstance3D) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = part_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var source_plain: StandardMaterial3D = null
	if source.has_meta("plain_material") and source.get_meta("plain_material") is StandardMaterial3D:
		source_plain = source.get_meta("plain_material") as StandardMaterial3D
	elif source.material_override is StandardMaterial3D:
		source_plain = source.material_override as StandardMaterial3D
	if source_plain != null:
		var plain := source_plain.duplicate(true) as StandardMaterial3D
		plain.resource_local_to_scene = true
		mesh.set_meta("plain_material", plain)
		mesh.material_override = plain
	var source_toon: ShaderMaterial = null
	if source.has_meta("toon_material") and source.get_meta("toon_material") is ShaderMaterial:
		source_toon = source.get_meta("toon_material") as ShaderMaterial
	if source_toon != null:
		var toon := source_toon.duplicate(true) as ShaderMaterial
		toon.resource_local_to_scene = true
		mesh.set_meta("toon_material", toon)
		mesh.material_override = toon
	parent.add_child(mesh)
	return mesh


static func _color_for_part(part_name: String) -> Color:
	if part_name.begins_with("LokerEye_") or part_name == "LokerMouth":
		return EYE_BLACK
	if part_name == "LokerHeadTop":
		return GREEN_LIGHT
	if part_name == "LokerSpineStripe":
		return GREEN_DARK
	if part_name == "LokerLowerBody":
		return GREEN_SHADOW
	if part_name.begins_with("Foot_"):
		return GREEN_DARK
	if part_name.begins_with("Claw_"):
		return GREEN
	if part_name.begins_with("Loker"):
		return GREEN
	return GREEN


static func _apply_color(mesh: MeshInstance3D, color: Color) -> void:
	var source_plain: StandardMaterial3D = null
	if mesh.has_meta("plain_material") and mesh.get_meta("plain_material") is StandardMaterial3D:
		source_plain = mesh.get_meta("plain_material") as StandardMaterial3D
	elif mesh.material_override is StandardMaterial3D:
		source_plain = mesh.material_override as StandardMaterial3D
	var plain := StandardMaterial3D.new()
	if source_plain != null:
		plain = source_plain.duplicate(true) as StandardMaterial3D
	plain.resource_local_to_scene = true
	plain.albedo_texture = null
	plain.albedo_color = color
	plain.metallic = 0.04
	plain.roughness = 0.68
	mesh.set_meta("plain_material", plain)
	var source_toon: ShaderMaterial = null
	if mesh.has_meta("toon_material") and mesh.get_meta("toon_material") is ShaderMaterial:
		source_toon = mesh.get_meta("toon_material") as ShaderMaterial
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
