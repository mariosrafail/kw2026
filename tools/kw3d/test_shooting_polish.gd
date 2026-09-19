extends SceneTree
var failures: Array[String] = []
func check(v: bool, label: String) -> void:
	if not v:
		failures.append(label)
		push_error("SHOOTING_POLISH_FAIL "+label)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	ProjectSettings.set_setting("kw3d/offline_test_mode","sandbox")
	var stage = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	for i in range(18): await process_frame
	check(stage.combat != null,"combat_exists")
	check(stage.weapon_muzzle != null,"muzzle_exists")
	var start: Vector3 = stage.weapon_muzzle.global_position
	var end := start + Vector3(0.4,0.2,-9.0)
	stage.combat._spawn_tracer(start,end)
	check(stage.combat.active_tracers.size() == 1,"tracer_created")
	if stage.combat.active_tracers.size() == 1:
		var data: Dictionary = stage.combat.active_tracers[0]
		check(data.has("core") and data.has("halo") and data.has("head"),"layered_tracer")
		check(is_instance_valid(data.core) and is_instance_valid(data.halo) and is_instance_valid(data.head),"tracer_parts_valid")
	stage.combat._spawn_impact(end,Vector3.UP)
	stage.combat._spawn_damage_feedback(end,Vector3(0,0,-1),20.0,false)
	check(stage.combat.hit_effects.size() >= 7,"impact_and_hit_debris")
	stage._kick_weapon_visuals()
	check(absf(stage.weapon_visual_twist_kick) > 0.0001 or absf(stage.weapon_visual_side_kick) > 0.0001,"weapon_visual_kick")
	stage._spawn_muzzle_flash()
	check(stage.weapon_muzzle.get_child_count() > 0,"muzzle_burst_created")
	for i in range(12):
		stage.combat._process(1.0/120.0)
		await process_frame
	check(stage.combat.active_tracers.size() <= 1,"tracer_updates")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://tmp/kw3d/shooting_polish_fx.png") == OK,"screenshot")
	print("SHOOTING_POLISH_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
