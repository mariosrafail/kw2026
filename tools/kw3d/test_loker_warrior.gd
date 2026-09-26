extends SceneTree

const LOKER_SCENE := preload("res://scenes/prototypes/characters/loker_fullbody.tscn")
const LOKER_STYLE := preload("res://scripts/prototypes/loker_warrior_style.gd")

var failures: Array[String] = []


func check(value: bool, label: String) -> void:
	if value:
		return
	failures.append(label)
	push_error("LOKER_WARRIOR_FAIL " + label)


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var direct := LOKER_SCENE.instantiate() as Node3D
	LOKER_STYLE.apply(direct)
	check(direct.name == "LokerFullBody", "direct_name")
	check(str(direct.get_meta("warrior_id", "")) == "loker", "direct_metadata")
	check(str(direct.get_meta("hitbox_profile", "")) == "standard", "standard_hitbox_profile")
	check(absf(float(direct.get_meta("capsule_height", 0.0)) - 3.43) < 0.001, "standard_capsule_contract")
	check(bool(direct.get_meta("long_head_visual_only", false)), "long_head_visual_only")
	check(direct.get_node_or_null("LeftHandRig") is Node3D, "left_claw_hand")
	check(direct.get_node_or_null("RightHandRig") is Node3D, "right_claw_hand")
	var core := direct.get_node_or_null("HeadRig/LokerHeadCore") as MeshInstance3D
	var snout_mid := direct.get_node_or_null("HeadRig/LokerSnoutMid") as MeshInstance3D
	var snout_tip := direct.get_node_or_null("HeadRig/LokerSnoutTip") as MeshInstance3D
	check(core != null and snout_mid != null and snout_tip != null, "long_head_parts")
	if core != null and snout_mid != null and snout_tip != null:
		check(snout_tip.position.z < snout_mid.position.z and snout_mid.position.z < core.position.z, "snout_extends_forward")
		check(absf(snout_tip.position.z - core.position.z) > 0.70, "snout_is_long")
	check(direct.get_node_or_null("HeadRig/LokerEye_Left") is MeshInstance3D, "left_black_eye")
	check(direct.get_node_or_null("HeadRig/LokerEye_Right") is MeshInstance3D, "right_black_eye")
	check(direct.get_node_or_null("TorsoRig/LokerTorso") is MeshInstance3D, "green_torso")
	direct.free()

	var old := str(ProjectSettings.get_setting("kw3d/selected_warrior_id", "outrage"))
	ProjectSettings.set_setting("kw3d/selected_warrior_id", "loker")
	var stage: Variant = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	for i in range(90):
		await physics_frame
	check(stage.player_warrior_id == "loker", "gameplay_selected")
	check(stage.player.name == "Loker3D", "gameplay_player_name")
	check(stage.head_style != null and str(stage.head_style.get_meta("warrior_id", "")) == "loker", "gameplay_model")
	check(stage.head_style.get_node_or_null("HeadRig/LokerSnoutTip") is MeshInstance3D, "gameplay_long_head")
	check(stage.left_hand_rig != null and stage.right_hand_rig != null, "gameplay_two_hands")
	stage.queue_free()
	for i in range(6):
		await process_frame
	ProjectSettings.set_setting("kw3d/selected_warrior_id", old)
	print("LOKER_WARRIOR_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
