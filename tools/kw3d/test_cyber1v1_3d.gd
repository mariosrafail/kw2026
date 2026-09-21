extends SceneTree

var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	if value:
		return
	failures.append(label)
	push_error("CYBER1V1_3D_FAIL " + label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var stage: Variant = load("res://scenes/prototypes/cyber1v1_3d_test.tscn").instantiate()
	root.add_child(stage)
	for i in range(90):
		await physics_frame

	check(stage.get_node_or_null("CyberFloor") is StaticBody3D, "cyber_floor")
	check(stage.get_node_or_null("UpperLeftBridge") is StaticBody3D, "upper_left_bridge")
	check(stage.get_node_or_null("MidLeftOrange") is StaticBody3D, "mid_left_orange")
	check(stage.get_node_or_null("MidRightPerch") is StaticBody3D, "mid_right_perch")
	check(stage.get_node_or_null("LowerCenterCore") is StaticBody3D, "lower_center_core")
	check(stage.get_node_or_null("RightTower") is StaticBody3D, "right_tower")
	check(stage.get_node_or_null("CyberFrontReference") is MeshInstance3D, "source_front_layer")
	check(stage.get_node_or_null("CyberBG1") is MeshInstance3D, "source_bg1_layer")
	check(stage.get_node_or_null("CyberBG2") is MeshInstance3D, "source_bg2_layer")
	check(stage.get_node_or_null("Cyber1v1Sign") is Label3D, "cyber_sign")
	check(stage.player != null and stage.player.global_position.z > 3.0, "player_spawn")

	var cyber_static := 0
	for child in stage.get_children():
		if child is StaticBody3D and str(child.name).begins_with("Cyber"):
			cyber_static += 1
	check(cyber_static >= 6, "cyber_geometry_count")

	print("CYBER1V1_3D_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
