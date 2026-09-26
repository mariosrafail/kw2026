extends SceneTree

const AEVILOK_SCENE := preload("res://scenes/prototypes/characters/aevilok_fullbody.tscn")
const AEVILOK_STYLE := preload("res://scripts/prototypes/aevilok_warrior_style.gd")

var failures: Array[String] = []


func check(value: bool, label: String) -> void:
	if value:
		return
	failures.append(label)
	push_error("AEVILOK_WARRIOR_FAIL " + label)


func _mesh_color(mesh: MeshInstance3D) -> Color:
	if mesh == null:
		return Color.TRANSPARENT
	if mesh.material_override is ShaderMaterial:
		return (mesh.material_override as ShaderMaterial).get_shader_parameter("base_color") as Color
	if mesh.material_override is StandardMaterial3D:
		return (mesh.material_override as StandardMaterial3D).albedo_color
	return Color.TRANSPARENT


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var direct := AEVILOK_SCENE.instantiate() as Node3D
	AEVILOK_STYLE.apply(direct)
	check(direct.name == "AevilokFullBody", "direct_name")
	check(str(direct.get_meta("warrior_id", "")) == "aevilok", "direct_metadata")
	check(str(direct.get_meta("hitbox_profile", "")) == "standard", "standard_hitbox_profile")
	check(absf(float(direct.get_meta("capsule_height", 0.0)) - 3.43) < 0.001, "standard_capsule_contract")
	check(bool(direct.get_meta("wings_visual_only", false)), "visual_only_wing_contract")

	var head := direct.get_node("HeadRig") as Node3D
	var torso := direct.get_node("TorsoRig") as Node3D
	var left_leg := direct.get_node("LeftLegRig") as Node3D
	var right_leg := direct.get_node("RightLegRig") as Node3D
	check(direct.get_node_or_null("LeftHandRig") is Node3D, "left_claw_hand")
	check(direct.get_node_or_null("RightHandRig") is Node3D, "right_claw_hand")
	check(direct.get_node_or_null("LeftHandRig/Claw_Left_Bridge") is MeshInstance3D, "left_claw_bridge")
	check(direct.get_node_or_null("RightHandRig/Claw_Right_Bridge") is MeshInstance3D, "right_claw_bridge")
	check(head.position.y > 1.15, "floating_head_height")
	check(torso.get_node_or_null("AevilokTorsoCore") is MeshInstance3D, "compact_torso_core")
	check(torso.get_node_or_null("AevilokRibTop") is MeshInstance3D, "rib_top")
	check(torso.get_node_or_null("AevilokRibMid") is MeshInstance3D, "rib_mid")
	check(torso.get_node_or_null("AevilokRibLow") is MeshInstance3D, "rib_low")
	check(left_leg.scale.x <= 0.59 and right_leg.scale.x <= 0.59, "tiny_detached_feet")

	check(head.get_node_or_null("AevilokEye_Left") is MeshInstance3D, "left_white_eye")
	check(head.get_node_or_null("AevilokEye_Right") is MeshInstance3D, "right_white_eye")
	var left_eye := head.get_node_or_null("AevilokEye_Left") as MeshInstance3D
	var right_eye := head.get_node_or_null("AevilokEye_Right") as MeshInstance3D
	for eye in [left_eye, right_eye]:
		check(eye != null and _mesh_color(eye).is_equal_approx(AEVILOK_STYLE.EYE_WHITE), "eye_is_white")
		if eye != null:
			var eye_size: Vector3 = eye.mesh.get_aabb().size
			check(absf(eye_size.y - eye_size.x * 2.0) < 0.001, "eye_is_two_pixels_high")
	for old_eye_name in ["Eye_Left_Upper", "Eye_Left_Lower", "Eye_Right_Upper", "Eye_Right_Lower"]:
		var old_eye := head.get_node_or_null(old_eye_name) as MeshInstance3D
		check(old_eye == null or not old_eye.visible, "old_%s_hidden" % old_eye_name.to_lower())
	check(head.get_node_or_null("AevilokBrow_Left") is MeshInstance3D, "evil_left_brow")
	check(head.get_node_or_null("AevilokBrow_Right") is MeshInstance3D, "evil_right_brow")
	check(head.get_node_or_null("AevilokJaw_Left") is MeshInstance3D, "angular_left_jaw")
	check(head.get_node_or_null("AevilokJaw_Right") is MeshInstance3D, "angular_right_jaw")
	var chin_base := head.get_node_or_null("AevilokChin_Base") as MeshInstance3D
	var chin_point := head.get_node_or_null("AevilokChin_Point") as MeshInstance3D
	check(chin_base != null and chin_point != null, "pointed_chin_parts")
	if chin_base != null and chin_point != null:
		check(chin_point.position.y < chin_base.position.y - 0.08, "chin_extends_downward")
		check(chin_point.mesh.get_aabb().size.x < chin_base.mesh.get_aabb().size.x * 0.55, "chin_tapers_to_point")

	var wing_root := torso.get_node_or_null("AevilokWingRoot") as Node3D
	check(wing_root != null, "wing_root")
	if wing_root != null:
		check(bool(wing_root.get_meta("visual_only", false)), "wing_root_visual_only")
		check(not bool(wing_root.get_meta("gameplay_hitbox", true)), "wing_root_not_hitbox")
		check(wing_root.find_children("*", "CollisionShape3D", true, false).is_empty(), "wings_have_no_collision_shapes")
		check(wing_root.get_child_count() >= 30, "elaborate_layered_wings")
		var left_tip := wing_root.get_node_or_null("AevilokWingLeft_TipMid") as MeshInstance3D
		var right_tip := wing_root.get_node_or_null("AevilokWingRight_TipMid") as MeshInstance3D
		check(left_tip != null and left_tip.position.x < -2.6, "wide_left_wing")
		check(right_tip != null and right_tip.position.x > 2.6, "wide_right_wing")
		var left_membrane := wing_root.get_node_or_null("AevilokWingLeft_MembraneInner") as MeshInstance3D
		var right_membrane := wing_root.get_node_or_null("AevilokWingRight_MembraneInner") as MeshInstance3D
		check(left_membrane != null and _mesh_color(left_membrane).is_equal_approx(AEVILOK_STYLE.WING_CRIMSON), "left_crimson_membrane")
		check(right_membrane != null and _mesh_color(right_membrane).is_equal_approx(AEVILOK_STYLE.WING_CRIMSON), "right_crimson_membrane")
		if left_tip != null and right_tip != null:
			var rest_left: Transform3D = left_tip.transform
			var rest_right: Transform3D = right_tip.transform
			for frame in range(24):
				AEVILOK_STYLE.animate_wings(direct, 1.0 / 60.0, frame / 60.0, frame * 0.32, 7.5, 0.0, true)
			var walk_left: Transform3D = left_tip.transform
			var walk_right: Transform3D = right_tip.transform
			check(not walk_left.is_equal_approx(rest_left), "walking_animates_left_wing")
			check(not walk_right.is_equal_approx(rest_right), "walking_animates_right_wing")
			check(signf(walk_left.origin.x) == -1.0 and signf(walk_right.origin.x) == 1.0, "walking_keeps_mirrored_span")
			for frame in range(24):
				AEVILOK_STYLE.animate_wings(direct, 1.0 / 60.0, 1.0 + frame / 60.0, frame * 0.20, 3.0, 7.0, false)
			var jump_left: Transform3D = left_tip.transform
			check(not jump_left.is_equal_approx(walk_left), "jump_has_distinct_wing_animation")
			for frame in range(24):
				AEVILOK_STYLE.animate_wings(direct, 1.0 / 60.0, 2.0 + frame / 60.0, frame * 0.20, 3.0, -7.0, false)
			var fall_left: Transform3D = left_tip.transform
			check(not fall_left.is_equal_approx(jump_left), "fall_uses_glide_animation")
	direct.free()

	var old_warrior := str(ProjectSettings.get_setting("kw3d/selected_warrior_id", "outrage"))
	ProjectSettings.set_setting("kw3d/selected_warrior_id", "aevilok")
	var stage: Variant = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	for i in range(90):
		await physics_frame
	check(stage.player_warrior_id == "aevilok", "gameplay_selected")
	check(stage.player.name == "Aevilok3D", "gameplay_player_name")
	check(stage.head_style != null and str(stage.head_style.get_meta("warrior_id", "")) == "aevilok", "gameplay_model")
	check(stage.head_style.get_node_or_null("TorsoRig/AevilokWingRoot") is Node3D, "gameplay_wings")
	check(stage.left_hand_rig != null and stage.right_hand_rig != null, "gameplay_two_claw_hands")
	var collision := stage.player.get_child(0) as CollisionShape3D
	check(collision != null and collision.shape is CapsuleShape3D, "gameplay_capsule")
	if collision != null and collision.shape is CapsuleShape3D:
		var capsule := collision.shape as CapsuleShape3D
		check(absf(capsule.radius - 0.52) < 0.001, "same_capsule_radius")
		check(absf(capsule.height - 3.43) < 0.001, "same_capsule_height")
	stage.queue_free()
	for i in range(6):
		await process_frame
	ProjectSettings.set_setting("kw3d/selected_warrior_id", old_warrior)
	print("AEVILOK_WARRIOR_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
