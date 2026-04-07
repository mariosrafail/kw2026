extends RefCounted

class_name MainMenuShopGridController

const DATA := preload("res://scripts/ui/main_menu/data.gd")
const MENU_PALETTE := preload("res://scripts/ui/main_menu/menu_palette.gd")

const WEAPON_UZI := DATA.WEAPON_UZI
const WEAPON_GRENADE := DATA.WEAPON_GRENADE
const WEAPON_AK47 := DATA.WEAPON_AK47
const WEAPON_KAR := DATA.WEAPON_KAR
const WEAPON_SHOTGUN := DATA.WEAPON_SHOTGUN

var _host: Control

func configure(host: Control) -> void:
	_host = host

func build_warrior_shop_grid() -> void:
	_host.call("_clear_children", _host.get("warrior_grid"))
	var warrior_ui = _host.get("_warrior_ui")
	if warrior_ui == null or not warrior_ui.has_method("warrior_ids"):
		return
	var warrior_list: PackedStringArray = warrior_ui.call("warrior_ids")
	var warrior_grid := _host.get("warrior_grid") as GridContainer
	for warrior_id in warrior_list:
		var preview_skin_index := int(_host.call("_equipped_warrior_skin", warrior_id))
		var btn: Button = warrior_ui.call("make_warrior_item_button", _host, Callable(_host, "_make_shop_button"), warrior_id, preview_skin_index, "warrior")
		btn.pressed.connect(Callable(_host, "_on_warrior_select_button_pressed").bind(warrior_id))
		warrior_grid.add_child(btn)
		_host.call("_center_pivot", btn)
	_host.call("_build_warrior_skin_grid", str(_host.get("_pending_warrior_id")))

func build_warrior_skin_grid(warrior_id: String) -> void:
	var warrior_skin_grid := _host.get("warrior_skin_grid") as GridContainer
	_host.call("_clear_children", warrior_skin_grid)
	if warrior_skin_grid == null:
		return
	var normalized := warrior_id.strip_edges().to_lower()
	if normalized.is_empty():
		normalized = str(_host.get("selected_warrior_id"))
	var warrior_ui = _host.get("_warrior_ui")
	if warrior_ui == null or not warrior_ui.has_method("warrior_skins_for"):
		return
	var warrior_skins: Array = warrior_ui.call("warrior_skins_for", normalized)
	for skin in warrior_skins:
		var skin_index := int((skin as Dictionary).get("index", 0))
		var btn: Button = warrior_ui.call("make_warrior_item_button", _host, Callable(_host, "_make_shop_button"), normalized, skin_index, "skin")
		btn.pressed.connect(Callable(_host, "_on_warrior_skin_button_pressed").bind(normalized, skin_index))
		warrior_skin_grid.add_child(btn)
		_host.call("_center_pivot", btn)

func on_warrior_select_button_pressed(warrior_id: String) -> void:
	var normalized := warrior_id.strip_edges().to_lower()
	var target_skin := int(_host.call("_equipped_warrior_skin", normalized))
	if not bool(_host.call("_warrior_is_owned", normalized)):
		target_skin = 0
	_host.call("_select_warrior_skin", normalized, target_skin, false)

func on_warrior_skin_button_pressed(warrior_id: String, skin_index: int) -> void:
	_host.call("_on_warrior_item_button_pressed", warrior_id, skin_index)

func build_weapon_shop_grid() -> void:
	var weapon_grid := _host.get("weapon_grid") as GridContainer
	_host.call("_clear_children", weapon_grid)
	if weapon_grid != null:
		weapon_grid.columns = 4
	var weapon_list: Array = [WEAPON_UZI, WEAPON_AK47, WEAPON_KAR, WEAPON_SHOTGUN, WEAPON_GRENADE]
	var selected_filter := str(_host.get("_weapon_filter_weapon_id"))
	if not selected_filter.is_empty():
		weapon_list = [selected_filter]
	var weapon_ui = _host.get("_weapon_ui")
	if weapon_ui == null or not weapon_ui.has_method("make_weapon_item_button"):
		return
	for weapon_id in weapon_list:
		var skins: Array = _host.call("_weapon_skins_for", weapon_id)
		for skin in skins:
			var skin_index := int((skin as Dictionary).get("skin", 0))
			var btn: Button = weapon_ui.call("make_weapon_item_button", _host, Callable(_host, "_make_shop_button"), weapon_id, skin_index)
			btn.pressed.connect(Callable(_host, "_on_weapon_item_button_pressed").bind(weapon_id, skin_index))
			weapon_grid.add_child(btn)
			_host.call("_center_pivot", btn)

func make_shop_button() -> Button:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(170, 32)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.clip_text = true
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.clip_contents = true
	copy_button_look(_host.get("options_button") as Button, btn)
	_host.call("_normalize_button_outline", btn, 0)
	btn.add_theme_font_size_override("font_size", 11)
	_host.call("_add_hover_pop", btn)
	btn.pressed.connect(func() -> void:
		_host.call("_button_press_anim", btn)
	)
	return btn

func copy_button_look(src: Button, dst: Button) -> void:
	if src == null or dst == null:
		return
	for sb_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		if src.has_theme_stylebox_override(sb_name):
			var stylebox := src.get_theme_stylebox(sb_name)
			dst.add_theme_stylebox_override(sb_name, stylebox)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		if src.has_theme_color_override(color_name):
			var color := src.get_theme_color(color_name)
			dst.add_theme_color_override(color_name, color)
	if src.has_theme_font_override("font"):
		var font := src.get_theme_font("font")
		if font != null:
			dst.add_theme_font_override("font", font)
	dst.add_theme_color_override("font_color", MENU_PALETTE.text_dark(1.0))
	dst.add_theme_color_override("font_hover_color", MENU_PALETTE.text_dark(1.0))
	dst.add_theme_color_override("font_pressed_color", MENU_PALETTE.text_dark(1.0))
	dst.add_theme_color_override("font_disabled_color", MENU_PALETTE.text_dark(0.9))
	dst.add_theme_constant_override("outline_size", 0)
	_host.call("_normalize_button_outline", dst, 0)
