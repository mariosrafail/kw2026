extends SceneTree
var failures: Array[String] = []
func check(v: bool, label: String) -> void:
	if not v:
		failures.append(label)
		push_error("VISIBLE_BUTTON_FAIL "+label)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var stage = load("res://scenes/prototypes/kw_3d_lan_duel.tscn").instantiate()
	root.add_child(stage)
	for i in range(16): await process_frame
	var menu: Control = stage.client.menu
	var b: Button = menu.create_button
	var j: Button = menu.join_button
	var menu_rect := menu.get_global_rect()
	var br := b.get_global_rect()
	var jr := j.get_global_rect()
	print("MENU_RECT ",menu_rect)
	print("CREATE_RECT ",br)
	print("JOIN_RECT ",jr)
	check(b.visible and b.is_visible_in_tree(),"create_visible")
	check(j.visible and j.is_visible_in_tree(),"join_visible")
	check(menu_rect.encloses(br),"create_inside_menu")
	check(menu_rect.encloses(jr),"join_inside_menu")
	check(br.size.x>80 and br.size.y>25,"create_has_size")
	check(jr.size.x>80 and jr.size.y>25,"join_has_size")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://tmp/kw3d/duel_main_menu_compact.png")==OK,"screenshot")
	print("VISIBLE_BUTTON_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
