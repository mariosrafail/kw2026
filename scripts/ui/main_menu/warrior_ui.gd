extends RefCounted

class_name WarriorUi

const WARRIOR_MANIFEST_PATHS := {
	"outrage": "res://assets/warriors/outrage/skin_manifest.json",
	"erebus": "res://assets/warriors/erebus/skin_manifest.json",
	"tasko": "res://assets/warriors/tasko/skin_manifest.json",
}
const MENU_PALETTE := preload("res://scripts/ui/main_menu/menu_palette.gd")

var _manifest_cache: Dictionary = {}
var _texture_cache: Dictionary = {}
var _preview_texture_cache: Dictionary = {}

func default_warrior_id() -> String:
	var ids := warrior_ids()
	if ids.has("outrage"):
		return "outrage"
	if ids.is_empty():
		return "outrage"
	return str(ids[0]).strip_edges().to_lower()

func default_owned_warriors() -> PackedStringArray:
	return PackedStringArray([default_warrior_id()])

func default_owned_warrior_skins_by_warrior() -> Dictionary:
	var out: Dictionary = {}
	for warrior_id in warrior_ids():
		out[str(warrior_id).strip_edges().to_lower()] = PackedInt32Array([0])
	return out

func default_equipped_warrior_skin_by_warrior() -> Dictionary:
	var out: Dictionary = {}
	for warrior_id in warrior_ids():
		out[str(warrior_id).strip_edges().to_lower()] = 0
	return out

func available_skin_indices_for(warrior_id: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	for skin in warrior_skins_for(warrior_id):
		var entry := skin as Dictionary
		var idx := maxi(0, int(entry.get("index", 0)))
		if not out.has(idx):
			out.append(idx)
	if not out.has(0):
		out.append(0)
	out.sort()
	return out

func warrior_ids() -> Array[String]:
	var out: Array[String] = []
	for warrior_id in WARRIOR_MANIFEST_PATHS.keys():
		out.append(str(warrior_id))
	out.sort()
	if out.has("outrage"):
		out.erase("outrage")
		out.push_front("outrage")
	return out

func warrior_manifest(warrior_id: String) -> Dictionary:
	var normalized := warrior_id.strip_edges().to_lower()
	if _manifest_cache.has(normalized):
		return _manifest_cache[normalized] as Dictionary
	var path := str(WARRIOR_MANIFEST_PATHS.get(normalized, "")).strip_edges()
	if path.is_empty() or not FileAccess.file_exists(path):
		_manifest_cache[normalized] = {}
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		_manifest_cache[normalized] = {}
		return {}
	var manifest := parsed as Dictionary
	manifest["warrior_id"] = normalized
	if not manifest.has("display_name"):
		manifest["display_name"] = normalized.capitalize()
	if not manifest.has("warrior_cost"):
		manifest["warrior_cost"] = 0 if normalized == "outrage" else 3000
	var skins := manifest.get("skins", []) as Array
	skins.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int((a as Dictionary).get("index", 0)) < int((b as Dictionary).get("index", 0))
	)
	manifest["skins"] = skins
	_manifest_cache[normalized] = manifest
	return manifest

func warrior_display_name(warrior_id: String) -> String:
	var manifest := warrior_manifest(warrior_id)
	if manifest.is_empty():
		return warrior_id.strip_edges().to_upper()
	return str(manifest.get("display_name", warrior_id)).strip_edges()

func warrior_base_cost(warrior_id: String) -> int:
	var manifest := warrior_manifest(warrior_id)
	return maxi(0, int(manifest.get("warrior_cost", 0)))

func warrior_skins_for(warrior_id: String) -> Array:
	var manifest := warrior_manifest(warrior_id)
	return manifest.get("skins", []) as Array

func warrior_skin_entry(warrior_id: String, skin_index: int) -> Dictionary:
	var idx := maxi(0, skin_index)
	for skin in warrior_skins_for(warrior_id):
		var entry := skin as Dictionary
		if int(entry.get("index", 0)) == idx:
			return entry
	return {}

func warrior_skin_label(warrior_id: String, skin_index: int) -> String:
	var entry := warrior_skin_entry(warrior_id, skin_index)
	if not entry.is_empty():
		return str(entry.get("name", "Skin %02d" % skin_index))
	return "Skin %02d" % skin_index

func warrior_skin_cost(warrior_id: String, skin_index: int) -> int:
	var entry := warrior_skin_entry(warrior_id, skin_index)
	return maxi(0, int(entry.get("cost", 0)))

