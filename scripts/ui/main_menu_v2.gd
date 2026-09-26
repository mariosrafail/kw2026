extends Control
## Main menu V2 presentation layer.
## The preserved legacy scene owns the game/menu flows.
## This scene only replaces the main-screen presentation and renders the real 3D Outrage model.

const LEGACY_SCENE := preload("res://scenes/ui/main_menu_legacy.tscn")
const OUTRAGE_SCENE := preload("res://scenes/prototypes/characters/outrage_fullbody.tscn")
const EREBUS_SCENE := preload("res://scenes/prototypes/characters/erebus_fullbody.tscn")
const KOSAS_SCENE := preload("res://scenes/prototypes/characters/kosas_fullbody.tscn")
const AEVILOK_SCENE := preload("res://scenes/prototypes/characters/aevilok_fullbody.tscn")
const LOKER_SCENE := preload("res://scenes/prototypes/characters/loker_fullbody.tscn")
const OUTRAGE_SKINS := preload("res://scripts/prototypes/outrage_skin_style.gd")
const EREBUS_SKINS := preload("res://scripts/prototypes/erebus_skin_style.gd")
const KOSAS_STYLE := preload("res://scripts/prototypes/kosas_warrior_style.gd")
const AEVILOK_STYLE := preload("res://scripts/prototypes/aevilok_warrior_style.gd")
const LOKER_STYLE := preload("res://scripts/prototypes/loker_warrior_style.gd")
const HERO_MATERIALS := preload("res://scripts/ui/main_menu/menu_hero_materials.gd")
const OUTRAGE_STATUE := preload("res://scripts/ui/main_menu/outrage_statue_style.gd")
const CITY_STAGE := preload("res://scripts/ui/main_menu/menu_city_stage.gd")
const WEAPON_SHOWROOM := preload("res://scripts/ui/main_menu/menu_weapon_showroom.gd")
const RETICLE_SETTINGS := preload("res://scripts/kw3d/reticle_settings.gd")
const PIXEL_FONT := preload("res://assets/fonts/pixel_operator/PixelOperator.ttf")
const PIXEL_FONT_BOLD := preload("res://assets/fonts/pixel_operator/PixelOperator-Bold.ttf")

const CLR_BG := Color("050814")
const CLR_PANEL := Color(0.025, 0.04, 0.09, 0.92)
const CLR_PANEL_HOVER := Color(0.045, 0.10, 0.17, 0.97)
const CLR_CYAN := Color("4CEBFF")
const CLR_BLUE := Color("2478FF")
const CLR_MAGENTA := Color("FF247F")
const CLR_TEXT := Color("EAF7FF")
const CLR_MUTED := Color("7F9CB8")

var legacy: Control
var presentation: Control
var hero_viewport: SubViewport
var hero: Node3D
var hero_head: Node3D
var hero_torso: Node3D
var hero_left_leg: Node3D
var hero_right_leg: Node3D
var hero_camera: Camera3D
var hero_surface: TextureRect
var hero_panel: Control
var main_rail: Panel
var hero_tag: Label
var hero_strap: Label

var submenu_layer: Control
var submenu_panel: PanelContainer
var submenu_title: Label
var submenu_header_meta: Label
var submenu_body: HBoxContainer
var submenu_selector_panel: PanelContainer
var submenu_selector: VBoxContainer
var submenu_showroom_panel: PanelContainer
var submenu_info_panel: PanelContainer
var submenu_info_title: Label
var submenu_info_body: Label
var submenu_settings_panel: PanelContainer
var submenu_settings_grid: GridContainer
var submenu_back_button: Button
var active_submenu := ""

var showroom_surface: TextureRect
var showroom_viewport: SubViewport
var showroom_world: Node3D
var showroom_root: Node3D
var showroom_camera: Camera3D
var showroom_dragging := false
var showroom_last_mouse := Vector2.ZERO
var showroom_yaw := -0.38
var showroom_pitch := -0.05
var selected_showroom_weapon := "ak47"
var selected_ak_skin := 0
var selected_kar_skin := 0
var selected_showroom_warrior := "outrage"
var selected_outrage_skin := 0
var selected_erebus_skin := 0

var settings_music_slider: HSlider
var settings_sfx_slider: HSlider
var settings_particles_button: Button
var settings_shake_button: Button
var settings_reticle_option: OptionButton
var settings_reticle_size_slider: HSlider
var settings_reticle_png_button: Button
var settings_reticle_png_label: Label
var settings_reticle_dialog: FileDialog

var loading_overlay_v2: Control
var loading_label_v2: Label
var loading_bar_v2: ColorRect
var loading_tween_v2: Tween

var hero_base_position := Vector3.ZERO
var head_base_rotation := Vector3.ZERO
var torso_base_rotation := Vector3.ZERO
var left_leg_base_rotation := Vector3.ZERO
var right_leg_base_rotation := Vector3.ZERO
var camera_base_position := Vector3.ZERO
var camera_target := Vector3(0.72, 0.72, 0.35)
var hero_base_rotation := Vector3.ZERO

var play_button: Button
var offline_button: Button
var wallet_label: Label
var status_label: Label
var time := 0.0
var hide_until := 0.0
var presentation_was_visible := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	legacy = LEGACY_SCENE.instantiate() as Control
	legacy.name = "LegacyMainMenu"
	add_child(legacy)

	_build_presentation()
	call_deferred("_finish_setup")
	set_process(true)

func _finish_setup() -> void:
	var legacy_skin := 0
	if legacy != null and str(legacy.get("selected_warrior_id")).strip_edges().to_lower() == "outrage":
		legacy_skin = int(legacy.get("selected_warrior_skin"))
	selected_outrage_skin = clampi(
		int(ProjectSettings.get_setting("kw3d/selected_outrage_skin", legacy_skin)),
		0,
		OUTRAGE_SKINS.skin_count() - 1
	)
	selected_erebus_skin = clampi(
		int(ProjectSettings.get_setting("kw3d/selected_erebus_skin", 0)),
		0,
		EREBUS_SKINS.skin_count() - 1
	)
	_sync_selected_warrior_from_legacy()
	selected_ak_skin = clampi(
		int(ProjectSettings.get_setting("kw3d/selected_ak_skin", 0)),
		0,
		WEAPON_SHOWROOM.skin_count("ak47") - 1
	)
	selected_kar_skin = clampi(
		int(ProjectSettings.get_setting("kw3d/selected_kar_skin", 0)),
		0,
		WEAPON_SHOWROOM.skin_count("kar") - 1
	)
	_sync_presentation_visibility()
	if play_button != null and presentation.visible:
		play_button.grab_focus()

func _process(delta: float) -> void:
	time += delta
	_sync_presentation_visibility()
	if presentation_was_visible and active_submenu.is_empty():
		_animate_hero()
	_update_showroom(delta)
	_update_loading_fx()
	_sync_legacy_meta()

func _sync_presentation_visibility() -> void:
	if legacy == null or presentation == null:
		return

	var screen_main := legacy.get_node_or_null("Screens/ScreenMain") as Control
	var active := screen_main != null and screen_main.visible and time >= hide_until
	# Settings is an overlay: ScreenMain deliberately stays visible underneath it.
	for screen_name in ["ScreenOptions", "ScreenWarriors", "ScreenWeapons"]:
		var screen := legacy.get_node_or_null("Screens/" + screen_name) as Control
		if screen != null and screen.visible:
			active = false
	if legacy.get("_play_lobby_transition_running") == true:
		active = false

	var lobby_ctrl: Variant = legacy.get("_lobby_overlay_ctrl")
	if lobby_ctrl != null and lobby_ctrl.has_method("is_visible") and lobby_ctrl.call("is_visible") == true:
		active = false

	var confirm_ui: Variant = legacy.get("_confirm_overlay_ui")
	if confirm_ui is Control and (confirm_ui as Control).visible:
		active = false

	var offline_ui: Variant = legacy.get("_offline_test_overlay")
	if offline_ui is Control and (offline_ui as Control).visible:
		active = false

	var auth_ui: Variant = legacy.get("_auth_overlay")
	if auth_ui is Control and (auth_ui as Control).visible:
		active = false

	presentation.visible = active
	# The legacy username and other raised controls must not paint over the new screen.
	legacy.visible = not active
	if hero_viewport != null:
		hero_viewport.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if active and active_submenu.is_empty() else SubViewport.UPDATE_DISABLED
		)
	if showroom_viewport != null:
		showroom_viewport.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if active and active_submenu in ["guns", "warriors"] else SubViewport.UPDATE_DISABLED
		)

	if active and not presentation_was_visible and play_button != null:
		play_button.call_deferred("grab_focus")
	presentation_was_visible = active

func _sync_legacy_meta() -> void:
	if legacy == null or not presentation_was_visible:
		return
	if wallet_label != null:
		var coins := legacy.get_node_or_null("%CoinsLabel") as Label
		var clk := legacy.get_node_or_null("%ClkLabel") as Label
		var left := coins.text if coins != null else "COINS: --"
		var right := clk.text if clk != null else "CLK: --"
		wallet_label.text = left.to_upper() + "   //   " + right.to_upper()

func _build_presentation() -> void:
	presentation = Control.new()
	presentation.name = "MainPresentationV2"
	presentation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	presentation.mouse_filter = Control.MOUSE_FILTER_STOP
	presentation.z_index = 950
	add_child(presentation)

	_build_background()
	_build_hero_view()
	_build_left_panel()
	_build_edge_details()
	_build_submenu_layer()
	_build_loading_overlay_v2()

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.name = "Atmosphere"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.color = Color.WHITE

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

float grid_line(float v, float count, float width) {
	float f = abs(fract(v * count) - 0.5);
	return 1.0 - smoothstep(width, width + 0.02, f);
}

