extends SceneTree
var failures: Array[String] = []

func check(v: bool, label: String) -> void:
	if not v:
		failures.append(label)
		push_error("OFFLINE_FLOW_FAIL "+label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	ProjectSettings.set_setting("kw3d/open_offline_tests_on_load", false)
	ProjectSettings.set_setting("kw3d/offline_test_mode", "waves")
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	menu.enable_intro_animation = false
	root.add_child(menu)
	current_scene = menu
	for i in range(20):
		await process_frame

	check(menu.offline_test_button != null and menu.offline_test_button.visible, "offline_button_visible")
	check(menu.offline_test_button.text == "TEST OFFLINE", "offline_button_text")
	var play_normal := menu.play_button.get_theme_stylebox("normal") as StyleBoxFlat
	var offline_normal := menu.offline_test_button.get_theme_stylebox("normal") as StyleBoxFlat
	check(play_normal != null and offline_normal != null, "main_button_styles_exist")
	if play_normal != null and offline_normal != null:
		check(play_normal.bg_color.is_equal_approx(offline_normal.bg_color), "offline_matches_fight_bg")
		check(play_normal.border_color.is_equal_approx(offline_normal.border_color), "offline_matches_fight_border")
		check(play_normal.border_width_bottom == offline_normal.border_width_bottom, "offline_matches_fight_bottom_border")

	menu.offline_test_button.pressed.emit()
	await create_timer(0.15).timeout
	var overlay = menu.get_node_or_null("OfflineTestRooms")
	check(overlay != null and overlay.visible, "offline_rooms_open")
	check(overlay.waves_button != null and overlay.sandbox_button != null, "room_buttons_exist")
	if overlay != null:
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://tmp/kw3d/offline_test_rooms.png") == OK, "offline_menu_screenshot")
		overlay.sandbox_button.pressed.emit()

	await create_timer(0.65).timeout
	for i in range(8):
		await process_frame
	check(current_scene != null and current_scene.name != "MainMenu", "sandbox_scene_loaded")
	var sandbox = current_scene
	check(str(sandbox.offline_test_mode) == "sandbox", "sandbox_mode_set")
	check(sandbox.combat != null and sandbox.combat.director != null, "sandbox_director_exists")
	if sandbox.combat != null and sandbox.combat.director != null:
		check(not sandbox.combat.director.advancement_enabled, "sandbox_no_wave_advancement")
		check(not sandbox.combat.director.attacks_enabled, "sandbox_no_enemy_fire")
		check(not sandbox.combat.roaming_enabled, "sandbox_stationary_targets")
		check(sandbox.combat.targets.size() == 3, "sandbox_three_targets")

	var back := InputEventKey.new()
	back.physical_keycode = KEY_F10
	back.pressed = true
	sandbox._unhandled_input(back)
	await create_timer(0.25).timeout
	for i in range(8):
		await process_frame
	check(current_scene != null and current_scene.name == "MainMenu", "f10_returns_main")
	var menu2 = current_scene
	await create_timer(0.12).timeout
	var overlay2 = menu2.get_node_or_null("OfflineTestRooms")
	check(overlay2 != null and overlay2.visible, "f10_reopens_test_rooms")
	if overlay2 != null:
		overlay2.waves_button.pressed.emit()

	await create_timer(0.65).timeout
	for i in range(8):
		await process_frame
	var waves = current_scene
	check(str(waves.offline_test_mode) == "waves", "waves_mode_set")
	if waves.combat != null and waves.combat.director != null:
		check(waves.combat.director.advancement_enabled, "waves_advancement_enabled")
		check(waves.combat.director.attacks_enabled, "waves_attacks_enabled")
		check(waves.combat.roaming_enabled, "waves_roaming_enabled")

	print("OFFLINE_FLOW_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
