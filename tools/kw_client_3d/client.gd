extends Node3D

const CLIENT_VERSION := "1.4.0"
const MANIFEST_URL := "https://cab-smith-walls-spending.trycloudflare.com/kw/update_manifest.json"
const UPDATES_URL := "https://cab-smith-walls-spending.trycloudflare.com/kw/updates.json"
const WEBSITE_URL := "https://cab-smith-walls-spending.trycloudflare.com/kw/"

const C_BG := Color("07101d")
const C_NAV := Color("0d1727")
const C_PANEL := Color("111e31")
const C_PANEL_2 := Color("192942")
const C_CREAM := Color("f7f4df")
const C_MUTED := Color("91a5bd")
const C_CYAN := Color("22c8ff")
const C_MINT := Color("76efbd")
const C_PURPLE := Color("5145b8")
const C_PINK := Color("ef3f86")
const C_RED := Color("ff1849")

var showroom_time := 0.0
var camera: Camera3D
var showroom_world: Node3D
var showroom_root: Node3D
var hero_model: Node3D
var hero_head: Node3D
var hero_torso: Node3D
var hero_left_leg: Node3D
var hero_right_leg: Node3D
var hero_base_position := Vector3.ZERO
var hero_base_rotation := Vector3.ZERO
var hero_head_base_rotation := Vector3.ZERO
var hero_torso_base_rotation := Vector3.ZERO
var hero_left_leg_base_rotation := Vector3.ZERO
var hero_right_leg_base_rotation := Vector3.ZERO
var selected_warrior_id := "outrage"
var selected_warrior_skin := 0
var game_pack_loaded := false

var ui_layer: CanvasLayer
var home_page: Control
var updates_page: Control
var profile_page: Control
var status_label: Label
var version_label: Label
var progress: ProgressBar
var play_button: Button
var update_button: Button
var username_label: Label
var username_edit: LineEdit
var updates_text: RichTextLabel
var game_dir_label: Label
var home_welcome_label: Label
var hero_name_label: Label
var hero_skin_label: Label

var manifest: Dictionary = {}
var update_required := true
var current_download := ""
var game_dir := ""
var virtual_username := "KW_ROOKIE"


func _ready() -> void:
	get_window().title = "KW Client"
	_load_local_config()
	_read_game_menu_state()
	_mount_game_pack()
	_build_showroom_world()
	_build_ui()
	_refresh_profile_ui()
	_refresh_showroom_labels()
	_check_live_state.call_deferred()


func _process(delta: float) -> void:
	showroom_time += delta
	_animate_showroom(delta)


func _game_menu_state_path() -> String:
	var appdata := OS.get_environment("APPDATA").strip_edges()
	if appdata.is_empty():
		return ""
	return appdata.path_join("Godot/app_userdata/kw_Godot/main_menu_shop_state.json")


func _read_game_menu_state() -> void:
	var path := _game_menu_state_path()
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return
	var state := parsed as Dictionary
	var warrior := str(state.get("selected_warrior_id", selected_warrior_id)).strip_edges().to_lower()
	if warrior in ["outrage", "erebus", "kosas", "aevilok", "loker"]:
		selected_warrior_id = warrior
		selected_warrior_skin = maxi(0, int(state.get("selected_warrior_skin", 0)))


func _mount_game_pack() -> bool:
	if game_pack_loaded:
		return true
	var candidates: Array[String] = [game_dir.path_join("kw.pck")]
	if OS.has_feature("editor"):
		candidates.append(ProjectSettings.globalize_path("res://../../updates_site/kw/kw.pck"))
	for pack in candidates:
		if pack.is_empty() or not FileAccess.file_exists(pack):
			continue
		if ProjectSettings.load_resource_pack(pack, false):
			game_pack_loaded = true
			return true
	return false


