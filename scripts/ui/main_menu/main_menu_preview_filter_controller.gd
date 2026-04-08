extends RefCounted

class_name MainMenuPreviewFilterController

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

func prepare_player_preview(player: Node) -> void:
	if player == null:
		return
	player.process_mode = Node.PROCESS_MODE_DISABLED

	var visual_root := player.get_node_or_null("VisualRoot") as Node
	if visual_root == null:
		return

	var gun_pivot := visual_root.get_node_or_null("GunPivot") as CanvasItem
	if gun_pivot != null:
		gun_pivot.visible = false

	for label_name in ["HealthLabel", "AmmoLabel", "NameLabel"]:
		var label := visual_root.get_node_or_null(label_name) as CanvasItem
		if label != null:
			label.visible = false

func handle_warrior_preview_zoom_input(event: InputEvent) -> bool:
	# Manual zoom is intentionally disabled to preserve stable preview movement/placement.
	# Keep the function for API compatibility with main_menu.gd.
	if event == null:
		return false
	return false

func apply_warrior_preview_zoom() -> void:
	var warrior_shop_preview: Variant = _host.get("warrior_shop_preview")
	if not (warrior_shop_preview is Node2D):
		return
	var preview := warrior_shop_preview as Node2D
	var base_zoom := clampf(float(_host.get("warriors_menu_preview_scale_mult")), 0.01, 3.0)
	var base_scale: Vector2 = _host.get("_warrior_shop_preview_base_scale")
	preview.scale = base_scale * base_zoom

func apply_warrior_skin_to_player(player: Node, warrior_id: String, skin_index: int) -> void:
	var warrior_ui: Variant = _host.get("_warrior_ui")
	if warrior_ui != null and warrior_ui.has_method("apply_warrior_menu_preview"):
		warrior_ui.call("apply_warrior_menu_preview", player, warrior_id, skin_index)

func set_weapon_icon_sprite(target: Sprite2D, weapon_id: String, extra_mult: float = 1.0, skin_index: int = 0) -> void:
	var normalized := weapon_id.strip_edges().to_lower()
	var idx := maxi(0, skin_index)
	if target != null:
		target.set_meta("weapon_id", normalized)
		target.set_meta("skin_index", idx)
	var weapon_shop_preview := _host.get("weapon_shop_preview") as Sprite2D
	if target == weapon_shop_preview:
		_host.set("_visible_weapon_id", normalized)
		_host.set("_visible_weapon_skin", idx)
	var weapon_ui: Variant = _host.get("_weapon_ui")
	if weapon_ui != null and weapon_ui.has_method("set_weapon_icon_sprite"):
		weapon_ui.call("set_weapon_icon_sprite", target, normalized, extra_mult, weapon_shop_preview, idx)

func sync_visible_weapon_from_preview() -> void:
	var weapon_shop_preview := _host.get("weapon_shop_preview") as Sprite2D
	if weapon_shop_preview == null:
		return
	if weapon_shop_preview.has_meta("weapon_id"):
		_host.set("_visible_weapon_id", str(weapon_shop_preview.get_meta("weapon_id")).strip_edges().to_lower())
	if weapon_shop_preview.has_meta("skin_index"):
		_host.set("_visible_weapon_skin", maxi(0, int(weapon_shop_preview.get_meta("skin_index"))))

func make_filter_button(text: String) -> Button:
	var btn := _host.call("_make_shop_button") as Button
	if btn == null:
		btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 26)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.text = text
	btn.clip_text = false
	btn.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	btn.add_theme_font_size_override("font_size", 9)
	return btn

func set_filter_btn_selected(btn: Button, selected: bool) -> void:
	if btn == null:
		return
	btn.modulate = Color(1, 1, 1, 1) if selected else Color(1, 1, 1, 0.9)

func refresh_weapon_filter_button_state() -> void:
	var weapon_buttons := _host.get("_weapon_filter_weapon_buttons") as Dictionary
	var category_buttons := _host.get("_weapon_filter_category_buttons") as Dictionary
	var selected_weapon_id := str(_host.get("_weapon_filter_weapon_id"))
	var selected_category := str(_host.get("_weapon_filter_category"))

	for key in weapon_buttons.keys():
		set_filter_btn_selected(weapon_buttons.get(key, null) as Button, str(key) == selected_weapon_id)
	for key in category_buttons.keys():
		set_filter_btn_selected(category_buttons.get(key, null) as Button, str(key) == selected_category)

	for key in weapon_buttons.keys():
		var wid := str(key)
		var btn := weapon_buttons.get(wid, null) as Button
		if btn == null:
			continue
		if wid.is_empty():
			btn.text = "ALL"
			continue
		btn.text = str(_host.call("_weapon_ui_weapon_display_name", wid))
	_host.call_deferred("_update_weapon_filter_bridge")