func warrior_preview_texture_for(warrior_id: String, skin_index: int) -> Texture2D:
	var normalized := warrior_id.strip_edges().to_lower()
	var idx := maxi(0, skin_index)
	var key := "%s:%d" % [normalized, idx]
	if _preview_texture_cache.has(key):
		return _preview_texture_cache[key] as Texture2D
	var manifest := warrior_manifest(normalized)
	var frame_size := manifest.get("frame_size", {"x": 64, "y": 64}) as Dictionary
	var frame_w := maxi(1, int(frame_size.get("x", 64)))
	var frame_h := maxi(1, int(frame_size.get("y", 64)))
	var preview_path := str(manifest.get("ui_preview", "")).strip_edges()
	var preview_tex := _load_texture(preview_path)
	if preview_tex == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = preview_tex
	atlas.region = Rect2(float(idx * frame_w), 0.0, float(frame_w), float(frame_h))
	_preview_texture_cache[key] = atlas
	return atlas

func warrior_item_title_text(warrior_id: String, skin_index: int) -> String:
	return "%s - %s" % [warrior_display_name(warrior_id), warrior_skin_label(warrior_id, skin_index)]

func warrior_card_title_text(warrior_id: String, skin_index: int) -> String:
	return warrior_skin_label(warrior_id, skin_index)

func warrior_is_locked(host: Object, warrior_id: String, skin_index: int) -> bool:
	var normalized := warrior_id.strip_edges().to_lower()
	if host == null or not host.has_method("_warrior_is_owned"):
		return true
	var warrior_owned := bool(host.call("_warrior_is_owned", normalized))
	if not warrior_owned:
		return true
	if skin_index <= 0:
		return false
	if host.has_method("_warrior_skin_is_owned"):
		return not bool(host.call("_warrior_skin_is_owned", normalized, maxi(0, skin_index)))
	return true

func warrior_item_status_text(host: Object, warrior_id: String, skin_index: int) -> String:
	var normalized := warrior_id.strip_edges().to_lower()
	var idx := maxi(0, skin_index)
	var warrior_owned := false
	if host != null and host.has_method("_warrior_is_owned"):
		warrior_owned = bool(host.call("_warrior_is_owned", normalized))
	if not warrior_owned:
		var cost := warrior_base_cost(normalized)
		return "BUY %d" % cost if cost > 0 else "LOCKED"
	if idx <= 0:
		var selected_warrior_id := str(host.get("selected_warrior_id")).strip_edges().to_lower() if host != null else ""
		var equipped_skin := 0
		if host != null and host.has_method("_equipped_warrior_skin"):
			equipped_skin = int(host.call("_equipped_warrior_skin", normalized))
		if selected_warrior_id == normalized and equipped_skin == 0:
			return "OWNED"
		return "OWNED"
	var skin_owned := false
	if host != null and host.has_method("_warrior_skin_is_owned"):
		skin_owned = bool(host.call("_warrior_skin_is_owned", normalized, idx))
	if skin_owned:
		var equipped_skin := 0
		var selected_id := ""
		if host != null and host.has_method("_equipped_warrior_skin"):
			equipped_skin = int(host.call("_equipped_warrior_skin", normalized))
		if host != null:
			selected_id = str(host.get("selected_warrior_id")).strip_edges().to_lower()
		if selected_id == normalized and idx == equipped_skin:
			return "OWNED"
		return "OWNED"
	return "BUY %d" % warrior_skin_cost(normalized, idx)

func warrior_item_cost_text(host: Object, warrior_id: String, skin_index: int) -> String:
	var normalized := warrior_id.strip_edges().to_lower()
	var idx := maxi(0, skin_index)
	var warrior_owned := false
	if host != null and host.has_method("_warrior_is_owned"):
		warrior_owned = bool(host.call("_warrior_is_owned", normalized))
	if not warrior_owned:
		return "Coins: %d" % warrior_base_cost(normalized)
	if idx <= 0:
		return ""
	var skin_owned := false
	if host != null and host.has_method("_warrior_skin_is_owned"):
		skin_owned = bool(host.call("_warrior_skin_is_owned", normalized, idx))
	if skin_owned:
		return ""
	return "Coins: %d" % warrior_skin_cost(normalized, idx)

