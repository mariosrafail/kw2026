extends RefCounted

const HOVER_FILL_NODE := "KwHoverFill"
const HOVER_FILL_TWEEN_META := "kw_hover_fill_tween"

func add_hover_pop(btn: Button) -> void:
	if btn == null:
		return
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if bool(btn.get_meta("kw_hover_pop_bound", false)):
		_ensure_center_pivot(btn)
		_ensure_hover_fill(btn)
		return
	btn.set_meta("kw_hover_pop_bound", true)
	_ensure_center_pivot(btn)
	_ensure_hover_fill(btn)
	if not bool(btn.get_meta("kw_hover_pop_resized_bound", false)):
		btn.resized.connect(_on_hover_button_resized.bind(btn))
		btn.set_meta("kw_hover_pop_resized_bound", true)
	btn.mouse_entered.connect(func() -> void:
		btn.set_meta("kw_hovered", true)
		_tween_hover_fill(btn, true)
		tween_scale(btn, Vector2(1.04, 1.04), 0.12)
	)
	btn.mouse_exited.connect(func() -> void:
		btn.set_meta("kw_hovered", false)
		_tween_hover_fill(btn, false)
		tween_scale(btn, Vector2(1, 1), 0.14)
	)
	btn.button_down.connect(func() -> void: press_in(btn, 0.94))
	btn.button_up.connect(func() -> void: release_to_hover(btn, btn))

func hover_area(area: Control, hovered: bool) -> void:
	if area == null:
		return
	var target := Vector2(1.045, 1.045) if hovered else Vector2(1, 1)
	tween_scale(area, target, 0.12)

func press_in(ci: CanvasItem, target_mult: float) -> void:
	if ci == null:
		return
	tween_scale(ci, ci.scale * target_mult, 0.06)

func release_to_hover(ci: CanvasItem, btn: Button) -> void:
	if ci == null:
		return
	var hovered := false
	if btn != null and btn.has_meta("kw_hovered"):
		hovered = bool(btn.get_meta("kw_hovered"))
	var target := Vector2(1.04, 1.04) if hovered else Vector2(1, 1)
	tween_scale(ci, target, 0.08)

func button_press_anim(host: Node, ci: CanvasItem, extra_scale: float = 0.06) -> void:
	if host == null or ci == null:
		return
	var start_scale: Vector2 = Vector2.ONE
	if ci is Node2D:
		start_scale = (ci as Node2D).scale
	elif ci is Control:
		start_scale = (ci as Control).scale
	var t := host.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(ci, "scale", start_scale * (1.0 - extra_scale * 0.6), 0.06)
	t.tween_property(ci, "scale", start_scale * (1.0 + extra_scale), 0.12)
	t.tween_property(ci, "scale", start_scale, 0.08)

func tween_scale(ci: CanvasItem, target_scale: Vector2, duration: float) -> void:
	if ci == null:
		return
	_ensure_center_pivot(ci)
	var t := ci.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(ci, "scale", target_scale, duration)

func pop(host: Node, ci: CanvasItem) -> void:
	if host == null or ci == null:
		return
	var start_scale: Vector2 = Vector2.ONE
	if ci is Node2D:
		start_scale = (ci as Node2D).scale
	elif ci is Control:
		start_scale = (ci as Control).scale
	var t := host.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(ci, "scale", start_scale * 1.08, 0.12)
	t.tween_property(ci, "scale", start_scale, 0.16)

func shake(host: Node, ci: CanvasItem) -> void:
	if host == null or ci == null:
		return
	var base := Vector2.ZERO
	if ci is Control:
		base = (ci as Control).position
	var t := host.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(ci, "position", base + Vector2(-6, 0), 0.05)
	t.tween_property(ci, "position", base + Vector2(6, 0), 0.05)
	t.tween_property(ci, "position", base + Vector2(-4, 0), 0.05)
	t.tween_property(ci, "position", base + Vector2(4, 0), 0.05)
	t.tween_property(ci, "position", base, 0.05)

func _on_hover_button_resized(btn: Button) -> void:
	if btn == null:
		return
	_ensure_center_pivot(btn)
	_refresh_hover_fill_size(btn)

func _ensure_center_pivot(ci: CanvasItem) -> void:
	if ci == null:
		return
	if ci is Control:
		var c := ci as Control
		c.pivot_offset = c.size * 0.5

func _ensure_hover_fill(btn: Button) -> void:
	if btn == null:
		return
	btn.clip_contents = true
	var fill := btn.get_node_or_null(HOVER_FILL_NODE) as ColorRect
	if fill == null:
		fill = ColorRect.new()
		fill.name = HOVER_FILL_NODE
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.color = Color(0.9, 0.74, 0.27, 0.22)
		fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		fill.anchor_left = 0.0
		fill.anchor_top = 0.0
		fill.anchor_right = 0.0
		fill.anchor_bottom = 1.0
		fill.offset_left = 0.0
		fill.offset_top = 0.0
		fill.offset_right = 0.0
		fill.offset_bottom = 0.0
		btn.add_child(fill)
		btn.move_child(fill, 0)
	_refresh_hover_fill_size(btn)

func _refresh_hover_fill_size(btn: Button) -> void:
	var fill := btn.get_node_or_null(HOVER_FILL_NODE) as ColorRect
	if fill == null:
		return
	var hovered := bool(btn.get_meta("kw_hovered", false))
	fill.size = Vector2(btn.size.x if hovered else 0.0, btn.size.y)
	fill.position = Vector2.ZERO

func _tween_hover_fill(btn: Button, hovered: bool) -> void:
	var fill := btn.get_node_or_null(HOVER_FILL_NODE) as ColorRect
	if fill == null:
		return
	var existing = btn.get_meta(HOVER_FILL_TWEEN_META) if btn.has_meta(HOVER_FILL_TWEEN_META) else null
	if existing is Tween:
		(existing as Tween).kill()
	var t := btn.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var target_w := btn.size.x if hovered else 0.0
	var dur := 0.16 if hovered else 0.12
	t.tween_property(fill, "size:x", target_w, dur)
	btn.set_meta(HOVER_FILL_TWEEN_META, t)
