extends RefCounted

var enable_intro_animation := true
var intro_timeout_sec := 6.0
var intro_fx_enabled := true

var _host: Node
var _intro: Control
var _intro_fade: ColorRect
var _intro_plate: CanvasItem
var _intro_label: Label
var _pixel_burst_at: Callable

var _intro_nonce := 0
var _intro_tween: Tween = null

func configure(host: Node, intro: Control, intro_fade: ColorRect, intro_plate: CanvasItem, intro_label: Label, pixel_burst_at: Callable) -> void:
	_host = host
	_intro = intro
	_intro_fade = intro_fade
	_intro_plate = intro_plate
	_intro_label = intro_label
	_pixel_burst_at = pixel_burst_at

func play_intro_animation_safe() -> void:
	if not enable_intro_animation:
		return
	if _host == null:
		return
	if intro_timeout_sec > 0.0:
		_intro_nonce += 1
		var nonce := _intro_nonce
		var timer := _host.get_tree().create_timer(intro_timeout_sec)
		timer.timeout.connect(func() -> void:
			if nonce != _intro_nonce:
				return
			if not enable_intro_animation:
				return
			var still_visible := _intro != null and _intro.visible
			var still_running := _intro_tween != null and _intro_tween.is_running()
			if still_visible or still_running:
				push_error("Intro animation watchdog timeout (%.2fs). Aborting intro." % float(intro_timeout_sec))
				abort_intro_animation()
		)
	_play_intro_animation()

func abort_intro_animation() -> void:
	_intro_nonce += 1
	enable_intro_animation = false
	if _intro_tween != null:
		_intro_tween.kill()
		_intro_tween = null
	if _intro != null:
		_intro.visible = false
		_intro.modulate = Color(1, 1, 1, 0)

func _play_intro_animation() -> void:
	if _intro == null or _intro_fade == null or _intro_plate == null or _intro_label == null:
		return
	if _intro_tween != null and _intro_tween.is_running():
		return

	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.visible = true
	_intro.modulate = Color(1, 1, 1, 1)
	_intro_fade.color = Color(0, 0, 0, 0)

	var base_label_pos := _intro_label.position
	var base_plate_pos := Vector2.ZERO
	if _intro_plate is Control:
		base_plate_pos = (_intro_plate as Control).position
	elif _intro_plate is Node2D:
		base_plate_pos = (_intro_plate as Node2D).position
	_intro_plate.modulate = Color(1, 1, 1, 0)
	_intro_plate.scale = Vector2(0.86, 0.86)
	_intro_plate.rotation = -0.03

	_intro_label.visible_characters = 0
	_intro_label.modulate = Color(1, 1, 1, 0)
	_intro_label.scale = Vector2(1.2, 1.2)
	_intro_label.position = base_label_pos + Vector2(0, -10)

	var t := _host.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_intro_tween = t
	t.parallel().tween_property(_intro_fade, "color:a", 0.72, 0.18)
	t.parallel().tween_property(_intro_plate, "modulate:a", 1.0, 0.18)
	t.parallel().tween_property(_intro_plate, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_intro_plate, "rotation", 0.0, 0.26)
	t.parallel().tween_property(_intro_label, "modulate:a", 1.0, 0.18)
	t.parallel().tween_property(_intro_label, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_intro_label, "position", base_label_pos, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	t.tween_method(Callable(self, "_set_intro_chars"), 0.0, float(_intro_label.text.length()), 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void:
		if intro_fx_enabled and _pixel_burst_at.is_valid():
			var plate_center := _intro_plate.get_global_transform().origin
			_pixel_burst_at.call(plate_center + Vector2(-120, 0), Color(0.25, 1, 0.85, 1))
			_pixel_burst_at.call(plate_center + Vector2(120, 0), Color(0.9, 0.74, 0.27, 1))
	)

	for i in range(7):
		var jitter := Vector2(randf_range(-4, 4), randf_range(-2, 2))
		var flash := Color(1, 1, 1, 1) if i % 2 == 0 else Color(0.25, 1, 0.85, 1)
		t.tween_property(_intro_label, "position", base_label_pos + jitter, 0.025).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.parallel().tween_property(_intro_label, "modulate", flash, 0.025)
	t.tween_property(_intro_label, "position", base_label_pos, 0.05)
	t.parallel().tween_property(_intro_label, "modulate", Color(1, 1, 1, 1), 0.05)

	t.tween_interval(0.85)
	t.parallel().tween_property(_intro_label, "position", base_label_pos + Vector2(0, -18), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_intro_label, "modulate:a", 0.0, 0.24)
	t.parallel().tween_property(_intro_plate, "scale", Vector2(0.92, 0.92), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_intro_plate, "modulate:a", 0.0, 0.24)
	t.parallel().tween_property(_intro_fade, "color:a", 0.0, 0.26)
	t.tween_callback(func() -> void:
		_intro.visible = false
		_intro_label.position = base_label_pos
		_intro_label.scale = Vector2.ONE
		_intro_label.modulate = Color(1, 1, 1, 1)
		if _intro_plate is Control:
			(_intro_plate as Control).position = base_plate_pos
		elif _intro_plate is Node2D:
			(_intro_plate as Node2D).position = base_plate_pos
		_intro_plate.scale = Vector2.ONE
		_intro_plate.rotation = 0.0
		_intro_plate.modulate = Color(1, 1, 1, 1)
	)

func _set_intro_chars(v: float) -> void:
	if _intro_label == null:
		return
	_intro_label.visible_characters = int(v)
