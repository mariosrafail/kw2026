extends SceneTree

var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	if value:
		return
	failures.append(label)
	push_error("V2_MENU_LAYOUT_FAIL " + label)

func inside(outer: Rect2, inner: Rect2, epsilon := 0.75) -> bool:
	return (
		inner.position.x >= outer.position.x - epsilon
		and inner.position.y >= outer.position.y - epsilon
		and inner.end.x <= outer.end.x + epsilon
		and inner.end.y <= outer.end.y + epsilon
	)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var menu: Variant = load("res://scenes/ui/main_menu_v2.tscn").instantiate()
	root.add_child(menu)
	for i in range(20):
		await process_frame

	check(inside(menu.presentation.get_global_rect(), menu.main_rail.get_global_rect()), "main_rail_inside")
	for kind in ["warriors", "guns", "settings"]:
		menu._open_v2_submenu(kind)
		for i in range(10):
			await process_frame
		var frame: Rect2 = menu.submenu_panel.get_global_rect()
		var bounds: Rect2 = menu.submenu_layer.get_global_rect()
		check(inside(bounds, frame), "%s_frame_inside" % kind)
		check(inside(frame, menu.submenu_body.get_global_rect()), "%s_body_inside" % kind)
		for panel in [
			menu.submenu_selector_panel,
			menu.submenu_showroom_panel,
			menu.submenu_info_panel,
			menu.submenu_settings_panel,
		]:
			if panel.visible and panel.is_visible_in_tree():
				check(inside(frame, panel.get_global_rect()), "%s_%s_inside" % [kind, panel.name])
		menu._close_v2_submenu()
		for i in range(12):
			await process_frame

	print("V2_MENU_LAYOUT_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	menu.queue_free()
	for i in range(4):
		await process_frame
	quit(0 if failures.is_empty() else 1)
