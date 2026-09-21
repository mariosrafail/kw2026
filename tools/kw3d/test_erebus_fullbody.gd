extends SceneTree

var stage: Node3D
var output := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):
			output = arg.trim_prefix("--qa-output=")
	assert(not output.is_empty())
	run.call_deferred()

func run() -> void:
	stage = load("res://scenes/prototypes/kw_3d_erebus_preview.tscn").instantiate()
	root.add_child(stage)
	for i in range(90):
		await physics_frame
	stage.combat.set_training_mode(true)
	stage.combat.set_roaming_enabled(false)

	var source: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/prototypes/erebus_fullbody/build_data.json")
	)
	assert(stage.player_warrior_id == "erebus")
	assert(stage.head_style.get_meta("warrior_id") == "erebus")
	assert(stage.head_style.get_meta("source_sha256") == source["sha256"])
	assert(stage.head_style.name == "ErebusFullBody")
	assert(stage.head_style.get_node_or_null("HeadRig/Head_Core") != null)
	assert(stage.head_style.get_node_or_null("HeadRig/Eye_Left_Lower") != null)

	var count := 0
	for rig in source["rigs"]:
		var node: Node3D = stage.head_style.get_node(NodePath(rig["name"]))
		for part in rig["parts"]:
			var mesh: MeshInstance3D = node.get_node(NodePath(part["name"]))
			assert(mesh.get_meta("bb_from") == v3(part["from"]))
			assert(mesh.get_meta("bb_to") == v3(part["to"]))
			assert(mesh.material_override is ShaderMaterial)
			count += 1
	assert(count == int(source["part_count"]))
	assert(count == 15)

	var belly: MeshInstance3D = stage.head_style.get_node("TorsoRig/Torso_Lower")
	assert(belly.get_meta("bb_from") == Vector3(-4.5, 16.0, -7.5))
	assert(belly.get_meta("bb_to") == Vector3(4.5, 20.0, 3.0))
	var left_sole: MeshInstance3D = stage.head_style.get_node("LeftLegRig/Foot_Left_Sole")
	assert(left_sole.get_meta("bb_from") == Vector3(-7, 1, -5))
	assert(left_sole.get_meta("bb_to") == Vector3(-2, 3, 3))

	stage.set_physics_process(false)
	for node in stage.get_children():
		if node is CanvasLayer:
			node.visible = false
	stage.camera.global_position = stage.player.global_position + Vector3(3.5, 1.30, -6.4)
	stage.camera.look_at(stage.player.global_position + Vector3(0, 0.05, 0), Vector3.UP)
	stage.camera.fov = 45.0
	await capture("erebus_fullbody_ingame")
	print("EREBUS_FULLBODY_INTEGRATION_QA_PASS parts=", count)
	stage.queue_free()
	for i in range(8):
		await process_frame
	quit(0)

func capture(label: String) -> void:
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.save_png(output.path_join(label + ".png")) == OK)
	print("RENDERED ", label)

func v3(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
