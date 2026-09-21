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

	var erebus_button := menu.submenu_selector.get_node("Warrior_Erebus") as Button
	ere_bus_click(erebus_button)
	for i in range(8):
		await process_frame
	check(menu._current_warrior_id() == "erebus", "erebus_selected")
	check(str(ProjectSettings.get_setting("kw3d/selected_warrior_id", "")) == "erebus", "erebus_runtime_setting")
	check(str(menu.legacy.get("selected_warrior_id")) == "erebus", "erebus_legacy_state")
	check(menu.hero != null and menu.hero.name == "ErebusMenuHero", "erebus_main_menu_model")
	check(menu.showroom_root != null and menu.showroom_root.name == "WarriorPreview_Erebus", "erebus_showroom_model")

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
	check(menu.showroom_root != null and menu.showroom_root.name == "WarriorPreview_Outrage", "outrage_showroom_model")

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
