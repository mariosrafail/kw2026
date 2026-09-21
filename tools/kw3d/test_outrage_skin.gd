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
	check(OUTRAGE_SKINS.skin_count() == 4, "four_outage_skins")
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

	var baseline := OUTRAGE_SCENE.instantiate() as Node3D
	var baseline_horn_y := (baseline.get_node("HeadRig/Horn_Left_Root") as MeshInstance3D).position.y
	baseline.free()
	var neon := OUTRAGE_SCENE.instantiate() as Node3D
	OUTRAGE_SKINS.apply(neon, 2)
	check(str(neon.get_meta("warrior_skin_name", "")) == "NEON", "neon_skin_metadata")
	check(color_matches(mesh_plain_color(neon, "HeadRig/Head_Solid"), OUTRAGE_SKINS.NEON_BODY), "neon_head_green")
	check(color_matches(mesh_plain_color(neon, "HeadRig/Front_Panel"), OUTRAGE_SKINS.NEON_BODY), "neon_front_panel_green")
	check(color_matches(mesh_plain_color(neon, "HeadRig/Left_Panel"), OUTRAGE_SKINS.NEON_BODY), "neon_left_panel_green")
	check(color_matches(mesh_plain_color(neon, "HeadRig/Right_Panel"), OUTRAGE_SKINS.NEON_BODY), "neon_right_panel_green")
	check(color_matches(mesh_plain_color(neon, "TorsoRig/Torso_Upper"), OUTRAGE_SKINS.NEON_BODY), "neon_torso_green")
	check(color_matches(mesh_plain_color(neon, "HeadRig/Horn_Left_Root"), OUTRAGE_SKINS.NEON_HORN), "neon_left_horn_yellow")
	check(color_matches(mesh_plain_color(neon, "HeadRig/Horn_Right_Tip"), OUTRAGE_SKINS.NEON_HORN), "neon_right_horn_yellow")
	check(color_matches(mesh_plain_color(neon, "HeadRig/Eye_Left"), OUTRAGE_SKINS.NEON_EYE), "neon_left_eye_black")
	check(color_matches(mesh_plain_color(neon, "HeadRig/Eye_Right"), OUTRAGE_SKINS.NEON_EYE), "neon_right_eye_black")
	var neon_body_material := (neon.get_node("TorsoRig/Torso_Upper") as MeshInstance3D).get_meta("plain_material") as StandardMaterial3D
	check(
		neon_body_material != null
		and neon_body_material.emission_enabled
		and neon_body_material.emission_energy_multiplier >= 1.5
		and neon_body_material.emission_energy_multiplier <= 2.0,
		"neon_body_emissive_soft"
	)
	var neon_horn_y := (neon.get_node("HeadRig/Horn_Left_Root") as MeshInstance3D).position.y
	check(absf((neon_horn_y - baseline_horn_y) - OUTRAGE_SKINS.HORN_RAISE_3PX) < 0.001, "neon_horns_three_pixels_higher")
	check(neon.get_node_or_null("NeonHeadGlow") is OmniLight3D, "neon_head_light")
	check(neon.get_node_or_null("NeonBodyGlow") is OmniLight3D, "neon_body_light")
	check(neon.get_node_or_null("NeonLowerGlow") is OmniLight3D, "neon_lower_light")
	check(neon.get_node_or_null("NeonHornGlow") is OmniLight3D, "neon_horn_light")
	var direct_body_light := neon.get_node("NeonBodyGlow") as OmniLight3D
	check(direct_body_light.light_energy >= 2.2 and direct_body_light.omni_range >= 4.0, "gameplay_strength_neon_light")
	var direct_body_light_energy := direct_body_light.light_energy
	neon.free()

	var heart := OUTRAGE_SCENE.instantiate() as Node3D
	OUTRAGE_SKINS.apply(heart, 3)
	check(str(heart.get_meta("warrior_skin_name", "")) == "HEART", "heart_skin_metadata")
	check(color_matches(mesh_plain_color(heart, "HeadRig/Head_Solid"), OUTRAGE_SKINS.HEART_BODY), "heart_head_purple")
	check(color_matches(mesh_plain_color(heart, "HeadRig/Front_Panel"), OUTRAGE_SKINS.HEART_BODY), "heart_front_panel_purple")
	check(color_matches(mesh_plain_color(heart, "HeadRig/Left_Panel"), OUTRAGE_SKINS.HEART_PANEL), "heart_side_panel_dark_purple")
	check(color_matches(mesh_plain_color(heart, "TorsoRig/Torso_Upper"), OUTRAGE_SKINS.HEART_BODY), "heart_torso_purple")
	check(color_matches(mesh_plain_color(heart, "HeadRig/Horn_Left_Root"), OUTRAGE_SKINS.HEART_HORN), "heart_left_horn_red")
	check(color_matches(mesh_plain_color(heart, "HeadRig/Horn_Right_Tip"), OUTRAGE_SKINS.HEART_HORN), "heart_right_horn_red")
	check(color_matches(mesh_plain_color(heart, "HeadRig/Eye_Left"), OUTRAGE_SKINS.HEART_EYE), "heart_left_eye_black")
	check(color_matches(mesh_plain_color(heart, "HeadRig/Eye_Right"), OUTRAGE_SKINS.HEART_EYE), "heart_right_eye_black")
	var heart_left_upper := heart.get_node("HeadRig/Horn_Left_Upper") as MeshInstance3D
	var heart_right_upper := heart.get_node("HeadRig/Horn_Right_Upper") as MeshInstance3D
	var heart_left_tip := heart.get_node("HeadRig/Horn_Left_Tip") as MeshInstance3D
	var heart_right_tip := heart.get_node("HeadRig/Horn_Right_Tip") as MeshInstance3D
	check(absf(heart_left_tip.position.x) < absf(heart_left_upper.position.x), "heart_left_horn_bends_inward")
	check(absf(heart_right_tip.position.x) < absf(heart_right_upper.position.x), "heart_right_horn_bends_inward")
	check(heart_left_tip.position.y < heart_left_upper.position.y and heart_right_tip.position.y < heart_right_upper.position.y, "heart_center_notch_dips")
	check(absf(heart_left_tip.position.x + heart_right_tip.position.x) < 0.001, "heart_tips_mirrored")
	check(absf(heart_left_tip.position.x - heart_right_tip.position.x) <= 0.15, "heart_tips_meet_at_center")
	check(heart_left_tip.scale.x >= 1.9 and heart_right_tip.scale.x >= 1.9, "heart_inner_tips_join")
	heart.free()

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
	menu._select_outage_skin(2)
	for i in range(10):
		await process_frame

	check(menu.selected_outrage_skin == 2, "menu_neon_selected")
	check(int(ProjectSettings.get_setting("kw3d/selected_outrage_skin", -1)) == 2, "runtime_setting")
	var neon_button := menu.submenu_selector.get_node_or_null("OutrageSkin_02") as Button
	check(neon_button != null and neon_button.text.contains("NEON"), "neon_skin_button")
	var heart_button := menu.submenu_selector.get_node_or_null("OutrageSkin_03") as Button
	check(heart_button != null and heart_button.text.contains("HEART"), "heart_skin_button")
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
		check(horn_mat != null and color_matches(horn_mat.albedo_color, OUTRAGE_SKINS.NEON_HORN), "showroom_yellow_horn")
		check(eye_mat != null and color_matches(eye_mat.albedo_color, OUTRAGE_SKINS.NEON_EYE), "showroom_black_eye")
		check(body_mat != null and color_matches(body_mat.albedo_color, OUTRAGE_SKINS.NEON_BODY), "showroom_neon_green_body")
		check(body_mat != null and body_mat.emission_enabled, "showroom_body_emission")
		check(showroom_model.get_node_or_null("NeonHeadGlow") is OmniLight3D, "showroom_head_light")
		check(showroom_model.get_node_or_null("NeonBodyGlow") is OmniLight3D, "showroom_neon_light")
		check(showroom_model.get_node_or_null("NeonLowerGlow") is OmniLight3D, "showroom_lower_light")
		var showroom_light := showroom_model.get_node("NeonBodyGlow") as OmniLight3D
		check(showroom_light.light_energy < direct_body_light_energy, "showroom_glow_stays_softer")

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
		check(stage.outrage_skin_id == 2, "offline_neon_skin_id")
		check(str(stage.head_style.get_meta("warrior_skin_name", "")) == "NEON", "offline_neon_metadata")
		check(color_matches(mesh_plain_color(stage.head_style, "HeadRig/Horn_Left_Root"), OUTRAGE_SKINS.NEON_HORN), "offline_yellow_horn")
		check(color_matches(mesh_plain_color(stage.head_style, "HeadRig/Eye_Left"), OUTRAGE_SKINS.NEON_EYE), "offline_black_eye")
		check(color_matches(mesh_plain_color(stage.head_style, "TorsoRig/Torso_Upper"), OUTRAGE_SKINS.NEON_BODY), "offline_neon_body")
		check(color_matches(mesh_plain_color(stage.head_style, "HeadRig/Front_Panel"), OUTRAGE_SKINS.NEON_BODY), "offline_neon_head_panel")
		check(stage.head_style.get_node_or_null("NeonHeadGlow") is OmniLight3D, "offline_neon_head_light")
		check(stage.head_style.get_node_or_null("NeonBodyGlow") is OmniLight3D, "offline_neon_body_light")
		check(stage.head_style.get_node_or_null("NeonLowerGlow") is OmniLight3D, "offline_neon_lower_light")
		var offline_body_light := stage.head_style.get_node("NeonBodyGlow") as OmniLight3D
		check(offline_body_light.light_energy >= 2.2 and offline_body_light.omni_range >= 4.0, "offline_real_neon_light")

	if stage != null and is_instance_valid(stage):
		stage.queue_free()
		for i in range(4):
			await process_frame

	var heart_menu: Variant = load("res://scenes/ui/main_menu_v2.tscn").instantiate()
	root.add_child(heart_menu)
	current_scene = heart_menu
	for i in range(20):
		await process_frame
	heart_menu._select_v2_warrior("outrage")
	heart_menu._open_v2_submenu("warriors")
	for i in range(8):
		await process_frame
	heart_menu._select_outage_skin(3)
	for i in range(10):
		await process_frame
	check(heart_menu.selected_outrage_skin == 3, "menu_heart_selected")
	check(int(ProjectSettings.get_setting("kw3d/selected_outrage_skin", -1)) == 3, "heart_runtime_setting")
	var heart_showroom := heart_menu.showroom_root.find_child("OutrageFullBody", true, false) as Node3D
	check(heart_showroom != null, "heart_showroom_outage_model")
	if heart_showroom != null:
		var showroom_heart_horn := heart_showroom.get_node("HeadRig/Horn_Left_Tip") as MeshInstance3D
		var showroom_heart_body := heart_showroom.get_node("TorsoRig/Torso_Upper") as MeshInstance3D
		check(showroom_heart_horn.position.x > -0.15, "heart_showroom_tip_moves_to_center")
		check(color_matches((showroom_heart_horn.material_override as StandardMaterial3D).albedo_color, OUTRAGE_SKINS.HEART_HORN), "heart_showroom_red_horn")
		check(color_matches((showroom_heart_body.material_override as StandardMaterial3D).albedo_color, OUTRAGE_SKINS.HEART_BODY), "heart_showroom_purple_body")
	heart_menu._launch_offline_waves()
	var heart_stage: Variant = null
	for i in range(180):
		await process_frame
		if current_scene != null and current_scene != heart_menu and current_scene.get("outrage_skin_id") != null:
			heart_stage = current_scene
			break
	check(heart_stage != null, "heart_offline_scene_loaded")
	if heart_stage != null:
		for i in range(90):
			await physics_frame
		check(heart_stage.player_warrior_id == "outrage", "heart_offline_outage_selected")
		check(heart_stage.outrage_skin_id == 3, "heart_offline_skin_id")
		check(str(heart_stage.head_style.get_meta("warrior_skin_name", "")) == "HEART", "heart_offline_metadata")
		check(color_matches(mesh_plain_color(heart_stage.head_style, "HeadRig/Horn_Left_Root"), OUTRAGE_SKINS.HEART_HORN), "heart_offline_red_horn")
		check(color_matches(mesh_plain_color(heart_stage.head_style, "HeadRig/Eye_Left"), OUTRAGE_SKINS.HEART_EYE), "heart_offline_black_eye")
		check(color_matches(mesh_plain_color(heart_stage.head_style, "TorsoRig/Torso_Upper"), OUTRAGE_SKINS.HEART_BODY), "heart_offline_purple_body")
		var offline_heart_left_tip := heart_stage.head_style.get_node("HeadRig/Horn_Left_Tip") as MeshInstance3D
		var offline_heart_right_tip := heart_stage.head_style.get_node("HeadRig/Horn_Right_Tip") as MeshInstance3D
		check(absf(offline_heart_left_tip.position.x - offline_heart_right_tip.position.x) <= 0.15, "heart_offline_horns_join")

	ProjectSettings.set_setting("kw3d/selected_warrior_id", old_warrior)
	ProjectSettings.set_setting("kw3d/selected_outrage_skin", old_skin)
	print("OUTRAGE_SKIN_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
