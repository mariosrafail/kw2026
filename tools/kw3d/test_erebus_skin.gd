extends SceneTree

const EREBUS_SCENE := preload("res://scenes/prototypes/characters/erebus_fullbody.tscn")
const EREBUS_SKINS := preload("res://scripts/prototypes/erebus_skin_style.gd")

var failures: Array[String] = []


func check(value: bool, label: String) -> void:
	if value:
		return
	failures.append(label)
	push_error("EREBUS_SKIN_FAIL " + label)


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	check(EREBUS_SKINS.skin_count() == 2, "two_erebus_skins")
	var direct := EREBUS_SCENE.instantiate() as Node3D
	EREBUS_SKINS.apply(direct, 1)
	check(direct.get_node_or_null("LeftHandRig") is Node3D, "left_claw_hand")
	check(direct.get_node_or_null("RightHandRig") is Node3D, "right_claw_hand")
	check(direct.get_node_or_null("LeftHandRig/Claw_Left_Bridge") is MeshInstance3D, "left_claw_bridge")
	check(direct.get_node_or_null("RightHandRig/Claw_Right_Bridge") is MeshInstance3D, "right_claw_bridge")
	check(str(direct.get_meta("warrior_skin_name", "")) == "PHOTO FACE", "photo_skin_metadata")
	var panel := direct.get_node_or_null("HeadRig/PhotoFacePanel") as MeshInstance3D
	check(panel != null, "photo_face_panel")
	if panel != null:
		var material := panel.material_override as StandardMaterial3D
		check(material != null and material.albedo_texture != null, "photo_texture_loaded")
		if material != null and material.albedo_texture != null:
			check(material.albedo_texture.get_width() == 237, "photo_texture_width")
			check(material.albedo_texture.get_height() == 243, "photo_texture_height")
		check(str(panel.get_meta("erebus_face_texture_path", "")) == EREBUS_SKINS.FACE_TEXTURE_PATH, "photo_texture_exact_asset_path")
		check(panel.position.z < -0.35, "photo_panel_in_front_of_head")
	for eye_name in EREBUS_SKINS.EYE_PARTS:
		var eye := direct.get_node_or_null("HeadRig/%s" % eye_name) as MeshInstance3D
		check(eye != null and not eye.visible, "photo_hides_%s" % eye_name)
	EREBUS_SKINS.apply(direct, 0)
	check(direct.get_node_or_null("HeadRig/PhotoFacePanel") == null, "classic_removes_photo_panel")
	for eye_name in EREBUS_SKINS.EYE_PARTS:
		var eye := direct.get_node_or_null("HeadRig/%s" % eye_name) as MeshInstance3D
		check(eye != null and eye.visible, "classic_restores_%s" % eye_name)
	direct.free()

	var old_warrior := str(ProjectSettings.get_setting("kw3d/selected_warrior_id", "outrage"))
	var old_skin := int(ProjectSettings.get_setting("kw3d/selected_erebus_skin", 0))
	ProjectSettings.set_setting("kw3d/selected_warrior_id", "erebus")
	ProjectSettings.set_setting("kw3d/selected_erebus_skin", 1)

	var menu: Variant = load("res://scenes/ui/main_menu_v2.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in range(20):
		await process_frame
	menu._select_v2_warrior("erebus")
	menu._open_v2_submenu("warriors")
	for i in range(8):
		await process_frame
	menu._select_erebus_skin(1)
	for i in range(10):
		await process_frame
	check(menu.selected_erebus_skin == 1, "menu_photo_selected")
	check(int(ProjectSettings.get_setting("kw3d/selected_erebus_skin", -1)) == 1, "photo_runtime_setting")
	var photo_button := menu.submenu_selector.get_node_or_null("ErebusSkin_01") as Button
	check(photo_button != null and photo_button.text.contains("PHOTO FACE"), "photo_skin_button")
	var showroom := menu.showroom_root.get_node_or_null("ErebusFullBody") as Node3D
	check(showroom != null, "photo_showroom_erebus")
	if showroom != null:
		var showroom_panel := showroom.get_node_or_null("HeadRig/PhotoFacePanel") as MeshInstance3D
		check(showroom_panel != null, "photo_showroom_panel")
		if showroom_panel != null:
			var showroom_material := showroom_panel.material_override as StandardMaterial3D
			check(showroom_material != null and showroom_material.albedo_texture != null, "photo_showroom_texture")

	menu._launch_offline_waves()
	var stage: Variant = null
	for i in range(180):
		await process_frame
		if current_scene != null and current_scene != menu and current_scene.get("erebus_skin_id") != null:
			stage = current_scene
			break
	check(stage != null, "photo_offline_scene_loaded")
	if stage != null:
		for i in range(60):
			await physics_frame
		check(stage.player_warrior_id == "erebus", "photo_offline_erebus")
		check(stage.left_hand_rig != null and stage.right_hand_rig != null, "gameplay_two_claw_hands")
		check(stage.erebus_skin_id == 1, "photo_offline_skin_id")
		check(str(stage.head_style.get_meta("warrior_skin_name", "")) == "PHOTO FACE", "photo_offline_metadata")
		var game_panel := stage.head_style.get_node_or_null("HeadRig/PhotoFacePanel") as MeshInstance3D
		check(game_panel != null, "photo_offline_panel")
		if game_panel != null:
			var game_material := game_panel.material_override as StandardMaterial3D
			check(game_material != null and game_material.albedo_texture != null, "photo_offline_texture")
		stage.queue_free()
		for i in range(4):
			await process_frame

	ProjectSettings.set_setting("kw3d/selected_warrior_id", old_warrior)
	ProjectSettings.set_setting("kw3d/selected_erebus_skin", old_skin)
	print("EREBUS_SKIN_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
