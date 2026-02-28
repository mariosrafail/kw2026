extends RefCounted

const DATA := preload("res://scripts/ui/test_menu/data.gd")
const RAINBOW_SHADER: Shader = preload("res://assets/shaders/rainbow_tint.gdshader")
const MONO_TINT_SHADER: Shader = preload("res://assets/shaders/mono_tint.gdshader")

var weapon_icon_max_height_ratio := 0.42
var weapons_menu_preview_scale_mult := 1.0
var rainbow_skin_cost := 5000

var _weapon_skin_material_cache: Dictionary = {}
var _weapon_ui_texture_cache: Dictionary = {}

func weapon_display_name(weapon_id: String) -> String:
	var normalized := weapon_id.strip_edges().to_lower()
	if normalized == DATA.WEAPON_UZI:
		return "UZI"
	if normalized == DATA.WEAPON_GRENADE:
		return "GRENADE"
	return normalized.to_upper()

func weapon_ui_texture(weapon_id: String) -> Texture2D:
	var normalized := weapon_id.strip_edges().to_lower()
	if not DATA.WEAPON_UI_TEXTURE_BY_ID.has(normalized):
		normalized = DATA.WEAPON_UZI
	if _weapon_ui_texture_cache.has(normalized):
		return _weapon_ui_texture_cache[normalized] as Texture2D

	var base := DATA.WEAPON_UI_TEXTURE_BY_ID.get(normalized, DATA.UZI_UI_TEXTURE) as Texture2D
	var region := DATA.WEAPON_UI_REGION_BY_ID.get(normalized, Rect2()) as Rect2
	if base == null or region.size == Vector2.ZERO:
		_weapon_ui_texture_cache[normalized] = base
		return base

	var atlas := AtlasTexture.new()
	atlas.atlas = base
	atlas.region = region
	_weapon_ui_texture_cache[normalized] = atlas
	return atlas

func weapon_icon_effective_size(weapon_id: String) -> Vector2:
	var tex := weapon_ui_texture(weapon_id)
	return tex.get_size() if tex != null else Vector2(64, 64)

func weapon_icon_sprite_scale_normalized(weapon_id: String, slot_size: Vector2) -> Vector2:
	var eff := weapon_icon_effective_size(weapon_id)
	if eff.x <= 0.0 or eff.y <= 0.0:
		return Vector2.ONE
	var w := maxf(1.0, float(slot_size.x))
	var h := maxf(1.0, float(slot_size.y))
	var s := w / float(eff.x)
	var max_h := h * clampf(weapon_icon_max_height_ratio, 0.05, 1.0)
	if float(eff.y) * s > max_h:
		s = max_h / float(eff.y)
	return Vector2(s, s)

func set_weapon_icon_sprite(target: Sprite2D, weapon_id: String, extra_mult: float = 1.0, preview_sprite: Sprite2D = null) -> void:
	if target == null:
		return
	var normalized := weapon_id.strip_edges().to_lower()
	target.texture = weapon_ui_texture(normalized)

	var slot := target.get_parent() as Control
	var slot_size := Vector2(116, 64)
	if slot != null:
		if slot.size.x > 0.0 and slot.size.y > 0.0:
			slot_size = slot.size

	var mult := clampf(extra_mult, 0.01, 8.0)
	if preview_sprite != null and target == preview_sprite:
		mult *= clampf(weapons_menu_preview_scale_mult, 0.01, 3.0)
	target.scale = weapon_icon_sprite_scale_normalized(normalized, slot_size) * mult

func weapon_skins_for(weapon_id: String) -> Array:
	var normalized := weapon_id.strip_edges().to_lower()
	var arr := DATA.WEAPON_SKINS_BY_ID.get(normalized, []) as Array
	return arr if arr != null else []

func weapon_skin_entry(weapon_id: String, skin_index: int) -> Dictionary:
	var idx := maxi(0, skin_index)
	for skin in weapon_skins_for(weapon_id):
		if int(skin.get("skin", 0)) == idx:
			return skin as Dictionary
	return {}

func weapon_skin_label(weapon_id: String, skin_index: int) -> String:
	var entry := weapon_skin_entry(weapon_id, skin_index)
	if not entry.is_empty():
		return str(entry.get("name", "Skin %d" % skin_index))
	return "Skin %d" % skin_index

func weapon_skin_cost(weapon_id: String, skin_index: int) -> int:
	var entry := weapon_skin_entry(weapon_id, skin_index)
	if entry.is_empty():
		return 0
	if bool(entry.get("rainbow", false)):
		return maxi(0, int(rainbow_skin_cost))
	return maxi(0, int(entry.get("cost", 0)))