func _build_showroom_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0D2540")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("89BEE8")
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)

	showroom_world = Node3D.new()
	showroom_world.name = "ShowroomWorld"
	add_child(showroom_world)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-28, -135, 0)
	key.light_color = Color("E6F3FF")
	key.light_energy = 1.42
	key.shadow_enabled = true
	showroom_world.add_child(key)

	_add_omni(Vector3(0.7, 1.8, -2.2), Color("53D7FF"), 7.0, 3.1)
	_add_omni(Vector3(5.8, 1.2, 0.8), Color("FF3155"), 7.0, 3.0)

	# Same showroom language as the real main menu, shifted to the right so the
	# launcher controls can live on the left without covering the selected warrior.
	_add_box(Vector3(3.25, -1.55, 1.0), Vector3(7.4, 0.10, 5.8), Color("12304A"), false)
	_add_box(Vector3(3.25, 0.35, 2.45), Vector3(7.8, 4.6, 0.10), Color("123A61"), false)
	_add_box(Vector3(0.80, 0.55, 2.36), Vector3(0.16, 3.25, 0.05), C_CYAN, false, true)
	_add_box(Vector3(5.70, 0.35, 2.36), Vector3(0.16, 3.55, 0.05), C_PINK, false, true)
	_add_box(Vector3(3.25, 1.95, 2.36), Vector3(2.9, 0.08, 0.05), Color("2478FF"), false, true)
	_add_box(Vector3(1.00, -1.38, 0.8), Vector3(0.06, 0.05, 3.6), C_CYAN, false, true)
	_add_box(Vector3(5.50, -1.38, 0.8), Vector3(0.06, 0.05, 3.6), C_PINK, false, true)

	var pedestal := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.15
	ring.outer_radius = 1.21
	pedestal.mesh = ring
	pedestal.position = Vector3(3.25, -1.47, 0.25)
	pedestal.material_override = _material(Color("42DFFF"), true, 3.2)
	pedestal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	showroom_world.add_child(pedestal)
	pedestal.set_meta("showroom_ring", true)

	var banner := Sprite3D.new()
	banner.texture = load("res://assets/kw_logo.png")
	banner.pixel_size = 0.0065
	banner.position = Vector3(5.72, 1.65, 2.28)
	banner.modulate = Color(0.55, 0.90, 1.0, 0.72)
	showroom_world.add_child(banner)

	_spawn_selected_warrior()

	camera = Camera3D.new()
	camera.position = Vector3(0.10, 0.12, -8.25 if selected_warrior_id in ["aevilok", "loker"] else -6.75)
	camera.fov = 36.0 if selected_warrior_id in ["aevilok", "loker"] else 34.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(3.15, 0.05, 0), Vector3.UP)


func _warrior_scene_path(id: String) -> String:
	return "res://scenes/prototypes/characters/%s_fullbody.tscn" % id


func _spawn_selected_warrior() -> void:
	if showroom_root != null and is_instance_valid(showroom_root):
		showroom_root.queue_free()
	showroom_root = Node3D.new()
	showroom_root.name = "SelectedWarriorShowroom"
	showroom_root.position = Vector3(3.25, 0.0, 0.0)
	showroom_root.rotation.y = -0.18
	showroom_world.add_child(showroom_root)

	var scene: PackedScene = null
	if game_pack_loaded and ResourceLoader.exists(_warrior_scene_path(selected_warrior_id)):
		scene = load(_warrior_scene_path(selected_warrior_id)) as PackedScene
	if scene == null:
		hero_model = _make_fallback_warrior(selected_warrior_id)
	else:
		hero_model = scene.instantiate() as Node3D
		if selected_warrior_id == "outrage":
			var outage_style := load("res://scripts/prototypes/outrage_skin_style.gd") as Script
			if outage_style != null:
				outage_style.call("apply", hero_model, selected_warrior_skin, 0.38)
		hero_model.set_script(null)
		var hero_materials := load("res://scripts/ui/main_menu/menu_hero_materials.gd") as Script
		if hero_materials != null:
			if selected_warrior_id in ["erebus", "kosas", "aevilok", "loker"] or (selected_warrior_id == "outrage" and selected_warrior_skin in [2, 4]):
				hero_materials.call("apply_flat_to", hero_model)
			else:
				hero_materials.call("apply_to", hero_model)
		match selected_warrior_id:
			"erebus":
				var script := load("res://scripts/prototypes/erebus_skin_style.gd") as Script
				if script != null: script.call("apply", hero_model, selected_warrior_skin)
			"kosas":
				var script := load("res://scripts/prototypes/kosas_warrior_style.gd") as Script
				if script != null: script.call("apply", hero_model)
			"aevilok":
				var script := load("res://scripts/prototypes/aevilok_warrior_style.gd") as Script
				if script != null: script.call("apply", hero_model)
			"loker":
				var script := load("res://scripts/prototypes/loker_warrior_style.gd") as Script
				if script != null: script.call("apply", hero_model)

	hero_model.position = Vector3(0, 0.10, 0)
	hero_model.scale = Vector3.ONE * (0.78 if selected_warrior_id == "aevilok" else (0.84 if selected_warrior_id == "loker" else 0.92))
	showroom_root.add_child(hero_model)
	showroom_root.scale = Vector3.ONE
	hero_head = hero_model.get_node_or_null("HeadRig") as Node3D
	hero_torso = hero_model.get_node_or_null("TorsoRig") as Node3D
	hero_left_leg = hero_model.get_node_or_null("LeftLegRig") as Node3D
	hero_right_leg = hero_model.get_node_or_null("RightLegRig") as Node3D
	hero_base_position = showroom_root.position
	hero_base_rotation = showroom_root.rotation
	if hero_head != null: hero_head_base_rotation = hero_head.rotation
	if hero_torso != null: hero_torso_base_rotation = hero_torso.rotation
	if hero_left_leg != null: hero_left_leg_base_rotation = hero_left_leg.rotation
	if hero_right_leg != null: hero_right_leg_base_rotation = hero_right_leg.rotation


