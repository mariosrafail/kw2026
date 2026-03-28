extends RefCounted
class_name MainMenuThemeController

const MENU_PALETTE := preload("res://scripts/ui/main_menu/menu_palette.gd")

var MENU_CLR_BASE: Color = Color.WHITE
var MENU_CLR_ACCENT: Color = Color.WHITE
var MENU_CLR_HOT: Color = Color.WHITE
var MENU_CLR_HIGHLIGHT: Color = Color.WHITE
var MENU_CLR_TEXT_PRIMARY: Color = Color.WHITE
var MENU_CLR_TEXT_DARK: Color = Color.BLACK

func _init() -> void:
	MENU_CLR_BASE = MENU_PALETTE.base()
	MENU_CLR_ACCENT = MENU_PALETTE.accent()
	MENU_CLR_HOT = MENU_PALETTE.hot()
	MENU_CLR_HIGHLIGHT = MENU_PALETTE.highlight()
	MENU_CLR_TEXT_PRIMARY = MENU_PALETTE.text_primary()
	MENU_CLR_TEXT_DARK = MENU_PALETTE.text_dark()

static func color_from_hex(hex: String, alpha: float = 1.0) -> Color:
	return MENU_PALETTE.color_from_hex(hex, alpha)

static func with_alpha(c: Color, alpha: float) -> Color:
	return MENU_PALETTE.with_alpha(c, alpha)

func apply_menu_background_palette(host: Control) -> void:
	var bg := host.get_node_or_null("Background") as ColorRect
	if bg != null:
		bg.color = MENU_CLR_ACCENT
	var noise := host.get_node_or_null("BgNoise") as TextureRect
	if noise != null:
		noise.modulate = with_alpha(MENU_CLR_HOT, 0.18)
		host.set("_bgnoise_base_alpha", noise.modulate.a)

func apply_uniform_button_outlines(host: Control, root: Node, border_width: int = 0) -> void:
	if root == null:
		return
	if root is Button:
		normalize_button_outline(host, root as Button, border_width)
	for child in root.get_children():
		if child is Node:
			apply_uniform_button_outlines(host, child as Node, border_width)

func normalize_button_outline(host: Control, btn: Button, border_width: int = 0) -> void:
	if btn == null:
		return
	var base_style := btn.get_theme_stylebox("normal")
	if not (base_style is StyleBoxFlat):
		return
	var base_flat := base_style as StyleBoxFlat
	for sb_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := btn.get_theme_stylebox(sb_name)
		var src: StyleBoxFlat = null
		if sb is StyleBoxFlat:
			src = sb as StyleBoxFlat
		else:
			src = base_flat
		var normalized := src.duplicate() as StyleBoxFlat
		normalized.border_width_left = border_width
		normalized.border_width_top = border_width
		normalized.border_width_right = border_width
		normalized.border_width_bottom = border_width
		normalized.corner_radius_top_left = base_flat.corner_radius_top_left
		normalized.corner_radius_top_right = base_flat.corner_radius_top_right
		normalized.corner_radius_bottom_left = base_flat.corner_radius_bottom_left
		normalized.corner_radius_bottom_right = base_flat.corner_radius_bottom_right
		normalized.bg_color = brighten_button_bg(normalized.bg_color, sb_name)
		btn.add_theme_stylebox_override(sb_name, normalized)

func apply_main_category_button_brightness(host: Control) -> void:
	var warrior_button := host.get("warrior_button") as Button
	var weapon_button := host.get("weapon_button") as Button
	apply_button_brightness_override(warrior_button)
	apply_button_brightness_override(weapon_button)

