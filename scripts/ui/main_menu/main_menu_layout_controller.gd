extends RefCounted

class_name MainMenuLayoutController

const WARRIORS_BACK_BUTTON_SCREEN_POS := Vector2(16.0, 16.0)
const WARRIORS_TITLE_SCREEN_Y := 44.0

var _host: Control

func configure(host: Control) -> void:
	_host = host

func apply_center_pivots() -> void:
	for node_name in [
		"warrior_area",
		"weapon_area",
		"play_button",
		"options_button",
		"exit_button",
		"options_back_button",
		"warriors_back_button",
		"weapons_back_button",
		"warrior_action_button",
		"weapon_action_button",
	]:
		center_pivot(_host.get(node_name) as Control)

func sync_wallet_size_to_back_button() -> void:
	var wallet_panel := _host.get("wallet_panel") as Control
	var warriors_back_button := _host.get("warriors_back_button") as Button
	if wallet_panel == null or warriors_back_button == null:
		return
	var target_size := warriors_back_button.get_combined_minimum_size().ceil()
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		_host.call_deferred("_sync_wallet_size_to_back_button")
		return
	wallet_panel.offset_left = wallet_panel.offset_right - target_size.x
	wallet_panel.offset_bottom = wallet_panel.offset_top + target_size.y

func sync_warriors_header_centering() -> void:
	sync_wallet_size_to_back_button()
	var warriors_right_spacer := _host.get("warriors_right_spacer") as Control
	if warriors_right_spacer != null:
		warriors_right_spacer.custom_minimum_size = Vector2.ZERO
	pin_warriors_back_button()

func sync_weapons_header_centering() -> void:
	var weapons_top_row := _host.get("weapons_top_row") as HBoxContainer
	var weapons_back_button := _host.get("weapons_back_button") as Button
	var weapons_right_spacer := _host.get("weapons_right_spacer") as Control
	if weapons_top_row == null or weapons_back_button == null or weapons_right_spacer == null:
		return
	if weapons_top_row.size.x <= 0.0:
		_host.call_deferred("_sync_weapons_header_centering")
		return
	var back_w := weapons_back_button.size.x
	if back_w <= 0.0:
		back_w = weapons_back_button.get_combined_minimum_size().x
	var viewport_center_x := _host.get_viewport_rect().size.x * 0.5
	var row_left_x := weapons_top_row.global_position.x
	var required_spacer_w := weapons_top_row.size.x + back_w - 2.0 * (viewport_center_x - row_left_x)
	required_spacer_w = clampf(required_spacer_w, 0.0, weapons_top_row.size.x)
	weapons_right_spacer.custom_minimum_size = Vector2(required_spacer_w, 0.0)

func on_viewport_size_changed() -> void:
	_host.call_deferred("_sync_warriors_header_centering")
	_host.call_deferred("_sync_weapons_header_centering")
	_host.call_deferred("_pin_warriors_back_button")
	_host.call_deferred("_rebuild_background_cracks")
	_host.call_deferred("_layout_toxic_chat_stack")

func pin_warriors_back_button() -> void:
	var warriors_back_button := _host.get("warriors_back_button") as Button
	if warriors_back_button == null:
		return
	warriors_back_button.top_level = true
	warriors_back_button.z_as_relative = false
	warriors_back_button.z_index = 2500
	warriors_back_button.position = WARRIORS_BACK_BUTTON_SCREEN_POS
	var warriors_title := _host.get("warriors_title") as Label
	if warriors_title != null:
		warriors_title.top_level = true
		warriors_title.z_as_relative = false
		warriors_title.z_index = 2500
		var title_size := warriors_title.get_combined_minimum_size().ceil()
		if title_size.x <= 0.0:
			title_size.x = maxf(1.0, warriors_title.size.x)
		if title_size.y <= 0.0:
			title_size.y = maxf(1.0, warriors_title.size.y)
		warriors_title.size = title_size
		warriors_title.pivot_offset = title_size * 0.5
		var viewport_width := _host.get_viewport_rect().size.x
		var centered_x: float = floor((viewport_width - title_size.x) * 0.5)
		warriors_title.position = Vector2(maxf(0.0, centered_x), WARRIORS_TITLE_SCREEN_Y)

func center_pivot(control: Control) -> void:
	if control == null:
		return
	if control.size.x <= 0.0 or control.size.y <= 0.0:
		_host.call_deferred("_center_pivot", control)
		return
	control.pivot_offset = control.size * 0.5
