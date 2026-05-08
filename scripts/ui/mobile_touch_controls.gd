extends Control
class_name MobileTouchControls

signal movement_changed(value: Vector2)
signal aim_changed(value: Vector2)
signal shoot_pressed()
signal shoot_released()
signal jump_pressed()
signal jump_released()
signal ultimate_pressed()
signal reload_pressed()

const ENABLE_MOBILE_DEBUG := false
const STICK_RADIUS_RATIO := 0.095
const STICK_KNOB_RATIO := 0.42
const DEADZONE := 0.22
const BTN_RADIUS_RATIO := 0.06
const SAFE_MARGIN_X_RATIO := 0.05
const SAFE_MARGIN_Y_RATIO := 0.08

var _is_mobile_runtime := false
var _controls_enabled := false
var _movement_vec := Vector2.ZERO
var _aim_vec := Vector2.ZERO
var _shoot_held := false
var _jump_held := false
var _jump_pressed_edge := false
var _ultimate_pressed_edge := false
var _reload_pressed_edge := false

var _left_touch_id := -1
var _right_touch_id := -1
var _jump_touch_id := -1
var _ultimate_touch_id := -1
var _reload_touch_id := -1

var _left_center := Vector2.ZERO
var _right_center := Vector2.ZERO
var _left_radius := 80.0
var _right_radius := 80.0

var _left_base: ColorRect
var _left_knob: ColorRect
var _right_base: ColorRect
var _right_knob: ColorRect
var _jump_btn: Button
var _ultimate_btn: Button
var _reload_btn: Button
var _info_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_is_mobile_runtime = _detect_mobile_runtime()
	_build_ui()
	_update_layout()
	var viewport := get_viewport()
	if viewport != null:
		viewport.size_changed.connect(_update_layout)
	visible = false
	set_process_input(true)

func _detect_mobile_runtime() -> bool:
	if not OS.has_feature("web"):
		return false
	var ua: String = str(JavaScriptBridge.eval("navigator.userAgent || ''")).to_lower()
	var touch_points: int = int(JavaScriptBridge.eval("navigator.maxTouchPoints || 0"))
	var width: int = int(JavaScriptBridge.eval("window.innerWidth || 0"))
	var height: int = int(JavaScriptBridge.eval("window.innerHeight || 0"))
	var smallest_edge: int = mini(width, height)
	var mobile_ua: bool = ua.find("android") >= 0 or ua.find("iphone") >= 0 or ua.find("ipad") >= 0 or ua.find("mobile") >= 0 or ua.find("tablet") >= 0
	var touch_device: bool = touch_points >= 2
	var likely_handheld: bool = smallest_edge > 0 and smallest_edge <= 1024
	return mobile_ua or (touch_device and likely_handheld)

func is_mobile_runtime() -> bool:
	return _is_mobile_runtime

func show_controls() -> void:
	if not _is_mobile_runtime:
		return
	_controls_enabled = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

func hide_controls() -> void:
	_controls_enabled = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_release_all_touches()

func get_movement_vector() -> Vector2:
	return _movement_vec

func get_aim_vector() -> Vector2:
	return _aim_vec

func is_shoot_held() -> bool:
	return _shoot_held

func is_jump_held() -> bool:
	return _jump_held

func consume_jump_pressed() -> bool:
	var out := _jump_pressed_edge
	_jump_pressed_edge = false
	return out

func consume_ultimate_pressed() -> bool:
	var out := _ultimate_pressed_edge
	_ultimate_pressed_edge = false
	return out

func consume_reload_pressed() -> bool:
	var out := _reload_pressed_edge
	_reload_pressed_edge = false
	return out

