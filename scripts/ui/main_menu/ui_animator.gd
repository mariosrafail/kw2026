extends RefCounted

func add_hover_pop(btn: Button) -> void:
	if btn == null:
		return
	if bool(btn.get_meta("kw_hover_pop_bound", false)):
		_ensure_center_pivot(btn)
		return
	btn.set_meta("kw_hover_pop_bound", true)
	_ensure_center_pivot(btn)
	if not bool(btn.get_meta("kw_hover_pop_resized_bound", false)):
		btn.resized.connect(_on_hover_button_resized.bind(btn))
		btn.set_meta("kw_hover_pop_resized_bound", true)
	btn.mouse_entered.connect(func() -> void:
		btn.set_meta("kw_hovered", true)
		tween_scale(btn, Vector2(1.04, 1.04), 0.12)
	)
	btn.mouse_exited.connect(func() -> void:
		btn.set_meta("kw_hovered", false)
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

func _ensure_center_pivot(ci: CanvasItem) -> void:
	if ci == null:
		return
	if ci is Control:
		var c := ci as Control
		c.pivot_offset = c.size * 0.5
