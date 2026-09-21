extends SceneTree

var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	if value:
		return
	failures.append(label)
	push_error("OFFLINE_AK_SKIN_FAIL " + label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var original := int(ProjectSettings.get_setting("kw3d/selected_ak_skin", 0))
	var menu: Variant = load("res://scenes/ui/main_menu_v2.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in range(18):
		await process_frame

	menu._open_v2_submenu("guns")
	for i in range(8):
		await process_frame
	menu.selected_showroom_weapon = "ak47"
	menu._select_weapon_skin("ak47", 4)
	for i in range(8):
		await process_frame

	check(menu.selected_ak_skin == 4, "menu_inferno_selected")
	check(int(ProjectSettings.get_setting("kw3d/selected_ak_skin", -1)) == 4, "runtime_setting")
	var inferno_button := menu.submenu_selector.find_child("*Skin_04", false, false) as Button
	check(inferno_button != null and inferno_button.text.contains("INFERNO"), "inferno_button")
	check(menu.showroom_root.find_child("InfernoFlame_Mid", true, false) != null, "showroom_inferno_geometry")

	menu._launch_offline_waves()
	var stage: Variant = null
	for i in range(180):
		await process_frame
		if current_scene != null and current_scene != menu and current_scene.get("ak_skin_id") != null:
			stage = current_scene
			break
	check(stage != null, "offline_scene_loaded")
	if stage != null:
		for i in range(90):
			await physics_frame
		check(stage.ak_skin_id == 4, "offline_skin_id")
		check(stage.ak_visual_root.find_child("InfernoFlame_Mid", true, false) != null, "offline_inferno_geometry")
		check(stage.ak_visual_root.find_child("InfernoWeaponParticles", true, false) is GPUParticles3D, "offline_inferno_weapon_particles")

	ProjectSettings.set_setting("kw3d/selected_ak_skin", original)
	print("OFFLINE_AK_SKIN_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