func _build_ui() -> void:
	_left_base = _make_circle(Color(0.22, 0.38, 0.8, 0.5))
	_left_knob = _make_circle(Color(0.58, 0.82, 1.0, 0.75))
	_right_base = _make_circle(Color(0.8, 0.32, 0.6, 0.5))
	_right_knob = _make_circle(Color(1.0, 0.72, 0.9, 0.78))
	add_child(_left_base)
	add_child(_right_base)
	add_child(_left_knob)
	add_child(_right_knob)

	_jump_btn = _make_button("JUMP")
	_jump_btn.pressed.connect(func() -> void:
		# Press state for touch comes from _input id tracking.
		pass
	)
	add_child(_jump_btn)

	_ultimate_btn = _make_button("ULT")
	_ultimate_btn.modulate = Color(1.0, 0.65, 0.35, 0.9)
	add_child(_ultimate_btn)

	_reload_btn = _make_button("R")
	_reload_btn.modulate = Color(0.8, 0.95, 1.0, 0.85)
	add_child(_reload_btn)

	_info_label = Label.new()
	_info_label.visible = false
	add_child(_info_label)

func _make_circle(color: Color) -> ColorRect:
	var node := ColorRect.new()
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _make_button(text_value: String) -> Button:
	var btn := Button.new()
	btn.text = text_value
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return btn

func _update_layout() -> void:
	var size := get_viewport_rect().size
	var safe_x := size.x * SAFE_MARGIN_X_RATIO
	var safe_y := size.y * SAFE_MARGIN_Y_RATIO
	_left_radius = maxf(56.0, size.y * STICK_RADIUS_RATIO)
	_right_radius = _left_radius
	var btn_radius := maxf(36.0, size.y * BTN_RADIUS_RATIO)

	_left_center = Vector2(safe_x + _left_radius, size.y - safe_y - _left_radius)
	_right_center = Vector2(size.x - safe_x - _right_radius, size.y - safe_y - _right_radius)
	_place_circle(_left_base, _left_center, _left_radius)
	_place_circle(_right_base, _right_center, _right_radius)
	_place_circle(_left_knob, _left_center, _left_radius * STICK_KNOB_RATIO)
	_place_circle(_right_knob, _right_center, _right_radius * STICK_KNOB_RATIO)

	var jump_pos := _left_center + Vector2(_left_radius * 1.45, -_left_radius * 0.18)
	_place_button(_jump_btn, jump_pos, btn_radius)
	var ult_pos := _right_center + Vector2(0.0, -_right_radius * 1.35)
	_place_button(_ultimate_btn, ult_pos, btn_radius * 0.94)
	var reload_pos := _right_center + Vector2(-_right_radius * 1.25, -_right_radius * 0.6)
	_place_button(_reload_btn, reload_pos, btn_radius * 0.8)

func _place_circle(node: ColorRect, center: Vector2, radius: float) -> void:
	var diameter := radius * 2.0
	node.position = center - Vector2(radius, radius)
	node.size = Vector2(diameter, diameter)

func _place_button(node: Button, center: Vector2, radius: float) -> void:
	var diameter := radius * 2.0
	node.position = center - Vector2(radius, radius)
	node.size = Vector2(diameter, diameter)
	node.custom_minimum_size = Vector2(diameter, diameter)

func _input(event: InputEvent) -> void:
	if not _controls_enabled or not visible:
		return
	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	var id := event.index
	var pos := event.position
	if event.pressed:
		if _left_touch_id == -1 and pos.distance_to(_left_center) <= _left_radius * 1.25:
			_left_touch_id = id
			_update_left_stick(pos)
			return
		if _right_touch_id == -1 and pos.distance_to(_right_center) <= _right_radius * 1.25:
			_right_touch_id = id
			_update_right_stick(pos)
			return
		if _jump_touch_id == -1 and _is_inside_button(_jump_btn, pos):
			_jump_touch_id = id
			_set_jump_held(true)
			return
		if _ultimate_touch_id == -1 and _is_inside_button(_ultimate_btn, pos):
			_ultimate_touch_id = id
			_ultimate_pressed_edge = true
			emit_signal("ultimate_pressed")
			_flash_button(_ultimate_btn)
			if ENABLE_MOBILE_DEBUG:
				print("[MOBILE_INPUT] ultimate")
			return
		if _reload_touch_id == -1 and _is_inside_button(_reload_btn, pos):
			_reload_touch_id = id
			_reload_pressed_edge = true
			emit_signal("reload_pressed")
			_flash_button(_reload_btn)
			return
		return

	if id == _left_touch_id:
		_left_touch_id = -1
		_update_left_stick(_left_center)
	if id == _right_touch_id:
		_right_touch_id = -1
		_stop_right_stick()
	if id == _jump_touch_id:
		_jump_touch_id = -1
		_set_jump_held(false)
	if id == _ultimate_touch_id:
		_ultimate_touch_id = -1
	if id == _reload_touch_id:
		_reload_touch_id = -1

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	var id := event.index
	var pos := event.position
	if id == _left_touch_id:
		_update_left_stick(pos)
	elif id == _right_touch_id:
		_update_right_stick(pos)

