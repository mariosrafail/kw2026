extends SceneTree

const OUTRAGE_SCENE := preload("res://scenes/prototypes/characters/outrage_fullbody.tscn")
const OUTRAGE_SKINS := preload("res://scripts/prototypes/outrage_skin_style.gd")

var failures: Array[String] = []


func check(value: bool, label: String) -> void:
	if value:
		return
	failures.append(label)
	push_error("OUTRAGE_SKIN_FAIL " + label)


func color_matches(a: Color, b: Color) -> bool:
	return (
		absf(a.r - b.r) < 0.01
		and absf(a.g - b.g) < 0.01
		and absf(a.b - b.b) < 0.01
	)


func mesh_plain_color(model: Node3D, path: String) -> Color:
	var mesh := model.get_node(path) as MeshInstance3D
	var material := mesh.get_meta("plain_material", mesh.material_override) as StandardMaterial3D
	return material.albedo_color if material != null else Color.TRANSPARENT


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	# Material-level proof on the authored Outrage scene.
	var direct := OUTRAGE_SCENE.instantiate() as Node3D
	OUTRAGE_SKINS.apply(direct, 1)
	check(str(direct.get_meta("warrior_skin_name", "")) == "VOID", "skin_metadata")
	check(color_matches(mesh_plain_color(direct, "HeadRig/Head_Solid"), OUTRAGE_SKINS.VOID_BODY), "head_dark_gray")
	check(color_matches(mesh_plain_color(direct, "TorsoRig/Torso_Upper"), OUTRAGE_SKINS.VOID_BODY), "torso_dark_gray")
	check(color_matches(mesh_plain_color(direct, "HeadRig/Front_Panel"), OUTRAGE_SKINS.VOID_PANEL), "head_panel_dark")
	check(color_matches(mesh_plain_color(direct, "HeadRig/Horn_Left_Root"), OUTRAGE_SKINS.VOID_HORN), "left_horn_purple")
	check(color_matches(mesh_plain_color(direct, "HeadRig/Horn_Right_Tip"), OUTRAGE_SKINS.VOID_HORN), "right_horn_purple")
	check(color_matches(mesh_plain_color(direct, "HeadRig/Eye_Left"), OUTRAGE_SKINS.VOID_EYE), "left_eye_white")
	check(color_matches(mesh_plain_color(direct, "HeadRig/Eye_Right"), OUTRAGE_SKINS.VOID_EYE), "right_eye_white")
	direct.free()

	var old_warrior := str(ProjectSettings.get_setting("kw3d/selected_warrior_id", "outrage"))
	var old_skin := int(ProjectSettings.get_setting("kw3d/selected_outrage_skin", 0))
	ProjectSettings.set_setting("kw3d/selected_warrior_id", "outrage")
	ProjectSettings.set_setting("kw3d/selected_outrage_skin", 0)

	var menu: Variant = load("res://scenes/ui/main_menu_v2.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in range(20):
		await process_frame

	menu._select_v2_warrior("outrage")
	menu._open_v2_submenu("warriors")
	for i in range(8):
		await process_frame
	menu._select_outage_skin(1)
	for i in range(10):
		await process_frame

	check(menu.selected_outrage_skin == 1, "menu_void_selected")
	check(int(ProjectSettings.get_setting("kw3d/selected_outrage_skin", -1)) == 1, "runtime_setting")
	var void_button := menu.submenu_selector.get_node_or_null("OutrageSkin_01") as Button
	check(void_button != null and void_button.text.contains("VOID"), "void_skin_button")
	check(menu.hero != null and menu.hero.name == "OutrageMenuHero", "main_menu_outage_model")

	var showroom_model := menu.showroom_root.find_child("OutrageFullBody", true, false) as Node3D
	check(showroom_model != null, "showroom_outage_model")
	if showroom_model != null:
		var showroom_horn := showroom_model.get_node("HeadRig/Horn_Left_Upper") as MeshInstance3D
		var showroom_eye := showroom_model.get_node("HeadRig/Eye_Left") as MeshInstance3D
		var showroom_body := showroom_model.get_node("TorsoRig/Torso_Upper") as MeshInstance3D
		var horn_mat := showroom_horn.material_override as StandardMaterial3D
		var eye_mat := showroom_eye.material_override as StandardMaterial3D
		var body_mat := showroom_body.material_override as StandardMaterial3D
		check(horn_mat != null and color_matches(horn_mat.albedo_color, OUTRAGE_SKINS.VOID_HORN), "showroom_purple_horn")
		check(eye_mat != null and color_matches(eye_mat.albedo_color, OUTRAGE_SKINS.VOID_EYE), "showroom_white_eye")
		check(body_mat != null and color_matches(body_mat.albedo_color, OUTRAGE_SKINS.VOID_BODY), "showroom_dark_body")

	menu._launch_offline_waves()
	var stage: Variant = null
	for i in range(180):
		await process_frame
		if current_scene != null and current_scene != menu and current_scene.get("outrage_skin_id") != null:
			stage = current_scene
			break
	check(stage != null, "offline_scene_loaded")
	if stage != null:
		for i in range(90):
			await physics_frame
		check(stage.player_warrior_id == "outrage", "offline_outage_selected")
		check(stage.outrage_skin_id == 1, "offline_void_skin_id")
		check(str(stage.head_style.get_meta("warrior_skin_name", "")) == "VOID", "offline_void_metadata")
		check(color_matches(mesh_plain_color(stage.head_style, "HeadRig/Horn_Left_Root"), OUTRAGE_SKINS.VOID_HORN), "offline_purple_horn")
		check(color_matches(mesh_plain_color(stage.head_style, "HeadRig/Eye_Left"), OUTRAGE_SKINS.VOID_EYE), "offline_white_eye")
		check(color_matches(mesh_plain_color(stage.head_style, "TorsoRig/Torso_Upper"), OUTRAGE_SKINS.VOID_BODY), "offline_dark_body")

	ProjectSettings.set_setting("kw3d/selected_warrior_id", old_warrior)
	ProjectSettings.set_setting("kw3d/selected_outrage_skin", old_skin)
	print("OUTRAGE_SKIN_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
