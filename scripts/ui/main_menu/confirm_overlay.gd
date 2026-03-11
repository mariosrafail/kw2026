extends Control

var _make_button: Callable
var _set_weapon_icon: Callable
var _apply_weapon_skin: Callable
var _center_pivot_cb: Callable
var _hover_pop_cb: Callable
var _press_anim_cb: Callable
var _release_to_hover_cb: Callable

var _panel: Control
var _title_label: Label
var _text_label: Label
var _weapon_slot: Control
var _weapon_sprite: Sprite2D
var _ok_button: Button
var _cancel_button: Button

var _on_confirm: Callable = Callable()

func _make_menu_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.content_margin_left = 14.0
	sb.content_margin_top = 12.0
	sb.content_margin_right = 14.0
	sb.content_margin_bottom = 12.0
	sb.bg_color = Color(0.12, 0.11, 0.16, 0.98)
	sb.border_width_left = 4
	sb.border_width_top = 4
	sb.border_width_right = 4
	sb.border_width_bottom = 4
	sb.border_color = Color(0.06, 0.05, 0.08, 1)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	return sb

func _make_menu_button_hover_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.content_margin_left = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_right = 14.0
	sb.content_margin_bottom = 8.0
	sb.bg_color = Color(0.1, 0.17, 0.27, 1)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 5
	sb.border_color = Color(0.33, 0.95, 1, 1)
	sb.shadow_color = Color(0.02, 0.18, 0.24, 0.7)
	sb.shadow_size = 7
	return sb

func _make_menu_button_focus_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.content_margin_left = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_right = 14.0
	sb.content_margin_bottom = 8.0
	sb.bg_color = Color(0.08, 0.22, 0.31, 0.5)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 4
	sb.border_color = Color(0.5, 0.98, 1, 0.95)
	sb.shadow_color = Color(0.02, 0.12, 0.18, 0.35)
	sb.shadow_size = 4
	return sb

func _normalize_confirm_button_theme(btn: Button) -> void:
	if btn == null:
		return
	btn.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.08, 1))
	btn.add_theme_constant_override("outline_size", 0)
	var hover_style := _make_menu_button_hover_style()
	var focus_style := _make_menu_button_focus_style()
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("focus", focus_style)

func _install_button_anim(btn: Button) -> void:
	if btn == null:
		return
	if _center_pivot_cb.is_valid():
		_center_pivot_cb.call(btn)
	if _hover_pop_cb.is_valid():
		_hover_pop_cb.call(btn)
	btn.button_down.connect(func() -> void:
		if _press_anim_cb.is_valid():
			_press_anim_cb.call(btn, 0.06)
	)
	btn.button_up.connect(func() -> void:
		if _release_to_hover_cb.is_valid():
			_release_to_hover_cb.call(btn, btn)
	)

func configure(make_button: Callable, set_weapon_icon: Callable, apply_weapon_skin: Callable, center_pivot: Callable = Callable(), hover_pop: Callable = Callable(), press_anim: Callable = Callable(), release_to_hover: Callable = Callable()) -> void:
	_make_button = make_button
	_set_weapon_icon = set_weapon_icon
	_apply_weapon_skin = apply_weapon_skin
	_center_pivot_cb = center_pivot
	_hover_pop_cb = hover_pop
	_press_anim_cb = press_anim
	_release_to_hover_cb = release_to_hover

