extends RefCounted
## Visual-only Kosas treatment layered over the stable authored fullbody rig.
## Gameplay collision/hurtbox sizing intentionally stays on the standard warrior profile.

const HAND_STYLE := preload("res://scripts/prototypes/warrior_hand_style.gd")

const BODY_PINK := Color("f044d7")
const BODY_PINK_LIGHT := Color("ff78e6")
const BODY_PURPLE := Color("aa2bd0")
const BODY_PURPLE_DARK := Color("6d1598")
const NOSE_PINK := Color("ff58dc")
const NOSE_LIGHT := Color("ff9bec")
const EYE_BLACK := Color("08050b")
const FOOT_BLACK := Color("07050a")


static func apply(model: Node3D) -> void:
	if model == null:
		return
	if bool(model.get_meta("kosas_style_applied", false)):
		return
	model.set_meta("kosas_style_applied", true)
	model.set_meta("warrior_id", "kosas")
	model.set_meta("warrior_display_name", "Kosas")
	# Keep exactly the same capsule-height contract as the other fullbody warriors.
	model.set_meta("capsule_height", 3.43)
	model.set_meta("hitbox_profile", "standard")
	HAND_STYLE.ensure_hands(model)

	var head := model.get_node_or_null("HeadRig") as Node3D
	var torso := model.get_node_or_null("TorsoRig") as Node3D
	var left_leg := model.get_node_or_null("LeftLegRig") as Node3D
	var right_leg := model.get_node_or_null("RightLegRig") as Node3D
	if head != null:
		# Keep the wide Kosas head, but sit it a little lower than the first pass.
		head.position += Vector3(0.0, 0.25, -0.02)
		head.scale = Vector3(1.22, 0.80, 0.92)
		_add_nose(head)
		_build_vertical_eyes(head)
	if torso != null:
		# Kosas body is one simple rectangular box, matching the reference silhouette.
		torso.position += Vector3(0.0, -0.10, 0.02)
		torso.scale = Vector3.ONE
		_build_rect_body(torso)
	if left_leg != null:
		left_leg.position += Vector3(0.03, -0.16, 0.0)
		left_leg.scale = Vector3.ONE * 0.80
	if right_leg != null:
		right_leg.position += Vector3(-0.03, -0.16, 0.0)
		right_leg.scale = Vector3.ONE * 0.80

	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or str(mesh.name).contains("Outline"):
			continue
		_apply_color(mesh, _color_for_part(str(mesh.name)))


static func _build_rect_body(torso: Node3D) -> void:
	if torso.get_node_or_null("KosasBodyBox") != null:
		return
	var source := torso.get_node_or_null("Torso_Upper") as MeshInstance3D
	if source == null:
		return
	# Hide the authored stepped torso so only the single Kosas rectangle remains.
	for part_name in ["Torso_Upper", "Torso_Step", "Torso_Lower", "Torso_Tip", "ShaderInkOutline"]:
		var part := torso.get_node_or_null(part_name) as MeshInstance3D
		if part != null:
			part.visible = false
	_add_box(torso, "KosasBodyBox", Vector3(0.0, -0.10, 0.0), Vector3(0.50, 0.82, 0.32), source)


static func _build_vertical_eyes(head: Node3D) -> void:
	if head.get_node_or_null("KosasEye_Left") != null:
		return
	var source := head.get_node_or_null("Head_Core") as MeshInstance3D
	if source == null:
		return
	# Replace the four authored eye chunks with two clean vertical pixel bars.
	for part_name in ["Eye_Left_Upper", "Eye_Left_Lower", "Eye_Right_Upper", "Eye_Right_Lower"]:
		var old_eye := head.get_node_or_null(part_name) as MeshInstance3D
		if old_eye != null:
			old_eye.visible = false
	_add_box(head, "KosasEye_Left", Vector3(-0.22, -0.07, -0.385), Vector3(0.09, 0.22, 0.07), source)
	_add_box(head, "KosasEye_Right", Vector3(0.22, -0.07, -0.385), Vector3(0.09, 0.22, 0.07), source)


static func _add_nose(head: Node3D) -> void:
	if head.get_node_or_null("Nose_Bridge") != null:
		return
	var source := head.get_node_or_null("Head_Core") as MeshInstance3D
	if source == null:
		return
	# Thin J-shaped strip like the pixel reference: a short connector comes out
	# from the face, one narrow shaft hangs straight down, then the bottom hooks
	# back inward toward the face.
	_add_box(head, "Nose_Bridge", Vector3(0.0, -0.08, -0.41), Vector3(0.14, 0.14, 0.24), source)
	_add_box(head, "Nose_Shaft", Vector3(0.0, -0.30, -0.53), Vector3(0.14, 0.48, 0.14), source)
	_add_box(head, "Nose_Tip", Vector3(0.0, -0.54, -0.42), Vector3(0.14, 0.14, 0.22), source)


static func _add_box(parent: Node3D, part_name: String, pos: Vector3, size: Vector3, source: MeshInstance3D, rot_degrees: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = part_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.rotation_degrees = rot_degrees
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
	parent.add_child(mesh)
	return mesh


static func _color_for_part(part_name: String) -> Color:
	if part_name.begins_with("Eye_"):
		return EYE_BLACK
	if part_name.begins_with("Nose_"):
		return NOSE_PINK
	if part_name.begins_with("KosasEye_"):
		return EYE_BLACK
	if part_name == "KosasBodyBox":
		return BODY_PURPLE
	if part_name == "Head_Top_Cap":
		return BODY_PINK_LIGHT
	if part_name == "Head_Bottom_Cap":
		return BODY_PURPLE_DARK
	if part_name == "Torso_Upper":
		return BODY_PINK
	if part_name in ["Torso_Step", "Torso_Lower"]:
		return BODY_PURPLE
	if part_name == "Torso_Tip":
		return BODY_PURPLE_DARK
	if part_name.begins_with("Foot_"):
		return BODY_PINK
	return BODY_PINK


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