func weapon_skin_material(weapon_id: String, skin_index: int) -> Material:
	var normalized := weapon_id.strip_edges().to_lower()
	var idx := maxi(0, skin_index)
	var entry := weapon_skin_entry(normalized, idx)
	if entry.is_empty():
		return null

	var key := "%s:%d" % [normalized, idx]
	if _weapon_skin_material_cache.has(key):
		return _weapon_skin_material_cache[key] as Material

	var mat := ShaderMaterial.new()
	if bool(entry.get("rainbow", false)):
		mat.shader = RAINBOW_SHADER
		mat.set_shader_parameter("speed", 1.15)
		mat.set_shader_parameter("saturation", 1.0)
		mat.set_shader_parameter("value", 1.0)
	else:
		mat.shader = MONO_TINT_SHADER
		var tint := entry.get("tint", Color(1, 1, 1, 1)) as Color
		mat.set_shader_parameter("tint_color", tint)
	_weapon_skin_material_cache[key] = mat
	return mat

func apply_weapon_skin_visual(target: CanvasItem, weapon_id: String, skin_index: int) -> void:
	if target == null:
		return
	var a := target.modulate.a
	target.modulate = Color(1, 1, 1, a)
	target.material = weapon_skin_material(weapon_id, skin_index)

func weapon_is_locked(host: Object, weapon_id: String, skin_index: int) -> bool:
	var normalized := weapon_id.strip_edges().to_lower()
	var idx := maxi(0, skin_index)
	var is_owned: bool = false
	if host != null and host.has_method("_weapon_is_owned"):
		is_owned = bool(host.call("_weapon_is_owned", normalized))
	if not is_owned:
		return true
	var skin_owned: bool = (idx == 0)
	if host != null and host.has_method("_weapon_skin_is_owned"):
		skin_owned = bool(host.call("_weapon_skin_is_owned", normalized, idx))
	return not skin_owned

func weapon_item_status_text(host: Object, weapon_id: String, skin_index: int) -> String:
	var normalized := weapon_id.strip_edges().to_lower()
	var idx := maxi(0, skin_index)
	var is_owned: bool = false
	if host != null and host.has_method("_weapon_is_owned"):
		is_owned = bool(host.call("_weapon_is_owned", normalized))
	if not is_owned:
		var weapon_cost := int(DATA.WEAPON_BASE_COST_BY_ID.get(normalized, 0))
		return "BUY %d" % weapon_cost if weapon_cost > 0 else "LOCKED"
	var skin_owned: bool = (idx == 0)
	if host != null and host.has_method("_weapon_skin_is_owned"):
		skin_owned = bool(host.call("_weapon_skin_is_owned", normalized, idx))
	if skin_owned:
		var sel_id: String = ""
		var sel_skin: int = 0
		if host != null:
			sel_id = str(host.get("selected_weapon_id"))
			sel_skin = int(host.get("selected_weapon_skin"))
		if normalized == sel_id and idx == sel_skin:
			return "EQUIPPED"
		return "OWNED"
	return "BUY %d" % weapon_skin_cost(normalized, idx)

func update_weapon_item_button(host: Object, btn: Button) -> void:
	if btn == null:
		return
	if not btn.has_meta("weapon_id") or not btn.has_meta("skin_index"):
		return
	var weapon_id := str(btn.get_meta("weapon_id"))
	var skin_index := int(btn.get_meta("skin_index"))

	var name_label := btn.get_node_or_null("Margin/VBox/Name") as Label
	var icon_slot := btn.get_node_or_null("Margin/VBox/IconSlot") as Control
	var icon := btn.get_node_or_null("Margin/VBox/IconSlot/Icon") as Sprite2D
	var label := btn.get_node_or_null("Margin/VBox/Info") as Label

	if name_label != null:
		name_label.text = weapon_display_name(weapon_id)

	if icon_slot != null and icon != null:
		icon.position = icon_slot.size * 0.5
		set_weapon_icon_sprite(icon, weapon_id, 1.0, null)
		apply_weapon_skin_visual(icon, weapon_id, skin_index)

	if label != null:
		label.text = weapon_item_status_text(host, weapon_id, skin_index)

	btn.tooltip_text = "%s - %s" % [weapon_id.to_upper(), weapon_skin_label(weapon_id, skin_index)]

	var locked := weapon_is_locked(host, weapon_id, skin_index)
	btn.modulate = Color(0.65, 0.67, 0.72, 0.75) if locked else Color(1, 1, 1, 1)