func _make_fallback_warrior(_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "FallbackWarrior"
	_add_box_to(root, Vector3(0, 1.1, 0), Vector3(0.85, 0.82, 0.68), Color("971a30"))
	_add_box_to(root, Vector3(0, 0.35, 0), Vector3(0.66, 0.68, 0.50), Color("741426"))
	_add_box_to(root, Vector3(-0.25, -0.35, 0), Vector3(0.20, 0.64, 0.28), Color("4c101e"))
	_add_box_to(root, Vector3(0.25, -0.35, 0), Vector3(0.20, 0.64, 0.28), Color("4c101e"))
	_add_box_to(root, Vector3(-0.28, 1.60, 0), Vector3(0.14, 0.48, 0.14), C_RED, true)
	_add_box_to(root, Vector3(0.28, 1.60, 0), Vector3(0.14, 0.48, 0.14), C_RED, true)
	return root


func _selected_skin_name() -> String:
	if not game_pack_loaded:
		return "CLASSIC"
	var script: Script = null
	if selected_warrior_id == "outrage":
		script = load("res://scripts/prototypes/outrage_skin_style.gd") as Script
	elif selected_warrior_id == "erebus":
		script = load("res://scripts/prototypes/erebus_skin_style.gd") as Script
	if script != null and script.has_method("skin_name"):
		return str(script.call("skin_name", selected_warrior_skin)).to_upper()
	return "CLASSIC"


func _animate_showroom(_delta: float) -> void:
	if showroom_root == null or not is_instance_valid(showroom_root):
		return
	var t := showroom_time
	showroom_root.position = hero_base_position + Vector3(0, sin(t * 1.35) * 0.018, 0)
	showroom_root.rotation.y = hero_base_rotation.y + sin(t * 0.42) * 0.055
	if hero_head != null:
		hero_head.rotation = hero_head_base_rotation + Vector3(0, sin(t * 0.55) * 0.035, 0)
	if hero_torso != null:
		hero_torso.rotation = hero_torso_base_rotation + Vector3(0, 0, sin(t * 0.72) * 0.012)
	if hero_left_leg != null:
		hero_left_leg.rotation = hero_left_leg_base_rotation + Vector3(sin(t * 0.82) * 0.008, 0, 0)
	if hero_right_leg != null:
		hero_right_leg.rotation = hero_right_leg_base_rotation + Vector3(-sin(t * 0.82) * 0.008, 0, 0)
	if camera != null:
		camera.position.x = 0.10 + sin(t * 0.19) * 0.055
		camera.look_at(Vector3(3.15, 0.05 + sin(t * 0.23) * 0.015, 0), Vector3.UP)
	for child in showroom_world.get_children():
		if child.has_meta("showroom_ring"):
			child.rotation.y += 0.003


func _add_box(position_value: Vector3, size_value: Vector3, color: Color, shadow := true, emissive := false) -> MeshInstance3D:
	return _add_box_to(showroom_world, position_value, size_value, color, emissive, shadow)


func _add_box_to(parent: Node3D, position_value: Vector3, size_value: Vector3, color: Color, emissive := false, shadow := true) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	node.mesh = mesh
	node.position = position_value
	node.material_override = _material(color, emissive, 3.2 if emissive else 0.0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


func _add_omni(position_value: Vector3, color: Color, range_value: float, energy: float) -> void:
	var light := OmniLight3D.new()
	light.position = position_value
	light.light_color = color
	light.omni_range = range_value
	light.light_energy = energy
	light.shadow_enabled = false
	showroom_world.add_child(light)


func _material(color: Color, emissive := false, energy := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.78
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = energy
	return mat


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(root)

	# Readability vignette.
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.035, 0.07, 0.32)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)

	var sidebar := Panel.new()
	sidebar.position = Vector2(0, 0)
	sidebar.size = Vector2(218, 720)
	sidebar.add_theme_stylebox_override("panel", _panel_style(Color(C_NAV, 0.93), C_CYAN, 0, 2))
	root.add_child(sidebar)

	var logo := TextureRect.new()
	logo.texture = load("res://assets/kw_logo.png")
	logo.position = Vector2(24, 22)
	logo.size = Vector2(72, 66)
	logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sidebar.add_child(logo)
	var kw := _label("KW", 30, C_CREAM, true)
	kw.position = Vector2(102, 31)
	sidebar.add_child(kw)
	var sub := _label("3D SHOWROOM CLIENT", 10, C_MINT, true)
	sub.position = Vector2(28, 92)
	sidebar.add_child(sub)

	var home_nav := _nav_button("HOME", Vector2(14, 142))
	var updates_nav := _nav_button("UPDATES", Vector2(14, 202))
	var profile_nav := _nav_button("PROFILE", Vector2(14, 262))
	sidebar.add_child(home_nav)
	sidebar.add_child(updates_nav)
	sidebar.add_child(profile_nav)
	home_nav.pressed.connect(_show_page.bind("home"))
	updates_nav.pressed.connect(_show_page.bind("updates"))
	profile_nav.pressed.connect(_show_page.bind("profile"))

	var lower := _label("PLAY\nCUSTOMIZE\nUPDATE\nCONNECT\n\n// KW", 11, C_MUTED, true)
	lower.position = Vector2(28, 545)
	sidebar.add_child(lower)

	# Top profile card.
	var top_profile := Panel.new()
	top_profile.position = Vector2(930, 20)
	top_profile.size = Vector2(330, 88)
	top_profile.add_theme_stylebox_override("panel", _panel_style(Color(C_PANEL, 0.91), C_MINT, 8, 2))
	root.add_child(top_profile)
	var avatar := TextureRect.new()
	avatar.texture = load("res://assets/avatar.png")
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar.position = Vector2(12, 12)
	avatar.size = Vector2(64, 64)
	top_profile.add_child(avatar)
	username_label = _label("KW_ROOKIE", 17, C_CREAM, true)
	username_label.position = Vector2(88, 16)
	top_profile.add_child(username_label)
	var virtual_note := _label("VIRTUAL PROFILE // LOCAL ONLY", 9, C_MINT, true)
	virtual_note.position = Vector2(88, 47)
	top_profile.add_child(virtual_note)

	# Home overlay: controls stay on the left, the selected 3D warrior owns the right.
	home_page = Control.new()
	home_page.position = Vector2(236, 122)
	home_page.size = Vector2(1024, 568)
	root.add_child(home_page)
	home_welcome_label = _label("WELCOME BACK,\n%s" % virtual_username, 38, C_CREAM, true)
	home_welcome_label.position = Vector2(24, 42)
	home_page.add_child(home_welcome_label)
	var tagline := _label("SELECTED LOADOUT // LIVE 3D SHOWROOM", 11, C_CYAN, true)
	tagline.position = Vector2(28, 166)
	home_page.add_child(tagline)
	var subline := _label("Your current warrior is loaded directly from the KW game profile.", 12, C_MUTED, false)
	subline.position = Vector2(28, 195)
	home_page.add_child(subline)

	var status_panel := Panel.new()
	status_panel.position = Vector2(22, 300)
	status_panel.size = Vector2(570, 160)
	status_panel.add_theme_stylebox_override("panel", _panel_style(Color(C_PANEL, 0.86), C_CYAN, 10, 2))
	home_page.add_child(status_panel)
	status_label = _label("CHECKING LIVE BUILD...", 19, C_MINT, true)
	status_label.position = Vector2(22, 20)
	status_panel.add_child(status_label)
	version_label = _label("LOCAL --   //   SERVER --", 11, C_MUTED, true)
	version_label.position = Vector2(24, 56)
	status_panel.add_child(version_label)
	game_dir_label = _label("GAME FOLDER: --", 9, C_MUTED, false)
	game_dir_label.position = Vector2(24, 84)
	status_panel.add_child(game_dir_label)
	progress = ProgressBar.new()
	progress.position = Vector2(24, 119)
	progress.size = Vector2(522, 14)
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background", _panel_style(C_NAV, C_NAV, 4, 0))
	progress.add_theme_stylebox_override("fill", _panel_style(C_CYAN, C_CYAN, 4, 0))
	status_panel.add_child(progress)

	play_button = _big_button("PLAY", C_CYAN, C_BG)
	play_button.position = Vector2(22, 480)
	play_button.size = Vector2(270, 64)
	play_button.disabled = true
	play_button.pressed.connect(_play_game)
	home_page.add_child(play_button)
	update_button = _big_button("CHECK", C_PINK, C_CREAM)
	update_button.position = Vector2(312, 480)
	update_button.size = Vector2(270, 64)
	update_button.pressed.connect(_update_or_check)
	home_page.add_child(update_button)

	var hero_card := Panel.new()
	hero_card.position = Vector2(665, 423)
	hero_card.size = Vector2(325, 120)
	hero_card.add_theme_stylebox_override("panel", _panel_style(Color(C_NAV, 0.74), C_MINT, 8, 1))
	home_page.add_child(hero_card)
	var selected_meta := _label("SELECTED WARRIOR", 9, C_MINT, true)
	selected_meta.position = Vector2(18, 12)
	hero_card.add_child(selected_meta)
	hero_name_label = _label(selected_warrior_id.to_upper(), 24, C_CREAM, true)
	hero_name_label.position = Vector2(18, 32)
	hero_card.add_child(hero_name_label)
	hero_skin_label = _label("SKIN // %s" % _selected_skin_name(), 10, C_CYAN, true)
	hero_skin_label.position = Vector2(20, 78)
	hero_card.add_child(hero_skin_label)

	# Updates page.
	updates_page = Control.new()
	updates_page.position = Vector2(246, 130)
	updates_page.size = Vector2(1004, 550)
	updates_page.visible = false
	root.add_child(updates_page)
	var updates_panel := Panel.new()
	updates_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	updates_panel.add_theme_stylebox_override("panel", _panel_style(Color(C_NAV, 0.91), C_PINK, 12, 2))
	updates_page.add_child(updates_panel)
	var up_title := _label("UPDATES // PATCH FEED", 26, C_CREAM, true)
	up_title.position = Vector2(28, 22)
	updates_panel.add_child(up_title)
	updates_text = RichTextLabel.new()
	updates_text.bbcode_enabled = true
	updates_text.position = Vector2(28, 76)
	updates_text.size = Vector2(948, 440)
	updates_text.fit_content = false
	updates_text.scroll_active = true
	updates_text.add_theme_color_override("default_color", C_MUTED)
	updates_text.add_theme_font_size_override("normal_font_size", 14)
	updates_panel.add_child(updates_text)

	# Profile page.
	profile_page = Control.new()
	profile_page.position = Vector2(300, 165)
	profile_page.size = Vector2(850, 470)
	profile_page.visible = false
	root.add_child(profile_page)
	var profile_panel := Panel.new()
	profile_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	profile_panel.add_theme_stylebox_override("panel", _panel_style(Color(C_NAV, 0.94), C_MINT, 14, 2))
	profile_page.add_child(profile_panel)
	var ptitle := _label("VIRTUAL PROFILE", 28, C_CREAM, true)
	ptitle.position = Vector2(34, 28)
	profile_panel.add_child(ptitle)
	var pnote := _label("Local identity only. No real account/login backend yet.", 13, C_MUTED, false)
	pnote.position = Vector2(36, 76)
	profile_panel.add_child(pnote)
	username_edit = LineEdit.new()
	username_edit.position = Vector2(36, 128)
	username_edit.size = Vector2(420, 50)
	username_edit.max_length = 24
	username_edit.placeholder_text = "Virtual username"
	username_edit.add_theme_font_size_override("font_size", 18)
	profile_panel.add_child(username_edit)
	var save_profile := _big_button("SAVE ID", C_PURPLE, C_CREAM)
	save_profile.position = Vector2(478, 128)
	save_profile.size = Vector2(170, 50)
	save_profile.pressed.connect(_save_profile)
	profile_panel.add_child(save_profile)
	var folder_button := _big_button("GAME FOLDER", C_PANEL_2, C_CREAM)
	folder_button.position = Vector2(36, 220)
	folder_button.size = Vector2(220, 48)
	folder_button.pressed.connect(_choose_game_folder)
	profile_panel.add_child(folder_button)
	var website_button := _big_button("KW WEBSITE", C_PANEL_2, C_CREAM)
	website_button.position = Vector2(276, 220)
	website_button.size = Vector2(220, 48)
	website_button.pressed.connect(func(): OS.shell_open(WEBSITE_URL))
	profile_panel.add_child(website_button)

	_show_page("home")


func _show_page(name: String) -> void:
	home_page.visible = name == "home"
	updates_page.visible = name == "updates"
	profile_page.visible = name == "profile"


func _panel_style(color: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.border_width_left = width
	box.border_width_top = width
	box.border_width_right = width
	box.border_width_bottom = width
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	return box


func _label(text_value: String, size_value: int, color: Color, bold := false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _nav_button(text_value: String, pos: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = pos
	button.size = Vector2(190, 48)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", C_CREAM)
	button.add_theme_stylebox_override("normal", _panel_style(Color(C_NAV, 0.0), C_NAV, 6, 0))
	button.add_theme_stylebox_override("hover", _panel_style(Color(C_PANEL_2, 0.9), C_CYAN, 6, 2))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(C_PURPLE, 0.8), C_PINK, 6, 2))
	return button


func _big_button(text_value: String, bg: Color, fg: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", fg)
	button.add_theme_color_override("font_hover_color", C_CREAM)
	button.add_theme_stylebox_override("normal", _panel_style(bg, bg.lightened(0.22), 8, 2))
	button.add_theme_stylebox_override("hover", _panel_style(bg.lightened(0.12), C_CREAM, 8, 2))
	button.add_theme_stylebox_override("pressed", _panel_style(bg.darkened(0.15), C_CREAM, 8, 2))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("263044"), Color("3a475c"), 8, 2))
	return button


func _config_path() -> String:
	return "user://kw_client_config.json"


func _load_local_config() -> void:
	game_dir = OS.get_executable_path().get_base_dir()
	virtual_username = _generate_username()
	# Import the previous Python client's local config once when present, so moving
	# to the live-3D client does not silently reset the user's virtual identity.
	var legacy_path := OS.get_executable_path().get_base_dir().path_join("updater_config.json")
	if FileAccess.file_exists(legacy_path):
		var legacy_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(legacy_path))
		if legacy_parsed is Dictionary:
			var legacy := legacy_parsed as Dictionary
			game_dir = str(legacy.get("game_dir", game_dir))
			virtual_username = _sanitize_username(str(legacy.get("virtual_username", virtual_username)))
	if FileAccess.file_exists(_config_path()):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_config_path()))
		if parsed is Dictionary:
			var cfg := parsed as Dictionary
			game_dir = str(cfg.get("game_dir", game_dir))
			virtual_username = _sanitize_username(str(cfg.get("virtual_username", virtual_username)))
	if not FileAccess.file_exists(game_dir.path_join("kw.exe")):
		var sibling := OS.get_executable_path().get_base_dir()
		if FileAccess.file_exists(sibling.path_join("kw.exe")):
			game_dir = sibling
	_save_local_config()


