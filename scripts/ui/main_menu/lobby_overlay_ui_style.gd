extends RefCounted
class_name LobbyOverlayUiStyle
const MENU_PALETTE := preload("res://scripts/ui/main_menu/menu_palette.gd")

func position_option_popup_below(option: OptionButton, popup: PopupMenu) -> void:
	if option == null or popup == null:
		return
	var origin := option.get_screen_position()
	var popup_x := int(round(origin.x))
	var popup_y := int(round(origin.y + option.size.y + 2.0))
	popup.position = Vector2i(popup_x, popup_y)

func remove_popup_left_markers(popup: PopupMenu) -> void:
	if popup == null:
		return
	for i in range(popup.get_item_count()):
		popup.set_item_as_checkable(i, false)
		popup.set_item_as_radio_checkable(i, false)
		popup.set_item_icon(i, null)

func make_pixel_dropdown_arrow() -> Texture2D:
	var img := Image.create(9, 9, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var color := MENU_PALETTE.highlight(1.0)
	var rows := {
		2: PackedInt32Array([2, 3, 4, 5, 6]),
		3: PackedInt32Array([3, 4, 5]),
		4: PackedInt32Array([3, 4, 5]),
		5: PackedInt32Array([4]),
	}
	for y in rows.keys():
		var xs := rows[y] as PackedInt32Array
		for x in xs:
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)