func update_warrior_item_button(host: Object, btn: Button) -> void:
	if btn == null or not btn.has_meta("warrior_id") or not btn.has_meta("skin_index"):
		return
	var warrior_id := str(btn.get_meta("warrior_id")).strip_edges().to_lower()
	var skin_index := int(btn.get_meta("skin_index"))
	var name_label := btn.get_node_or_null("Margin/VBox/Name") as Label
	var icon_slot := btn.get_node_or_null("Margin/VBox/IconSlot") as Control
	var icon := btn.get_node_or_null("Margin/VBox/IconSlot/Icon") as Sprite2D
	var info_label := btn.get_node_or_null("Margin/VBox/Info") as Label
	var selected := false
	if host != null:
		var pending_id := str(host.get("_pending_warrior_id")).strip_edges().to_lower()
		var pending_skin := int(host.get("_pending_warrior_skin"))
		selected = pending_id == warrior_id and pending_skin == skin_index
	if name_label != null:
		name_label.text = warrior_card_title_text(warrior_id, skin_index)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_color_override("font_color", MENU_PALETTE.text_dark(1.0))
	if icon != null:
		icon.texture = warrior_preview_texture_for(warrior_id, skin_index)
		icon.centered = true
		if icon_slot != null:
			icon.position = icon_slot.size * 0.5 + Vector2(0, 2)
		icon.scale = Vector2.ONE * 1.05
		btn.set_meta("_base_icon_scale", icon.scale)
	if info_label != null:
		info_label.text = warrior_item_cost_text(host, warrior_id, skin_index)
		info_label.add_theme_color_override("font_color", MENU_PALETTE.text_dark(0.9))
	btn.tooltip_text = "%s  (%s)" % [warrior_item_title_text(warrior_id, skin_index), warrior_item_status_text(host, warrior_id, skin_index)]
	var locked := warrior_is_locked(host, warrior_id, skin_index)
	_apply_selected_button_visual(btn, selected and not locked)
	btn.modulate = Color(0.65, 0.67, 0.72, 0.75) if locked else Color(1, 1, 1, 1)

func _ensure_button_style_cache(btn: Button) -> void:
	if btn == null:
		return
	for sb_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var key := "_base_sb_%s" % sb_name
		if btn.has_meta(key):
			continue
		var sb := btn.get_theme_stylebox(sb_name)
		if sb is StyleBoxFlat:
			btn.set_meta(key, (sb as StyleBoxFlat).duplicate())

func _apply_selected_button_visual(btn: Button, selected: bool) -> void:
	if btn == null:
		return
	_ensure_button_style_cache(btn)
	for sb_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var key := "_base_sb_%s" % sb_name
		if not btn.has_meta(key):
			continue
		var base: Variant = btn.get_meta(key)
		if not (base is StyleBoxFlat):
			continue
		var flat := (base as StyleBoxFlat).duplicate()
		if selected:
			flat.border_width_left = maxi(flat.border_width_left, 3)
			flat.border_width_top = maxi(flat.border_width_top, 3)
			flat.border_width_right = maxi(flat.border_width_right, 3)
			flat.border_width_bottom = maxi(flat.border_width_bottom, 5)
			flat.border_color = MENU_PALETTE.highlight(1.0)
			flat.shadow_color = MENU_PALETTE.highlight(0.45)
			flat.shadow_size = maxi(flat.shadow_size, 18)
			var target := MENU_PALETTE.hot(1.0)
			flat.bg_color = Color(
				lerpf(flat.bg_color.r, target.r, 0.24),
				lerpf(flat.bg_color.g, target.g, 0.24),
				lerpf(flat.bg_color.b, target.b, 0.24),
				clampf(flat.bg_color.a + 0.05, 0.0, 1.0)
			)
		btn.add_theme_stylebox_override(sb_name, flat)

func make_warrior_item_button(host: Object, make_shop_button: Callable, warrior_id: String, skin_index: int) -> Button:
	var btn := Button.new()
	if make_shop_button.is_valid():
		var created: Variant = make_shop_button.call()
		if created is Button:
			btn = created as Button
	btn.text = ""
	btn.custom_minimum_size = Vector2(84, 62)
	btn.set_meta("warrior_id", warrior_id.strip_edges().to_lower())
	btn.set_meta("skin_index", maxi(0, skin_index))
	btn.set_meta("_anim_key", "%s:%d" % [warrior_id.strip_edges().to_lower(), maxi(0, skin_index)])
	btn.pivot_offset = btn.custom_minimum_size * 0.5
	btn.resized.connect(func() -> void:
		btn.pivot_offset = btn.size * 0.5
	)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 12)
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
	name.add_theme_font_size_override("font_size", 11)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name)

	var icon_slot := Control.new()
	icon_slot.name = "IconSlot"
	icon_slot.custom_minimum_size = Vector2(0, 24)
	icon_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_slot)

	var icon := Sprite2D.new()
	icon.name = "Icon"
	icon.centered = true
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_slot.add_child(icon)
	icon_slot.resized.connect(func() -> void:
		update_warrior_item_button(host, btn)
	)

	var info := Label.new()
	info.name = "Info"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 10)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(info)

	update_warrior_item_button(host, btn)
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
	var base_icon_scale := Vector2.ONE
	if icon != null:
		if btn.has_meta("_base_icon_scale") and btn.get_meta("_base_icon_scale") is Vector2:
			base_icon_scale = btn.get_meta("_base_icon_scale") as Vector2
		else:
			base_icon_scale = icon.scale
	var icon_scale := base_icon_scale
	var dur := 0.08

	if state == "hover":
		target_scale = Vector2.ONE * 1.035
		target_rot = 0.0
		icon_scale = base_icon_scale * 1.03
		dur = 0.08
	elif state == "press":
		target_scale = Vector2.ONE * 0.965
		target_rot = deg_to_rad(-0.75)
		icon_scale = base_icon_scale * 0.97
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
			tw.parallel().tween_property(icon, "scale", base_icon_scale * 1.03, 0.10)
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