func _save_local_config() -> void:
	var file := FileAccess.open(_config_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"game_dir": game_dir, "virtual_username": virtual_username}, "  "))
		file.close()
	_write_profile_file()


func _write_profile_file() -> void:
	if game_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(game_dir)
	var path := game_dir.path_join("kw_profile.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"profile_kind": "virtual", "virtual_username": virtual_username, "real_account": false, "profile_version": 1}, "  "))
		file.close()


func _refresh_profile_ui() -> void:
	if username_label != null:
		username_label.text = virtual_username
	if username_edit != null:
		username_edit.text = virtual_username
	if game_dir_label != null:
		game_dir_label.text = "GAME FOLDER: " + game_dir
	_refresh_showroom_labels()


func _refresh_showroom_labels() -> void:
	if home_welcome_label != null:
		home_welcome_label.text = "WELCOME BACK,\n%s" % virtual_username
	if hero_name_label != null:
		hero_name_label.text = selected_warrior_id.to_upper()
	if hero_skin_label != null:
		hero_skin_label.text = "SKIN // %s" % _selected_skin_name()


func _sanitize_username(value: String) -> String:
	var result := ""
	for i in range(value.length()):
		var c := value.substr(i, 1)
		var code := c.unicode_at(0)
		if (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or c in ["_", "-"]:
			result += c
		elif c in [" ", "."]:
			result += "_"
		if result.length() >= 24:
			break
	result = result.strip_edges().trim_prefix("_").trim_suffix("_")
	return result if result.length() >= 3 else "KW_ROOKIE"


func _generate_username() -> String:
	var left := ["NEON", "VOID", "PIXEL", "VOLT", "RIFT", "NOVA", "CYBER", "NIGHT"]
	var right := ["CLAW", "CORE", "SHIFT", "GHOST", "WING", "RIDER", "PULSE", "DRIFT"]
	return "%s_%s_%03d" % [left.pick_random(), right.pick_random(), randi_range(100, 999)]


func _save_profile() -> void:
	virtual_username = _sanitize_username(username_edit.text)
	_save_local_config()
	_refresh_profile_ui()
	status_label.text = "VIRTUAL ID SAVED"


func _choose_game_folder() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.title = "Choose KW game folder"
	dialog.size = Vector2i(900, 620)
	dialog.dir_selected.connect(func(path: String):
		game_dir = path
		_save_local_config()
		if not game_pack_loaded and _mount_game_pack():
			_read_game_menu_state()
			_spawn_selected_warrior()
		_refresh_profile_ui()
		_check_live_state.call_deferred()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	ui_layer.add_child(dialog)
	dialog.popup_centered()


func _fetch_json(url: String) -> Dictionary:
	var request := HTTPRequest.new()
	add_child(request)
	var err := request.request(url, PackedStringArray(["ngrok-skip-browser-warning: 1", "User-Agent: KWClient/%s" % CLIENT_VERSION]))
	if err != OK:
		request.queue_free()
		return {}
	var result: Array = await request.request_completed
	request.queue_free()
	if int(result[1]) < 200 or int(result[1]) >= 300:
		return {}
	var parsed: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	return parsed as Dictionary if parsed is Dictionary else {}


func _check_live_state() -> void:
	status_label.text = "CHECKING LIVE BUILD..."
	update_button.disabled = true
	play_button.disabled = true
	progress.value = 0
	manifest = await _fetch_json(MANIFEST_URL)
	if manifest.is_empty():
		status_label.text = "UPDATE SERVICE OFFLINE"
		version_label.text = "CLIENT %s   //   SERVER --" % CLIENT_VERSION
		update_button.text = "RETRY"
		update_button.disabled = false
		return
	var remote_version := str(manifest.get("version", "--"))
	var local_version := "0.0.0"
	var version_path := game_dir.path_join("game_version.txt")
	if FileAccess.file_exists(version_path):
		local_version = FileAccess.get_file_as_string(version_path).strip_edges()
	var exe_ok := _hash_matches(game_dir.path_join("kw.exe"), str(manifest.get("exe_sha256", "")))
	var pck_ok := _hash_matches(game_dir.path_join("kw.pck"), str(manifest.get("pck_sha256", "")))
	update_required = not exe_ok or not pck_ok
	version_label.text = "LOCAL %s   //   SERVER %s" % [local_version, remote_version]
	status_label.text = "UPDATE READY" if update_required else "READY TO PLAY"
	update_button.text = "UPDATE" if update_required else "CHECK"
	update_button.disabled = false
	play_button.disabled = update_required
	progress.value = 0 if update_required else 100
	_load_updates.call_deferred()


func _load_updates() -> void:
	var feed := await _fetch_json(UPDATES_URL)
	if updates_text == null:
		return
	var rows := feed.get("updates", []) as Array
	var bb := ""
	for row in rows:
		if not row is Dictionary:
			continue
		var item := row as Dictionary
		bb += "[color=#76efbd][font_size=18][b]%s[/b][/font_size][/color]  [color=#91a5bd]%s[/color]\n" % [str(item.get("version", "KW UPDATE")), str(item.get("date", ""))]
		bb += "[font_size=22][b]%s[/b][/font_size]\n" % str(item.get("title", "UPDATE"))
		for line in item.get("items", []) as Array:
			bb += "[color=#22c8ff]◆[/color]  %s\n" % str(line)
		bb += "\n"
	updates_text.text = bb


func _hash_matches(path: String, expected: String) -> bool:
	if expected.is_empty() or not FileAccess.file_exists(path):
		return false
	return FileAccess.get_sha256(path).to_lower() == expected.to_lower()


func _update_or_check() -> void:
	if update_required and not manifest.is_empty():
		_run_update.call_deferred()
	else:
		_check_live_state.call_deferred()


func _run_update() -> void:
	update_button.disabled = true
	play_button.disabled = true
	status_label.text = "PREPARING VERIFIED UPDATE..."
	DirAccess.make_dir_recursive_absolute(game_dir)
	var files := [
		{"name": "kw.exe", "url": str(manifest.get("exe_url", "")), "hash": str(manifest.get("exe_sha256", ""))},
		{"name": "kw.pck", "url": str(manifest.get("pck_url", "")), "hash": str(manifest.get("pck_sha256", ""))},
	]
	for i in range(files.size()):
		var info := files[i] as Dictionary
		var target := game_dir.path_join(str(info.name))
		if _hash_matches(target, str(info.hash)):
			continue
		status_label.text = "DOWNLOADING %s..." % str(info.name).to_upper()
		progress.value = float(i) / float(files.size()) * 100.0
		var ok := await _download_verified(str(info.url), target, str(info.hash))
		if not ok:
			status_label.text = "UPDATE FAILED // %s" % str(info.name).to_upper()
			update_button.disabled = false
			return
		progress.value = float(i + 1) / float(files.size()) * 100.0
	var version_file := FileAccess.open(game_dir.path_join("game_version.txt"), FileAccess.WRITE)
	if version_file != null:
		version_file.store_string(str(manifest.get("version", "unknown")))
		version_file.close()
	_write_profile_file()
	if not game_pack_loaded and _mount_game_pack():
		_read_game_menu_state()
		_spawn_selected_warrior()
		_refresh_showroom_labels()
	status_label.text = "UPDATE VERIFIED // READY"
	update_required = false
	play_button.disabled = false
	update_button.text = "CHECK"
	update_button.disabled = false
	progress.value = 100


func _download_verified(url: String, target: String, expected_hash: String) -> bool:
	if url.is_empty() or expected_hash.is_empty():
		return false
	var temp := target + ".download"
	DirAccess.remove_absolute(temp)
	var request := HTTPRequest.new()
	request.download_file = temp
	add_child(request)
	var err := request.request(url, PackedStringArray(["ngrok-skip-browser-warning: 1", "User-Agent: KWClient/%s" % CLIENT_VERSION]))
	if err != OK:
		request.queue_free()
		return false
	var result: Array = await request.request_completed
	request.queue_free()
	if int(result[1]) < 200 or int(result[1]) >= 300:
		DirAccess.remove_absolute(temp)
		return false
	if not _hash_matches(temp, expected_hash):
		DirAccess.remove_absolute(temp)
		return false
	if FileAccess.file_exists(target):
		var backup := target + ".old"
		DirAccess.remove_absolute(backup)
		if DirAccess.rename_absolute(target, backup) != OK:
			DirAccess.remove_absolute(temp)
			return false
		if DirAccess.rename_absolute(temp, target) != OK:
			DirAccess.rename_absolute(backup, target)
			return false
		DirAccess.remove_absolute(backup)
	else:
		if DirAccess.rename_absolute(temp, target) != OK:
			return false
	return true


func _play_game() -> void:
	if update_required:
		status_label.text = "UPDATE REQUIRED BEFORE PLAY"
		return
	var exe := game_dir.path_join("kw.exe")
	if not FileAccess.file_exists(exe):
		status_label.text = "GAME FILES MISSING"
		return
	_save_local_config()
	OS.create_process(exe, PackedStringArray(["--", "--kw-name=%s" % virtual_username]))
	get_tree().quit()
