extends SceneTree

const KOSAS_SCENE := preload("res://scenes/prototypes/characters/kosas_fullbody.tscn")
const KOSAS_STYLE := preload("res://scripts/prototypes/kosas_warrior_style.gd")

var failures: Array[String] = []


func check(value: bool, label: String) -> void:
	if value:
		return
	failures.append(label)
	push_error("KOSAS_WARRIOR_FAIL " + label)


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var direct := KOSAS_SCENE.instantiate() as Node3D
	KOSAS_STYLE.apply(direct)
	check(direct.name == "KosasFullBody", "direct_name")
	check(str(direct.get_meta("warrior_id", "")) == "kosas", "direct_metadata")
	check(absf(float(direct.get_meta("capsule_height", 0.0)) - 3.43) < 0.001, "standard_capsule_contract")
	var head := direct.get_node("HeadRig") as Node3D
	var torso := direct.get_node("TorsoRig") as Node3D
	var left_leg := direct.get_node("LeftLegRig") as Node3D
	check(direct.get_node_or_null("LeftHandRig") is Node3D, "left_claw_hand")
	check(direct.get_node_or_null("RightHandRig") is Node3D, "right_claw_hand")
	check(direct.get_node_or_null("LeftHandRig/Claw_Left_Bridge") is MeshInstance3D, "left_claw_bridge")
	check(direct.get_node_or_null("RightHandRig/Claw_Right_Bridge") is MeshInstance3D, "right_claw_bridge")
	check(head.position.y > 1.20 and head.position.y < 1.35, "head_sits_lower")
	check(torso.get_node_or_null("KosasBodyBox") is MeshInstance3D, "rectangular_body_box")
	var body_box := torso.get_node_or_null("KosasBodyBox") as MeshInstance3D
	if body_box != null:
		var body_size := body_box.mesh.get_aabb().size
		check(absf(body_size.x - 0.50) < 0.001 and absf(body_size.y - 0.82) < 0.001 and absf(body_size.z - 0.32) < 0.001, "rectangular_body_dimensions")
		check(body_size.y > body_size.x * 1.5, "body_is_clearly_rectangle")
		var body_color := Color.TRANSPARENT
		if body_box.material_override is ShaderMaterial:
			body_color = (body_box.material_override as ShaderMaterial).get_shader_parameter("base_color") as Color
		elif body_box.material_override is StandardMaterial3D:
			body_color = (body_box.material_override as StandardMaterial3D).albedo_color
		check(body_color.is_equal_approx(KOSAS_STYLE.BODY_PURPLE), "body_keeps_previous_purple")
	for old_part_name in ["Torso_Upper", "Torso_Step", "Torso_Lower", "Torso_Tip", "ShaderInkOutline"]:
		var old_part := torso.get_node_or_null(old_part_name) as MeshInstance3D
		check(old_part == null or not old_part.visible, "old_%s_hidden" % old_part_name.to_lower())
	check(left_leg.scale.x <= 0.81, "small_feet")
	for leg_path in [
		"LeftLegRig/Foot_Left_Sole",
		"LeftLegRig/Foot_Left_Ankle",
		"RightLegRig/Foot_Right_Sole",
		"RightLegRig/Foot_Right_Ankle"
	]:
		var foot := direct.get_node_or_null(leg_path) as MeshInstance3D
		check(foot != null, "foot_exists_%s" % leg_path.replace("/", "_").to_lower())
		if foot != null:
			var foot_color := Color.TRANSPARENT
			if foot.material_override is ShaderMaterial:
				foot_color = (foot.material_override as ShaderMaterial).get_shader_parameter("base_color") as Color
			elif foot.material_override is StandardMaterial3D:
				foot_color = (foot.material_override as StandardMaterial3D).albedo_color
			check(foot_color.is_equal_approx(KOSAS_STYLE.BODY_PINK), "foot_is_pink_%s" % leg_path.replace("/", "_").to_lower())
	check(direct.get_node_or_null("HeadRig/KosasEye_Left") is MeshInstance3D, "left_vertical_eye")
	check(direct.get_node_or_null("HeadRig/KosasEye_Right") is MeshInstance3D, "right_vertical_eye")
	var left_eye := direct.get_node("HeadRig/KosasEye_Left") as MeshInstance3D
	var right_eye := direct.get_node("HeadRig/KosasEye_Right") as MeshInstance3D
	check(left_eye.mesh.get_aabb().size.y > left_eye.mesh.get_aabb().size.x * 2.0, "left_eye_is_vertical_pixel")
	check(right_eye.mesh.get_aabb().size.y > right_eye.mesh.get_aabb().size.x * 2.0, "right_eye_is_vertical_pixel")
	for old_eye_name in ["Eye_Left_Upper", "Eye_Left_Lower", "Eye_Right_Upper", "Eye_Right_Lower"]:
		var old_eye := direct.get_node_or_null("HeadRig/%s" % old_eye_name) as MeshInstance3D
		check(old_eye == null or not old_eye.visible, "old_%s_hidden" % old_eye_name.to_lower())
	check(direct.get_node_or_null("HeadRig/Nose_Bridge") is MeshInstance3D, "nose_bridge")
	check(direct.get_node_or_null("HeadRig/Nose_Shaft") is MeshInstance3D, "nose_shaft")
	check(direct.get_node_or_null("HeadRig/Nose_Tip") is MeshInstance3D, "nose_tip")
	var bridge := direct.get_node("HeadRig/Nose_Bridge") as MeshInstance3D
	var shaft := direct.get_node("HeadRig/Nose_Shaft") as MeshInstance3D
	var nose := direct.get_node("HeadRig/Nose_Tip") as MeshInstance3D
	check(shaft.position.y < bridge.position.y - 0.15, "nose_hangs_down")
	check(nose.position.y < shaft.position.y - 0.15, "nose_tip_at_bottom")
	check(nose.position.z > shaft.position.z + 0.05, "nose_hooks_inward")
	check(absf(bridge.mesh.get_aabb().size.x - shaft.mesh.get_aabb().size.x) < 0.001, "nose_is_one_strip_width")
	check(absf(nose.mesh.get_aabb().size.x - shaft.mesh.get_aabb().size.x) < 0.001, "nose_tip_keeps_strip_width")
	direct.free()

	var old_warrior := str(ProjectSettings.get_setting("kw3d/selected_warrior_id", "outrage"))
	ProjectSettings.set_setting("kw3d/selected_warrior_id", "kosas")
	var stage: Variant = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	for i in range(90):
		await physics_frame
	check(stage.player_warrior_id == "kosas", "gameplay_selected")
	check(stage.player.name == "Kosas3D", "gameplay_player_name")
	check(stage.left_hand_rig != null and stage.right_hand_rig != null, "gameplay_two_claw_hands")
	check(stage.head_style != null and str(stage.head_style.get_meta("warrior_id", "")) == "kosas", "gameplay_model")
	check(stage.head_style.get_node_or_null("HeadRig/Nose_Tip") is MeshInstance3D, "gameplay_nose")
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
	print("KOSAS_WARRIOR_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