func make_pixel_checkbox_icon(checked: bool) -> Texture2D:
	var img := Image.create(11, 11, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var border := MENU_PALETTE.highlight(1.0)
	var fill := MENU_PALETTE.hot(1.0)
	for y in range(11):
		for x in range(11):
			var on_border := x == 0 or x == 10 or y == 0 or y == 10
			img.set_pixel(x, y, border if on_border else fill)
	if checked:
		var accent := MENU_PALETTE.highlight(1.0)
		for y in range(2, 9):
			for x in range(2, 9):
				img.set_pixel(x, y, accent)
	return ImageTexture.create_from_image(img)

func apply_pixel_checkbox_style(check: CheckBox) -> void:
	if check == null:
		return
	check.alignment = HORIZONTAL_ALIGNMENT_LEFT
	check.add_theme_constant_override("h_separation", 6)
	check.add_theme_color_override("font_color", MENU_PALETTE.text_dark(1.0))
	check.add_theme_color_override("font_hover_color", MENU_PALETTE.text_dark(1.0))
	check.add_theme_color_override("font_pressed_color", MENU_PALETTE.text_dark(1.0))
	check.add_theme_color_override("font_disabled_color", MENU_PALETTE.text_dark(0.74))
	var unchecked := make_pixel_checkbox_icon(false)
	var checked := make_pixel_checkbox_icon(true)
	check.add_theme_icon_override("unchecked", unchecked)
	check.add_theme_icon_override("checked", checked)
	check.add_theme_icon_override("unchecked_disabled", unchecked)
	check.add_theme_icon_override("checked_disabled", checked)
	check.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func apply_button_palette(btn: Button, normal_bg: Color, border: Color) -> void:
	if btn == null:
		return
	for sb_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := btn.get_theme_stylebox(sb_name)
		var flat := StyleBoxFlat.new()
		if sb is StyleBoxFlat:
			flat = (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
		flat.border_width_left = maxi(1, flat.border_width_left)
		flat.border_width_top = maxi(1, flat.border_width_top)
		flat.border_width_right = maxi(1, flat.border_width_right)
		flat.border_width_bottom = maxi(1, flat.border_width_bottom)
		flat.corner_radius_top_left = 0
		flat.corner_radius_top_right = 0
		flat.corner_radius_bottom_right = 0
		flat.corner_radius_bottom_left = 0
		if sb_name == "hover":
			flat.bg_color = _tinted_color(normal_bg, 0.06)
		elif sb_name == "pressed":
			flat.bg_color = _tinted_color(normal_bg, -0.07)
		elif sb_name == "disabled":
			flat.bg_color = Color(normal_bg.r, normal_bg.g, normal_bg.b, 0.42)
		else:
			flat.bg_color = normal_bg
		flat.border_color = Color(border.r, border.g, border.b, 0.48) if sb_name == "disabled" else border
		btn.add_theme_stylebox_override(sb_name, flat)
	btn.add_theme_color_override("font_color", MENU_PALETTE.text_dark(1.0))
	btn.add_theme_color_override("font_hover_color", MENU_PALETTE.text_dark(1.0))
	btn.add_theme_color_override("font_pressed_color", MENU_PALETTE.text_dark(1.0))
	btn.add_theme_color_override("font_disabled_color", MENU_PALETTE.text_dark(0.9))

func apply_ready_button_state_style(btn: Button, is_ready: bool, ready_bg: Color, ready_border: Color, idle_bg: Color, idle_border: Color) -> void:
	if btn == null:
		return
	if is_ready:
		apply_button_palette(btn, ready_bg, ready_border)
	else:
		apply_button_palette(btn, idle_bg, idle_border)

func set_rooms_list_visible(rooms_box: VBoxContainer, rooms_list_panel: PanelContainer, visible: bool) -> void:
	if rooms_box != null:
		rooms_box.visible = visible
	if rooms_list_panel != null:
		rooms_list_panel.visible = visible

func apply_compact_option_style(option: OptionButton, arrow: Texture2D) -> void:
	if option == null:
		return
	option.alignment = HORIZONTAL_ALIGNMENT_LEFT
	option.add_theme_constant_override("arrow_margin", 4)
	option.add_theme_constant_override("h_separation", 4)
	option.add_theme_color_override("font_color", MENU_PALETTE.text_primary(1.0))
	option.add_theme_color_override("font_hover_color", MENU_PALETTE.text_primary(1.0))
	option.add_theme_color_override("font_pressed_color", MENU_PALETTE.text_primary(1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = MENU_PALETTE.accent(1.0)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = MENU_PALETTE.accent(1.0)
	normal.content_margin_left = 6
	normal.content_margin_right = 6
	normal.content_margin_top = 3
	normal.content_margin_bottom = 3
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = MENU_PALETTE.highlight(1.0)
	option.add_theme_stylebox_override("normal", normal)
	option.add_theme_stylebox_override("hover", hover)
	option.add_theme_stylebox_override("pressed", normal)
	option.add_theme_stylebox_override("focus", normal)
	option.add_theme_icon_override("arrow", arrow)
	var popup := option.get_popup()
	var panel := StyleBoxFlat.new()
	panel.bg_color = MENU_PALETTE.accent(1.0)
	panel.border_width_left = 2
	panel.border_width_top = 2
	panel.border_width_right = 2
	panel.border_width_bottom = 2
	panel.border_color = MENU_PALETTE.accent(1.0)
	var hover_popup := StyleBoxFlat.new()
	hover_popup.bg_color = MENU_PALETTE.hot(1.0)
	hover_popup.border_width_left = 1
	hover_popup.border_width_top = 1
	hover_popup.border_width_right = 1
	hover_popup.border_width_bottom = 1
	hover_popup.border_color = MENU_PALETTE.highlight(1.0)
	var selected_popup := StyleBoxFlat.new()
	selected_popup.bg_color = MENU_PALETTE.accent(1.0)
	selected_popup.border_width_left = 1
	selected_popup.border_width_top = 1
	selected_popup.border_width_right = 1
	selected_popup.border_width_bottom = 1
	selected_popup.border_color = MENU_PALETTE.accent(1.0)
	popup.add_theme_stylebox_override("panel", panel)
	popup.add_theme_stylebox_override("hover", hover_popup)
	popup.add_theme_stylebox_override("hover_pressed", hover_popup)
	popup.add_theme_stylebox_override("selected", selected_popup)
	popup.add_theme_stylebox_override("focus", selected_popup)
	popup.add_theme_stylebox_override("item_hover", hover_popup)
	popup.add_theme_constant_override("v_separation", 2)
	popup.add_theme_constant_override("h_separation", 6)
	popup.add_theme_color_override("font_color", MENU_PALETTE.text_primary(1.0))
	popup.add_theme_color_override("font_hover_color", MENU_PALETTE.text_primary(1.0))
	popup.add_theme_color_override("font_selected_color", MENU_PALETTE.text_primary(1.0))
	popup.add_theme_font_size_override("font_size", 8)

func remove_button_outlines(btn: Button) -> void:
	if btn == null:
		return
	for sb_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := btn.get_theme_stylebox(sb_name)
		if not (sb is StyleBoxFlat):
			continue
		var flat := (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
		flat.border_width_left = 0
		flat.border_width_top = 0
		flat.border_width_right = 0
		flat.border_width_bottom = 0
		btn.add_theme_stylebox_override(sb_name, flat)

func _tinted_color(color: Color, amount: float) -> Color:
	return Color(
		clampf(color.r + amount, 0.0, 1.0),
		clampf(color.g + amount, 0.0, 1.0),
		clampf(color.b + amount, 0.0, 1.0),
		color.a
	)

