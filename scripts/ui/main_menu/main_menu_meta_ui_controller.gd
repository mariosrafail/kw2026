extends RefCounted
class_name MainMenuMetaUiController

const MENU_PALETTE := preload("res://scripts/ui/main_menu/menu_palette.gd")
var MENU_CLR_ACCENT := MENU_PALETTE.accent()
var MENU_CLR_TEXT_PRIMARY := MENU_PALETTE.text_primary()

func ensure_auth_logout_button(host: Control) -> void:
	var footer_panel := host.get("_auth_footer_panel") as PanelContainer
	var logout_button := host.get("_auth_logout_button") as Button
	if footer_panel != null and is_instance_valid(footer_panel) and logout_button != null and is_instance_valid(logout_button):
		layout_auth_logout_button(host)
		refresh_auth_footer(host)
		return

	var screen_main := host.get("screen_main") as Control
	if screen_main == null:
		return

	var panel := PanelContainer.new()
	panel.name = "AuthFooterPanel"
	panel.visible = false
	panel.z_index = 210
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = MENU_PALETTE.accent(0.92)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = MENU_CLR_ACCENT
	panel_style.corner_radius_top_left = 2
	panel_style.corner_radius_top_right = 2
	panel_style.corner_radius_bottom_left = 2
	panel_style.corner_radius_bottom_right = 2
	panel.add_theme_stylebox_override("panel", panel_style)
	screen_main.add_child(panel)
	host.set("_auth_footer_panel", panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var info := Label.new()
	info.name = "AuthFooterLabel"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", MENU_CLR_TEXT_PRIMARY)
	info.text = "Not logged in"
	row.add_child(info)
	host.set("_auth_footer_label", info)

	var btn := host.call("_make_shop_button") as Button
	btn.name = "LogoutButton"
	btn.text = "LOG OUT"
	btn.visible = true
	btn.custom_minimum_size = Vector2(118, 28)
	row.add_child(btn)
	host.set("_auth_logout_button", btn)

	layout_auth_logout_button(host)
	host.call_deferred("_layout_auth_logout_button")
	refresh_auth_footer(host)

func layout_auth_logout_button(host: Control) -> void:
	var footer_panel := host.get("_auth_footer_panel") as PanelContainer
	if footer_panel == null or not is_instance_valid(footer_panel):
		return
	var screen_main := host.get("screen_main") as Control
	if screen_main == null:
		return
	var measured := footer_panel.get_combined_minimum_size()
	var desired_size := Vector2(maxf(344.0, measured.x), maxf(44.0, measured.y))
	footer_panel.custom_minimum_size = desired_size
	if footer_panel.size.x <= 0.0 or footer_panel.size.y <= 0.0:
		footer_panel.size = desired_size
	var panel_size := Vector2(maxf(desired_size.x, footer_panel.size.x), maxf(desired_size.y, footer_panel.size.y))
	var margin_bottom := 12.0
	var x := floorf((screen_main.size.x - panel_size.x) * 0.5)
	var y := floorf(screen_main.size.y - panel_size.y - margin_bottom)
	footer_panel.position = Vector2(maxf(0.0, x), maxf(0.0, y))
	var logout_button := host.get("_auth_logout_button") as Button
	if logout_button != null and is_instance_valid(logout_button) and host.has_method("_center_pivot"):
		host.call("_center_pivot", logout_button)

func refresh_auth_footer(host: Control) -> void:
	var footer_panel := host.get("_auth_footer_panel") as PanelContainer
	if footer_panel == null or not is_instance_valid(footer_panel):
		return
	var logged: bool = host.get("_auth_logged_in") == true
	var logout_button := host.get("_auth_logout_button") as Button
	if logout_button != null and is_instance_valid(logout_button):
		logout_button.visible = logged
	var footer_label := host.get("_auth_footer_label") as Label
	if footer_label != null and is_instance_valid(footer_label):
		if logged:
			var username_text := str(host.get("player_username")).strip_edges()
			if username_text.is_empty():
				username_text = "Player"
			footer_label.text = "Logged in: %s" % username_text
		else:
			footer_label.text = "Not logged in"
	layout_auth_logout_button(host)
	refresh_meta_ui_visibility(host)

func is_main_menu_meta_ui_visible(host: Control) -> bool:
	# Keep meta UI visible on main screen even when lobby overlay is open,
	# so username stays above the warrior during lobby browsing.
	return host.get("_current_screen") == host.get("screen_main")

func refresh_meta_ui_visibility(host: Control) -> void:
	apply_meta_ui_visibility(host, is_main_menu_meta_ui_visible(host))

func apply_meta_ui_visibility(host: Control, show_on_main: bool) -> void:
	var lobby: Object = host.get("_lobby_overlay_ctrl") as Object
	var lobby_visible: bool = lobby != null and lobby.has_method("is_visible") and lobby.call("is_visible") == true
	var warrior_button := host.get("warrior_button") as BaseButton
	var warrior_button_visible := warrior_button != null and warrior_button.is_visible_in_tree()
	var show_username: bool = show_on_main and warrior_button_visible
	var show_footer: bool = host.get("_auth_logged_in") == true and show_on_main and not lobby_visible
	host.set("_meta_force_immediate_visibility", false)
	apply_meta_visibility_immediate(host, host.get("_warrior_username_label") as CanvasItem, show_username, "_meta_username_tween")
	apply_meta_visibility_immediate(host, host.get("_auth_footer_panel") as CanvasItem, show_footer, "_meta_footer_tween")

func apply_meta_visibility_immediate(host: Control, item: CanvasItem, should_show: bool, tween_slot: String) -> void:
	if item == null or not is_instance_valid(item):
		return
	var active_tween := host.get(tween_slot) as Tween
	if active_tween != null:
		active_tween.kill()
	host.set(tween_slot, null)
	item.visible = should_show
	item.modulate.a = 1.0 if should_show else 0.0

func tween_meta_visibility(host: Control, item: CanvasItem, should_show: bool, tween_slot: String) -> void:
	if item == null or not is_instance_valid(item):
		return
	var active_tween := host.get(tween_slot) as Tween
	if active_tween != null:
		active_tween.kill()
	var current_alpha := clampf(item.modulate.a, 0.0, 1.0)
	if should_show:
		item.visible = true
		if current_alpha < 0.98:
			item.modulate.a = current_alpha
		var t_show := host.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t_show.tween_property(item, "modulate:a", 1.0, 0.2)
		host.set(tween_slot, t_show)
	else:
		if not item.visible and current_alpha <= 0.01:
			item.modulate.a = 0.0
			host.set(tween_slot, null)
			return
		item.visible = true
		var t_hide := host.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t_hide.tween_property(item, "modulate:a", 0.0, 0.16)
		t_hide.tween_callback(func() -> void:
			item.visible = false
			item.modulate.a = 0.0
			host.set(tween_slot, null)
		)
		host.set(tween_slot, t_hide)

func ensure_warrior_username_label(host: Control) -> void:
	var label_existing := host.get("_warrior_username_label") as Label
	if label_existing != null and is_instance_valid(label_existing):
		return
	var warrior_area := host.get("warrior_area") as Control
	if warrior_area == null:
		return
	var label := Label.new()
	label.name = "WarriorUsername"
	label.z_as_relative = false
	label.z_index = 1500
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchors_preset = Control.PRESET_CENTER_TOP
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.anchor_top = 0.0
	label.anchor_bottom = 0.0
	label.offset_left = -64
	label.offset_right = 74
	label.offset_top = 45
	label.offset_bottom = 30
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	label.add_theme_color_override("font_outline_color", MENU_PALETTE.text_dark(1.0))
	label.add_theme_constant_override("outline_size", 0)
	warrior_area.add_child(label)
	host.set("_warrior_username_label", label)

func refresh_warrior_username_label(host: Control) -> void:
	var label := host.get("_warrior_username_label") as Label
	if label == null:
		return
	label.text = str(host.get("player_username"))
	refresh_meta_ui_visibility(host)