void fragment() {
	vec2 uv = UV;
		vec3 left_col = vec3(0.007, 0.012, 0.021);
		vec3 right_col = vec3(0.010, 0.016, 0.028);
	vec3 col = mix(left_col, right_col, smoothstep(0.25, 1.0, uv.x));

	float cyan_glow = exp(-distance(uv, vec2(0.70, 0.28)) * 6.0);
	float magenta_glow = exp(-distance(uv, vec2(0.92, 0.60)) * 7.0);
		col += vec3(0.00, 0.12, 0.19) * cyan_glow * 0.34;
		col += vec3(0.26, 0.00, 0.10) * magenta_glow * 0.32;

	float gx = grid_line(uv.x + TIME * 0.0015, 32.0, 0.465);
	float gy = grid_line(uv.y, 18.0, 0.465);
	float grid = max(gx, gy) * 0.035;
		col += vec3(0.05, 0.20, 0.28) * grid * smoothstep(0.32, 1.0, uv.x);

	float scan = 0.010 * sin((uv.y * 360.0) + TIME * 1.6);
	col += vec3(scan);

	float vignette = smoothstep(0.92, 0.30, distance(uv, vec2(0.52)));
	col *= 0.70 + 0.30 * vignette;

	COLOR = vec4(col, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	bg.material = material
	presentation.add_child(bg)

	var left_veil := ColorRect.new()
	left_veil.name = "LeftVeil"
	left_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_veil.anchor_left = 0.0
	left_veil.anchor_top = 0.0
	left_veil.anchor_right = 0.39
	left_veil.anchor_bottom = 1.0
	left_veil.color = Color(0.002, 0.004, 0.010, 0.74)
	presentation.add_child(left_veil)

	# Pixel/voxel skyline silhouettes behind the UI.
	var blocks := [
		[0.00, 0.72, 0.055, 0.28, Color(0.02,0.08,0.15,0.52)],
		[0.055, 0.80, 0.035, 0.20, Color(0.02,0.11,0.17,0.48)],
		[0.090, 0.68, 0.048, 0.32, Color(0.03,0.05,0.14,0.48)],
		[0.138, 0.77, 0.025, 0.23, Color(0.08,0.02,0.12,0.42)],
		[0.163, 0.61, 0.060, 0.39, Color(0.025,0.05,0.13,0.42)],
		[0.223, 0.75, 0.032, 0.25, Color(0.03,0.08,0.14,0.40)],
	]
	for entry in blocks:
		var block := ColorRect.new()
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.anchor_left = float(entry[0])
		block.anchor_top = float(entry[1])
		block.anchor_right = float(entry[0]) + float(entry[2])
		block.anchor_bottom = float(entry[1]) + float(entry[3])
		block.color = entry[4]
		presentation.add_child(block)

func _build_left_panel() -> void:
	var rail := Panel.new()
	main_rail = rail
	rail.name = "MenuRail"
	rail.anchor_left = 0.028
	rail.anchor_top = 0.035
	rail.anchor_right = 0.350
	rail.anchor_bottom = 0.965
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_theme_stylebox_override("panel", _rail_style())
	presentation.add_child(rail)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 19)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 19)
	margin.add_theme_constant_override("margin_bottom", 13)
	rail.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(box)

	var title := Label.new()
	title.text = "KW"
	title.add_theme_font_override("font", PIXEL_FONT_BOLD)
	title.add_theme_font_size_override("font_size", 41)
	title.add_theme_color_override("font_color", CLR_TEXT)
	title.add_theme_color_override("font_shadow_color", Color(0.0,0.65,1.0,0.48))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	box.add_child(title)

	var online := Label.new()
	online.text = "ONLINE"
	online.add_theme_font_override("font", PIXEL_FONT_BOLD)
	online.add_theme_font_size_override("font_size", 18)
	online.add_theme_color_override("font_color", CLR_CYAN)
	online.add_theme_constant_override("letter_spacing", 4)
	box.add_child(online)

	hero_strap = Label.new()
	hero_strap.text = "OUTRAGE // LIVE COMBAT SYSTEM"
	hero_strap.add_theme_font_override("font", PIXEL_FONT)
	hero_strap.add_theme_font_size_override("font_size", 8)
	hero_strap.add_theme_color_override("font_color", CLR_MUTED)
	box.add_child(hero_strap)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(CLR_CYAN,0.48)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(divider)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0,2)
	box.add_child(spacer)

	play_button = _make_voxel_button("FIGHT", "PlayButton", true, false, false, Color.TRANSPARENT, 1)
	box.add_child(play_button)
	offline_button = _make_voxel_button("OFFLINE TESTING", "", false, false, false, CLR_BLUE, 2)
	offline_button.pressed.connect(_launch_offline_waves)
	box.add_child(offline_button)
	var combat_spacer := Control.new()
	combat_spacer.custom_minimum_size = Vector2(0, 2)
	combat_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(combat_spacer)
	var warriors_button := _make_voxel_button("WARRIORS", "", false, false, false, Color.TRANSPARENT, 3)
	warriors_button.pressed.connect(func() -> void: _open_v2_submenu("warriors"))
	box.add_child(warriors_button)
	var guns_button := _make_voxel_button("GUNS", "", false, false, false, Color.TRANSPARENT, 4)
	guns_button.pressed.connect(func() -> void: _open_v2_submenu("guns"))
	box.add_child(guns_button)
	var settings_button := _make_voxel_button("SETTINGS", "", false, false, false, Color.TRANSPARENT, 5)
	settings_button.pressed.connect(func() -> void: _open_v2_submenu("settings"))
	box.add_child(settings_button)
	var quit_button := _make_voxel_button("I HATE THIS GAME", "ExitButton", false, true, false, Color.TRANSPARENT, 6)
	quit_button.name = "QuitButtonV2"
	box.add_child(quit_button)

	var flex := Control.new()
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	flex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(flex)

	wallet_label = Label.new()
	wallet_label.text = "COINS: --   //   CLK: --"
	wallet_label.add_theme_font_override("font", PIXEL_FONT)
	wallet_label.add_theme_font_size_override("font_size", 8)
	wallet_label.add_theme_color_override("font_color", Color(CLR_TEXT,0.70))
	box.add_child(wallet_label)

	status_label = Label.new()
	status_label.text = "3D HERO LINK // READY"
	status_label.add_theme_font_override("font", PIXEL_FONT)
	status_label.add_theme_font_size_override("font_size", 7)
	status_label.add_theme_color_override("font_color", Color(CLR_CYAN,0.62))
	box.add_child(status_label)

