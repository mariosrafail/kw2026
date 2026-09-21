extends SceneTree
var stage: Node3D
var output := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	assert(not output.is_empty())
	run.call_deferred()
func run() -> void:
	stage = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	stage.use_menu_warrior_selection = false
	stage.player_warrior_id = "outrage"
	stage.use_menu_weapon_skin_selection = false
	stage.ak_skin_id = 0
	stage.kar_skin_id = 0
	root.add_child(stage)
	stage.combat.set_training_mode(true)
	# Freeze target travel for deterministic aim/terrain fixtures; roaming has its own test.
	stage.combat.set_roaming_enabled(false)
	for i in range(90): await physics_frame
	assert(stage.get_node_or_null("EditorPreview") == null, "Preview must not duplicate the game")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/prototypes/outrage_fullbody/build_data.json"))
	assert(stage.head_style.get_meta("source_sha256") == source["sha256"])
	var count := 0
	for rig in source["rigs"]:
		var node: Node3D = stage.head_style.get_node(NodePath(rig["name"]))
		for part in rig["parts"]:
			var mesh: MeshInstance3D = node.get_node(NodePath(part["name"]))
			assert(mesh.get_meta("bb_from") == v3(part["from"]))
			assert(mesh.get_meta("bb_to") == v3(part["to"]))
			var expected := (v3(part["to"]) - v3(part["from"])) * float(source["scale"])
			assert(mesh.mesh.get_aabb().size.is_equal_approx(expected))
			assert(mesh.material_override is ShaderMaterial)
			count += 1
	assert(count == 25)
	assert(stage.player.is_on_floor())
	assert(absf(stage.player.position.y - 1.715) < 0.04)
	print("SOURCE_GEOMETRY_PASS sha=", source["sha256"], " parts=",count)
	await capture("gameplay_v11")
	stage.set_physics_process(false)
	for node in stage.get_children():
		if node is CanvasLayer: node.visible = false
	for tag in stage.player_visual.get_children():
		if tag is Label3D: tag.visible = false
	stage.camera.global_position = stage.player.global_position + Vector3(3.5,1.35,-6.4)
	stage.camera.look_at(stage.player.global_position + Vector3(0,0.05,0),Vector3.UP)
	stage.camera.fov = 45.0
	await capture("fullbody_v11_comic")
	stage.head_style.set_enabled(false)
	await capture("fullbody_v11_plain")
	stage.head_style.set_enabled(true)
	for i in range(1000):
		var dt := 1.0/60.0
		stage.body_yaw = sin(i*0.03)*2.0
		stage.player_visual.rotation.y = stage.body_yaw
		stage.player.velocity = Vector3(sin(i*0.03)*7.0,0.0,cos(i*0.04)*7.0)
		stage._update_character_animation(dt)
		assert(stage.head_rig.transform.is_finite())
		assert(stage.left_leg_rig.transform.is_finite())
		assert(stage.right_leg_rig.transform.is_finite())
		assert(absf(stage.head_rig.rotation.y)<1.41)
		# Feet now replant in world space when the body turns; their local X is not fixed.
		assert(stage.left_leg_rig.position.distance_to(stage.left_leg_rest)<2.0)
		assert(stage.right_leg_rig.position.distance_to(stage.right_leg_rest)<2.0)
	stage.ak_fire_audio.volume_db = -80.0
	for i in range(6):
		stage.shot_cooldown = 0.0
		stage._fire_physics_ball()
		await physics_frame
	print("ANIMATION_SPRING_WEAPON_PASS")
	print("FULLBODY_INTEGRATION_QA_PASS")
	stage.queue_free()
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	Node.print_orphan_nodes()
	quit(0)
func capture(label: String) -> void:
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.save_png(output.path_join(label+".png")) == OK)
	print("RENDERED ",label)
func v3(a: Array) -> Vector3:
	return Vector3(float(a[0]),float(a[1]),float(a[2]))
