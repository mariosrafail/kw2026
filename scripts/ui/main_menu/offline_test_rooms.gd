extends Control

const UI_ANIM := preload("res://scripts/ui/main_menu/ui_animator.gd")
const SKIN := preload("res://scripts/ui/main_menu/kw_menu_skin.gd")
const MENU_PALETTE := preload("res://scripts/ui/main_menu/menu_palette.gd")

var host: Control
var close_action: Callable
var launch_action: Callable
var ui_anim := UI_ANIM.new()
var panel: PanelContainer
var waves_button: Button
var sandbox_button: Button
var back_button: Button
var panel_rest_position := Vector2.ZERO

func setup(menu_host: Control, close_cb: Callable, launch_cb: Callable) -> void:
	host = menu_host
	close_action = close_cb
	launch_action = launch_cb
	name = "OfflineTestRooms"
	z_index = 1850
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if host != null:
		theme = host.theme

	var background := ColorRect.new()
	background.color = Color(0.5248462, 0.7325527, 0.7741166, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var noise := TextureRect.new()
	noise.texture = load("res://assets/textures/bullet.png")
	noise.modulate = Color(1, 1, 1, 0.06)
	noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	noise.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	noise.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(noise)
	noise.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", SKIN.dark_panel_style(0.97))
	add_child(panel)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 8)
	margin.add_child(root_box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root_box.add_child(top)

	var logo := TextureRect.new()
	logo.texture = load("res://assets/textures/textLogo.png")
	logo.custom_minimum_size = Vector2(140, 46)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(logo)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(title_box)

	var title := Label.new()
	title.text = "OFFLINE TEST ROOMS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", SKIN.FONT)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.98, 0.97, 0.95, 1))
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "DEV LAB  /  LOCAL ONLY  /  NO SERVER  /  NO INTERNET"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", SKIN.FONT)
	subtitle.add_theme_font_size_override("font_size", 9)
	subtitle.add_theme_color_override("font_color", Color(0.5216, 0.7804, 0.6039, 1))
	title_box.add_child(subtitle)

	var rooms_row := HBoxContainer.new()
	rooms_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rooms_row.add_theme_constant_override("separation", 10)
	root_box.add_child(rooms_row)

	waves_button = _make_room_button(
		"WAVES / COMBAT RANGE\nENDLESS WAVES + BOTS + DAMAGE + GRENADE",
		func() -> void: _launch("waves")
	)
	rooms_row.add_child(waves_button)

	sandbox_button = _make_room_button(
		"SANDBOX / AIM LAB\nSTATIONARY TARGETS + NO ENEMY FIRE + NO WAVES",
		func() -> void: _launch("sandbox")
	)
	rooms_row.add_child(sandbox_button)

	var hint := Label.new()
	hint.text = "F10 returns here from any offline test room."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", SKIN.FONT)
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.86, 0.90, 0.94, 0.82))
	root_box.add_child(hint)

	back_button = Button.new()
	back_button.text = "BACK"
	SKIN.apply_button(back_button, 14, 34)
	ui_anim.add_hover_pop(back_button)
	back_button.pressed.connect(func() -> void:
		ui_anim.button_press_anim(self, back_button, 0.055)
		if close_action.is_valid():
			close_action.call()
	)
	root_box.add_child(back_button)

	if not resized.is_connected(_layout):
		resized.connect(_layout)
	_layout()
	call_deferred("_animate_in")
	call_deferred("_grab_initial_focus")

func _make_room_button(text_value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 126)
	SKIN.apply_button(button, 13, 126)
	ui_anim.add_hover_pop(button)
	button.pressed.connect(func() -> void:
		ui_anim.button_press_anim(self, button, 0.055)
		action.call()
	)
	return button

func _layout() -> void:
	if panel == null:
		return
	var target := Vector2(minf(610.0, maxf(420.0, size.x - 24.0)), minf(330.0, maxf(270.0, size.y - 20.0)))
	panel.size = target
	panel.position = (size - target) * 0.5
	panel_rest_position = panel.position
	panel.pivot_offset = panel.size * 0.5

func _animate_in() -> void:
	if panel == null:
		return
	panel.modulate = Color(1, 1, 1, 0)
	panel.scale = Vector2(0.94, 0.94)
	panel.position = panel_rest_position + Vector2(0, 12)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "position", panel_rest_position, 0.28)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.28)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.14)

func _grab_initial_focus() -> void:
	if waves_button != null:
		waves_button.grab_focus()

func _launch(mode: String) -> void:
	if not launch_action.is_valid():
		return
	waves_button.disabled = true
	sandbox_button.disabled = true
	back_button.disabled = true
	launch_action.call(mode)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if close_action.is_valid():
			close_action.call()
