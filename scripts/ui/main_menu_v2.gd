extends Control
## Main menu V2 presentation layer.
## The legacy main_menu.tscn remains untouched underneath and still owns all game/menu flows.
## This scene only replaces the main-screen presentation and renders the real 3D Outrage model.

const LEGACY_SCENE := preload("res://scenes/ui/main_menu_legacy.tscn")
const OUTRAGE_SCENE := preload("res://scenes/prototypes/characters/outrage_fullbody.tscn")
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

var hero_base_position := Vector3.ZERO
var head_base_rotation := Vector3.ZERO
var torso_base_rotation := Vector3.ZERO
var left_leg_base_rotation := Vector3.ZERO
var right_leg_base_rotation := Vector3.ZERO
var camera_base_position := Vector3.ZERO

var play_button: Button
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
	_sync_presentation_visibility()
	if play_button != null and presentation.visible:
		play_button.grab_focus()

func _process(delta: float) -> void:
	time += delta
	_animate_hero()
	_sync_presentation_visibility()
	_sync_legacy_meta()

func _sync_presentation_visibility() -> void:
	if legacy == null or presentation == null:
		return

	var screen_main := legacy.get_node_or_null("Screens/ScreenMain") as Control
	var active := screen_main != null and screen_main.visible and time >= hide_until

	var lobby_ctrl: Variant = legacy.get("_lobby_overlay_ctrl")
	if lobby_ctrl != null and lobby_ctrl.has_method("is_visible") and bool(lobby_ctrl.call("is_visible")):
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

	var old_wallet := legacy.get_node_or_null("WalletPanel") as Control
	if old_wallet != null:
		old_wallet.visible = not active

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
	vec3 left_col = vec3(0.015, 0.025, 0.070);
	vec3 right_col = vec3(0.030, 0.018, 0.085);
	vec3 col = mix(left_col, right_col, smoothstep(0.25, 1.0, uv.x));

	float cyan_glow = exp(-distance(uv, vec2(0.70, 0.28)) * 6.0);
	float magenta_glow = exp(-distance(uv, vec2(0.92, 0.60)) * 7.0);
	col += vec3(0.00, 0.18, 0.27) * cyan_glow * 0.48;
	col += vec3(0.32, 0.00, 0.16) * magenta_glow * 0.48;

	float gx = grid_line(uv.x + TIME * 0.0015, 32.0, 0.465);
	float gy = grid_line(uv.y, 18.0, 0.465);
	float grid = max(gx, gy) * 0.035;
	col += vec3(0.08, 0.42, 0.60) * grid * smoothstep(0.32, 1.0, uv.x);

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
	left_veil.anchor_right = 0.48
	left_veil.anchor_bottom = 1.0
	left_veil.color = Color(0.005, 0.008, 0.025, 0.58)
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
	rail.name = "MenuRail"
	rail.anchor_left = 0.045
	rail.anchor_top = 0.055
	rail.anchor_right = 0.405
	rail.anchor_bottom = 0.945
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_theme_stylebox_override("panel", _rail_style())
	presentation.add_child(rail)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
	rail.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(box)

	var title := Label.new()
	title.text = "KW"
	title.add_theme_font_override("font", PIXEL_FONT_BOLD)
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", CLR_TEXT)
	title.add_theme_color_override("font_shadow_color", Color(0.0,0.65,1.0,0.48))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	box.add_child(title)

	var online := Label.new()
	online.text = "ONLINE"
	online.add_theme_font_override("font", PIXEL_FONT_BOLD)
	online.add_theme_font_size_override("font_size", 20)
	online.add_theme_color_override("font_color", CLR_CYAN)
	online.add_theme_constant_override("letter_spacing", 4)
	box.add_child(online)

	var strap := Label.new()
	strap.text = "OUTRAGE // LIVE COMBAT SYSTEM"
	strap.add_theme_font_override("font", PIXEL_FONT)
	strap.add_theme_font_size_override("font_size", 9)
	strap.add_theme_color_override("font_color", CLR_MUTED)
	box.add_child(strap)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(CLR_CYAN,0.48)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(divider)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0,4)
	box.add_child(spacer)

	play_button = _make_voxel_button("PLAY", "PlayButton", true)
	box.add_child(play_button)
	box.add_child(_make_voxel_button("WARRIORS", "WarriorButton"))
	box.add_child(_make_voxel_button("ARSENAL", "WeaponButton"))
	box.add_child(_make_voxel_button("SETTINGS", "OptionsButton"))
	box.add_child(_make_voxel_button("QUIT", "ExitButton", false, true))

	var flex := Control.new()
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	flex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(flex)

	wallet_label = Label.new()
	wallet_label.text = "COINS: --   //   CLK: --"
	wallet_label.add_theme_font_override("font", PIXEL_FONT)
	wallet_label.add_theme_font_size_override("font_size", 9)
	wallet_label.add_theme_color_override("font_color", Color(CLR_TEXT,0.70))
	box.add_child(wallet_label)

	status_label = Label.new()
	status_label.text = "3D HERO LINK // READY"
	status_label.add_theme_font_override("font", PIXEL_FONT)
	status_label.add_theme_font_size_override("font_size", 8)
	status_label.add_theme_color_override("font_color", Color(CLR_CYAN,0.62))
	box.add_child(status_label)

