extends RefCounted
class_name KWMenuSkin

const FONT := preload("res://assets/fonts/kwFont.ttf")

static func button_style(state: String) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	match state:
		"pressed":
			box.content_margin_left = 14.0
			box.content_margin_top = 9.0
			box.content_margin_right = 14.0
			box.content_margin_bottom = 7.0
			box.bg_color = Color(0.1569, 0.1098, 0.349, 0.96)
			box.border_width_left = 3
			box.border_width_top = 3
			box.border_width_right = 3
			box.border_width_bottom = 3
			box.border_color = Color(0.5216, 0.7804, 0.6039, 1)
			box.shadow_color = Color(0.1569, 0.1098, 0.349, 0.22)
			box.shadow_size = 1
		"hover":
			box.content_margin_left = 14.0
			box.content_margin_top = 8.0
			box.content_margin_right = 14.0
			box.content_margin_bottom = 8.0
			box.bg_color = Color(0.5216, 0.7804, 0.6039, 0.96)
			box.border_width_left = 3
			box.border_width_top = 3
			box.border_width_right = 3
			box.border_width_bottom = 5
			box.border_color = Color(0.9294, 0.9686, 0.7412, 1)
			box.shadow_color = Color(0.1569, 0.1098, 0.349, 0.24)
			box.shadow_size = 7
		"focus":
			box.bg_color = Color(0.3059, 0.5529, 0.6118, 0.56)
			box.border_width_left = 2
			box.border_width_top = 2
			box.border_width_right = 2
			box.border_width_bottom = 4
			box.border_color = Color(0.9294, 0.9686, 0.7412, 0.95)
		"disabled":
			box.content_margin_left = 14.0
			box.content_margin_top = 8.0
			box.content_margin_right = 14.0
			box.content_margin_bottom = 8.0
			box.bg_color = Color(0.3059, 0.5529, 0.6118, 0.32)
			box.border_width_left = 3
			box.border_width_top = 3
			box.border_width_right = 3
			box.border_width_bottom = 5
			box.border_color = Color(0.5216, 0.7804, 0.6039, 0.42)
			box.shadow_color = Color(0.1569, 0.1098, 0.349, 0.12)
			box.shadow_size = 2
		_:
			box.content_margin_left = 14.0
			box.content_margin_top = 8.0
			box.content_margin_right = 14.0
			box.content_margin_bottom = 8.0
			box.bg_color = Color(0.3059, 0.5529, 0.6118, 0.94)
			box.border_width_left = 3
			box.border_width_top = 3
			box.border_width_right = 3
			box.border_width_bottom = 5
			box.border_color = Color(0.5216, 0.7804, 0.6039, 1)
			box.shadow_color = Color(0.1569, 0.1098, 0.349, 0.28)
			box.shadow_size = 5
	return box

static func panel_style(alpha: float = 0.92) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.content_margin_left = 14.0
	box.content_margin_top = 12.0
	box.content_margin_right = 14.0
	box.content_margin_bottom = 12.0
	box.bg_color = Color(0.3059, 0.5529, 0.6118, alpha)
	box.border_width_left = 4
	box.border_width_top = 4
	box.border_width_right = 4
	box.border_width_bottom = 4
	box.border_color = Color(0.9294, 0.9686, 0.7412, 0.9)
	box.shadow_color = Color(0.1569, 0.1098, 0.349, 0.24)
	box.shadow_size = 6
	return box

static func dark_panel_style(alpha: float = 0.94) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.content_margin_left = 14.0
	box.content_margin_top = 10.0
	box.content_margin_right = 14.0
	box.content_margin_bottom = 10.0
	box.bg_color = Color(0.1216, 0.1569, 0.2549, alpha)
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 3
	box.border_color = Color(0.9294, 0.9686, 0.7412, 0.95)
	box.shadow_color = Color(0.06, 0.05, 0.08, 0.5)
	box.shadow_size = 0
	return box

static func apply_button(button: Button, font_size: int = 14, min_height: float = 34.0) -> void:
	button.custom_minimum_size.y = min_height
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98, 1))
	button.add_theme_color_override("font_hover_color", Color(0.92, 0.95, 0.98, 1))
	button.add_theme_color_override("font_pressed_color", Color(0.92, 0.95, 0.98, 1))
	button.add_theme_color_override("font_focus_color", Color(0.92, 0.95, 0.98, 1))
	button.add_theme_color_override("font_disabled_color", Color(0.82, 0.85, 0.88, 0.72))
	button.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.08, 1))
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_stylebox_override("normal", button_style("normal"))
	button.add_theme_stylebox_override("pressed", button_style("pressed"))
	button.add_theme_stylebox_override("hover", button_style("hover"))
	button.add_theme_stylebox_override("focus", button_style("focus"))
	button.add_theme_stylebox_override("disabled", button_style("disabled"))
