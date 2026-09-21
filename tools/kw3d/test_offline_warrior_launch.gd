extends SceneTree

var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	if value:
		return
	failures.append(label)
	push_error("OFFLINE_WARRIOR_LAUNCH_FAIL " + label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var original := str(ProjectSettings.get_setting("kw3d/selected_warrior_id", "outrage"))
	var menu: Variant = load("res://scenes/ui/main_menu_v2.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in range(18):
		await process_frame

	menu._select_v2_warrior("erebus")
	for i in range(6):
		await process_frame
	check(str(ProjectSettings.get_setting("kw3d/selected_warrior_id", "")) == "erebus", "menu_selected_erebus")
	menu._launch_offline_waves()

	var stage: Variant = null
	for i in range(180):
		await process_frame
		if current_scene != null and current_scene != menu and current_scene.get("player_warrior_id") != null:
			stage = current_scene
			break
	check(stage != null, "offline_scene_loaded")
	if stage != null:
		for i in range(90):
			await physics_frame
		check(stage.player_warrior_id == "erebus", "offline_spawned_erebus")
		check(stage.head_style != null and str(stage.head_style.get_meta("warrior_id", "")) == "erebus", "offline_erebus_model")

	ProjectSettings.set_setting("kw3d/selected_warrior_id", original)
	print("OFFLINE_WARRIOR_LAUNCH_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
