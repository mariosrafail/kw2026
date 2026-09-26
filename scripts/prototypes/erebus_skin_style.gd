extends RefCounted
## Small runtime skin layer for the authored Erebus fullbody.
## The photo skin adds a real textured quad to the front of the head without
## modifying the baked Blockbench geometry or UVs.

const HAND_STYLE := preload("res://scripts/prototypes/warrior_hand_style.gd")

const SKIN_NAMES := [
	"CLASSIC",
	"PHOTO FACE",
]

const FACE_TEXTURE_PATH := "res://assets/warriors/erebus/custom_face_photo.webp"
const FACE_TEXTURE := preload("res://assets/warriors/erebus/custom_face_photo.webp")
const FACE_PANEL_NAME := "PhotoFacePanel"
const EYE_PARTS := [
	"Eye_Left_Upper",
	"Eye_Left_Lower",
	"Eye_Right_Upper",
	"Eye_Right_Lower",
]


static func skin_count() -> int:
	return SKIN_NAMES.size()


static func skin_name(skin_id: int) -> String:
	return SKIN_NAMES[clampi(skin_id, 0, SKIN_NAMES.size() - 1)]


static func skin_accent(skin_id: int) -> Color:
	return Color("f1b08a") if clampi(skin_id, 0, SKIN_NAMES.size() - 1) == 1 else Color("df7126")


static func apply(model: Node3D, skin_id: int) -> void:
	var resolved := clampi(skin_id, 0, SKIN_NAMES.size() - 1)
	HAND_STYLE.ensure_hands(model)
	model.set_meta("warrior_skin_id", resolved)
	model.set_meta("warrior_skin_name", skin_name(resolved))
	_remove_face_panel(model)
	_set_authored_eyes_visible(model, true)
	if resolved != 1:
		return
	_set_authored_eyes_visible(model, false)
	_add_photo_face(model)


static func _remove_face_panel(model: Node3D) -> void:
	var existing := model.get_node_or_null("HeadRig/%s" % FACE_PANEL_NAME)
	if existing != null:
		existing.get_parent().remove_child(existing)
		existing.free()


static func _set_authored_eyes_visible(model: Node3D, visible: bool) -> void:
	for part_name in EYE_PARTS:
		var eye := model.get_node_or_null("HeadRig/%s" % part_name) as MeshInstance3D
		if eye != null:
			eye.visible = visible


static func _add_photo_face(model: Node3D) -> void:
	var head_rig := model.get_node_or_null("HeadRig") as Node3D
	if head_rig == null:
		return
	var panel := MeshInstance3D.new()
	panel.name = FACE_PANEL_NAME
	var quad := QuadMesh.new()
	# Keep the source photo's portrait proportions instead of stretching it to
	# the very wide voxel head.  It sits just outside the authored front face.
	quad.size = Vector2(0.615, 0.630)
	panel.mesh = quad
	panel.position = Vector3(0.0, 0.0, -0.371)
	panel.rotation_degrees.y = 180.0
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.albedo_texture = FACE_TEXTURE
	material.albedo_color = Color.WHITE
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.roughness = 1.0
	panel.material_override = material
	panel.set_meta("erebus_photo_face", true)
	panel.set_meta("erebus_face_texture_path", FACE_TEXTURE_PATH)
	head_rig.add_child(panel)