func _build_hero_view() -> void:
	var hero_panel := Control.new()
	hero_panel.name = "HeroStage"
	hero_panel.anchor_left = 0.405
	hero_panel.anchor_top = 0.0
	hero_panel.anchor_right = 1.0
	hero_panel.anchor_bottom = 1.0
	hero_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	presentation.add_child(hero_panel)

	var container := SubViewportContainer.new()
	container.name = "HeroViewportContainer"
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_panel.add_child(container)

	hero_viewport = SubViewport.new()
	hero_viewport.name = "HeroViewport"
	hero_viewport.size = Vector2i(760,720)
	hero_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	hero_viewport.transparent_bg = false
	container.add_child(hero_viewport)

	var world := Node3D.new()
	world.name = "HeroWorld"
	hero_viewport.add_child(world)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("060A19")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("506AA5")
	env.ambient_light_energy = 0.78
	env_node.environment = env
	world.add_child(env_node)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-28,-155,0)
	key.light_color = Color("B8D9FF")
	key.light_energy = 1.55
	key.shadow_enabled = true
	world.add_child(key)

	var cyan := OmniLight3D.new()
	cyan.position = Vector3(-2.4,1.6,-2.0)
	cyan.light_color = CLR_CYAN
	cyan.light_energy = 4.2
	cyan.omni_range = 8.0
	world.add_child(cyan)

	var pink := OmniLight3D.new()
	pink.position = Vector3(2.1,0.7,-1.2)
	pink.light_color = CLR_MAGENTA
	pink.light_energy = 5.0
	pink.omni_range = 7.0
	world.add_child(pink)

	_add_voxel_backdrop(world)

	hero = OUTRAGE_SCENE.instantiate() as Node3D
	hero.name = "OutrageMenuHero"
	hero.position = Vector3(0.18,-0.05,0)
	hero.scale = Vector3.ONE * 1.08
	world.add_child(hero)

	hero_head = hero.get_node_or_null("HeadRig") as Node3D
	hero_torso = hero.get_node_or_null("TorsoRig") as Node3D
	hero_left_leg = hero.get_node_or_null("LeftLegRig") as Node3D
	hero_right_leg = hero.get_node_or_null("RightLegRig") as Node3D
	hero_base_position = hero.position
	if hero_head != null: head_base_rotation = hero_head.rotation
	if hero_torso != null: torso_base_rotation = hero_torso.rotation
	if hero_left_leg != null: left_leg_base_rotation = hero_left_leg.rotation
	if hero_right_leg != null: right_leg_base_rotation = hero_right_leg.rotation

	hero_camera = Camera3D.new()
	hero_camera.name = "HeroCamera"
	hero_camera.position = Vector3(0.15,0.34,-4.15)
	hero_camera.fov = 33.0
	hero_camera.near = 0.05
	hero_camera.current = true
	world.add_child(hero_camera)
	hero_camera.look_at(Vector3(0.12,0.34,0.0),Vector3.UP)
	camera_base_position = hero_camera.position

	# Blend the 3D viewport into the left menu.
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
	float left_fade = pow(1.0 - smoothstep(0.0, 0.34, uv.x), 1.5) * 0.92;
	float bottom = smoothstep(0.68, 1.0, uv.y) * 0.30;
	COLOR = vec4(0.01, 0.015, 0.045, clamp(left_fade + bottom, 0.0, 0.95));
}
"""
	var fade_material := ShaderMaterial.new()
	fade_material.shader = fade_shader
	fade.material = fade_material
	hero_panel.add_child(fade)

	var hero_tag := Label.new()
	hero_tag.anchor_left = 0.58
	hero_tag.anchor_top = 0.87
	hero_tag.anchor_right = 0.97
	hero_tag.anchor_bottom = 0.96
	hero_tag.text = "OUTRAGE // IDLE LINK"
	hero_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hero_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hero_tag.add_theme_font_override("font",PIXEL_FONT_BOLD)
	hero_tag.add_theme_font_size_override("font_size",9)
	hero_tag.add_theme_color_override("font_color",Color(CLR_TEXT,0.58))
	hero_panel.add_child(hero_tag)

func _add_voxel_backdrop(world: Node3D) -> void:
	var specs := [
		[Vector3(-2.5,-1.1,2.0),Vector3(1.1,1.6,1.0),Color("102A4B")],
		[Vector3(-1.6,-0.4,2.5),Vector3(0.7,3.0,0.8),Color("0D1B38")],
		[Vector3(2.4,-0.9,2.2),Vector3(1.2,2.2,1.1),Color("35102E")],
		[Vector3(1.55,0.4,2.8),Vector3(0.55,2.8,0.7),Color("1A123D")],
		[Vector3(0.0,-1.7,1.1),Vector3(7.0,0.18,5.0),Color("071322")],
	]
	for spec in specs:
		_add_box(world,spec[0],spec[1],spec[2],false)

	_add_box(world,Vector3(-2.05,1.18,1.35),Vector3(0.10,1.25,0.10),CLR_CYAN,true)
	_add_box(world,Vector3(2.20,0.78,1.20),Vector3(0.12,1.65,0.12),CLR_MAGENTA,true)
	_add_box(world,Vector3(1.65,-0.48,0.92),Vector3(0.34,0.10,0.10),Color("FF4FA0"),true)

func _add_box(parent: Node3D, position: Vector3, size: Vector3, color: Color, emissive: bool) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.8
	mesh.material_override = material
	parent.add_child(mesh)

func _animate_hero() -> void:
	if hero == null:
		return

	var breathe := sin(time * 1.45)
	var slow := sin(time * 0.58)
	var look := sin(time * 0.73 + 0.7)

	hero.position = hero_base_position + Vector3(slow * 0.010,breathe * 0.018,0)
	hero.rotation.y = deg_to_rad(slow * 1.5)
	hero.rotation.z = deg_to_rad(sin(time * 0.43) * 0.35)

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
		hero_camera.look_at(Vector3(0.12,0.34 + breathe * 0.006,0.0),Vector3.UP)

func _make_voxel_button(label_text: String, legacy_unique_name: String, hot: bool = false, danger: bool = false) -> Button:
	var button := Button.new()
	button.name = label_text.capitalize().replace(" ","") + "ButtonV2"
	button.custom_minimum_size = Vector2(0,42 if hot else 36)
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = "  " + label_text
	button.add_theme_font_override("font",PIXEL_FONT_BOLD)
	button.add_theme_font_size_override("font_size",19 if hot else 14)
	button.add_theme_color_override("font_color",CLR_TEXT)
	button.add_theme_color_override("font_hover_color",Color.WHITE)
	button.add_theme_color_override("font_focus_color",Color.WHITE)

	var accent := CLR_MAGENTA if danger else CLR_CYAN
	button.add_theme_stylebox_override("normal",_button_style(CLR_PANEL,Color(accent,0.42),7))
	button.add_theme_stylebox_override("hover",_button_style(CLR_PANEL_HOVER,accent,9))
	button.add_theme_stylebox_override("focus",_button_style(CLR_PANEL_HOVER,accent,9))
	button.add_theme_stylebox_override("pressed",_button_style(Color(0.02,0.07,0.11,1.0),accent,2))

	var stripe := ColorRect.new()
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.anchor_left = 0.0
	stripe.anchor_top = 0.0
	stripe.anchor_right = 0.0
	stripe.anchor_bottom = 1.0
	stripe.offset_left = 2
	stripe.offset_right = 6
	stripe.offset_top = 5
	stripe.offset_bottom = -5
	stripe.color = accent
	button.add_child(stripe)

	for y in [5.0,13.0,21.0]:
		var pixel := ColorRect.new()
		pixel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pixel.anchor_left = 1.0
		pixel.anchor_right = 1.0
		pixel.offset_left = -7
		pixel.offset_right = -3
		pixel.offset_top = y
		pixel.offset_bottom = y + 4
		pixel.color = Color(accent,0.42)
		button.add_child(pixel)

	button.mouse_entered.connect(func(): _button_hover(button,true))
	button.mouse_exited.connect(func(): _button_hover(button,false))
	button.focus_entered.connect(func(): _button_hover(button,true))
	button.focus_exited.connect(func(): _button_hover(button,false))
	button.pressed.connect(func(): _activate_legacy(legacy_unique_name,label_text))
	return button

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
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _rail_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015,0.025,0.065,0.76)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(CLR_CYAN,0.18)
	style.shadow_color = Color(0,0,0,0.55)
	style.shadow_size = 12
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