func _build_hero_view() -> void:
	var hero_panel_node := Control.new()
	hero_panel = hero_panel_node
	hero_panel_node.name = "HeroStage"
	hero_panel_node.anchor_left = 0.0
	hero_panel_node.anchor_top = 0.0
	hero_panel_node.anchor_right = 1.0
	hero_panel_node.anchor_bottom = 1.0
	hero_panel_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	presentation.add_child(hero_panel_node)

	# Render at display resolution, independently of the 640x360 pixel-art UI canvas.
	hero_surface = TextureRect.new()
	hero_surface.name = "HeroViewportContainer"
	hero_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero_surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_surface.stretch_mode = TextureRect.STRETCH_SCALE
	hero_surface.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	hero_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_panel_node.add_child(hero_surface)

	hero_viewport = SubViewport.new()
	hero_viewport.name = "HeroViewport"
	hero_viewport.size = Vector2i(760,720)
	hero_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	hero_viewport.transparent_bg = false
	hero_viewport.own_world_3d = true
	hero_viewport.msaa_3d = Viewport.MSAA_4X
	hero_surface.add_child(hero_viewport)
	hero_surface.texture = hero_viewport.get_texture()
	hero_surface.resized.connect(_resize_hero_viewport, CONNECT_DEFERRED)
	get_viewport().size_changed.connect(_resize_hero_viewport, CONNECT_DEFERRED)
	call_deferred("_resize_hero_viewport")

	var world := Node3D.new()
	world.name = "HeroWorld"
	hero_viewport.add_child(world)

	var env_node := WorldEnvironment.new()
	env_node.name = "PortraitEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.background_color = Color("04070D")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("4C607A")
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("070B14")
	sky_material.sky_horizon_color = Color("243243")
	sky_material.ground_bottom_color = Color("050609")
	sky_material.ground_horizon_color = Color("121927")
	sky_material.sky_energy_multiplier = 0.24
	sky_material.ground_energy_multiplier = 0.12
	var reflection_sky := Sky.new()
	reflection_sky.sky_material = sky_material
	env.sky = reflection_sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.fog_enabled = true
	env.fog_light_color = Color("263A50")
	env.fog_light_energy = 0.42
	env.fog_density = 0.025
	env.fog_height = 0.2
	env.fog_height_density = 0.17
	env_node.environment = env
	world.add_child(env_node)

	var key := DirectionalLight3D.new()
	key.name = "PortraitKey"
	key.rotation_degrees = Vector3(-28, -150, 0)
	key.light_color = Color("D7E9FF")
	key.light_energy = 0.68
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 12.0
	world.add_child(key)

	var cyan := OmniLight3D.new()
	cyan.name = "PortraitFill"
	cyan.position = Vector3(-1.8, 1.2, -2.8)
	cyan.light_color = Color("6CCFFF")
	cyan.light_energy = 1.25
	cyan.omni_range = 8.0
	world.add_child(cyan)

	var pink := OmniLight3D.new()
	pink.name = "PortraitRim"
	pink.position = Vector3(4.0, 2.0, -0.3)
	pink.light_color = Color("FF334F")
	pink.light_energy = 3.1
	pink.omni_range = 7.0
	world.add_child(pink)

	var city_fill := OmniLight3D.new()
	city_fill.name = "CityFill"
	city_fill.position = Vector3(-2.8, 3.8, 4.8)
	city_fill.light_color = Color("759AC6")
	city_fill.light_energy = 1.05
	city_fill.omni_range = 13.0
	world.add_child(city_fill)

	var city_red := OmniLight3D.new()
	city_red.name = "CityRedBounce"
	city_red.position = Vector3(3.4, 1.0, 5.2)
	city_red.light_color = Color("C62B43")
	city_red.light_energy = 0.72
	city_red.omni_range = 10.0
	world.add_child(city_red)

	CITY_STAGE.build(world)

	selected_showroom_warrior = _current_warrior_id()
	_set_main_menu_hero(world, selected_showroom_warrior)

	hero_camera = Camera3D.new()
	hero_camera.name = "HeroCamera"
	hero_camera.position = Vector3(0.25, 1.16, -6.25)
	hero_camera.fov = 35.0
	hero_camera.near = 0.05
	hero_camera.current = true
	world.add_child(hero_camera)
	hero_camera.look_at(camera_target, Vector3.UP)
	camera_base_position = hero_camera.position

	# Darken the UI side while keeping the 3D city visible behind the glass panel.
	var fade := ColorRect.new()
	fade.name = "HeroBlend"
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.color = Color.WHITE
	var fade_shader := Shader.new()
	fade_shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
		float left_fade = pow(1.0 - smoothstep(0.0, 0.41, uv.x), 1.55) * 0.66;
		float bottom = smoothstep(0.78, 1.0, uv.y) * 0.18;
		float top = (1.0 - smoothstep(0.0, 0.20, uv.y)) * 0.08;
		COLOR = vec4(0.005, 0.009, 0.018, clamp(left_fade + bottom + top, 0.0, 0.78));
}
"""
	var fade_material := ShaderMaterial.new()
	fade_material.shader = fade_shader
	fade.material = fade_material
	hero_panel_node.add_child(fade)

	hero_tag = Label.new()
	hero_tag.anchor_left = 0.73
	hero_tag.anchor_top = 0.87
	hero_tag.anchor_right = 0.97
	hero_tag.anchor_bottom = 0.96
	hero_tag.text = "OUTRAGE // ONLINE"
	hero_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hero_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hero_tag.add_theme_font_override("font",PIXEL_FONT_BOLD)
	hero_tag.add_theme_font_size_override("font_size",9)
	hero_tag.add_theme_color_override("font_color",Color(CLR_TEXT,0.58))
	hero_panel_node.add_child(hero_tag)
	_update_selected_warrior_labels()

func _resize_hero_viewport() -> void:
	if hero_viewport == null or hero_surface == null or not hero_surface.is_inside_tree():
		return
	var to_pixels := get_viewport().get_stretch_transform() * hero_surface.get_global_transform_with_canvas()
	var pixel_size := hero_surface.size * to_pixels.get_scale().abs()
	if pixel_size.x < 1.0 or pixel_size.y < 1.0:
		return
	# Keep the portrait sharp without rendering a full 4K view on integrated GPUs.
	pixel_size *= minf(1.0, 1440.0 / maxf(pixel_size.x, pixel_size.y))
	var render_size := Vector2i(ceili(pixel_size.x), ceili(pixel_size.y))
	if hero_viewport.size != render_size:
		hero_viewport.size = render_size

func _animate_hero() -> void:
	if hero == null:
		return

	var breathe := sin(time * 1.45)
	var slow := sin(time * 0.58)
	var look := sin(time * 0.73 + 0.7)

	hero.position = hero_base_position + Vector3(slow * 0.006, breathe * 0.009, 0)
	hero.rotation = hero_base_rotation + Vector3(
		0.0, deg_to_rad(slow * 0.8), deg_to_rad(sin(time * 0.43) * 0.18)
	)

	if hero_head != null:
		hero_head.rotation = head_base_rotation + Vector3(
			deg_to_rad(sin(time * 0.82) * 0.65),
			deg_to_rad(look * 1.0),
			deg_to_rad(sin(time * 0.51) * 0.25)
		)
	if hero_torso != null:
		hero_torso.rotation = torso_base_rotation + Vector3(
			deg_to_rad(breathe * 0.22),
			deg_to_rad(slow * 0.30),
			deg_to_rad(sin(time * 0.67) * 0.24)
		)
	if hero_left_leg != null:
		hero_left_leg.rotation = left_leg_base_rotation + Vector3(deg_to_rad(-breathe * 0.12),0,0)
	if hero_right_leg != null:
		hero_right_leg.rotation = right_leg_base_rotation + Vector3(deg_to_rad(breathe * 0.12),0,0)

	if hero_camera != null:
		hero_camera.position = camera_base_position + Vector3(
			sin(time * 0.31) * 0.012,
			sin(time * 0.41) * 0.008,
			0
		)
		hero_camera.look_at(camera_target + Vector3(0, breathe * 0.003, 0), Vector3.UP)

func _make_voxel_button(label_text: String, legacy_unique_name: String, hot: bool = false,
		danger: bool = false, compact: bool = false, accent_override: Color = Color.TRANSPARENT,
		row_number: int = 0) -> Button:
	var button := Button.new()
	button.name = label_text.capitalize().replace(" ","") + "ButtonV2"
	button.custom_minimum_size = Vector2(0, 36 if hot else (30 if compact else 32))
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = "    " + label_text
	button.clip_contents = true
	button.add_theme_font_override("font",PIXEL_FONT_BOLD)
	button.add_theme_font_size_override("font_size", 12 if compact else (19 if hot else 14))
	button.add_theme_color_override("font_color",CLR_TEXT)
	button.add_theme_color_override("font_hover_color",Color.WHITE)
	button.add_theme_color_override("font_focus_color",Color.WHITE)

	var accent := accent_override if accent_override.a > 0.0 else (CLR_MAGENTA if danger else CLR_CYAN)
	button.add_theme_stylebox_override("normal",_button_style(CLR_PANEL,Color(accent,0.42),7))
	button.add_theme_stylebox_override("hover",_button_style(CLR_PANEL_HOVER,accent,9))
	button.add_theme_stylebox_override("focus",_button_style(CLR_PANEL_HOVER,accent,9))
	button.add_theme_stylebox_override("pressed",_button_style(Color(0.02,0.07,0.11,1.0),accent,2))

	_add_button_thumbnail(button, row_number, accent, danger)

	var stripe := ColorRect.new()
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.anchor_left = 0.0
	stripe.anchor_top = 0.0
	stripe.anchor_right = 0.0
	stripe.anchor_bottom = 1.0
	stripe.offset_left = 2
	stripe.offset_right = 7
	stripe.offset_top = 4 if compact else 5
	stripe.offset_bottom = -4 if compact else -5
	stripe.color = accent
	button.add_child(stripe)

	if row_number > 0:
		var number := Label.new()
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number.anchor_left = 0.91
		number.anchor_top = 0.0
		number.anchor_right = 1.0
		number.anchor_bottom = 1.0
		number.offset_right = -4
		number.text = "%02d\n%02d" % [row_number, row_number]
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number.add_theme_font_override("font", PIXEL_FONT)
		number.add_theme_font_size_override("font_size", 7)
		number.add_theme_color_override("font_color", Color(accent, 0.76))
		button.add_child(number)

	button.mouse_entered.connect(func(): _button_hover(button,true))
	button.mouse_exited.connect(func(): _button_hover(button,false))
	button.focus_entered.connect(func(): _button_hover(button,true))
	button.focus_exited.connect(func(): _button_hover(button,false))
	if not legacy_unique_name.is_empty():
		button.pressed.connect(func(): _activate_legacy(legacy_unique_name,label_text))
	return button

func _add_button_thumbnail(button: Button, row_number: int, accent: Color, danger: bool) -> void:
	if row_number <= 0:
		return
	var thumbnail := ColorRect.new()
	thumbnail.name = "Thumbnail"
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail.show_behind_parent = true
	thumbnail.anchor_left = 0.35
	thumbnail.anchor_top = 0.06
	thumbnail.anchor_right = 0.90
	thumbnail.anchor_bottom = 0.94
	thumbnail.color = Color.WHITE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float variant = 1.0;
uniform vec4 accent : source_color = vec4(0.3,0.8,1.0,1.0);
void fragment() {
	vec2 uv = UV;
	float sky = smoothstep(0.0, 0.9, uv.y);
	vec3 col = mix(vec3(0.015,0.028,0.045), vec3(0.035,0.055,0.075), sky);
	float skyline = 0.0;
	float b1 = step(0.50 + 0.08*sin(variant*2.1), uv.y) * step(0.10, uv.x) * step(uv.x, 0.24);
	float b2 = step(0.36 + 0.05*cos(variant*1.7), uv.y) * step(0.30, uv.x) * step(uv.x, 0.48);
	float b3 = step(0.58 - 0.03*sin(variant), uv.y) * step(0.58, uv.x) * step(uv.x, 0.76);
	float b4 = step(0.43 + 0.04*cos(variant*2.9), uv.y) * step(0.80, uv.x) * step(uv.x, 0.95);
	skyline = max(max(b1,b2), max(b3,b4));
	col = mix(col, vec3(0.006,0.010,0.016), skyline * 0.92);
	float horizon = exp(-abs(uv.y - 0.72) * 65.0);
	col += accent.rgb * horizon * 0.12;
	float beam = exp(-abs(uv.x - (0.66 + 0.05*sin(variant))) * 55.0) * smoothstep(0.9,0.2,uv.y);
	col += accent.rgb * beam * 0.12;
	float vignette = smoothstep(0.85,0.30,distance(uv,vec2(0.5)));
	col *= 0.58 + vignette*0.42;
	COLOR = vec4(col, 0.82);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("variant", float(row_number))
	material.set_shader_parameter("accent", accent if not danger else CLR_MAGENTA)
	thumbnail.material = material
	button.add_child(thumbnail)

func _launch_offline_waves() -> void:
	if legacy == null or not legacy.has_method("_launch_offline_test_room"):
		if status_label != null:
			status_label.text = "LINK ERROR // OFFLINE TESTING"
		return
	# Resolve the character again at the exact scene-transition boundary.  This
	# makes Offline Testing deterministic even if legacy state was refreshed
	# after the user picked a warrior in the V2 roster.
	selected_showroom_warrior = _current_warrior_id()
	ProjectSettings.set_setting("kw3d/selected_warrior_id", selected_showroom_warrior)
	ProjectSettings.set_setting("kw3d/selected_outrage_skin", selected_outrage_skin)
	ProjectSettings.set_setting("kw3d/selected_erebus_skin", selected_erebus_skin)
	ProjectSettings.set_setting("kw3d/selected_ak_skin", selected_ak_skin)
	ProjectSettings.set_setting("kw3d/selected_kar_skin", selected_kar_skin)
	if status_label != null:
		status_label.text = "LOADING // OFFLINE WAVES // %s" % selected_showroom_warrior.to_upper()
	_show_v2_loading("LOADING // OFFLINE WAVES // %s" % selected_showroom_warrior.to_upper(), 0.82)
	hide_until = time + 1.0
	legacy.call("_launch_offline_test_room", "waves")

func _button_hover(button: Button, active: bool) -> void:
	if not is_instance_valid(button):
		return
	button.pivot_offset = button.size * 0.5
	var target := Vector2(1.025,1.025) if active else Vector2.ONE
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button,"scale",target,0.08)

func _activate_legacy(unique_name: String, label_text: String) -> void:
	if legacy == null:
		return
	var button := legacy.get_node_or_null("%" + unique_name) as Button
	if button == null:
		if status_label != null:
			status_label.text = "LINK ERROR // " + label_text
		return

	if status_label != null:
		status_label.text = "OPENING // " + label_text
	if unique_name == "PlayButton":
		_show_v2_loading("CONNECTING // KW ONLINE", 0.78)
	hide_until = time + (0.72 if unique_name == "PlayButton" else 0.10)
	button.emit_signal("pressed")

func _button_style(bg: Color, border: Color, shadow: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 4
	style.border_color = border
	style.shadow_color = Color(0.0,0.0,0.0,0.72)
	style.shadow_size = shadow
	style.shadow_offset = Vector2(3,4)
	style.content_margin_left = 12
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _rail_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.004,0.009,0.016,0.80)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.46,0.68,0.78,0.44)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.shadow_color = Color(0,0,0,0.55)
	style.shadow_size = 18
	style.content_margin_left = 4
	style.content_margin_top = 4
	style.content_margin_right = 4
	style.content_margin_bottom = 4
	return style

func _build_edge_details() -> void:
	var top_line := ColorRect.new()
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_line.anchor_left = 0.0
	top_line.anchor_top = 0.0
	top_line.anchor_right = 1.0
	top_line.anchor_bottom = 0.0
	top_line.offset_bottom = 2
	top_line.color = Color(CLR_CYAN,0.20)
	presentation.add_child(top_line)

	var magenta_line := ColorRect.new()
	magenta_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	magenta_line.anchor_left = 0.74
	magenta_line.anchor_top = 0.0
	magenta_line.anchor_right = 1.0
	magenta_line.anchor_bottom = 0.0
	magenta_line.offset_bottom = 2
	magenta_line.color = Color(CLR_MAGENTA,0.52)
	presentation.add_child(magenta_line)

	var corner := Label.new()
	corner.anchor_left = 1.0
	corner.anchor_top = 0.0
	corner.anchor_right = 1.0
	corner.anchor_bottom = 0.0
	corner.offset_left = -150
	corner.offset_top = 10
	corner.offset_right = -12
	corner.offset_bottom = 34
	corner.text = "PEOPLE // HEROES // FIGHT"
	corner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	corner.add_theme_font_override("font",PIXEL_FONT)
	corner.add_theme_font_size_override("font_size",7)
	corner.add_theme_color_override("font_color",Color(CLR_TEXT,0.34))
	presentation.add_child(corner)

	var season_panel := PanelContainer.new()
	season_panel.name = "SeasonCard"
	season_panel.anchor_left = 0.835
	season_panel.anchor_top = 0.035
	season_panel.anchor_right = 0.975
	season_panel.anchor_bottom = 0.145
	season_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var season_style := StyleBoxFlat.new()
	season_style.bg_color = Color(0.006, 0.022, 0.035, 0.68)
	season_style.border_width_left = 1
	season_style.border_width_top = 1
	season_style.border_width_right = 1
	season_style.border_width_bottom = 1
	season_style.border_color = Color(CLR_CYAN, 0.34)
	season_style.content_margin_left = 8
	season_style.content_margin_top = 6
	season_style.content_margin_right = 8
	season_style.content_margin_bottom = 6
	season_panel.add_theme_stylebox_override("panel", season_style)
	presentation.add_child(season_panel)
	var season := Label.new()
	season.text = "SEASON 01\nA BIGGER FIGHT AWAITS"
	season.add_theme_font_override("font", PIXEL_FONT)
	season.add_theme_font_size_override("font_size", 6)
	season.add_theme_color_override("font_color", Color(CLR_CYAN, 0.72))
	season.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	season_panel.add_child(season)

	var system_label := Label.new()
	system_label.name = "OutrageSystemSign"
	system_label.anchor_left = 0.905
	system_label.anchor_top = 0.31
	system_label.anchor_right = 0.985
	system_label.anchor_bottom = 0.64
	system_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	system_label.text = "OUTRAGE\n\nLIVE\nCOMBAT\nSYSTEM"
	system_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	system_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	system_label.add_theme_font_override("font", PIXEL_FONT_BOLD)
	system_label.add_theme_font_size_override("font_size", 7)
	system_label.add_theme_color_override("font_color", Color(0.65, 0.77, 0.90, 0.44))
	presentation.add_child(system_label)

	var slogan := Label.new()
	slogan.name = "MenuSlogan"
	slogan.anchor_left = 0.70
	slogan.anchor_top = 0.89
	slogan.anchor_right = 0.86
	slogan.anchor_bottom = 0.97
	slogan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slogan.text = "SMALL BATTLES.\nBIGGER WARRIORS."
	slogan.add_theme_font_override("font", PIXEL_FONT)
	slogan.add_theme_font_size_override("font_size", 6)
	slogan.add_theme_color_override("font_color", Color(CLR_CYAN, 0.46))
	slogan.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	presentation.add_child(slogan)

func _build_submenu_layer() -> void:
	submenu_layer = Control.new()
	submenu_layer.name = "MenuSubmenuV2"
	submenu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	submenu_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	submenu_layer.clip_contents = true
	submenu_layer.visible = false
	submenu_layer.z_index = 2100
	presentation.add_child(submenu_layer)

	var backdrop := ColorRect.new()
	backdrop.name = "SubmenuBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.color = Color.WHITE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
		vec3 col = mix(vec3(0.018,0.050,0.085), vec3(0.050,0.026,0.090), uv.x);
		float cyan = exp(-distance(uv, vec2(0.72,0.30))*7.0);
		float red = exp(-distance(uv, vec2(0.88,0.72))*8.0);
		float blue = exp(-distance(uv, vec2(0.24,0.72))*6.5);
		col += vec3(0.00,0.45,0.72)*cyan*0.42;
		col += vec3(0.70,0.02,0.28)*red*0.34;
		col += vec3(0.06,0.18,0.58)*blue*0.34;
		float scan = 0.006*sin(uv.y*720.0 + TIME*2.0);
		col += vec3(scan);
		float vignette = smoothstep(0.92,0.28,distance(uv,vec2(0.5)));
		col *= 0.80 + vignette*0.20;
		COLOR = vec4(col,1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	backdrop.material = material
	submenu_layer.add_child(backdrop)

	submenu_panel = PanelContainer.new()
	submenu_panel.name = "SubmenuFrame"
	submenu_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	submenu_panel.offset_left = 8.0
	submenu_panel.offset_top = 8.0
	submenu_panel.offset_right = -8.0
	submenu_panel.offset_bottom = -8.0
	submenu_panel.add_theme_stylebox_override("panel", _glass_panel_style(CLR_CYAN, 0.86))
	submenu_layer.add_child(submenu_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 8)
	submenu_panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 5)
	margin.add_child(outer)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 27)
	header.add_theme_constant_override("separation", 7)
	outer.add_child(header)

	submenu_back_button = _make_submenu_button("< BACK", CLR_CYAN, false)
	submenu_back_button.custom_minimum_size = Vector2(78, 25)
	submenu_back_button.pressed.connect(_close_v2_submenu)
	header.add_child(submenu_back_button)

	submenu_title = Label.new()
	submenu_title.text = "SYSTEM"
	submenu_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	submenu_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	submenu_title.add_theme_font_override("font", PIXEL_FONT_BOLD)
	submenu_title.add_theme_font_size_override("font_size", 20)
	submenu_title.add_theme_color_override("font_color", CLR_TEXT)
	submenu_title.add_theme_color_override("font_shadow_color", Color(CLR_CYAN, 0.35))
	submenu_title.add_theme_constant_override("shadow_offset_x", 2)
	submenu_title.add_theme_constant_override("shadow_offset_y", 2)
	header.add_child(submenu_title)

	submenu_header_meta = Label.new()
	submenu_header_meta.text = "KW // LIVE INTERFACE\nDRAG 3D VIEW TO ROTATE"
	submenu_header_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	submenu_header_meta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	submenu_header_meta.add_theme_font_override("font", PIXEL_FONT)
	submenu_header_meta.add_theme_font_size_override("font_size", 6)
	submenu_header_meta.add_theme_color_override("font_color", Color(CLR_CYAN, 0.56))
	header.add_child(submenu_header_meta)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(CLR_CYAN, 0.32)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(divider)

	submenu_body = HBoxContainer.new()
	submenu_body.name = "SubmenuBody"
	submenu_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	submenu_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	submenu_body.add_theme_constant_override("separation", 5)
	outer.add_child(submenu_body)

	submenu_selector_panel = PanelContainer.new()
	submenu_selector_panel.name = "SelectorPanel"
	submenu_selector_panel.custom_minimum_size = Vector2(96, 0)
	submenu_selector_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	submenu_selector_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	submenu_selector_panel.size_flags_stretch_ratio = 0.86
	submenu_selector_panel.clip_contents = true
	submenu_selector_panel.add_theme_stylebox_override("panel", _glass_panel_style(CLR_CYAN, 0.68))
	submenu_body.add_child(submenu_selector_panel)
	var selector_margin := MarginContainer.new()
	selector_margin.add_theme_constant_override("margin_left", 6)
	selector_margin.add_theme_constant_override("margin_top", 6)
	selector_margin.add_theme_constant_override("margin_right", 6)
	selector_margin.add_theme_constant_override("margin_bottom", 6)
	submenu_selector_panel.add_child(selector_margin)
	submenu_selector = VBoxContainer.new()
	submenu_selector.name = "Selector"
	submenu_selector.add_theme_constant_override("separation", 7)
	selector_margin.add_child(submenu_selector)

	submenu_showroom_panel = PanelContainer.new()
	submenu_showroom_panel.name = "ShowroomPanel"
	submenu_showroom_panel.custom_minimum_size = Vector2(205, 0)
	submenu_showroom_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	submenu_showroom_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	submenu_showroom_panel.size_flags_stretch_ratio = 2.35
	submenu_showroom_panel.clip_contents = true
	submenu_showroom_panel.add_theme_stylebox_override("panel", _glass_panel_style(Color("6CCFFF"), 0.48))
	submenu_body.add_child(submenu_showroom_panel)
	_build_showroom_view()

	submenu_info_panel = PanelContainer.new()
	submenu_info_panel.name = "InfoPanel"
	submenu_info_panel.custom_minimum_size = Vector2(106, 0)
	submenu_info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	submenu_info_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	submenu_info_panel.size_flags_stretch_ratio = 1.06
	submenu_info_panel.clip_contents = true
	submenu_info_panel.add_theme_stylebox_override("panel", _glass_panel_style(CLR_MAGENTA, 0.62))
	submenu_body.add_child(submenu_info_panel)
	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 8)
	info_margin.add_theme_constant_override("margin_top", 8)
	info_margin.add_theme_constant_override("margin_right", 8)
	info_margin.add_theme_constant_override("margin_bottom", 8)
	submenu_info_panel.add_child(info_margin)
	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 6)
	info_margin.add_child(info_box)
	submenu_info_title = Label.new()
	submenu_info_title.text = "OUTRAGE"
	submenu_info_title.add_theme_font_override("font", PIXEL_FONT_BOLD)
	submenu_info_title.add_theme_font_size_override("font_size", 15)
	submenu_info_title.add_theme_color_override("font_color", CLR_TEXT)
	info_box.add_child(submenu_info_title)
	var info_line := ColorRect.new()
	info_line.custom_minimum_size = Vector2(0, 2)
	info_line.color = Color(CLR_MAGENTA, 0.55)
	info_box.add_child(info_line)
	submenu_info_body = Label.new()
	submenu_info_body.custom_minimum_size = Vector2(0, 0)
	submenu_info_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	submenu_info_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	submenu_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	submenu_info_body.clip_text = true
	submenu_info_body.add_theme_font_override("font", PIXEL_FONT)
	submenu_info_body.add_theme_font_size_override("font_size", 7)
	submenu_info_body.add_theme_color_override("font_color", Color(CLR_TEXT, 0.78))
	info_box.add_child(submenu_info_body)

	submenu_settings_panel = PanelContainer.new()
	submenu_settings_panel.name = "SettingsPanel"
	submenu_settings_panel.visible = false
	submenu_settings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	submenu_settings_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var settings_style := _glass_panel_style(CLR_CYAN, 0.92)
	settings_style.bg_color = Color(0.060, 0.180, 0.285, 0.90)
	settings_style.border_color = Color(CLR_CYAN, 0.78)
	settings_style.shadow_color = Color(0.0, 0.18, 0.32, 0.32)
	submenu_settings_panel.add_theme_stylebox_override("panel", settings_style)
	submenu_body.add_child(submenu_settings_panel)

	var footer := Label.new()
	footer.text = "PEOPLE // HEROES // FIGHT        KW SYSTEM REV 02"
	footer.add_theme_font_override("font", PIXEL_FONT)
	footer.custom_minimum_size = Vector2(0, 8)
	footer.add_theme_font_size_override("font_size", 5)
	footer.add_theme_color_override("font_color", Color(CLR_MUTED, 0.52))
	outer.add_child(footer)
	if not submenu_layer.resized.is_connected(_layout_submenu_frame):
		submenu_layer.resized.connect(_layout_submenu_frame)
	call_deferred("_layout_submenu_frame")

func _layout_submenu_frame() -> void:
	if submenu_layer == null or submenu_panel == null:
		return
	var edge := 6.0 if submenu_layer.size.x < 700.0 else 8.0
	var available := submenu_layer.size - Vector2(edge * 2.0, edge * 2.0)
	if available.x <= 1.0 or available.y <= 1.0:
		return
	submenu_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	submenu_panel.position = Vector2(edge, edge)
	submenu_panel.size = available
	submenu_panel.pivot_offset = available * 0.5
	var compact := available.x < 700.0
	var very_compact := available.x < 560.0
	if submenu_body != null:
		submenu_body.add_theme_constant_override("separation", 4 if compact else 6)
	if submenu_selector_panel != null:
		submenu_selector_panel.custom_minimum_size.x = 82.0 if very_compact else (96.0 if compact else 118.0)
	if submenu_showroom_panel != null:
		submenu_showroom_panel.custom_minimum_size.x = 170.0 if very_compact else (205.0 if compact else 285.0)
	if submenu_info_panel != null:
		submenu_info_panel.custom_minimum_size.x = 92.0 if very_compact else (106.0 if compact else 136.0)
	if submenu_header_meta != null:
		submenu_header_meta.visible = available.x >= 510.0
	if submenu_settings_grid != null:
		submenu_settings_grid.columns = 1 if very_compact else 2

func _build_showroom_view() -> void:
	showroom_surface = TextureRect.new()
	showroom_surface.name = "ShowroomSurface"
	showroom_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	showroom_surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	showroom_surface.stretch_mode = TextureRect.STRETCH_SCALE
	showroom_surface.custom_minimum_size = Vector2(1, 1)
	showroom_surface.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	showroom_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	showroom_surface.gui_input.connect(_on_showroom_input)
	submenu_showroom_panel.add_child(showroom_surface)

	showroom_viewport = SubViewport.new()
	showroom_viewport.name = "ShowroomViewport"
	# Keep this fixed: dynamically resizing it from the TextureRect creates a
	# texture/minimum-size feedback loop inside PanelContainer layouts.
	showroom_viewport.size = Vector2i(900, 720)
	showroom_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	showroom_viewport.transparent_bg = false
	showroom_viewport.own_world_3d = true
	showroom_viewport.msaa_3d = Viewport.MSAA_4X
	showroom_surface.add_child(showroom_viewport)
	showroom_surface.texture = showroom_viewport.get_texture()

	showroom_world = Node3D.new()
	showroom_world.name = "ShowroomWorld"
	showroom_viewport.add_child(showroom_world)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0D2540")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("89BEE8")
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_node.environment = env
	showroom_world.add_child(env_node)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-28, -135, 0)
	key.light_color = Color("E6F3FF")
	key.light_energy = 1.42
	key.shadow_enabled = true
	showroom_world.add_child(key)
	var cyan := OmniLight3D.new()
	cyan.position = Vector3(-2.4, 1.8, -2.2)
	cyan.light_color = Color("53D7FF")
	cyan.light_energy = 3.1
	cyan.omni_range = 7.0
	showroom_world.add_child(cyan)
	var red := OmniLight3D.new()
	red.position = Vector3(2.8, 1.2, 0.8)
	red.light_color = Color("FF3155")
	red.light_energy = 3.0
	red.omni_range = 7.0
	showroom_world.add_child(red)

	var floor := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(6.8, 0.10, 5.8)
	floor.mesh = floor_mesh
	floor.position = Vector3(0, -1.55, 1.0)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("12304A")
	floor_mat.metallic = 0.62
	floor_mat.roughness = 0.16
	floor_mat.clearcoat_enabled = true
	floor_mat.clearcoat = 0.5
	floor.material_override = floor_mat
	showroom_world.add_child(floor)

	var back_wall := MeshInstance3D.new()
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(7.2, 4.6, 0.10)
	back_wall.mesh = back_mesh
	back_wall.position = Vector3(0.0, 0.35, 2.45)
	var back_mat := StandardMaterial3D.new()
	back_mat.albedo_color = Color("123A61")
	back_mat.metallic = 0.34
	back_mat.roughness = 0.42
	back_mat.emission_enabled = true
	back_mat.emission = Color("08243C")
	back_mat.emission_energy_multiplier = 0.72
	back_wall.material_override = back_mat
	showroom_world.add_child(back_wall)

	for panel_spec in [
		[Vector3(-2.45,0.55,2.36),Vector3(0.16,3.25,0.05),CLR_CYAN],
		[Vector3(2.45,0.35,2.36),Vector3(0.16,3.55,0.05),CLR_MAGENTA],
		[Vector3(0.0,1.95,2.36),Vector3(2.9,0.08,0.05),Color("2478FF")],
	]:
		var panel_mesh_instance := MeshInstance3D.new()
		var panel_mesh := BoxMesh.new()
		panel_mesh.size = panel_spec[1]
		panel_mesh_instance.mesh = panel_mesh
		panel_mesh_instance.position = panel_spec[0]
		var panel_mat := StandardMaterial3D.new()
		panel_mat.albedo_color = panel_spec[2]
		panel_mat.emission_enabled = true
		panel_mat.emission = panel_spec[2]
		panel_mat.emission_energy_multiplier = 2.6
		panel_mesh_instance.material_override = panel_mat
		showroom_world.add_child(panel_mesh_instance)

	for spec in [
		[Vector3(-2.25,-1.38,0.8),Vector3(0.06,0.05,3.6),CLR_CYAN],
		[Vector3(2.25,-1.38,0.8),Vector3(0.06,0.05,3.6),CLR_MAGENTA],
	]:
		var light_strip := MeshInstance3D.new()
		var strip_mesh := BoxMesh.new()
		strip_mesh.size = spec[1]
		light_strip.mesh = strip_mesh
		light_strip.position = spec[0]
		var strip_mat := StandardMaterial3D.new()
		strip_mat.albedo_color = spec[2]
		strip_mat.emission_enabled = true
		strip_mat.emission = spec[2]
		strip_mat.emission_energy_multiplier = 3.2
		light_strip.material_override = strip_mat
		showroom_world.add_child(light_strip)

	showroom_camera = Camera3D.new()
	showroom_camera.position = Vector3(0.25, 0.35, -4.8)
	showroom_camera.fov = 34.0
	showroom_camera.current = true
	showroom_world.add_child(showroom_camera)
	showroom_camera.look_at(Vector3(0, 0.15, 0), Vector3.UP)

	var drag_hint := Label.new()
	drag_hint.anchor_left = 0.03
	drag_hint.anchor_top = 0.90
	drag_hint.anchor_right = 0.97
	drag_hint.anchor_bottom = 0.98
	drag_hint.text = "< DRAG TO ROTATE >"
	drag_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drag_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	drag_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_hint.add_theme_font_override("font", PIXEL_FONT)
	drag_hint.add_theme_font_size_override("font_size", 7)
	drag_hint.add_theme_color_override("font_color", Color(CLR_CYAN, 0.55))
	submenu_showroom_panel.add_child(drag_hint)

func _glass_panel_style(accent: Color, alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.125, 0.195, alpha)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(accent, 0.58)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.shadow_color = Color(0.0, 0.10, 0.22, 0.32)
	style.shadow_size = 8
	return style

func _make_submenu_button(text_value: String, accent: Color, active: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.custom_minimum_size = Vector2(0, 30)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", PIXEL_FONT_BOLD)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color.WHITE if active else CLR_TEXT)
	var normal_bg := Color(0.035, 0.16, 0.22, 0.98) if active else Color(0.025, 0.080, 0.13, 0.94)
	button.add_theme_stylebox_override("normal", _button_style(normal_bg, Color(accent, 0.55 if active else 0.28), 4))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.05,0.19,0.26,0.99), accent, 6))
	button.add_theme_stylebox_override("focus", _button_style(Color(0.05,0.19,0.26,0.99), accent, 6))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.035,0.13,0.19,1.0), accent, 2))
	button.mouse_entered.connect(func() -> void: _button_hover(button, true))
	button.mouse_exited.connect(func() -> void: _button_hover(button, false))
	button.focus_entered.connect(func() -> void: _button_hover(button, true))
	button.focus_exited.connect(func() -> void: _button_hover(button, false))
	return button

func _clear_submenu_selector() -> void:
	if submenu_selector == null:
		return
	for child in submenu_selector.get_children():
		submenu_selector.remove_child(child)
		child.free()

func _open_v2_submenu(kind: String) -> void:
	if submenu_layer == null:
		return
	active_submenu = kind
	if main_rail != null:
		main_rail.visible = false
	if hero_panel != null:
		hero_panel.visible = false
	_clear_submenu_selector()
	submenu_settings_panel.visible = false
	submenu_showroom_panel.visible = kind != "settings"
	submenu_info_panel.visible = kind != "settings"
	var selector_parent := submenu_selector.get_parent().get_parent() as Control
	if selector_parent != null:
		selector_parent.visible = kind != "settings"

	match kind:
		"guns":
			_populate_guns_submenu()
		"warriors":
			_populate_warriors_submenu()
		"settings":
			_populate_settings_submenu()
		_:
			active_submenu = ""
			return

	submenu_layer.visible = true
	submenu_layer.modulate.a = 0.0
	_layout_submenu_frame()
	# The first SubViewportTexture settles its minimum size after a render/layout
	# pass. Keep the layer invisible briefly, fit again, then reveal it.
	var settle := create_tween()
	settle.tween_interval(0.08)
	settle.tween_callback(_layout_submenu_frame)
	settle.tween_callback(_reveal_v2_submenu)

func _reveal_v2_submenu() -> void:
	if submenu_layer == null or not submenu_layer.visible or active_submenu.is_empty():
		return
	_layout_submenu_frame()
	submenu_panel.scale = Vector2(0.985, 0.985)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(submenu_layer, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(submenu_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if submenu_back_button != null:
		submenu_back_button.call_deferred("grab_focus")

func _close_v2_submenu() -> void:
	if active_submenu.is_empty() or submenu_layer == null:
		return
	showroom_dragging = false
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(submenu_layer, "modulate:a", 0.0, 0.14)
	tween.parallel().tween_property(submenu_panel, "scale", Vector2(0.985, 0.985), 0.14)
	tween.tween_callback(func() -> void:
		active_submenu = ""
		submenu_layer.visible = false
		submenu_layer.modulate.a = 1.0
		submenu_panel.scale = Vector2.ONE
		_layout_submenu_frame()
		_clear_showroom()
		if main_rail != null:
			main_rail.visible = true
		if hero_panel != null:
			hero_panel.visible = true
		if play_button != null:
			play_button.grab_focus()
	)

func _populate_guns_submenu() -> void:
	_clear_submenu_selector()
	submenu_selector.add_theme_constant_override("separation", 4)
	submenu_title.text = "GUNS // ARMORY"
	for weapon_id in ["ak47", "shotgun", "kar", "grenade_launcher"]:
		var id := str(weapon_id)
		var label := WEAPON_SHOWROOM.display_name(id)
		var button := _make_submenu_button(label, CLR_CYAN, id == selected_showroom_weapon)
		button.name = "Gun_%s" % id
		button.pressed.connect(func() -> void:
			selected_showroom_weapon = id
			call_deferred("_populate_guns_submenu")
		)
		submenu_selector.add_child(button)
	if selected_showroom_weapon in ["ak47", "kar"]:
		_add_weapon_skin_selector(selected_showroom_weapon)
	_show_showroom_weapon(selected_showroom_weapon)

func _add_weapon_skin_selector(weapon_id: String) -> void:
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color(CLR_MAGENTA, 0.46)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	submenu_selector.add_child(divider)

	var label := Label.new()
	label.text = "%s SKINS // %02d" % [
		WEAPON_SHOWROOM.display_name(weapon_id),
		WEAPON_SHOWROOM.skin_count(weapon_id)
	]
	label.add_theme_font_override("font", PIXEL_FONT_BOLD)
	label.add_theme_font_size_override("font_size", 6)
	label.add_theme_color_override("font_color", Color(CLR_MAGENTA, 0.86))
	submenu_selector.add_child(label)

	var current_skin := selected_ak_skin if weapon_id == "ak47" else selected_kar_skin
	for skin_id in range(WEAPON_SHOWROOM.skin_count(weapon_id)):
		var id := skin_id
		var skin_button := _make_weapon_skin_button(
			weapon_id,
			WEAPON_SHOWROOM.skin_name(weapon_id, id),
			id,
			id == current_skin
		)
		skin_button.name = "%sSkin_%02d" % [weapon_id.capitalize(), id]
		skin_button.pressed.connect(func() -> void:
			call_deferred("_select_weapon_skin", weapon_id, id)
		)
		submenu_selector.add_child(skin_button)

func _select_weapon_skin(weapon_id: String, skin_id: int) -> void:
	var id := weapon_id.strip_edges().to_lower()
	var resolved := clampi(skin_id, 0, WEAPON_SHOWROOM.skin_count(id) - 1)
	if id == "ak47":
		selected_ak_skin = resolved
		ProjectSettings.set_setting("kw3d/selected_ak_skin", resolved)
	elif id == "kar":
		selected_kar_skin = resolved
		ProjectSettings.set_setting("kw3d/selected_kar_skin", resolved)
	if active_submenu == "guns" and selected_showroom_weapon == id:
		_populate_guns_submenu()

func _make_weapon_skin_button(weapon_id: String, label_text: String, skin_id: int, active: bool) -> Button:
	var accent := WEAPON_SHOWROOM.skin_accent(weapon_id, skin_id)
	var button := Button.new()
	button.text = ("> " if active else "  ") + label_text
	button.custom_minimum_size = Vector2(0, 20)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", PIXEL_FONT_BOLD)
	button.add_theme_font_size_override("font_size", 7)
	button.add_theme_color_override("font_color", Color.WHITE if active else Color(CLR_TEXT, 0.84))
	button.add_theme_stylebox_override(
		"normal",
		_button_style(
			Color(accent.r * 0.11, accent.g * 0.11, accent.b * 0.11, 0.94),
			Color(accent, 0.72 if active else 0.34),
			2
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_button_style(Color(accent.r * 0.18, accent.g * 0.18, accent.b * 0.18, 0.98), accent, 4)
	)
	button.add_theme_stylebox_override(
		"focus",
		_button_style(Color(accent.r * 0.18, accent.g * 0.18, accent.b * 0.18, 0.98), accent, 4)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_button_style(Color(accent.r * 0.14, accent.g * 0.14, accent.b * 0.14, 1.0), accent, 1)
	)
	return button

func _kar_skin_accent(skin_id: int) -> Color:
	match skin_id:
		1: return Color("39F1FF")
		2: return Color("FF244A")
		3: return Color("9FF5FF")
		4: return Color("FFCE5A")
		_: return Color("C58B63")

func _populate_warriors_submenu() -> void:
	_clear_submenu_selector()
	submenu_selector.add_theme_constant_override("separation", 7)
	submenu_title.text = "WARRIORS // LIVE ROSTER"
	selected_showroom_warrior = _current_warrior_id()
	for warrior_id in ["outrage", "erebus", "kosas", "aevilok", "loker"]:
		var id := str(warrior_id)
		var accent := CLR_MAGENTA if id == "outrage" else (Color("df7126") if id == "erebus" else (Color("ff43d5") if id == "kosas" else (Color("9a2038") if id == "aevilok" else Color("39d143"))))
		var active := id == selected_showroom_warrior
		var label := "%s // SELECTED" % id.to_upper() if active else id.to_upper()
		var button := _make_submenu_button(label, accent, active)
		button.name = "Warrior_%s" % id.capitalize()
		button.pressed.connect(func() -> void:
			_select_v2_warrior(id)
		)
		submenu_selector.add_child(button)
	if selected_showroom_warrior == "outrage":
		_add_outage_skin_selector()
	elif selected_showroom_warrior == "erebus":
		_add_erebus_skin_selector()
	_show_showroom_warrior(selected_showroom_warrior)

func _add_outage_skin_selector() -> void:
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color(OUTRAGE_SKINS.skin_accent(selected_outrage_skin), 0.52)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	submenu_selector.add_child(divider)
	var heading := Label.new()
	heading.text = "OUTRAGE SKINS // %02d" % OUTRAGE_SKINS.skin_count()
	heading.add_theme_font_override("font", PIXEL_FONT_BOLD)
	heading.add_theme_font_size_override("font_size", 6)
	heading.add_theme_color_override("font_color", Color(OUTRAGE_SKINS.skin_accent(selected_outrage_skin), 0.92))
	submenu_selector.add_child(heading)
	for skin_id in range(OUTRAGE_SKINS.skin_count()):
		var id := skin_id
		var active := id == selected_outrage_skin
		var accent: Color = OUTRAGE_SKINS.skin_accent(id)
		var button := Button.new()
		button.name = "OutrageSkin_%02d" % id
		button.text = ("> " if active else "  ") + OUTRAGE_SKINS.skin_name(id)
		button.custom_minimum_size = Vector2(0, 20)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_theme_font_override("font", PIXEL_FONT_BOLD)
		button.add_theme_font_size_override("font_size", 7)
		button.add_theme_color_override("font_color", Color.WHITE if active else Color(CLR_TEXT, 0.84))
		button.add_theme_stylebox_override("normal", _button_style(Color(accent.r * 0.11, accent.g * 0.11, accent.b * 0.11, 0.94), Color(accent, 0.72 if active else 0.34), 2))
		button.add_theme_stylebox_override("hover", _button_style(Color(accent.r * 0.18, accent.g * 0.18, accent.b * 0.18, 0.98), accent, 4))
		button.add_theme_stylebox_override("focus", _button_style(Color(accent.r * 0.18, accent.g * 0.18, accent.b * 0.18, 0.98), accent, 4))
		button.add_theme_stylebox_override("pressed", _button_style(Color(accent.r * 0.14, accent.g * 0.14, accent.b * 0.14, 1.0), accent, 1))
		button.pressed.connect(func() -> void:
			_select_outage_skin(id)
		)
		submenu_selector.add_child(button)

func _select_outage_skin(skin_id: int) -> void:
	selected_outrage_skin = clampi(skin_id, 0, OUTRAGE_SKINS.skin_count() - 1)
	ProjectSettings.set_setting("kw3d/selected_outrage_skin", selected_outrage_skin)
	if legacy != null and selected_showroom_warrior == "outrage":
		legacy.set("selected_warrior_skin", selected_outrage_skin)
		legacy.set("_pending_warrior_skin", selected_outrage_skin)
		if legacy.has_method("_set_equipped_warrior_skin"):
			legacy.call("_set_equipped_warrior_skin", "outrage", selected_outrage_skin)
		if legacy.has_method("_save_state"):
			legacy.call("_save_state")
	if hero != null and is_instance_valid(hero) and selected_showroom_warrior == "outrage":
		_set_main_menu_hero(hero.get_parent() as Node3D, "outrage")
	_update_selected_warrior_labels()
	if active_submenu == "warriors" and selected_showroom_warrior == "outrage":
		call_deferred("_populate_warriors_submenu")


func _add_erebus_skin_selector() -> void:
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color(EREBUS_SKINS.skin_accent(selected_erebus_skin), 0.52)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	submenu_selector.add_child(divider)
	var heading := Label.new()
	heading.text = "EREBUS SKINS // %02d" % EREBUS_SKINS.skin_count()
	heading.add_theme_font_override("font", PIXEL_FONT_BOLD)
	heading.add_theme_font_size_override("font_size", 6)
	heading.add_theme_color_override("font_color", Color(EREBUS_SKINS.skin_accent(selected_erebus_skin), 0.92))
	submenu_selector.add_child(heading)
	for skin_id in range(EREBUS_SKINS.skin_count()):
		var id := skin_id
		var active := id == selected_erebus_skin
		var accent: Color = EREBUS_SKINS.skin_accent(id)
		var button := Button.new()
		button.name = "ErebusSkin_%02d" % id
		button.text = ("> " if active else "  ") + EREBUS_SKINS.skin_name(id)
		button.custom_minimum_size = Vector2(0, 20)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_theme_font_override("font", PIXEL_FONT_BOLD)
		button.add_theme_font_size_override("font_size", 7)
		button.add_theme_color_override("font_color", Color.WHITE if active else Color(CLR_TEXT, 0.84))
		button.add_theme_stylebox_override("normal", _button_style(Color(accent.r * 0.11, accent.g * 0.11, accent.b * 0.11, 0.94), Color(accent, 0.72 if active else 0.34), 2))
		button.add_theme_stylebox_override("hover", _button_style(Color(accent.r * 0.18, accent.g * 0.18, accent.b * 0.18, 0.98), accent, 4))
		button.add_theme_stylebox_override("focus", _button_style(Color(accent.r * 0.18, accent.g * 0.18, accent.b * 0.18, 0.98), accent, 4))
		button.add_theme_stylebox_override("pressed", _button_style(Color(accent.r * 0.14, accent.g * 0.14, accent.b * 0.14, 1.0), accent, 1))
		button.pressed.connect(func() -> void:
			_select_erebus_skin(id)
		)
		submenu_selector.add_child(button)


func _select_erebus_skin(skin_id: int) -> void:
	selected_erebus_skin = clampi(skin_id, 0, EREBUS_SKINS.skin_count() - 1)
	ProjectSettings.set_setting("kw3d/selected_erebus_skin", selected_erebus_skin)
	if legacy != null and selected_showroom_warrior == "erebus":
		legacy.set("selected_warrior_skin", selected_erebus_skin)
		legacy.set("_pending_warrior_skin", selected_erebus_skin)
		if legacy.has_method("_set_equipped_warrior_skin"):
			legacy.call("_set_equipped_warrior_skin", "erebus", selected_erebus_skin)
		if legacy.has_method("_save_state"):
			legacy.call("_save_state")
	if hero != null and is_instance_valid(hero) and selected_showroom_warrior == "erebus":
		_set_main_menu_hero(hero.get_parent() as Node3D, "erebus")
	_update_selected_warrior_labels()
	if active_submenu == "warriors" and selected_showroom_warrior == "erebus":
		call_deferred("_populate_warriors_submenu")

func _populate_settings_submenu() -> void:
	submenu_title.text = "SETTINGS // SYSTEM CONTROL"
	submenu_settings_panel.visible = true
	for child in submenu_settings_panel.get_children():
		submenu_settings_panel.remove_child(child)
		child.free()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	submenu_settings_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)
	var heading := Label.new()
	heading.text = "AUDIO / VISUAL FEEL"
	heading.add_theme_font_override("font", PIXEL_FONT_BOLD)
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", CLR_CYAN)
	box.add_child(heading)
	var note := Label.new()
	note.text = "LIVE SETTINGS // SAVED AUTOMATICALLY"
	note.add_theme_font_override("font", PIXEL_FONT)
	note.add_theme_font_size_override("font_size", 7)
	note.add_theme_color_override("font_color", Color(CLR_MAGENTA, 0.72))
	box.add_child(note)
	submenu_settings_grid = GridContainer.new()
	submenu_settings_grid.columns = 2
	submenu_settings_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	submenu_settings_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	submenu_settings_grid.add_theme_constant_override("h_separation", 8)
	submenu_settings_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(submenu_settings_grid)
	settings_music_slider = _make_settings_slider_row(submenu_settings_grid, "MUSIC")
	settings_sfx_slider = _make_settings_slider_row(submenu_settings_grid, "SOUNDS")
	settings_particles_button = _make_settings_toggle_row(submenu_settings_grid, "PARTICLES")
	settings_shake_button = _make_settings_toggle_row(submenu_settings_grid, "SCREEN SHAKE")
	settings_reticle_option = _make_settings_option_row(
		submenu_settings_grid,
		"RETICLE",
		["BLOCKS", "DOT", "CLASSIC", "CUSTOM PNG"]
	)
	settings_reticle_size_slider = _make_settings_slider_row(submenu_settings_grid, "RETICLE SIZE")
	settings_reticle_size_slider.min_value = 0.45
	settings_reticle_size_slider.max_value = 1.60
	settings_reticle_size_slider.step = 0.05
	settings_reticle_png_button = _make_settings_png_row(submenu_settings_grid)
	settings_music_slider.value_changed.connect(func(value: float) -> void:
		var target := legacy.get_node_or_null("%MusicSlider") as HSlider
		if target != null:
			target.value = value
	)
	settings_sfx_slider.value_changed.connect(func(value: float) -> void:
		var target := legacy.get_node_or_null("%SfxSlider") as HSlider
		if target != null:
			target.value = value
	)
	settings_particles_button.pressed.connect(func() -> void:
		var enabled: bool = legacy.get("particles_enabled") != true
		if legacy.has_method("_set_particles_enabled"):
			legacy.call("_set_particles_enabled", enabled, true)
		_sync_v2_settings_from_legacy()
	)
	settings_shake_button.pressed.connect(func() -> void:
		var enabled: bool = legacy.get("screen_shake_enabled") != true
		if legacy.has_method("_set_screen_shake_enabled"):
			legacy.call("_set_screen_shake_enabled", enabled, true)
		_sync_v2_settings_from_legacy()
	)
	settings_reticle_option.item_selected.connect(_on_reticle_preset_selected)
	settings_reticle_size_slider.value_changed.connect(_on_reticle_size_changed)
	settings_reticle_png_button.pressed.connect(_open_reticle_png_dialog)
	_sync_v2_settings_from_legacy()
	_sync_v2_reticle_settings()
	_layout_submenu_frame()

func _make_settings_slider_row(parent: Container, label_text: String) -> HSlider:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 54)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _glass_panel_style(CLR_CYAN, 0.62))
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(72, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", PIXEL_FONT_BOLD)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", CLR_TEXT)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(105, 22)
	_style_neon_slider(slider)
	row.add_child(slider)
	return slider

func _style_neon_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.025, 0.055, 0.075, 0.96)
	track.border_width_top = 1
	track.border_width_bottom = 1
	track.border_color = Color(CLR_CYAN, 0.20)
	track.corner_radius_top_left = 2
	track.corner_radius_top_right = 2
	track.corner_radius_bottom_left = 2
	track.corner_radius_bottom_right = 2
	slider.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(CLR_CYAN, 0.68)
	fill.border_width_top = 1
	fill.border_width_bottom = 1
	fill.border_color = Color(CLR_CYAN, 0.85)
	fill.corner_radius_top_left = 2
	fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_left = 2
	fill.corner_radius_bottom_right = 2
	slider.add_theme_stylebox_override("grabber_area", fill)
	var fill_hot := fill.duplicate() as StyleBoxFlat
	fill_hot.bg_color = Color(CLR_CYAN, 0.92)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_hot)
	var image := Image.create_empty(7, 15, false, Image.FORMAT_RGBA8)
	image.fill(CLR_CYAN)
	var grabber := ImageTexture.create_from_image(image)
	slider.add_theme_icon_override("grabber", grabber)
	slider.add_theme_icon_override("grabber_highlight", grabber)

func _make_settings_toggle_row(parent: Container, label_text: String) -> Button:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 54)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _glass_panel_style(CLR_MAGENTA, 0.58))
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", PIXEL_FONT_BOLD)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", CLR_TEXT)
	row.add_child(label)
	var button := _make_submenu_button("ON", CLR_MAGENTA, true)
	button.custom_minimum_size = Vector2(72, 26)
	row.add_child(button)
	return button


func _make_settings_option_row(parent: Container, label_text: String, items: Array[String]) -> OptionButton:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 54)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _glass_panel_style(CLR_CYAN, 0.62))
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(72, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", PIXEL_FONT_BOLD)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", CLR_TEXT)
	row.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.custom_minimum_size = Vector2(118, 28)
	option.add_theme_font_override("font", PIXEL_FONT_BOLD)
	option.add_theme_font_size_override("font_size", 8)
	for title in items:
		option.add_item(title)
	row.add_child(option)
	return option


func _make_settings_png_row(parent: Container) -> Button:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 54)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _glass_panel_style(CLR_MAGENTA, 0.58))
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	settings_reticle_png_label = Label.new()
	settings_reticle_png_label.text = "CUSTOM PNG"
	settings_reticle_png_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_reticle_png_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	settings_reticle_png_label.add_theme_font_override("font", PIXEL_FONT_BOLD)
	settings_reticle_png_label.add_theme_font_size_override("font_size", 8)
	settings_reticle_png_label.add_theme_color_override("font_color", CLR_TEXT)
	row.add_child(settings_reticle_png_label)
	var button := _make_submenu_button("LOAD PNG", CLR_MAGENTA, true)
	button.custom_minimum_size = Vector2(88, 26)
	row.add_child(button)
	return button

func _sync_v2_settings_from_legacy() -> void:
	if legacy == null:
		return
	var music := legacy.get_node_or_null("%MusicSlider") as HSlider
	var sfx := legacy.get_node_or_null("%SfxSlider") as HSlider
	if settings_music_slider != null and music != null:
		settings_music_slider.set_value_no_signal(music.value)
	if settings_sfx_slider != null and sfx != null:
		settings_sfx_slider.set_value_no_signal(sfx.value)
	if settings_particles_button != null:
		var enabled: bool = legacy.get("particles_enabled") == true
		settings_particles_button.text = "ON" if enabled else "OFF"
		settings_particles_button.modulate = Color.WHITE if enabled else Color(0.58,0.66,0.74,1)
	if settings_shake_button != null:
		var enabled: bool = legacy.get("screen_shake_enabled") == true
		settings_shake_button.text = "ON" if enabled else "OFF"
		settings_shake_button.modulate = Color.WHITE if enabled else Color(0.58,0.66,0.74,1)


func _sync_v2_reticle_settings() -> void:
	var settings := RETICLE_SETTINGS.load_settings()
	var preset := str(settings.get("preset", RETICLE_SETTINGS.PRESET_BLOCKS))
	if settings_reticle_option != null:
		var index := 0
		match preset:
			RETICLE_SETTINGS.PRESET_DOT: index = 1
			RETICLE_SETTINGS.PRESET_CLASSIC: index = 2
			RETICLE_SETTINGS.PRESET_CUSTOM: index = 3
		settings_reticle_option.select(index)
	if settings_reticle_size_slider != null:
		settings_reticle_size_slider.set_value_no_signal(float(settings.get("size_scale", 0.72)))
	if settings_reticle_png_label != null:
		var path := str(settings.get("custom_png", ""))
		settings_reticle_png_label.text = "CUSTOM PNG // READY" if not path.is_empty() else "CUSTOM PNG // NONE"


func _on_reticle_preset_selected(index: int) -> void:
	var presets := [
		RETICLE_SETTINGS.PRESET_BLOCKS,
		RETICLE_SETTINGS.PRESET_DOT,
		RETICLE_SETTINGS.PRESET_CLASSIC,
		RETICLE_SETTINGS.PRESET_CUSTOM,
	]
	var current := RETICLE_SETTINGS.load_settings()
	var chosen := str(presets[clampi(index, 0, presets.size() - 1)])
	RETICLE_SETTINGS.save_settings(
		chosen,
		float(current.get("size_scale", 0.72)),
		str(current.get("custom_png", ""))
	)
	_sync_v2_reticle_settings()


func _on_reticle_size_changed(value: float) -> void:
	var current := RETICLE_SETTINGS.load_settings()
	RETICLE_SETTINGS.save_settings(
		str(current.get("preset", RETICLE_SETTINGS.PRESET_BLOCKS)),
		value,
		str(current.get("custom_png", ""))
	)


func _open_reticle_png_dialog() -> void:
	if settings_reticle_dialog == null:
		settings_reticle_dialog = FileDialog.new()
		settings_reticle_dialog.name = "ReticlePngDialog"
		settings_reticle_dialog.title = "CHOOSE RETICLE PNG"
		settings_reticle_dialog.access = FileDialog.ACCESS_FILESYSTEM
		settings_reticle_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		settings_reticle_dialog.filters = PackedStringArray(["*.png ; PNG Images"])
		settings_reticle_dialog.file_selected.connect(_on_reticle_png_selected)
		add_child(settings_reticle_dialog)
	settings_reticle_dialog.popup_centered_ratio(0.72)


func _on_reticle_png_selected(path: String) -> void:
	var imported := RETICLE_SETTINGS.import_custom_png(path)
	if not bool(imported.get("ok", false)):
		if settings_reticle_png_label != null:
			settings_reticle_png_label.text = "CUSTOM PNG // LOAD FAILED"
		return
	var current := RETICLE_SETTINGS.load_settings()
	RETICLE_SETTINGS.save_settings(
		RETICLE_SETTINGS.PRESET_CUSTOM,
		float(current.get("size_scale", 0.72)),
		str(imported.get("path", RETICLE_SETTINGS.CUSTOM_COPY_PATH))
	)
	_sync_v2_reticle_settings()

func _show_showroom_weapon(weapon_id: String) -> void:
	_clear_showroom()
	showroom_root = Node3D.new()
	showroom_root.name = "WeaponPreview_%s" % weapon_id
	showroom_world.add_child(showroom_root)
	var skin_id := selected_ak_skin if weapon_id == "ak47" else (selected_kar_skin if weapon_id == "kar" else 0)
	WEAPON_SHOWROOM.build_weapon(showroom_root, weapon_id, skin_id)
	showroom_root.position = Vector3(0, -0.02, 0)
	var target_scale_value := 1.15 if weapon_id == "kar" else (1.30 if weapon_id == "shotgun" else 1.34)
	var target_scale := Vector3.ONE * target_scale_value
	showroom_root.scale = target_scale * 0.86
	showroom_yaw = -0.52 if weapon_id == "kar" else -0.42
	showroom_pitch = -0.08
	showroom_camera.position = Vector3(0.10, 0.18, -5.05 if weapon_id == "kar" else -4.20)
	showroom_camera.look_at(Vector3(0, -0.04, 0), Vector3.UP)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(showroom_root, "scale", target_scale, 0.24)
	submenu_info_title.text = WEAPON_SHOWROOM.display_name(weapon_id)
	var skin_line := ""
	if weapon_id in ["ak47", "kar"]:
		skin_line = "\n\nSKIN // %s" % WEAPON_SHOWROOM.skin_name(weapon_id, skin_id)
	var offline_line := "\n\nOFFLINE TESTING AK SKIN // %s" % WEAPON_SHOWROOM.skin_name("ak47", selected_ak_skin)
	submenu_info_body.text = "%s%s\n\n3D MODEL PREVIEW\n\nDRAG THE MODEL TO INSPECT IT FROM ANY ANGLE.%s" % [
		WEAPON_SHOWROOM.descriptor(weapon_id),
		skin_line,
		offline_line
	]

func _show_showroom_warrior(warrior_id: String) -> void:
	var id := _normalize_warrior_id(warrior_id)
	_clear_showroom()
	showroom_root = Node3D.new()
	showroom_root.name = "WarriorPreview_%s" % id.capitalize()
	showroom_world.add_child(showroom_root)
	var model := _warrior_scene(id).instantiate() as Node3D
	if id == "outrage":
		OUTRAGE_SKINS.apply(model, selected_outrage_skin, 0.42)
	model.set_script(null)
	_apply_menu_warrior_materials(model, id)
	if id == "erebus":
		EREBUS_SKINS.apply(model, selected_erebus_skin)
	elif id == "kosas":
		KOSAS_STYLE.apply(model)
	elif id == "aevilok":
		AEVILOK_STYLE.apply(model)
	elif id == "loker":
		LOKER_STYLE.apply(model)
	# The authored character origin is near the middle of the body.  Place the
	# feet on the showroom floor instead of pushing the lower body below frame.
	model.position = Vector3(0, 0.10, 0)
	model.scale = Vector3.ONE * (0.78 if id == "aevilok" else (0.84 if id == "loker" else 0.92))
	showroom_root.add_child(model)
	showroom_root.scale = Vector3.ONE * 0.92
	showroom_yaw = -0.18
	showroom_pitch = 0.0
	showroom_camera.position = Vector3(0.20, 0.10, -7.10) if id in ["aevilok", "loker"] else Vector3(0.20, 0.10, -5.60)
	showroom_camera.fov = 36.0 if id in ["aevilok", "loker"] else 34.0
	showroom_camera.look_at(Vector3(0, 0.05, 0), Vector3.UP)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(showroom_root, "scale", Vector3.ONE, 0.26)
	if id == "aevilok":
		submenu_info_title.text = "AEVILOK"
		submenu_info_body.text = "WARRIOR 04\n\nBODY // BLACK VOID FRAME\n\nTRAIT // CRIMSON WINGS / FLOATING HEAD\n\nHITBOX // STANDARD WARRIOR PROFILE\n\nWINGS // VISUAL-ONLY EXTENSIONS\n\nOFFLINE TESTING LOADOUT // AEVILOK."
	elif id == "loker":
		submenu_info_title.text = "LOKER"
		submenu_info_body.text = "WARRIOR 05\n\nBODY // TOXIC GREEN FRAME\n\nTRAIT // LONG LIZARD HEAD\n\nHITBOX // STANDARD WARRIOR PROFILE\n\nSKILL // OVERCLOCK\n\nBOOSTS FIRE RATE AND RELOAD SPEED.\n\nOFFLINE TESTING LOADOUT // LOKER."
	elif id == "kosas":
		submenu_info_title.text = "KOSAS"
		submenu_info_body.text = "WARRIOR 03\n\nBODY // TALL PINK FRAME\n\nTRAIT // HUGE NOSE / SMALL CORE\n\nHITBOX // STANDARD WARRIOR PROFILE\n\nOFFLINE TESTING LOADOUT // KOSAS."
	elif id == "erebus":
		submenu_info_title.text = "EREBUS"
		submenu_info_body.text = "WARRIOR 02\n\nSKIN // %s\n\nBODY // ORANGE HEAVY FRAME\n\nSKILL // VOID GUARD\n\nSHORT IMMUNITY WINDOW TO SURVIVE BURST DAMAGE.\n\nOFFLINE TESTING LOADOUT // EREBUS." % EREBUS_SKINS.skin_name(selected_erebus_skin)
	else:
		submenu_info_title.text = "OUTRAGE"
		submenu_info_body.text = "WARRIOR 01\n\nSKIN // %s\n\nBODY // STREET ZERO FRAME\n\nSKILL // BOMB BLAST\n\nTHROWS AN EXPLOSIVE BOMB.\n\nOFFLINE TESTING LOADOUT // OUTRAGE." % OUTRAGE_SKINS.skin_name(selected_outrage_skin)

func _normalize_warrior_id(warrior_id: String) -> String:
	var id := warrior_id.strip_edges().to_lower()
	return id if id in ["outrage", "erebus", "kosas", "aevilok", "loker"] else "outrage"

func _current_warrior_id() -> String:
	if legacy != null:
		var raw_legacy_id := str(legacy.get("selected_warrior_id")).strip_edges().to_lower()
		if raw_legacy_id in ["outrage", "erebus", "kosas", "aevilok", "loker"]:
			return raw_legacy_id
	return _normalize_warrior_id(str(ProjectSettings.get_setting("kw3d/selected_warrior_id", "outrage")))

func _warrior_scene(warrior_id: String) -> PackedScene:
	var id := _normalize_warrior_id(warrior_id)
	return LOKER_SCENE if id == "loker" else (AEVILOK_SCENE if id == "aevilok" else (KOSAS_SCENE if id == "kosas" else (EREBUS_SCENE if id == "erebus" else OUTRAGE_SCENE)))

func _apply_menu_warrior_materials(model: Node3D, warrior_id: String) -> void:
	if _normalize_warrior_id(warrior_id) in ["erebus", "kosas", "aevilok", "loker"]:
		HERO_MATERIALS.apply_flat_to(model)
	elif _normalize_warrior_id(warrior_id) == "outrage" and selected_outrage_skin in [2, 4]:
		HERO_MATERIALS.apply_flat_to(model)
	else:
		HERO_MATERIALS.apply_to(model)

func _set_main_menu_hero(parent: Node3D, warrior_id: String) -> void:
	var id := _normalize_warrior_id(warrior_id)
	if hero != null and is_instance_valid(hero):
		var old_hero := hero
		old_hero.get_parent().remove_child(old_hero)
		old_hero.queue_free()
	hero = _warrior_scene(id).instantiate() as Node3D
	hero.name = "%sMenuHero" % id.capitalize()
	if id == "outrage":
		OUTRAGE_SKINS.apply(hero, selected_outrage_skin, 0.38)
	# Detach the presentation instance's gameplay style before _ready can apply it.
	hero.set_script(null)
	if id == "outrage":
		OUTRAGE_STATUE.apply_to(hero)
	else:
		_apply_menu_warrior_materials(hero, id)
	if id == "erebus":
		EREBUS_SKINS.apply(hero, selected_erebus_skin)
	elif id == "kosas":
		KOSAS_STYLE.apply(hero)
	elif id == "aevilok":
		AEVILOK_STYLE.apply(hero)
	elif id == "loker":
		LOKER_STYLE.apply(hero)
	hero.position = Vector3(-0.72, -0.34, 0.15) if id == "aevilok" else (Vector3(-0.95, -0.34, 0.15) if id == "loker" else Vector3(-1.05, -0.34, 0.15))
	hero.rotation_degrees.y = -11.0
	hero.scale = Vector3.ONE * (0.76 if id == "aevilok" else (0.98 if id == "loker" else 1.16))
	parent.add_child(hero)
	hero_head = hero.get_node_or_null("HeadRig") as Node3D
	hero_torso = hero.get_node_or_null("TorsoRig") as Node3D
	hero_left_leg = hero.get_node_or_null("LeftLegRig") as Node3D
	hero_right_leg = hero.get_node_or_null("RightLegRig") as Node3D
	hero_base_position = hero.position
	hero_base_rotation = hero.rotation
	head_base_rotation = hero_head.rotation if hero_head != null else Vector3.ZERO
	torso_base_rotation = hero_torso.rotation if hero_torso != null else Vector3.ZERO
	left_leg_base_rotation = hero_left_leg.rotation if hero_left_leg != null else Vector3.ZERO
	right_leg_base_rotation = hero_right_leg.rotation if hero_right_leg != null else Vector3.ZERO

func _update_selected_warrior_labels() -> void:
	var id := _normalize_warrior_id(selected_showroom_warrior)
	var display := id.to_upper()
	if id == "outrage":
		display += " // " + OUTRAGE_SKINS.skin_name(selected_outrage_skin)
	elif id == "erebus":
		display += " // " + EREBUS_SKINS.skin_name(selected_erebus_skin)
	if hero_tag != null:
		hero_tag.text = "%s // SELECTED" % display
	if hero_strap != null:
		hero_strap.text = "%s // LIVE COMBAT SYSTEM" % display
	if offline_button != null:
		offline_button.text = "OFFLINE TESTING // %s" % display

func _sync_selected_warrior_from_legacy() -> void:
	selected_showroom_warrior = _current_warrior_id()
	ProjectSettings.set_setting("kw3d/selected_warrior_id", selected_showroom_warrior)
	if hero != null and is_instance_valid(hero):
		_set_main_menu_hero(hero.get_parent() as Node3D, selected_showroom_warrior)
	_update_selected_warrior_labels()

func _select_v2_warrior(warrior_id: String) -> void:
	var id := _normalize_warrior_id(warrior_id)
	selected_showroom_warrior = id
	ProjectSettings.set_setting("kw3d/selected_warrior_id", id)
	if legacy != null:
		var owned := legacy.get("owned_warriors") as PackedStringArray
		if not owned.has(id):
			owned.append(id)
			legacy.set("owned_warriors", owned)
		legacy.set("selected_warrior_id", id)
		var warrior_skin := selected_outrage_skin if id == "outrage" else (selected_erebus_skin if id == "erebus" else 0)
		legacy.set("selected_warrior_skin", warrior_skin)
		legacy.set("_pending_warrior_id", id)
		legacy.set("_pending_warrior_skin", warrior_skin)
		if legacy.has_method("_set_equipped_warrior_skin"):
			legacy.call("_set_equipped_warrior_skin", id, warrior_skin)
		if legacy.has_method("_save_state"):
			legacy.call("_save_state")
		if legacy.has_method("_sync_active_lobby_loadout_selection"):
			legacy.call("_sync_active_lobby_loadout_selection")
	if hero != null and is_instance_valid(hero):
		_set_main_menu_hero(hero.get_parent() as Node3D, id)
	_update_selected_warrior_labels()
	if active_submenu == "warriors":
		call_deferred("_populate_warriors_submenu")

func _clear_showroom() -> void:
	if showroom_root != null and is_instance_valid(showroom_root):
		if showroom_root.get_parent() != null:
			showroom_root.get_parent().remove_child(showroom_root)
		showroom_root.queue_free()
	showroom_root = null

func _resize_showroom_viewport() -> void:
	if showroom_viewport == null or showroom_surface == null or not showroom_surface.is_inside_tree():
		return
	var to_pixels := get_viewport().get_stretch_transform() * showroom_surface.get_global_transform_with_canvas()
	var pixel_size := showroom_surface.size * to_pixels.get_scale().abs()
	if pixel_size.x < 1.0 or pixel_size.y < 1.0:
		return
	pixel_size *= minf(1.0, 1200.0 / maxf(pixel_size.x, pixel_size.y))
	var render_size := Vector2i(maxi(1, ceili(pixel_size.x)), maxi(1, ceili(pixel_size.y)))
	if showroom_viewport.size != render_size:
		showroom_viewport.size = render_size

func _on_showroom_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		showroom_dragging = event.pressed
		showroom_last_mouse = event.position
		showroom_surface.accept_event()
	elif event is InputEventMouseMotion and showroom_dragging:
		showroom_yaw += event.relative.x * 0.012
		showroom_pitch = clampf(showroom_pitch + event.relative.y * 0.007, -0.45, 0.35)
		showroom_last_mouse = event.position
		showroom_surface.accept_event()

func _update_showroom(delta: float) -> void:
	if showroom_root == null or active_submenu not in ["guns", "warriors"]:
		return
	if not showroom_dragging:
		showroom_yaw += delta * (0.22 if active_submenu == "guns" else 0.13)
	showroom_root.rotation = Vector3(showroom_pitch, showroom_yaw, 0)

func _build_loading_overlay_v2() -> void:
	loading_overlay_v2 = Control.new()
	loading_overlay_v2.name = "NeonLoadingOverlayV2"
	loading_overlay_v2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_overlay_v2.mouse_filter = Control.MOUSE_FILTER_STOP
	loading_overlay_v2.visible = false
	loading_overlay_v2.z_index = 4090
	add_child(loading_overlay_v2)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color.WHITE
	var bg_shader := Shader.new()
	bg_shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	vec3 col = mix(vec3(0.040,0.125,0.205), vec3(0.125,0.040,0.175), uv.x);
	float cyan = exp(-distance(uv, vec2(0.30,0.45))*5.8);
	float pink = exp(-distance(uv, vec2(0.76,0.58))*6.2);
	float cyan2 = exp(-distance(uv, vec2(0.88,0.20))*8.0);
	float blue2 = exp(-distance(uv, vec2(0.10,0.78))*7.0);
	col += vec3(0.00,0.55,0.82)*cyan*0.38;
	col += vec3(0.78,0.03,0.38)*pink*0.34;
	col += vec3(0.00,0.40,0.75)*cyan2*0.24;
	col += vec3(0.06,0.18,0.62)*blue2*0.26;
	float skyline = 0.0;
	skyline = max(skyline, step(0.67,uv.y)*step(0.05,uv.x)*step(uv.x,0.15));
	skyline = max(skyline, step(0.58,uv.y)*step(0.18,uv.x)*step(uv.x,0.29));
	skyline = max(skyline, step(0.72,uv.y)*step(0.33,uv.x)*step(uv.x,0.42));
	skyline = max(skyline, step(0.61,uv.y)*step(0.70,uv.x)*step(uv.x,0.82));
	skyline = max(skyline, step(0.52,uv.y)*step(0.86,uv.x)*step(uv.x,0.96));
	col = mix(col, vec3(0.028,0.080,0.135), skyline*0.46);
	float neon_a = exp(-abs(uv.x-0.145)*90.0)*smoothstep(0.92,0.28,uv.y);
	float neon_b = exp(-abs(uv.x-0.815)*95.0)*smoothstep(0.92,0.22,uv.y);
	float horizon = exp(-abs(uv.y-0.70)*52.0);
	col += vec3(0.12,0.82,1.00)*neon_a*0.24;
	col += vec3(1.00,0.10,0.42)*neon_b*0.22;
	col += vec3(0.08,0.38,0.62)*horizon*0.20;
	float bands = 0.010*sin(uv.y*540.0 + TIME*2.4);
	col += vec3(bands);
	float v = smoothstep(0.98,0.34,distance(uv,vec2(0.5)));
	col *= 0.82 + 0.18*v;
	COLOR = vec4(col,1.0);
}
"""
	var bg_material := ShaderMaterial.new()
	bg_material.shader = bg_shader
	bg.material = bg_material
	loading_overlay_v2.add_child(bg)
	var glow := ColorRect.new()
	glow.anchor_left = 0.14
	glow.anchor_top = 0.40
	glow.anchor_right = 0.86
	glow.anchor_bottom = 0.63
	glow.color = Color(CLR_CYAN, 0.12)
	loading_overlay_v2.add_child(glow)
	var title := Label.new()
	title.anchor_left = 0.25
	title.anchor_top = 0.34
	title.anchor_right = 0.75
	title.anchor_bottom = 0.44
	title.text = "KW // TRANSIT SYSTEM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", PIXEL_FONT_BOLD)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", CLR_CYAN)
	loading_overlay_v2.add_child(title)
	loading_label_v2 = Label.new()
	loading_label_v2.anchor_left = 0.16
	loading_label_v2.anchor_top = 0.46
	loading_label_v2.anchor_right = 0.84
	loading_label_v2.anchor_bottom = 0.53
	loading_label_v2.text = "LOADING // PLEASE REMAIN VIOLENT"
	loading_label_v2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label_v2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loading_label_v2.add_theme_font_override("font", PIXEL_FONT)
	loading_label_v2.add_theme_font_size_override("font_size", 11)
	loading_label_v2.add_theme_color_override("font_color", CLR_TEXT)
	loading_overlay_v2.add_child(loading_label_v2)
	var bar_bg := ColorRect.new()
	bar_bg.anchor_left = 0.22
	bar_bg.anchor_top = 0.55
	bar_bg.anchor_right = 0.78
	bar_bg.anchor_bottom = 0.565
	bar_bg.color = Color(0.05,0.18,0.28,0.90)
	loading_overlay_v2.add_child(bar_bg)
	loading_bar_v2 = ColorRect.new()
	loading_bar_v2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_bar_v2.color = CLR_CYAN
	loading_bar_v2.pivot_offset = Vector2.ZERO
	bar_bg.add_child(loading_bar_v2)
	var warning := Label.new()
	warning.anchor_left = 0.25
	warning.anchor_top = 0.61
	warning.anchor_right = 0.75
	warning.anchor_bottom = 0.67
	warning.text = "DO NOT DISCONNECT // THE GODS ARE WATCHING"
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.add_theme_font_override("font", PIXEL_FONT)
	warning.add_theme_font_size_override("font_size", 6)
	warning.add_theme_color_override("font_color", Color(CLR_MAGENTA,0.82))
	loading_overlay_v2.add_child(warning)

func _show_v2_loading(message: String, duration: float = 0.95) -> void:
	if loading_overlay_v2 == null:
		return
	if loading_tween_v2 != null:
		loading_tween_v2.kill()
	loading_label_v2.text = message
	loading_overlay_v2.visible = true
	loading_overlay_v2.modulate.a = 0.0
	loading_tween_v2 = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	loading_tween_v2.tween_property(loading_overlay_v2, "modulate:a", 1.0, 0.12)
	loading_tween_v2.tween_interval(duration)
	loading_tween_v2.tween_property(loading_overlay_v2, "modulate:a", 0.0, 0.16)
	loading_tween_v2.tween_callback(func() -> void:
		if loading_overlay_v2 != null:
			loading_overlay_v2.visible = false
	)

func _update_loading_fx() -> void:
	if loading_overlay_v2 == null or not loading_overlay_v2.visible or loading_bar_v2 == null:
		return
	loading_bar_v2.scale.x = 0.18 + absf(sin(time * 2.4)) * 0.82

func _unhandled_input(event: InputEvent) -> void:
	if not active_submenu.is_empty() and event.is_action_pressed("ui_cancel"):
		_close_v2_submenu()
		get_viewport().set_input_as_handled()
