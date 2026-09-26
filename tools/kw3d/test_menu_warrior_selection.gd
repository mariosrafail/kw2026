extends SceneTree

var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	if value:
		return
	failures.append(label)
	push_error("MENU_WARRIOR_SELECTION_FAIL " + label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var menu: Variant = load("res://scenes/ui/main_menu_v2.tscn").instantiate()
	root.add_child(menu)
	for i in range(18):
		await process_frame
	var original: String = menu._current_warrior_id()

	menu._open_v2_submenu("warriors")
	for i in range(8):
		await process_frame
	check(menu.submenu_selector.get_node_or_null("Warrior_Outrage") != null, "outrage_button")
	check(menu.submenu_selector.get_node_or_null("Warrior_Erebus") != null, "erebus_button")
	check(menu.submenu_selector.get_node_or_null("Warrior_Kosas") != null, "kosas_button")
	check(menu.submenu_selector.get_node_or_null("Warrior_Aevilok") != null, "aevilok_button")
	check(menu.submenu_selector.get_node_or_null("Warrior_Loker") != null, "loker_button")

	var erebus_button := menu.submenu_selector.get_node("Warrior_Erebus") as Button
	ere_bus_click(erebus_button)
	for i in range(8):
		await process_frame
	check(menu._current_warrior_id() == "erebus", "erebus_selected")
	check(str(ProjectSettings.get_setting("kw3d/selected_warrior_id", "")) == "erebus", "erebus_runtime_setting")
	check(str(menu.legacy.get("selected_warrior_id")) == "erebus", "erebus_legacy_state")
	check(menu.hero != null and menu.hero.name == "ErebusMenuHero", "erebus_main_menu_model")
	check(menu.showroom_root != null, "erebus_showroom_model")
	check(menu.offline_button != null and menu.offline_button.text.contains("EREBUS"), "offline_button_shows_erebus")
	var showroom_model := menu.showroom_root.get_node_or_null("ErebusFullBody") as Node3D
	check(showroom_model != null, "erebus_showroom_body")
	if showroom_model != null:
		check(showroom_model.position.y > 0.0, "erebus_fullbody_floor_alignment")
		var head := showroom_model.get_node("HeadRig/Head_Core") as MeshInstance3D
		var mat := head.material_override as StandardMaterial3D
		check(mat != null and not mat.normal_enabled and mat.normal_texture == null, "erebus_clean_showroom_material")

	var kosas_button := menu.submenu_selector.get_node("Warrior_Kosas") as Button
	ere_bus_click(kosas_button)
	for i in range(8):
		await process_frame
	check(menu._current_warrior_id() == "kosas", "kosas_selected")
	check(str(ProjectSettings.get_setting("kw3d/selected_warrior_id", "")) == "kosas", "kosas_runtime_setting")
	check(str(menu.legacy.get("selected_warrior_id")) == "kosas", "kosas_legacy_state")
	check(menu.hero != null and menu.hero.name == "KosasMenuHero", "kosas_main_menu_model")
	check(menu.showroom_root != null, "kosas_showroom_model")
	check(menu.offline_button != null and menu.offline_button.text.contains("KOSAS"), "offline_button_shows_kosas")
	var kosas_showroom := menu.showroom_root.get_node_or_null("KosasFullBody") as Node3D
	check(kosas_showroom != null, "kosas_showroom_body")
	if kosas_showroom != null:
		check(str(kosas_showroom.get_meta("warrior_id", "")) == "kosas", "kosas_showroom_metadata")
		check(kosas_showroom.get_node_or_null("HeadRig/Nose_Tip") is MeshInstance3D, "kosas_showroom_big_nose")

	var kosas_stage: Variant = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(kosas_stage)
	for i in range(90):
		await physics_frame
	check(kosas_stage.player_warrior_id == "kosas", "kosas_gameplay_selection")
	check(kosas_stage.head_style != null and str(kosas_stage.head_style.get_meta("warrior_id", "")) == "kosas", "kosas_gameplay_model")
	check(kosas_stage.head_style.get_node_or_null("HeadRig/Nose_Tip") is MeshInstance3D, "kosas_gameplay_big_nose")
	var kosas_game_body := kosas_stage.head_style.get_node_or_null("TorsoRig/KosasBodyBox") as MeshInstance3D
	check(kosas_game_body != null, "kosas_gameplay_rect_body")
	if kosas_game_body != null:
		var kosas_game_body_size := kosas_game_body.mesh.get_aabb().size
		check(
			absf(kosas_game_body_size.x - 0.50) < 0.001
			and absf(kosas_game_body_size.y - 0.82) < 0.001
			and absf(kosas_game_body_size.z - 0.32) < 0.001,
			"kosas_gameplay_rect_body_dimensions"
		)
	kosas_stage.queue_free()
	for i in range(6):
		await process_frame

	var aevilok_button := menu.submenu_selector.get_node("Warrior_Aevilok") as Button
	ere_bus_click(aevilok_button)
	for i in range(8):
		await process_frame
	check(menu._current_warrior_id() == "aevilok", "aevilok_selected")
	check(str(ProjectSettings.get_setting("kw3d/selected_warrior_id", "")) == "aevilok", "aevilok_runtime_setting")
	check(str(menu.legacy.get("selected_warrior_id")) == "aevilok", "aevilok_legacy_state")
	check(menu.hero != null and menu.hero.name == "AevilokMenuHero", "aevilok_main_menu_model")
	check(menu.showroom_root != null, "aevilok_showroom_model")
	check(menu.offline_button != null and menu.offline_button.text.contains("AEVILOK"), "offline_button_shows_aevilok")
	var aevilok_showroom := menu.showroom_root.get_node_or_null("AevilokFullBody") as Node3D
	check(aevilok_showroom != null, "aevilok_showroom_body")
	if aevilok_showroom != null:
		check(str(aevilok_showroom.get_meta("warrior_id", "")) == "aevilok", "aevilok_showroom_metadata")
		check(aevilok_showroom.get_node_or_null("TorsoRig/AevilokWingRoot") is Node3D, "aevilok_showroom_wings")

	var aevilok_stage: Variant = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(aevilok_stage)
	for i in range(90):
		await physics_frame
	check(aevilok_stage.player_warrior_id == "aevilok", "aevilok_gameplay_selection")
	check(aevilok_stage.head_style != null and str(aevilok_stage.head_style.get_meta("warrior_id", "")) == "aevilok", "aevilok_gameplay_model")
	check(aevilok_stage.head_style.get_node_or_null("TorsoRig/AevilokWingRoot") is Node3D, "aevilok_gameplay_wings")
	aevilok_stage.queue_free()
	for i in range(6):
		await process_frame

	menu._open_v2_submenu("warriors")
	for i in range(4):
		await process_frame
	var loker_button := menu.submenu_selector.get_node("Warrior_Loker") as Button
	ere_bus_click(loker_button)
	for i in range(8):
		await process_frame
	check(menu._current_warrior_id() == "loker", "loker_selected")
	check(str(ProjectSettings.get_setting("kw3d/selected_warrior_id", "")) == "loker", "loker_runtime_setting")
	check(str(menu.legacy.get("selected_warrior_id")) == "loker", "loker_legacy_state")
	check(menu.hero != null and menu.hero.name == "LokerMenuHero", "loker_main_menu_model")
	check(menu.showroom_root != null, "loker_showroom_model")
	check(menu.offline_button != null and menu.offline_button.text.contains("LOKER"), "offline_button_shows_loker")
	var loker_showroom := menu.showroom_root.get_node_or_null("LokerFullBody") as Node3D
	check(loker_showroom != null, "loker_showroom_body")
	if loker_showroom != null:
		check(str(loker_showroom.get_meta("warrior_id", "")) == "loker", "loker_showroom_metadata")
		check(loker_showroom.get_node_or_null("HeadRig/LokerSnoutTip") is MeshInstance3D, "loker_showroom_long_head")

	var loker_stage: Variant = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(loker_stage)
	for i in range(90):
		await physics_frame
	check(loker_stage.player_warrior_id == "loker", "loker_gameplay_selection")
	check(loker_stage.head_style != null and str(loker_stage.head_style.get_meta("warrior_id", "")) == "loker", "loker_gameplay_model")
	check(loker_stage.head_style.get_node_or_null("HeadRig/LokerSnoutTip") is MeshInstance3D, "loker_gameplay_long_head")
	loker_stage.queue_free()
	for i in range(6):
		await process_frame

	menu._open_v2_submenu("warriors")
	for i in range(4):
		await process_frame

	menu._select_v2_warrior("erebus")
	for i in range(6):
		await process_frame

	var stage: Variant = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	for i in range(90):
		await physics_frame
	check(stage.player_warrior_id == "erebus", "erebus_gameplay_selection")
	check(stage.head_style != null and str(stage.head_style.get_meta("warrior_id", "")) == "erebus", "erebus_gameplay_model")
	stage.queue_free()
	for i in range(6):
		await process_frame

	var outrage_button := menu.submenu_selector.get_node("Warrior_Outrage") as Button
	ere_bus_click(outrage_button)
	for i in range(8):
		await process_frame
	check(menu._current_warrior_id() == "outrage", "outrage_selected")
	check(str(ProjectSettings.get_setting("kw3d/selected_warrior_id", "")) == "outrage", "outrage_runtime_setting")
	check(menu.hero != null and menu.hero.name == "OutrageMenuHero", "outrage_main_menu_model")
	check(menu.showroom_root != null, "outrage_showroom_model")
	check(menu.offline_button != null and menu.offline_button.text.contains("OUTRAGE"), "offline_button_shows_outrage")

	menu._select_v2_warrior(original)
	for i in range(4):
		await process_frame
	print("MENU_WARRIOR_SELECTION_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	menu.queue_free()
	for i in range(4):
		await process_frame
	quit(0 if failures.is_empty() else 1)

func ere_bus_click(button: Button) -> void:
	button.emit_signal("pressed")