func _ready() -> void:
	visible = false
	z_index = 1200
	set_as_top_level(true)
	scale = Vector2.ONE
	_fit_to_viewport()
	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(_fit_to_viewport)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.04, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_cancel()
	)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -270.0
	panel.offset_top = -82.0
	panel.offset_right = 270.0
	panel.offset_bottom = 82.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = panel
	panel.add_theme_stylebox_override("panel", _make_menu_panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.text = "Confirm"
	vbox.add_child(_title_label)

	_weapon_slot = Control.new()
	_weapon_slot.name = "WeaponSlot"
	_weapon_slot.visible = false
	_weapon_slot.custom_minimum_size = Vector2(0, 0)
	_weapon_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_weapon_slot)

	var weapon_bg := Panel.new()
	weapon_bg.name = "WeaponBg"
	weapon_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	weapon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var weapon_sb := StyleBoxFlat.new()
	weapon_sb.bg_color = Color(0.05, 0.05, 0.06, 1)
	weapon_sb.border_color = Color(0.18, 0.2, 0.24, 1)
	weapon_sb.border_width_left = 2
	weapon_sb.border_width_right = 2
	weapon_sb.border_width_top = 2
	weapon_sb.border_width_bottom = 2
	weapon_sb.corner_radius_top_left = 10
	weapon_sb.corner_radius_top_right = 10
	weapon_sb.corner_radius_bottom_left = 10
	weapon_sb.corner_radius_bottom_right = 10
	weapon_bg.add_theme_stylebox_override("panel", weapon_sb)
	_weapon_slot.add_child(weapon_bg)

	_weapon_sprite = Sprite2D.new()
	_weapon_sprite.name = "WeaponIcon"
	_weapon_sprite.centered = true
	_weapon_sprite.z_index = 2
	_weapon_slot.add_child(_weapon_sprite)
	_weapon_slot.resized.connect(func() -> void:
		if _weapon_sprite != null:
			_weapon_sprite.position = _weapon_slot.size * 0.5
	)

	_text_label = Label.new()
	_text_label.name = "Text"
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.add_theme_font_size_override("font_size", 12)
	_text_label.text = ""
	vbox.add_child(_text_label)

	var row := HBoxContainer.new()
	row.name = "Buttons"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	vbox.add_child(row)

	_ok_button = _make_button.call() if _make_button.is_valid() else Button.new()
	_ok_button.name = "Ok"
	_ok_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ok_button.text = "OK"
	_ok_button.add_theme_font_size_override("font_size", 14)
	_ok_button.custom_minimum_size = Vector2(0, 36)
	_normalize_confirm_button_theme(_ok_button)
	_install_button_anim(_ok_button)
	_ok_button.pressed.connect(_confirm)
	row.add_child(_ok_button)

	_cancel_button = _make_button.call() if _make_button.is_valid() else Button.new()
	_cancel_button.name = "Cancel"
	_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel_button.text = "CANCEL"
	_cancel_button.add_theme_font_size_override("font_size", 14)
	_cancel_button.custom_minimum_size = Vector2(0, 36)
	_normalize_confirm_button_theme(_cancel_button)
	_install_button_anim(_cancel_button)
	_cancel_button.pressed.connect(_cancel)
	row.add_child(_cancel_button)

func _fit_to_viewport() -> void:
	global_position = Vector2.ZERO
	size = get_viewport_rect().size

func ask(title: String, text: String, on_confirm: Callable, weapon_id: String = "", skin_index: int = 0) -> void:
	_on_confirm = on_confirm
	if _title_label != null:
		_title_label.text = title
	if _text_label != null:
		_text_label.text = text
	_set_weapon(weapon_id, skin_index)
	visible = true
	modulate = Color(1, 1, 1, 1)
	if _ok_button != null:
		_ok_button.grab_focus()

func _set_weapon(weapon_id: String, skin_index: int) -> void:
	if _weapon_slot == null or _weapon_sprite == null:
		return
	var normalized := weapon_id.strip_edges().to_lower()
	if normalized.is_empty():
		_weapon_slot.visible = false
		return
	_weapon_slot.visible = true
	_weapon_sprite.position = _weapon_slot.size * 0.5
	if _set_weapon_icon.is_valid():
		_set_weapon_icon.call(_weapon_sprite, normalized, 0.85, maxi(0, skin_index))
	if _apply_weapon_skin.is_valid():
		_apply_weapon_skin.call(_weapon_sprite, normalized, maxi(0, skin_index))

func _confirm() -> void:
	visible = false
	var cb := _on_confirm
	_on_confirm = Callable()
	if cb.is_valid():
		cb.call()

func _cancel() -> void:
	visible = false
	_on_confirm = Callable()
