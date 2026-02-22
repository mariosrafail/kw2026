extends RefCounted
class_name LobbyUiBuilder

static func bind_scene_ui(
	owner: Node,
	font: Font,
	on_create_pressed: Callable,
	on_join_pressed: Callable,
	on_refresh_pressed: Callable,
	on_leave_pressed: Callable,
	on_selection_changed: Callable,
	on_empty_clicked: Callable,
	on_weapon_selected: Callable,
	on_character_selected: Callable,
	on_map_selected: Callable
) -> Dictionary:
	var refs := {
		"lobby_canvas": owner.get_node_or_null("LobbyUi") as CanvasLayer,
		"lobby_panel": owner.get_node_or_null("LobbyUi/LobbyPanel") as PanelContainer,
		"lobby_name_input": owner.get_node_or_null("LobbyUi/LobbyPanel/Margin/VBox/LobbyNameRow/LobbyNameInput") as LineEdit,
		"lobby_list": owner.get_node_or_null("LobbyUi/LobbyPanel/Margin/VBox/LobbyList") as ItemList,
		"lobby_status_label": owner.get_node_or_null("LobbyUi/LobbyPanel/Margin/VBox/LobbyStatusLabel") as Label,
		"lobby_create_button": owner.get_node_or_null("LobbyUi/LobbyPanel/Margin/VBox/LobbyNameRow/LobbyCreateButton") as Button,
		"lobby_join_button": owner.get_node_or_null("LobbyUi/LobbyPanel/Margin/VBox/LobbyActionsRow/LobbyJoinButton") as Button,
		"lobby_refresh_button": owner.get_node_or_null("LobbyUi/LobbyPanel/Margin/VBox/LobbyActionsRow/LobbyRefreshButton") as Button,
		"lobby_leave_button": owner.get_node_or_null("LobbyUi/LobbyPanel/Margin/VBox/LobbyActionsRow/LobbyLeaveButton") as Button,
		"lobby_weapon_option": owner.get_node_or_null("LobbyUi/LobbyPanel/Margin/VBox/LoadoutRow/LobbyWeaponOption") as OptionButton,
		"lobby_character_option": owner.get_node_or_null("LobbyUi/LobbyPanel/Margin/VBox/LoadoutRow/LobbyCharacterOption") as OptionButton,
		"lobby_map_option": owner.get_node_or_null("LobbyUi/LobbyPanel/Margin/VBox/MapRow/LobbyMapOption") as OptionButton,
		"lobby_room_bg": owner.get_node_or_null("LobbyUi/LobbyRoomBg") as ColorRect,
		"lobby_room_title": owner.get_node_or_null("LobbyUi/LobbyRoomTitle") as Label
	}

	var controls := [
		refs.get("lobby_room_title", null) as Control,
		refs.get("lobby_status_label", null) as Control,
		refs.get("lobby_list", null) as Control,
		refs.get("lobby_name_input", null) as Control,
		refs.get("lobby_create_button", null) as Control,
		refs.get("lobby_join_button", null) as Control,
		refs.get("lobby_refresh_button", null) as Control,
		refs.get("lobby_leave_button", null) as Control,
		refs.get("lobby_weapon_option", null) as Control,
		refs.get("lobby_map_option", null) as Control
	]
	for control in controls:
		if control != null and font != null:
			control.add_theme_font_override("font", font)

	var create_button := refs.get("lobby_create_button", null) as Button
	var join_button := refs.get("lobby_join_button", null) as Button
	var refresh_button := refs.get("lobby_refresh_button", null) as Button
	var leave_button := refs.get("lobby_leave_button", null) as Button
	var lobby_list := refs.get("lobby_list", null) as ItemList
	var lobby_weapon_option := refs.get("lobby_weapon_option", null) as OptionButton
	var lobby_map_option := refs.get("lobby_map_option", null) as OptionButton
	_connect_button_once(create_button, on_create_pressed)
	_connect_button_once(join_button, on_join_pressed)
	_connect_button_once(refresh_button, on_refresh_pressed)
	_connect_button_once(leave_button, on_leave_pressed)
	if lobby_list != null:
		if on_selection_changed.is_valid() and not lobby_list.item_selected.is_connected(on_selection_changed):
			lobby_list.item_selected.connect(on_selection_changed)
		if on_empty_clicked.is_valid() and not lobby_list.empty_clicked.is_connected(on_empty_clicked):
			lobby_list.empty_clicked.connect(on_empty_clicked)
	if lobby_weapon_option != null:
		if on_weapon_selected.is_valid() and not lobby_weapon_option.item_selected.is_connected(on_weapon_selected):
			lobby_weapon_option.item_selected.connect(on_weapon_selected)
	var lobby_character_option := refs.get("lobby_character_option", null) as OptionButton
	if lobby_character_option != null:
		if on_character_selected.is_valid() and not lobby_character_option.item_selected.is_connected(on_character_selected):
			lobby_character_option.item_selected.connect(on_character_selected)
	if lobby_map_option != null:
		if on_map_selected.is_valid() and not lobby_map_option.item_selected.is_connected(on_map_selected):
			lobby_map_option.item_selected.connect(on_map_selected)

	return refs

