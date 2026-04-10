extends RefCounted

var _host
var _screen_main
var _screen_warriors
var _screen_weapons
var _main_warrior_preview
var _warrior_shop_preview
var _main_weapon_icon
var _weapon_shop_preview
var _fx_layer
var _weapon_ui

var _set_current_screen: Callable = Callable()
var _stop_idle_loop: Callable = Callable()
var _start_idle_loop: Callable = Callable()
var _set_weapon_icon_sprite: Callable = Callable()
var _apply_weapon_skin_visual: Callable = Callable()

var _open_menu_tween: Tween
var _warrior_open_transition: Node2D
var _weapon_open_transition: Node2D

func _collect_sprite_bounds_in_visual(visual: Node2D, node: Node, min_v: Vector2, max_v: Vector2, found: bool) -> Dictionary:
	if node is Sprite2D:
		var spr := node as Sprite2D
		var tex := spr.texture
		if tex != null:
			var size := tex.get_size()
			if spr.region_enabled:
				size = spr.region_rect.size
			if size.x > 0.0 and size.y > 0.0:
				var origin := spr.offset
				if spr.centered:
					origin -= size * 0.5
				var local_rect := Rect2(origin, size)
				var to_visual := visual.get_global_transform().affine_inverse() * spr.get_global_transform()
				var p0 := to_visual * local_rect.position
				var p1 := to_visual * Vector2(local_rect.position.x + local_rect.size.x, local_rect.position.y)
				var p2 := to_visual * Vector2(local_rect.position.x + local_rect.size.x, local_rect.position.y + local_rect.size.y)
				var p3 := to_visual * Vector2(local_rect.position.x, local_rect.position.y + local_rect.size.y)
				if not found:
					min_v = p0
					max_v = p0
					found = true
				for p in [p0, p1, p2, p3]:
					min_v.x = minf(min_v.x, p.x)
					min_v.y = minf(min_v.y, p.y)
					max_v.x = maxf(max_v.x, p.x)
					max_v.y = maxf(max_v.y, p.y)
	for child in node.get_children():
		var result: Dictionary = _collect_sprite_bounds_in_visual(visual, child, min_v, max_v, found)
		var next_min: Variant = result.get("min", min_v)
		var next_max: Variant = result.get("max", max_v)
		if next_min is Vector2:
			min_v = next_min
		if next_max is Vector2:
			max_v = next_max
		found = bool(result.get("found", found))
	return {"min": min_v, "max": max_v, "found": found}

func _visual_center_local(visual: Node2D) -> Vector2:
	if visual == null:
		return Vector2.ZERO
	var result: Dictionary = _collect_sprite_bounds_in_visual(visual, visual, Vector2.ZERO, Vector2.ZERO, false)
	var found: bool = bool(result.get("found", false))
	if not found:
		return Vector2.ZERO
	var min_v: Vector2 = Vector2.ZERO
	var max_v: Vector2 = Vector2.ZERO
	var result_min: Variant = result.get("min", Vector2.ZERO)
	var result_max: Variant = result.get("max", Vector2.ZERO)
	if result_min is Vector2:
		min_v = result_min
	if result_max is Vector2:
		max_v = result_max
	return (min_v + max_v) * 0.5

func configure(refs: Dictionary, callbacks: Dictionary) -> void:
	_host = refs.get("host", null)
	_screen_main = refs.get("screen_main", null)
	_screen_warriors = refs.get("screen_warriors", null)
	_screen_weapons = refs.get("screen_weapons", null)
	_main_warrior_preview = refs.get("main_warrior_preview", null)
	_warrior_shop_preview = refs.get("warrior_shop_preview", null)
	_main_weapon_icon = refs.get("main_weapon_icon", null)
	_weapon_shop_preview = refs.get("weapon_shop_preview", null)
	_fx_layer = refs.get("fx_layer", null)
	_weapon_ui = refs.get("weapon_ui", null)

	_set_current_screen = callbacks.get("set_current_screen", Callable())
	_stop_idle_loop = callbacks.get("stop_idle_loop", Callable())
	_start_idle_loop = callbacks.get("start_idle_loop", Callable())
	_set_weapon_icon_sprite = callbacks.get("set_weapon_icon_sprite", Callable())
	_apply_weapon_skin_visual = callbacks.get("apply_weapon_skin_visual", Callable())