func ensure_weapon_filter_ui() -> void:
	var weapon_scroll := _host.get("weapon_scroll") as ScrollContainer
	if weapon_scroll == null:
		return
	var list_col := weapon_scroll.get_parent() as Control
	if list_col == null:
		return
	if list_col.get_node_or_null("WeaponFilters") != null:
		return
	if list_col is VBoxContainer:
		(list_col as VBoxContainer).add_theme_constant_override("separation", 0)

	var filters := VBoxContainer.new()
	filters.name = "WeaponFilters"
	filters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filters.add_theme_constant_override("separation", 0)
	list_col.add_child(filters)
	list_col.move_child(filters, 0)

	var weapon_row := HFlowContainer.new()
	weapon_row.name = "WeaponRow"
	weapon_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_row.add_theme_constant_override("separation", 6)
	filters.add_child(weapon_row)
	_host.set("_weapon_filters_row", weapon_row)

	var bridge_holder := Control.new()
	bridge_holder.name = "WeaponFiltersBridgeHolder"
	bridge_holder.custom_minimum_size = Vector2(0, 6)
	bridge_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bridge_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filters.add_child(bridge_holder)
	_host.set("_weapon_filters_bridge_holder", bridge_holder)

	var bridge := Panel.new()
	bridge.name = "WeaponFiltersBridge"
	bridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bridge_style := StyleBoxFlat.new()
	var accent: Color = _host.get("MENU_CLR_ACCENT")
	bridge_style.bg_color = MENU_PALETTE.with_alpha(accent, 1.0)
	bridge_style.border_width_left = 1
	bridge_style.border_width_top = 0
	bridge_style.border_width_right = 1
	bridge_style.border_width_bottom = 1
	bridge_style.border_color = MENU_PALETTE.with_alpha(accent, 1.0)
	bridge.add_theme_stylebox_override("panel", bridge_style)
	bridge_holder.add_child(bridge)
	_host.set("_weapon_filters_bridge", bridge)
	weapon_row.resized.connect(Callable(self, "update_weapon_filter_bridge"))
	bridge_holder.resized.connect(Callable(self, "update_weapon_filter_bridge"))

	var weapon_buttons := {}
	_host.set("_weapon_filter_weapon_buttons", weapon_buttons)
	var weapon_items := [
		{"label": "ALL", "id": ""},
		{"label": str(_host.call("_weapon_ui_weapon_display_name", WEAPON_UZI)), "id": WEAPON_UZI},
		{"label": str(_host.call("_weapon_ui_weapon_display_name", WEAPON_AK47)), "id": WEAPON_AK47},
		{"label": str(_host.call("_weapon_ui_weapon_display_name", WEAPON_KAR)), "id": WEAPON_KAR},
		{"label": str(_host.call("_weapon_ui_weapon_display_name", WEAPON_SHOTGUN)), "id": WEAPON_SHOTGUN},
		{"label": str(_host.call("_weapon_ui_weapon_display_name", WEAPON_GRENADE)), "id": WEAPON_GRENADE},
	]
	for it in weapon_items:
		var wid := str(it.get("id", ""))
		var btn := make_filter_button(str(it.get("label", "")))
		btn.pressed.connect(func() -> void:
			_host.set("_weapon_filter_weapon_id", wid)
			if not wid.is_empty():
				var equipped_skin := int(_host.call("_equipped_weapon_skin", wid))
				_host.call("_select_weapon_skin", wid, equipped_skin, true)
			refresh_weapon_filter_button_state()
			_host.call("_build_weapon_shop_grid")
		)
		weapon_row.add_child(btn)
		weapon_buttons[wid] = btn

	_host.set("_weapon_filter_weapon_buttons", weapon_buttons)
	_host.set("_weapon_filter_category_buttons", {})
	_host.set("_weapon_filter_category", "")

	refresh_weapon_filter_button_state()
	_host.call_deferred("_update_weapon_filter_bridge")

func update_weapon_filter_bridge() -> void:
	var bridge_holder := _host.get("_weapon_filters_bridge_holder") as Control
	if bridge_holder == null or not is_instance_valid(bridge_holder):
		return
	var bridge := _host.get("_weapon_filters_bridge") as Panel
	if bridge == null or not is_instance_valid(bridge):
		return
	var row := _host.get("_weapon_filters_row") as HFlowContainer
	if row == null or not is_instance_valid(row):
		return
	var weapon_buttons := _host.get("_weapon_filter_weapon_buttons") as Dictionary
	var key := str(_host.get("_weapon_filter_weapon_id"))
	if not weapon_buttons.has(key):
		key = ""
	var selected_btn := weapon_buttons.get(key, null) as Button
	if selected_btn == null or not is_instance_valid(selected_btn):
		bridge.visible = false
		return
	bridge.visible = true
	var x := row.position.x + selected_btn.position.x
	var w := selected_btn.size.x
	bridge.position = Vector2(x, 0)
	bridge.size = Vector2(maxf(1.0, w), bridge_holder.size.y)

func icon_global_rect(icon: CanvasItem) -> Rect2:
	if icon == null:
		return Rect2()
	if icon is Control:
		return (icon as Control).get_global_rect()
	if icon is Sprite2D:
		var sprite := icon as Sprite2D
		if sprite.texture == null:
			return Rect2(sprite.global_position, Vector2.ZERO)
		var size := sprite.texture.get_size() * sprite.global_scale
		return Rect2(sprite.global_position - size * 0.5, size)
	return Rect2(icon.get_global_transform().origin, Vector2.ZERO)