func apply_warrior_menu_preview(player: Node, warrior_id: String, skin_index: int) -> void:
	if player == null:
		return
	var normalized := warrior_id.strip_edges().to_lower()
	var idx := maxi(0, skin_index)
	var preview_tex := warrior_preview_texture_for(normalized, idx)
	var visual_root := player.get_node_or_null("VisualRoot") as Node
	if visual_root == null:
		return
	for child in visual_root.get_children():
		if not (child is CanvasItem):
			continue
		var canvas_item := child as CanvasItem
		canvas_item.visible = false
	var legacy_body := visual_root.get_node_or_null("Sprite2D") as Sprite2D
	if legacy_body != null:
		legacy_body.visible = true
		legacy_body.texture = preview_tex
		legacy_body.region_enabled = false
		legacy_body.modulate = Color(1, 1, 1, 1)

func apply_warrior_game_visual(player: Node, warrior_id: String, skin_index: int, fallback_heads: Texture2D = null, fallback_torso: Texture2D = null, fallback_legs: Texture2D = null) -> void:
	if player == null:
		return
	var normalized := warrior_id.strip_edges().to_lower()
	var idx := maxi(0, skin_index)
	if player.has_method("set_character_visual"):
		player.call("set_character_visual", normalized)

	var manifest := warrior_manifest(normalized)
	var parts := manifest.get("parts", {}) as Dictionary
	var frame_size := manifest.get("frame_size", {"x": 64, "y": 64}) as Dictionary
	var frame_w := maxi(1, int(frame_size.get("x", 64)))
	var frame_h := maxi(1, int(frame_size.get("y", 64)))
	var region := Rect2(float(idx * frame_w), 0.0, float(frame_w), float(frame_h))

	var head_tex := _load_texture(str(parts.get("head", "")))
	var torso_tex := _load_texture(str(parts.get("torso", "")))
	var legs_tex := _load_texture(str(parts.get("legs", "")))

	if head_tex == null or torso_tex == null or legs_tex == null:
		if player.has_method("set_skin_index"):
			player.call("set_skin_index", idx + 1)
		return

	if head_tex == null:
		head_tex = fallback_heads
	if torso_tex == null:
		torso_tex = fallback_torso
	if legs_tex == null:
		legs_tex = fallback_legs

	var visual_root := player.get_node_or_null("VisualRoot") as Node
	if visual_root == null:
		if player.has_method("set_skin_index"):
			player.call("set_skin_index", idx + 1)
		return

	var legacy_body := visual_root.get_node_or_null("Sprite2D") as CanvasItem
	if legacy_body != null:
		legacy_body.visible = false

	var head := visual_root.get_node_or_null("head") as Sprite2D
	if head != null and head_tex != null:
		head.visible = true
		head.texture = head_tex
		head.region_enabled = true
		head.region_rect = region

	var torso := visual_root.get_node_or_null("torso") as Sprite2D
	if torso != null and torso_tex != null:
		torso.visible = true
		torso.texture = torso_tex
		torso.region_enabled = true
		torso.region_rect = region

	for leg_name in ["leg1", "leg2"]:
		var leg := visual_root.get_node_or_null(leg_name) as Sprite2D
		if leg != null and legs_tex != null:
			leg.visible = true
			leg.texture = legs_tex
			leg.region_enabled = true
			leg.region_rect = region

func _load_texture(path: String) -> Texture2D:
	var normalized := path.strip_edges()
	if normalized.is_empty():
		return null
	if _texture_cache.has(normalized):
		return _texture_cache[normalized] as Texture2D
	var loaded := load(normalized) as Texture2D
	_texture_cache[normalized] = loaded
	return loaded