static func build(
	owner: Node,
	font: Font,
	on_create_pressed: Callable,
	on_join_pressed: Callable,
	on_refresh_pressed: Callable,
	on_leave_pressed: Callable,
	on_selection_changed: Callable,
	on_weapon_selected: Callable,
	on_character_selected: Callable,
	on_map_selected: Callable
) -> Dictionary:
	var refs: Dictionary = {}

	var lobby_canvas := CanvasLayer.new()
	lobby_canvas.name = "LobbyUi"
	lobby_canvas.layer = 30
	owner.add_child(lobby_canvas)

	var lobby_room_bg := ColorRect.new()
	lobby_room_bg.anchor_right = 1.0
	lobby_room_bg.anchor_bottom = 1.0
	lobby_room_bg.color = Color(0.08, 0.11, 0.16, 1.0)
	lobby_canvas.add_child(lobby_room_bg)

	var lobby_room_title := Label.new()
	lobby_room_title.text = "KW LOBBY ROOM"
	lobby_room_title.anchor_left = 0.5
	lobby_room_title.anchor_top = 0.18
	lobby_room_title.anchor_right = 0.5
	lobby_room_title.anchor_bottom = 0.18
	lobby_room_title.offset_left = -220.0
	lobby_room_title.offset_top = -22.0
	lobby_room_title.offset_right = 220.0
	lobby_room_title.offset_bottom = 22.0
	lobby_room_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_room_title.add_theme_font_size_override("font_size", 26)
	lobby_canvas.add_child(lobby_room_title)

	var lobby_panel := PanelContainer.new()
	lobby_panel.name = "LobbyPanel"
	lobby_panel.anchor_left = 0.5
	lobby_panel.anchor_top = 0.5
	lobby_panel.anchor_right = 0.5
	lobby_panel.anchor_bottom = 0.5
	lobby_panel.offset_left = -220.0
	lobby_panel.offset_top = -170.0
	lobby_panel.offset_right = 220.0
	lobby_panel.offset_bottom = 170.0
	lobby_canvas.add_child(lobby_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	lobby_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var lobby_status_label := Label.new()
	lobby_status_label.text = "Choose lobby"
	lobby_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lobby_status_label)

	var lobby_list := ItemList.new()
	lobby_list.custom_minimum_size = Vector2(0.0, 130.0)
	lobby_list.select_mode = ItemList.SELECT_SINGLE
	lobby_list.allow_rmb_select = false
	lobby_list.item_selected.connect(func(_index: int) -> void:
		if on_selection_changed.is_valid():
			on_selection_changed.call()
	)
	lobby_list.empty_clicked.connect(func(_position: Vector2, _mouse_button: int) -> void:
		if on_selection_changed.is_valid():
			on_selection_changed.call()
	)
	vbox.add_child(lobby_list)

	var create_row := HBoxContainer.new()
	create_row.add_theme_constant_override("separation", 6)
	vbox.add_child(create_row)

	var lobby_name_input := LineEdit.new()
	lobby_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_name_input.placeholder_text = "Lobby name"
	create_row.add_child(lobby_name_input)

	var lobby_create_button := Button.new()
	lobby_create_button.text = "Create Lobby"
	if on_create_pressed.is_valid():
		lobby_create_button.pressed.connect(on_create_pressed)
	create_row.add_child(lobby_create_button)

	var actions_row := HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 6)
	vbox.add_child(actions_row)

	var loadout_row := HBoxContainer.new()
	loadout_row.name = "LoadoutRow"
	loadout_row.add_theme_constant_override("separation", 6)
	vbox.add_child(loadout_row)

	var weapon_label := Label.new()
	weapon_label.text = "Weapon"
	loadout_row.add_child(weapon_label)

	var lobby_weapon_option := OptionButton.new()
	lobby_weapon_option.name = "LobbyWeaponOption"
	lobby_weapon_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_weapon_option.add_item("AK47")
	lobby_weapon_option.add_item("Uzi")
	if on_weapon_selected.is_valid():
		lobby_weapon_option.item_selected.connect(on_weapon_selected)
	loadout_row.add_child(lobby_weapon_option)

	var character_label := Label.new()
	character_label.text = "Character"
	loadout_row.add_child(character_label)

	var lobby_character_option := OptionButton.new()
	lobby_character_option.name = "LobbyCharacterOption"
	lobby_character_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_character_option.add_item("Outrage")
	lobby_character_option.set_item_metadata(0, "outrage")
	lobby_character_option.add_item("Erebus")
	lobby_character_option.set_item_metadata(1, "erebus")
	lobby_character_option.add_item("Tasko")
	lobby_character_option.set_item_metadata(2, "tasko")
	if on_character_selected.is_valid():
		lobby_character_option.item_selected.connect(on_character_selected)
	loadout_row.add_child(lobby_character_option)

	var skin_row := HBoxContainer.new()
	skin_row.name = "SkinRow"
	skin_row.add_theme_constant_override("separation", 6)
	vbox.add_child(skin_row)

	var skin_label := Label.new()
	skin_label.name = "SkinLabel"
	skin_label.text = "Skin"
	skin_row.add_child(skin_label)

	var lobby_skin_option := OptionButton.new()
	lobby_skin_option.name = "LobbySkinOption"
	lobby_skin_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skin_row.add_child(lobby_skin_option)

	var map_row := HBoxContainer.new()
	map_row.name = "MapRow"
	map_row.add_theme_constant_override("separation", 6)
	vbox.add_child(map_row)

	var map_label := Label.new()
	map_label.text = "Map"
	map_row.add_child(map_label)

	var lobby_map_option := OptionButton.new()
	lobby_map_option.name = "LobbyMapOption"
	lobby_map_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_map_option.add_item("Classic")
	lobby_map_option.add_item("Cyber")
	if on_map_selected.is_valid():
		lobby_map_option.item_selected.connect(on_map_selected)
	map_row.add_child(lobby_map_option)

	var lobby_join_button := Button.new()
	lobby_join_button.text = "Join Lobby"
	lobby_join_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if on_join_pressed.is_valid():
		lobby_join_button.pressed.connect(on_join_pressed)
	actions_row.add_child(lobby_join_button)

	var lobby_refresh_button := Button.new()
	lobby_refresh_button.text = "Refresh"
	if on_refresh_pressed.is_valid():
		lobby_refresh_button.pressed.connect(on_refresh_pressed)
	actions_row.add_child(lobby_refresh_button)

	var lobby_leave_button := Button.new()
	lobby_leave_button.text = "Leave"
	if on_leave_pressed.is_valid():
		lobby_leave_button.pressed.connect(on_leave_pressed)
	actions_row.add_child(lobby_leave_button)

	for control in [
		lobby_room_title,
		lobby_status_label,
		lobby_list,
		lobby_name_input,
		lobby_create_button,
		lobby_join_button,
		lobby_refresh_button,
		lobby_leave_button,
		weapon_label,
		lobby_weapon_option,
		character_label,
		lobby_character_option,
		map_label,
		lobby_map_option
	]:
		if control != null and font != null:
			control.add_theme_font_override("font", font)

	lobby_panel.visible = false
	lobby_room_bg.visible = false
	lobby_room_title.visible = false

	refs["lobby_canvas"] = lobby_canvas
	refs["lobby_panel"] = lobby_panel
	refs["lobby_name_input"] = lobby_name_input
	refs["lobby_list"] = lobby_list
	refs["lobby_status_label"] = lobby_status_label
	refs["lobby_create_button"] = lobby_create_button
	refs["lobby_join_button"] = lobby_join_button
	refs["lobby_refresh_button"] = lobby_refresh_button
	refs["lobby_leave_button"] = lobby_leave_button
	refs["lobby_weapon_option"] = lobby_weapon_option
	refs["lobby_character_option"] = lobby_character_option
	refs["lobby_map_option"] = lobby_map_option
	refs["lobby_room_bg"] = lobby_room_bg
	refs["lobby_room_title"] = lobby_room_title
	return refs

static func _connect_button_once(button: Button, callback: Callable) -> void:
	if button == null:
		return
	if not callback.is_valid():
		return
	if button.pressed.is_connected(callback):
		return
	button.pressed.connect(callback)
