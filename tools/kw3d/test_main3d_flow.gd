extends SceneTree
var failures: Array[String] = []
func check(v: bool, label: String) -> void:
	if not v:
		failures.append(label)
		push_error("MAIN3D_FLOW_FAIL "+label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	menu.enable_intro_animation = false
	root.add_child(menu)
	current_scene = menu
	for i in range(24):
		await process_frame
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/ui/main_menu.tscn", "main_scene_is_main_menu")
	check(menu.play_button != null and menu.play_button.visible, "fight_visible")
	check(menu.exit_button != null and menu.exit_button.text == "I HATE THIS GAME", "old_menu_visual_language")
	check(menu.get_node_or_null("MenuLoadingOverlay") != null, "loading_overlay_created")
	check(menu.get_node_or_null("NetworkModeOverlay") == null, "old_network_picker_absent")
	check(menu.get_node_or_null("AuthOverlay") == null, "old_auth_overlay_absent")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://tmp/kw3d/main3d_home.png") == OK, "home_screenshot")

	# Trigger the real Button signal, not a direct function call.
	menu.play_button.pressed.emit()
	await create_timer(0.72).timeout
	var loading = menu.get_node_or_null("MenuLoadingOverlay")
	check(loading != null and loading.visible, "loading_visible_after_fight_transition")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://tmp/kw3d/main3d_loading.png") == OK, "loading_screenshot")

	await create_timer(0.82).timeout
	for i in range(10):
		await process_frame
	check(current_scene != null and current_scene.name == "KW3DLANDuel", "changed_to_3d_duel")
	var duel = current_scene
	check(duel.client != null and duel.client.menu != null and duel.client.menu.visible, "online_room_browser_visible")
	check(duel.client.menu.create_button.visible and duel.client.menu.join_button.visible, "online_room_actions_visible")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://tmp/kw3d/main3d_online_lobby.png") == OK, "lobby_screenshot")
	print("MAIN3D_FLOW_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
