extends SceneTree
var failures: Array[String] = []
func check(v: bool, label: String) -> void:
	if not v:
		failures.append(label)
		push_error("BULLET_TRAIL_FAIL "+label)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	ProjectSettings.set_setting("kw3d/offline_test_mode","sandbox")
	var stage = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	for i in range(16):
		await process_frame
	stage.combat.set_process(false)
	var start: Vector3 = stage.weapon_muzzle.global_position
	var end := start + Vector3(0.25,0.08,-13.0)
	stage.combat._spawn_tracer(start,end)
	stage.combat._process(0.009)
	check(stage.combat.trail_echoes.size() >= 1,"trail_echoes_spawn")
	check(stage.combat.active_tracers.size() == 1,"main_tracer_active_during_flight")
	if stage.combat.trail_echoes.size() > 0:
		var e: Dictionary = stage.combat.trail_echoes[0]
		check(is_instance_valid(e.node),"trail_echo_valid")
		check((e.node as MeshInstance3D).transparency < 1.0,"trail_visible")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://tmp/kw3d/bullet_trail_0140.png") == OK,"trail_screenshot")
	for i in range(36):
		stage.combat._process(1.0/120.0)
	check(stage.combat.trail_echoes.size() < 96,"trail_cap_ok")
	check(stage.combat.active_tracers.is_empty(),"tracer_finishes_cleanly")
	print("BULLET_TRAIL_", "PASS" if failures.is_empty() else "FAIL", failures, " echoes=",stage.combat.trail_echoes.size())
	quit(0 if failures.is_empty() else 1)
