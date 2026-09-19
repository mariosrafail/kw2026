extends SceneTree
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
	if not v: failures.append(label);push_error("DUEL_UI_FAIL "+label)
func _initialize()->void: run.call_deferred()
func run()->void:
	var stage=load("res://scenes/prototypes/kw_3d_lan_duel.tscn").instantiate()
	root.add_child(stage)
	for i in range(12): await process_frame
	var client: Node=stage.client
	var menu: Control=client.menu
	check(menu.visible,"menu_visible")
	check(menu.create_button.visible and menu.join_button.visible,"create_join_visible")
	check(menu.create_button.has_focus(),"controller_focus_on_create")
	check(menu.create_button.get_theme_stylebox("normal") is StyleBoxFlat,"styled_button")
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://scenes/ui/main_menu.tscn","main_scene_main_menu")
	await RenderingServer.frame_post_draw
	var path="res://tmp/kw3d/duel_main_menu.png"
	var image=get_root().get_texture().get_image()
	check(image.save_png(path)==OK,"screenshot")
	print("DUEL_UI_QA_","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)