func apply_button_brightness_override(btn: Button) -> void:
	if btn == null:
		return
	var base_style := btn.get_theme_stylebox("normal")
	if not (base_style is StyleBoxFlat):
		return
	for sb_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := btn.get_theme_stylebox(sb_name)
		if not (sb is StyleBoxFlat):
			continue
		var flat := (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
		match sb_name:
			"normal":
				flat.bg_color = mix_to_color(flat.bg_color, MENU_CLR_ACCENT, 0.72)
			"hover":
				flat.bg_color = mix_to_color(flat.bg_color, MENU_CLR_HOT, 0.78)
			"pressed":
				flat.bg_color = mix_to_color(flat.bg_color, MENU_CLR_HOT, 0.66)
			"focus":
				flat.bg_color = mix_to_color(flat.bg_color, MENU_CLR_ACCENT, 0.8)
			"disabled":
				flat.bg_color = mix_to_color(flat.bg_color, MENU_CLR_BASE, 0.52)
		btn.add_theme_stylebox_override(sb_name, flat)

func mix_to_color(src: Color, target: Color, blend: float) -> Color:
	return Color(
		lerpf(src.r, target.r, clampf(blend, 0.0, 1.0)),
		lerpf(src.g, target.g, clampf(blend, 0.0, 1.0)),
		lerpf(src.b, target.b, clampf(blend, 0.0, 1.0)),
		src.a
	)

func brighten_button_bg(c: Color, state: String) -> Color:
	var target := MENU_CLR_BASE
	var blend := 0.52
	if state == "hover":
		target = MENU_CLR_ACCENT
		blend = 0.66
	elif state == "pressed":
		target = MENU_CLR_HOT
		blend = 0.62
	elif state == "focus":
		target = MENU_CLR_ACCENT
		blend = 0.68
	elif state == "disabled":
		target = MENU_CLR_BASE
		blend = 0.36
	var out := Color(
		lerpf(c.r, target.r, blend),
		lerpf(c.g, target.g, blend),
		lerpf(c.b, target.b, blend),
		c.a
	)
	if state != "disabled":
		out.a = clampf(c.a + 0.04, 0.0, 1.0)
	return out

func apply_pixel_slider_style(host: Control, slider: HSlider) -> void:
	if slider == null:
		return
	ensure_slider_grabbers(host)
	if host.has_method("_bind_menu_sfx_slider"):
		host.call("_bind_menu_sfx_slider", slider)

	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.add_theme_icon_override("grabber", host.get("_slider_grabber"))
	slider.add_theme_icon_override("grabber_highlight", host.get("_slider_grabber_hi"))

	var track := StyleBoxFlat.new()
	track.bg_color = with_alpha(MENU_CLR_ACCENT, 0.82)
	track.border_width_left = 3
	track.border_width_top = 3
	track.border_width_right = 3
	track.border_width_bottom = 3
	track.border_color = MENU_CLR_ACCENT
	track.content_margin_left = 6.0
	track.content_margin_right = 6.0
	track.content_margin_top = 4.0
	track.content_margin_bottom = 4.0
	slider.add_theme_stylebox_override("slider", track)

	var area := StyleBoxFlat.new()
	area.bg_color = with_alpha(MENU_CLR_ACCENT, 0.28)
	area.border_width_left = 2
	area.border_width_top = 2
	area.border_width_right = 2
	area.border_width_bottom = 2
	area.border_color = with_alpha(MENU_CLR_HIGHLIGHT, 0.62)
	slider.add_theme_stylebox_override("grabber_area_highlight", area)

	var focus := StyleBoxFlat.new()
	focus.bg_color = with_alpha(MENU_CLR_HOT, 0.2)
	focus.border_width_left = 2
	focus.border_width_top = 2
	focus.border_width_right = 2
	focus.border_width_bottom = 2
	focus.border_color = with_alpha(MENU_CLR_HOT, 0.55)
	slider.add_theme_stylebox_override("focus", focus)

func ensure_slider_grabbers(host: Control) -> void:
	if host.get("_slider_grabber") != null and host.get("_slider_grabber_hi") != null:
		return
	var border := MENU_CLR_ACCENT
	var fill := MENU_CLR_ACCENT
	var fill_hi := MENU_CLR_HIGHLIGHT

	var img := Image.create(9, 9, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	for x in range(9):
		img.set_pixel(x, 0, border)
		img.set_pixel(x, 8, border)
	for y in range(9):
		img.set_pixel(0, y, border)
		img.set_pixel(8, y, border)
	host.set("_slider_grabber", ImageTexture.create_from_image(img))

	var img_hi := Image.create(9, 9, false, Image.FORMAT_RGBA8)
	img_hi.fill(fill_hi)
	for x in range(9):
		img_hi.set_pixel(x, 0, border)
		img_hi.set_pixel(x, 8, border)
	for y in range(9):
		img_hi.set_pixel(0, y, border)
		img_hi.set_pixel(8, y, border)
	host.set("_slider_grabber_hi", ImageTexture.create_from_image(img_hi))

func apply_grid_spacing(grid: GridContainer) -> void:
	if grid == null:
		return
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)

func apply_pixel_scroll_style(host: Control, scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	ensure_scrollbar_styleboxes(host)
	var vsb := scroll.get_v_scroll_bar()
	if vsb != null:
		apply_pixel_scrollbar(host, vsb)
	var hsb := scroll.get_h_scroll_bar()
	if hsb != null:
		apply_pixel_scrollbar(host, hsb)

	var panel := StyleBoxFlat.new()
	panel.bg_color = with_alpha(MENU_CLR_ACCENT, 0.40)
	panel.border_width_left = 2
	panel.border_width_top = 2
	panel.border_width_right = 2
	panel.border_width_bottom = 2
	panel.border_color = with_alpha(MENU_CLR_ACCENT, 0.9)
	panel.content_margin_left = 6.0
	panel.content_margin_top = 6.0
	panel.content_margin_right = 6.0
	panel.content_margin_bottom = 6.0
	scroll.add_theme_stylebox_override("panel", panel)

func apply_pixel_scrollbar(host: Control, sb: ScrollBar) -> void:
	if sb == null:
		return
	sb.add_theme_stylebox_override("scroll", host.get("_scroll_sb"))
	sb.add_theme_stylebox_override("scroll_focus", host.get("_scroll_sb"))
	sb.add_theme_stylebox_override("grabber", host.get("_scroll_grabber_hi"))
	sb.add_theme_stylebox_override("grabber_highlight", host.get("_scroll_grabber_hi"))
	sb.add_theme_stylebox_override("grabber_pressed", host.get("_scroll_grabber_pressed"))

	sb.add_theme_constant_override("scrollbar_width", 12)
	sb.add_theme_constant_override("grabber_min_size", 28)

	var empty_icon := pixel_empty_icon()
	sb.add_theme_icon_override("increment", empty_icon)
	sb.add_theme_icon_override("decrement", empty_icon)

func ensure_scrollbar_styleboxes(host: Control) -> void:
	if host.get("_scroll_sb") != null:
		return
	var border := MENU_CLR_ACCENT

	var track := StyleBoxFlat.new()
	track.bg_color = with_alpha(MENU_CLR_ACCENT, 0.88)
	track.border_width_left = 3
	track.border_width_top = 3
	track.border_width_right = 3
	track.border_width_bottom = 3
	track.border_color = border
	track.content_margin_left = 2.0
	track.content_margin_right = 2.0
	track.content_margin_top = 2.0
	track.content_margin_bottom = 2.0
	host.set("_scroll_sb", track)

	var grab := StyleBoxFlat.new()
	grab.bg_color = with_alpha(MENU_CLR_ACCENT, 1.0)
	grab.border_width_left = 3
	grab.border_width_top = 3
	grab.border_width_right = 3
	grab.border_width_bottom = 3
	grab.border_color = border
	host.set("_scroll_grabber", grab)

	var grab_hi := StyleBoxFlat.new()
	grab_hi.bg_color = with_alpha(MENU_CLR_HOT, 1.0)
	grab_hi.border_width_left = 3
	grab_hi.border_width_top = 3
	grab_hi.border_width_right = 3
	grab_hi.border_width_bottom = 3
	grab_hi.border_color = MENU_CLR_HIGHLIGHT
	host.set("_scroll_grabber_hi", grab_hi)

	var grab_pressed := StyleBoxFlat.new()
	grab_pressed.bg_color = with_alpha(MENU_CLR_BASE, 1.0)
	grab_pressed.border_width_left = 3
	grab_pressed.border_width_top = 3
	grab_pressed.border_width_right = 3
	grab_pressed.border_width_bottom = 3
	grab_pressed.border_color = border
	host.set("_scroll_grabber_pressed", grab_pressed)

func pixel_empty_icon() -> Texture2D:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

func apply_runtime_palette(host: Control, root: Node = null) -> void:
	var start: Node = root if root != null else host
	if start == null:
		return
	_apply_palette_node_recursive(start)

func _apply_palette_node_recursive(node: Node) -> void:
	if node == null:
		return
	if node is Control:
		_apply_palette_to_control(node as Control)
	for child in node.get_children():
		if child is Node:
			_apply_palette_node_recursive(child as Node)

func _apply_palette_to_control(ctrl: Control) -> void:
	if ctrl == null:
		return
	for color_name in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_disabled_color",
		"font_focus_color",
		"font_outline_color",
		"font_placeholder_color",
		"caret_color"
	]:
		if ctrl.has_theme_color_override(color_name):
			var c := ctrl.get_theme_color(color_name)
			ctrl.add_theme_color_override(color_name, _remap_legacy_color(c))

	for sb_name in [
		"normal",
		"hover",
		"pressed",
		"focus",
		"disabled",
		"panel",
		"slider",
		"grabber_area_highlight",
		"scroll",
		"scroll_focus",
		"grabber",
		"grabber_highlight",
		"grabber_pressed"
	]:
		var sb := ctrl.get_theme_stylebox(sb_name)
		if not (sb is StyleBoxFlat):
			continue
		var flat := (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
		flat.bg_color = _remap_legacy_color(flat.bg_color)
		flat.border_color = _remap_legacy_color(flat.border_color)
		flat.shadow_color = _remap_legacy_color(flat.shadow_color)
		ctrl.add_theme_stylebox_override(sb_name, flat)

	if ctrl is ColorRect:
		var cr := ctrl as ColorRect
		cr.color = _remap_legacy_color(cr.color)
	if ctrl is CanvasItem:
		var ci := ctrl as CanvasItem
		ci.modulate = _remap_legacy_color(ci.modulate)

func _remap_legacy_color(c: Color) -> Color:
	var a := c.a
	if _is_near(c, Color(0.1569, 0.1098, 0.3490, a)):
		return with_alpha(MENU_CLR_BASE, a)
	if _is_near(c, Color(0.3059, 0.5529, 0.6118, a)):
		return with_alpha(MENU_CLR_ACCENT, a)
	if _is_near(c, Color(0.5216, 0.7804, 0.6039, a)):
		return with_alpha(MENU_CLR_HOT, a)
	if _is_near(c, Color(0.9294, 0.9686, 0.7412, a)):
		return with_alpha(MENU_CLR_HIGHLIGHT, a)
	if _is_near(c, Color(0.98, 0.97, 0.95, a)):
		return with_alpha(MENU_CLR_TEXT_PRIMARY, a)
	if _is_near(c, Color(0.94, 0.93, 0.9, a)):
		return with_alpha(MENU_CLR_TEXT_PRIMARY, a)
	if _is_near(c, Color(0.92, 0.95, 0.98, a)):
		return with_alpha(MENU_CLR_TEXT_DARK, a)
	if _is_near(c, Color(0.88, 0.9, 0.96, a)):
		return with_alpha(MENU_CLR_TEXT_DARK, a)
	if _is_near(c, Color(0.84, 0.84, 0.84, a)):
		return with_alpha(MENU_CLR_TEXT_DARK, a)
	if _is_near(c, Color(0.66, 0.66, 0.7, a)):
		return with_alpha(MENU_CLR_TEXT_DARK, a)
	if _is_near(c, Color(0.06, 0.05, 0.08, a)):
		return with_alpha(MENU_CLR_TEXT_DARK, a)
	if _is_near(c, Color(0.90, 0.74, 0.27, a)):
		return with_alpha(MENU_CLR_HIGHLIGHT, a)
	if _is_near(c, Color(0.5248462, 0.7325527, 0.7741166, a)):
		return with_alpha(mix_to_color(MENU_CLR_ACCENT, MENU_CLR_HOT, 0.34), a)
	return c

func _is_near(a: Color, b: Color, eps: float = 0.02) -> bool:
	return absf(a.r - b.r) <= eps and absf(a.g - b.g) <= eps and absf(a.b - b.b) <= eps