func _update_left_stick(pos: Vector2) -> void:
	var delta := pos - _left_center
	var norm := Vector2.ZERO
	if delta.length() > 0.001:
		norm = delta.normalized() * minf(1.0, delta.length() / _left_radius)
	_movement_vec = norm
	_left_knob.position = _left_center + norm * (_left_radius * 0.58) - _left_knob.size * 0.5
	emit_signal("movement_changed", _movement_vec)
	if ENABLE_MOBILE_DEBUG:
		print("[MOBILE_INPUT] movement = %s" % str(_movement_vec))

func _update_right_stick(pos: Vector2) -> void:
	var delta := pos - _right_center
	var norm := Vector2.ZERO
	if delta.length() > 0.001:
		norm = delta.normalized() * minf(1.0, delta.length() / _right_radius)
	_aim_vec = norm
	_right_knob.position = _right_center + norm * (_right_radius * 0.58) - _right_knob.size * 0.5
	emit_signal("aim_changed", _aim_vec)
	var above_deadzone := _aim_vec.length() >= DEADZONE
	if above_deadzone and not _shoot_held:
		_shoot_held = true
		emit_signal("shoot_pressed")
		if ENABLE_MOBILE_DEBUG:
			print("[MOBILE_INPUT] shoot down")
	elif not above_deadzone and _shoot_held:
		_shoot_held = false
		emit_signal("shoot_released")
		if ENABLE_MOBILE_DEBUG:
			print("[MOBILE_INPUT] shoot up")
	if ENABLE_MOBILE_DEBUG:
		print("[MOBILE_INPUT] aim = %s" % str(_aim_vec))

func _stop_right_stick() -> void:
	_aim_vec = Vector2.ZERO
	_right_knob.position = _right_center - _right_knob.size * 0.5
	if _shoot_held:
		_shoot_held = false
		emit_signal("shoot_released")
		if ENABLE_MOBILE_DEBUG:
			print("[MOBILE_INPUT] shoot up")

func _set_jump_held(value: bool) -> void:
	if value == _jump_held:
		return
	_jump_held = value
	if _jump_held:
		_jump_pressed_edge = true
		emit_signal("jump_pressed")
		if ENABLE_MOBILE_DEBUG:
			print("[MOBILE_INPUT] jump down")
	else:
		emit_signal("jump_released")
		if ENABLE_MOBILE_DEBUG:
			print("[MOBILE_INPUT] jump up")

func _release_all_touches() -> void:
	_left_touch_id = -1
	_right_touch_id = -1
	_jump_touch_id = -1
	_ultimate_touch_id = -1
	_reload_touch_id = -1
	_movement_vec = Vector2.ZERO
	_aim_vec = Vector2.ZERO
	_jump_held = false
	_jump_pressed_edge = false
	_ultimate_pressed_edge = false
	_reload_pressed_edge = false
	if _shoot_held:
		_shoot_held = false
		emit_signal("shoot_released")
	_left_knob.position = _left_center - _left_knob.size * 0.5
	_right_knob.position = _right_center - _right_knob.size * 0.5

func _is_inside_button(btn: Button, pos: Vector2) -> bool:
	var rect := Rect2(btn.position, btn.size)
	return rect.has_point(pos)

func _flash_button(btn: Button) -> void:
	btn.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(btn, "modulate:a", 0.82, 0.15)