func make_weapon_item_button(host: Object, make_shop_button: Callable, weapon_id: String, skin_index: int) -> Button:
	var btn: Button = Button.new()
	if make_shop_button.is_valid():
		var created: Variant = make_shop_button.call()
		if created is Button:
			btn = created as Button
	btn.text = ""
	btn.custom_minimum_size = Vector2(122, 74)
	btn.set_meta("weapon_id", weapon_id.strip_edges().to_lower())
	btn.set_meta("skin_index", maxi(0, skin_index))
	btn.set_meta("_anim_key", "%s:%d" % [weapon_id.strip_edges().to_lower(), maxi(0, skin_index)])
	btn.pivot_offset = btn.custom_minimum_size * 0.5
	btn.resized.connect(func() -> void:
		btn.pivot_offset = btn.size * 0.5
	)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var name := Label.new()
	name.name = "Name"
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 12)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name)

	var icon_slot := Control.new()
	icon_slot.name = "IconSlot"
	icon_slot.custom_minimum_size = Vector2(0, 34)
	icon_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_slot)

	var icon := Sprite2D.new()
	icon.name = "Icon"
	icon.centered = true
	icon_slot.add_child(icon)
	icon_slot.resized.connect(func() -> void:
		update_weapon_item_button(host, btn)
	)

	var info := Label.new()
	info.name = "Info"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 11)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(info)

	update_weapon_item_button(host, btn)

	_install_shop_button_anim(btn)
	return btn

func _kill_meta_tween(btn: Node, key: String) -> void:
	if btn == null or not btn.has_meta(key):
		return
	var v: Variant = btn.get_meta(key)
	if v is Tween:
		var t := v as Tween
		if t != null:
			t.kill()
	btn.set_meta(key, null)

func _start_idle_anim(btn: Button) -> void:
	if btn == null:
		return
	_kill_meta_tween(btn, "_idle_tween")
	_kill_meta_tween(btn, "_fx_tween")

	var key := str(btn.get_meta("_anim_key")) if btn.has_meta("_anim_key") else ""
	var h := int(key.hash()) if not key.is_empty() else int(btn.get_instance_id())
	var phase := float(abs(h % 1000)) / 1000.0
	var rot_a := deg_to_rad(lerpf(-1.25, -0.2, phase))
	var rot_b := deg_to_rad(lerpf(0.2, 1.25, phase))
	var s_hi := 1.0 + lerpf(0.010, 0.017, phase)
	var s_lo := 1.0 - lerpf(0.006, 0.012, phase)
	var d1 := lerpf(0.46, 0.62, phase)
	var d2 := lerpf(0.52, 0.70, 1.0 - phase)

	var tw := btn.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(btn, "rotation", rot_a, d1)
	tw.parallel().tween_property(btn, "scale", Vector2.ONE * s_hi, d1)
	tw.tween_property(btn, "rotation", rot_b, d2)
	tw.parallel().tween_property(btn, "scale", Vector2.ONE * s_lo, d2)
	btn.set_meta("_idle_tween", tw)

func _animate_state(btn: Button, state: String) -> void:
	if btn == null:
		return
	_kill_meta_tween(btn, "_fx_tween")
	if state != "idle":
		_kill_meta_tween(btn, "_idle_tween")

	var icon: Sprite2D = btn.get_node_or_null("Margin/VBox/IconSlot/Icon") as Sprite2D
	var target_scale := Vector2.ONE
	var target_rot := 0.0
	var icon_scale := Vector2.ONE
	var dur := 0.08

	if state == "hover":
		target_scale = Vector2.ONE * 1.035
		target_rot = 0.0
		icon_scale = Vector2.ONE * 1.03
		dur = 0.08
	elif state == "press":
		target_scale = Vector2.ONE * 0.965
		target_rot = deg_to_rad(-0.75)
		icon_scale = Vector2.ONE * 0.97
		dur = 0.05

	var tw := btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(btn, "scale", target_scale, dur)
	tw.parallel().tween_property(btn, "rotation", target_rot, dur)
	if icon != null:
		tw.parallel().tween_property(icon, "scale", icon_scale, dur)
	if state == "press":
		tw.tween_property(btn, "scale", Vector2.ONE * 1.035, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(btn, "rotation", 0.0, 0.10)
		if icon != null:
			tw.parallel().tween_property(icon, "scale", Vector2.ONE * 1.03, 0.10)
	btn.set_meta("_fx_tween", tw)
	if state == "idle":
		_start_idle_anim(btn)

func _install_shop_button_anim(btn: Button) -> void:
	if btn == null:
		return
	_start_idle_anim(btn)

	btn.mouse_entered.connect(func() -> void:
		_animate_state(btn, "hover")
	)
	btn.focus_entered.connect(func() -> void:
		_animate_state(btn, "hover")
	)
	btn.mouse_exited.connect(func() -> void:
		_animate_state(btn, "idle")
	)
	btn.focus_exited.connect(func() -> void:
		_animate_state(btn, "idle")
	)
	btn.button_down.connect(func() -> void:
		_animate_state(btn, "press")
	)
	btn.button_up.connect(func() -> void:
		var local := btn.get_local_mouse_position()
		if Rect2(Vector2.ZERO, btn.size).has_point(local):
			_animate_state(btn, "hover")
		else:
			_animate_state(btn, "idle")
	)
