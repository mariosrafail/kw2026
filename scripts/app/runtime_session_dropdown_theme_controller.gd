extends RefCounted


var _pixel_popup_panel_stylebox: StyleBoxFlat = null
var _pixel_popup_hover_stylebox: StyleBoxFlat = null
var _pixel_popup_separator_stylebox: StyleBoxFlat = null
var _pixel_empty_icon_texture: Texture2D = null

func apply_pixel_dropdown_popups(
	lobby_weapon_option: OptionButton,
	lobby_character_option: OptionButton,
	lobby_skin_option: OptionButton,
	lobby_map_option: OptionButton,
	lobby_mode_option: OptionButton,
	pixel_font: Font
) -> void:
	apply_pixel_dropdown_popup(lobby_weapon_option, pixel_font)
	apply_pixel_dropdown_popup(lobby_character_option, pixel_font)
	apply_pixel_dropdown_popup(lobby_skin_option, pixel_font)
	apply_pixel_dropdown_popup(lobby_map_option, pixel_font)
	apply_pixel_dropdown_popup(lobby_mode_option, pixel_font)

func apply_pixel_dropdown_popup(option: OptionButton, pixel_font: Font) -> void:
	if option == null:
		return
	var popup: PopupMenu = option.get_popup()
	if popup == null:
		return

	popup.add_theme_stylebox_override("panel", pixel_popup_panel())
	popup.add_theme_stylebox_override("hover", pixel_popup_hover())
	popup.add_theme_stylebox_override("hover_pressed", pixel_popup_hover())
	popup.add_theme_stylebox_override("selected", pixel_popup_hover())
	popup.add_theme_stylebox_override("focus", pixel_popup_hover())
	popup.add_theme_stylebox_override("item_hover", pixel_popup_hover())
	popup.add_theme_stylebox_override("separator", pixel_popup_separator())

	# Hide the default radio/check icons (the "dots" on the left).
	var empty_icon: Texture2D = pixel_empty_icon()
	popup.add_theme_icon_override("checked", empty_icon)
	popup.add_theme_icon_override("unchecked", empty_icon)
	popup.add_theme_icon_override("radio_checked", empty_icon)
	popup.add_theme_icon_override("radio_unchecked", empty_icon)
	popup.add_theme_constant_override("check_margin", 0)
	disable_popup_checkmarks(popup)

	popup.add_theme_font_override("font", pixel_font)
	popup.add_theme_font_size_override("font_size", 16)

	popup.add_theme_color_override("font_color", Color(0.98, 0.97, 0.95, 1))
	popup.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	popup.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	popup.add_theme_color_override("font_disabled_color", Color(0.62, 0.65, 0.7, 0.9))
	popup.add_theme_constant_override("outline_size", 0)
	popup.add_theme_constant_override("v_separation", 2)
	popup.add_theme_constant_override("h_separation", 10)
	popup.add_theme_constant_override("item_start_padding", 10)
	popup.add_theme_constant_override("item_end_padding", 10)

func disable_popup_checkmarks(popup: PopupMenu) -> void:
	if popup == null:
		return
	var count: int = int(popup.item_count)
	for i in range(count):
		if popup.has_method("set_item_as_radio_checkable"):
			popup.call("set_item_as_radio_checkable", i, false)
		if popup.has_method("set_item_as_checkable"):
			popup.call("set_item_as_checkable", i, false)
		if popup.has_method("set_item_checked"):
			popup.call("set_item_checked", i, false)

func pixel_popup_panel() -> StyleBoxFlat:
	if _pixel_popup_panel_stylebox != null:
		return _pixel_popup_panel_stylebox
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.11, 0.16, 0.98)
	sb.border_width_left = 4
	sb.border_width_top = 4
	sb.border_width_right = 4
	sb.border_width_bottom = 4
	sb.border_color = Color(0.06, 0.05, 0.08, 1)
	sb.content_margin_left = 6.0
	sb.content_margin_top = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_bottom = 6.0
	sb.shadow_size = 6
	sb.shadow_color = Color(0, 0, 0, 0.45)
	_pixel_popup_panel_stylebox = sb
	return sb

func pixel_popup_hover() -> StyleBoxFlat:
	if _pixel_popup_hover_stylebox != null:
		return _pixel_popup_hover_stylebox
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.6, 0.85, 0.45)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.9, 0.74, 0.27, 0.9)
	_pixel_popup_hover_stylebox = sb
	return sb

func pixel_popup_separator() -> StyleBoxFlat:
	if _pixel_popup_separator_stylebox != null:
		return _pixel_popup_separator_stylebox
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.08, 1)
	_pixel_popup_separator_stylebox = sb
	return sb

func pixel_empty_icon() -> Texture2D:
	if _pixel_empty_icon_texture != null:
		return _pixel_empty_icon_texture
	var img: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_pixel_empty_icon_texture = ImageTexture.create_from_image(img)
	return _pixel_empty_icon_texture