func update_refs(refs: Dictionary) -> void:
	if refs.has("fx_layer"):
		_fx_layer = refs.get("fx_layer", null)

func abort_transitions() -> void:
	if _open_menu_tween != null:
		_open_menu_tween.kill()
		_open_menu_tween = null
	if _warrior_open_transition != null and is_instance_valid(_warrior_open_transition):
		_warrior_open_transition.queue_free()
	_warrior_open_transition = null
	if _weapon_open_transition != null and is_instance_valid(_weapon_open_transition):
		_weapon_open_transition.queue_free()
	_weapon_open_transition = null

func open_warriors_menu() -> void:
	if _screen_warriors == null or _screen_main == null:
		return
	abort_transitions()
	if _stop_idle_loop.is_valid():
		_stop_idle_loop.call()

	_screen_warriors.visible = true
	_screen_warriors.z_index = 1200
	_screen_warriors.position = Vector2.ZERO
	_screen_warriors.scale = Vector2.ONE
	_screen_warriors.modulate = Color(1, 1, 1, 0)

	if _warrior_shop_preview != null and _warrior_shop_preview is CanvasItem:
		(_warrior_shop_preview as CanvasItem).visible = false

	if _host != null:
		_host.call_deferred("_open_warriors_menu_stage2")

func open_warriors_menu_stage2(warriors_menu_preview_scale_mult: float, warrior_shop_preview_base_scale: Vector2) -> void:
	if _screen_warriors == null or _screen_main == null:
		return
	var src_preview := _main_warrior_preview as Node2D
	var dst_preview := _warrior_shop_preview as Node2D
	if src_preview == null or dst_preview == null or _fx_layer == null:
		_open_menu_tween = _host.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_open_menu_tween.tween_property(_screen_warriors, "modulate:a", 1.0, 0.18)
		_open_menu_tween.tween_callback(func() -> void:
			_screen_main.visible = false
			if _set_current_screen.is_valid():
				_set_current_screen.call(_screen_warriors)
			if dst_preview != null:
				dst_preview.visible = true
			if _start_idle_loop.is_valid():
				_start_idle_loop.call()
		)
		return

	var src_visual := src_preview.get_node_or_null("VisualRoot") as Node2D
	var dst_visual := dst_preview.get_node_or_null("VisualRoot") as Node2D
	if src_visual == null or dst_visual == null:
		return
	var start_center_local := _visual_center_local(src_visual)
	var target_center_local := _visual_center_local(dst_visual)
	var start_pos := src_visual.to_global(start_center_local)
	var target_pos := dst_visual.to_global(target_center_local)
	var start_scale := src_visual.global_scale
	var target_scale := dst_visual.global_scale * clampf(warriors_menu_preview_scale_mult, 0.01, 3.0)

	_warrior_open_transition = Node2D.new()
	_warrior_open_transition.global_position = start_pos
	_warrior_open_transition.global_rotation = src_visual.global_rotation
	_warrior_open_transition.global_scale = start_scale
	_warrior_open_transition.z_index = 1200
	var warrior_visual := src_visual.duplicate() as Node2D
	if warrior_visual == null:
		return
	warrior_visual.position = -start_center_local
	_warrior_open_transition.add_child(warrior_visual)
	_fx_layer.add_child(_warrior_open_transition)

	src_preview.visible = false

	_open_menu_tween = _host.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_open_menu_tween.parallel().tween_property(_warrior_open_transition, "global_position", target_pos, 0.18)
	_open_menu_tween.parallel().tween_property(_warrior_open_transition, "global_scale", start_scale * 1.35, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_menu_tween.tween_property(_warrior_open_transition, "global_scale", target_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_open_menu_tween.tween_property(_screen_warriors, "modulate:a", 1.0, 0.18)

	_open_menu_tween.tween_callback(func() -> void:
		_screen_main.visible = false
		_screen_main.position = Vector2.ZERO
		_screen_main.modulate = Color(1, 1, 1, 1)
		if _set_current_screen.is_valid():
			_set_current_screen.call(_screen_warriors)
		if _warrior_open_transition != null and is_instance_valid(_warrior_open_transition):
			_warrior_open_transition.queue_free()
		_warrior_open_transition = null
		src_preview.visible = true
		if dst_preview != null:
			dst_preview.scale = warrior_shop_preview_base_scale * clampf(warriors_menu_preview_scale_mult, 0.01, 3.0)
			dst_preview.visible = true
		if _start_idle_loop.is_valid():
			_start_idle_loop.call()
	)

func close_warriors_menu() -> void:
	if _screen_warriors == null or _screen_main == null:
		return
	abort_transitions()
	if _stop_idle_loop.is_valid():
		_stop_idle_loop.call()
	if _warrior_shop_preview != null and _warrior_shop_preview is CanvasItem:
		(_warrior_shop_preview as CanvasItem).visible = true
	if _host != null:
		_host.call_deferred("_close_warriors_menu_stage2")

func close_warriors_menu_stage2(warrior_shop_preview_base_scale: Vector2) -> void:
	if _screen_warriors == null or _screen_main == null:
		return
	if _fx_layer == null:
		return
	var src_preview := _warrior_shop_preview as Node2D
	var dst_preview := _main_warrior_preview as Node2D
	if src_preview == null or dst_preview == null:
		return

	var src_visual := src_preview.get_node_or_null("VisualRoot") as Node2D
	var dst_visual := dst_preview.get_node_or_null("VisualRoot") as Node2D
	if src_visual == null or dst_visual == null:
		return

	var start_center_local := _visual_center_local(src_visual)
	var target_center_local := _visual_center_local(dst_visual)
	var start_pos := src_visual.to_global(start_center_local)
	var target_pos := dst_visual.to_global(target_center_local)
	var start_scale := src_visual.global_scale
	var target_scale := dst_visual.global_scale

	_warrior_open_transition = Node2D.new()
	_warrior_open_transition.global_position = start_pos
	_warrior_open_transition.global_rotation = src_visual.global_rotation
	_warrior_open_transition.global_scale = start_scale
	_warrior_open_transition.z_index = 1200
	var warrior_visual := src_visual.duplicate() as Node2D
	if warrior_visual == null:
		return
	warrior_visual.position = -start_center_local
	_warrior_open_transition.add_child(warrior_visual)
	_fx_layer.add_child(_warrior_open_transition)

	src_preview.visible = false
	dst_preview.visible = false

	_screen_main.visible = true
	_screen_main.position = Vector2.ZERO
	_screen_main.modulate = Color(1, 1, 1, 1)

	_open_menu_tween = _host.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_open_menu_tween.parallel().tween_property(_screen_warriors, "modulate:a", 0.0, 0.14)
	_open_menu_tween.parallel().tween_property(_warrior_open_transition, "global_position", target_pos, 0.18)
	_open_menu_tween.parallel().tween_property(_warrior_open_transition, "global_scale", target_scale * 1.15, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_menu_tween.tween_property(_warrior_open_transition, "global_scale", target_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_open_menu_tween.tween_callback(func() -> void:
		_screen_warriors.visible = false
		_screen_warriors.modulate = Color(1, 1, 1, 1)
		if _set_current_screen.is_valid():
			_set_current_screen.call(_screen_main)
		if _warrior_open_transition != null and is_instance_valid(_warrior_open_transition):
			_warrior_open_transition.queue_free()
		_warrior_open_transition = null
		dst_preview.visible = true
		src_preview.visible = true
		src_preview.scale = warrior_shop_preview_base_scale
		if _start_idle_loop.is_valid():
			_start_idle_loop.call()
	)

func open_weapons_menu(pending_weapon_id: String, pending_weapon_skin: int) -> void:
	if _screen_weapons == null or _screen_main == null:
		return
	abort_transitions()
	if _stop_idle_loop.is_valid():
		_stop_idle_loop.call()

	_screen_weapons.visible = true
	_screen_weapons.z_index = 1200
	_screen_weapons.position = Vector2.ZERO
	_screen_weapons.scale = Vector2.ONE
	_screen_weapons.modulate = Color(1, 1, 1, 0)

	if _weapon_shop_preview != null:
		if _set_weapon_icon_sprite.is_valid():
			_set_weapon_icon_sprite.call(_weapon_shop_preview, pending_weapon_id, 1.0, pending_weapon_skin)
		if _apply_weapon_skin_visual.is_valid():
			_apply_weapon_skin_visual.call(_weapon_shop_preview, pending_weapon_id, pending_weapon_skin)
		_weapon_shop_preview.visible = true
		_weapon_shop_preview.modulate.a = 0.0

	if _host != null:
		_host.call_deferred("_open_weapons_menu_stage2")

func _weapon_ui_offset(weapon_id: String) -> Vector2:
	if _weapon_ui == null:
		return Vector2.ZERO
	var value = _weapon_ui.call("weapon_ui_offset", weapon_id, 0)
	if typeof(value) == TYPE_VECTOR2:
		return value
	return Vector2.ZERO

func open_weapons_menu_stage2(pending_weapon_id: String, pending_weapon_skin: int, _weapon_uzi_id: String) -> void:
	if _screen_weapons == null or _screen_main == null:
		return
	if _fx_layer == null:
		return
	var src_icon := _main_weapon_icon as Sprite2D
	var dst_icon := _weapon_shop_preview as Sprite2D
	if src_icon == null or dst_icon == null:
		_open_menu_tween = _host.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_open_menu_tween.tween_property(_screen_weapons, "modulate:a", 1.0, 0.18)
		_open_menu_tween.tween_callback(func() -> void:
			_screen_main.visible = false
			if _set_current_screen.is_valid():
				_set_current_screen.call(_screen_weapons)
			if dst_icon != null:
				dst_icon.visible = true
			if _start_idle_loop.is_valid():
				_start_idle_loop.call()
		)
		return

	var start_center := src_icon.global_position
	var target_center := dst_icon.global_position

	var tex := src_icon.texture
	if tex == null:
		return

	var start_scale := src_icon.global_scale
	var target_scale := dst_icon.global_scale

	_weapon_open_transition = Node2D.new()
	_weapon_open_transition.global_position = start_center
	_weapon_open_transition.z_index = 1200
	var spr := Sprite2D.new()
	spr.centered = true
	spr.texture = tex
	spr.modulate = src_icon.modulate
	spr.material = src_icon.material
	spr.offset = Vector2.ZERO
	spr.scale = start_scale
	_weapon_open_transition.add_child(spr)
	_fx_layer.add_child(_weapon_open_transition)

	src_icon.visible = false

	_open_menu_tween = _host.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_open_menu_tween.parallel().tween_property(_weapon_open_transition, "global_position", target_center, 0.18)
	_open_menu_tween.parallel().tween_property(spr, "scale", start_scale * 1.35, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_menu_tween.tween_property(spr, "scale", target_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_open_menu_tween.tween_property(_screen_weapons, "modulate:a", 1.0, 0.18)

	_open_menu_tween.tween_callback(func() -> void:
		_screen_main.visible = false
		_screen_main.position = Vector2.ZERO
		_screen_main.modulate = Color(1, 1, 1, 1)
		if _set_current_screen.is_valid():
			_set_current_screen.call(_screen_weapons)
		if _weapon_open_transition != null and is_instance_valid(_weapon_open_transition):
			_weapon_open_transition.queue_free()
		_weapon_open_transition = null
		src_icon.visible = true
		if dst_icon != null:
			if _set_weapon_icon_sprite.is_valid():
				_set_weapon_icon_sprite.call(dst_icon, pending_weapon_id, 1.0, pending_weapon_skin)
			if _apply_weapon_skin_visual.is_valid():
				_apply_weapon_skin_visual.call(dst_icon, pending_weapon_id, pending_weapon_skin)
			dst_icon.visible = true
			dst_icon.modulate.a = 1.0
		if _start_idle_loop.is_valid():
			_start_idle_loop.call()
	)

func close_weapons_menu() -> void:
	if _screen_weapons == null or _screen_main == null:
		return
	abort_transitions()
	if _stop_idle_loop.is_valid():
		_stop_idle_loop.call()
	if _weapon_shop_preview != null:
		_weapon_shop_preview.visible = true
		_weapon_shop_preview.modulate.a = 1.0
	if _host != null:
		_host.call_deferred("_close_weapons_menu_stage2")

func close_weapons_menu_stage2(visible_weapon_id: String, visible_weapon_skin: int, _weapon_uzi_id: String) -> void:
	if _screen_weapons == null or _screen_main == null:
		return
	if _fx_layer == null:
		return
	var src_icon := _weapon_shop_preview as Sprite2D
	var dst_icon := _main_weapon_icon as Sprite2D
	if src_icon == null or dst_icon == null:
		return

	if _set_weapon_icon_sprite.is_valid():
		_set_weapon_icon_sprite.call(dst_icon, visible_weapon_id, 1.0, visible_weapon_skin)
	if _apply_weapon_skin_visual.is_valid():
		_apply_weapon_skin_visual.call(dst_icon, visible_weapon_id, visible_weapon_skin)

	var start_center := src_icon.global_position
	var target_center := dst_icon.global_position

	var tex := src_icon.texture
	if tex == null:
		return

	var start_scale := src_icon.global_scale
	var target_scale := dst_icon.global_scale

	_weapon_open_transition = Node2D.new()
	_weapon_open_transition.global_position = start_center
	_weapon_open_transition.z_index = 1200
	var spr := Sprite2D.new()
	spr.centered = true
	spr.texture = tex
	spr.modulate = src_icon.modulate
	spr.material = src_icon.material
	spr.offset = Vector2.ZERO
	spr.scale = start_scale
	_weapon_open_transition.add_child(spr)
	_fx_layer.add_child(_weapon_open_transition)

	src_icon.modulate.a = 0.0
	dst_icon.visible = false

	_screen_main.visible = true
	_screen_main.position = Vector2.ZERO
	_screen_main.modulate = Color(1, 1, 1, 1)

	_open_menu_tween = _host.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_open_menu_tween.parallel().tween_property(_screen_weapons, "modulate:a", 0.0, 0.14)
	_open_menu_tween.parallel().tween_property(_weapon_open_transition, "global_position", target_center, 0.18)
	_open_menu_tween.parallel().tween_property(spr, "scale", target_scale * 1.15, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_menu_tween.tween_property(spr, "scale", target_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_open_menu_tween.tween_callback(func() -> void:
		_screen_weapons.visible = false
		_screen_weapons.modulate = Color(1, 1, 1, 1)
		if _set_current_screen.is_valid():
			_set_current_screen.call(_screen_main)
		if _weapon_open_transition != null and is_instance_valid(_weapon_open_transition):
			_weapon_open_transition.queue_free()
		_weapon_open_transition = null
		dst_icon.visible = true
		src_icon.modulate.a = 1.0
		if _set_weapon_icon_sprite.is_valid():
			_set_weapon_icon_sprite.call(dst_icon, visible_weapon_id, 1.0, visible_weapon_skin)
			_set_weapon_icon_sprite.call(src_icon, visible_weapon_id, 1.0, visible_weapon_skin)
		if _apply_weapon_skin_visual.is_valid():
			_apply_weapon_skin_visual.call(dst_icon, visible_weapon_id, visible_weapon_skin)
			_apply_weapon_skin_visual.call(src_icon, visible_weapon_id, visible_weapon_skin)
		if _start_idle_loop.is_valid():
			_start_idle_loop.call()
	)
