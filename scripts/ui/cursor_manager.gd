extends CanvasLayer

const MENU_CURSOR_TEXTURE := preload("res://assets/cursor.png")
const MENU_CURSOR_CELL_SIZE := 32
const MENU_CURSOR_SCALE := 2

@export var pixel_size := 4.0 # size of each small square (in pixels)
@export var horizontal_rect_size := Vector2(6.5, 3.0)
@export var vertical_rect_size := Vector2(3.0, 6.5)
@export var arm_offset := 6.0 # base distance from center to each square
@export var move_spread_add := 3.0 # extra distance while moving fast
@export var hover_spread_mult := 1.10
@export var press_spread_mult := 0.75
@export var hover_scale := 1.04
@export var press_scale := 0.96
@export var hover_rotation_deg := 3.0
@export var press_rotation_deg := -7.0
@export var press_square_scale := 0.82
@export var motion_push_px := 3.5
@export var hover_wiggle_px := 0.9
@export var click_kick_px := 2.0
@export var shoot_spread_add := 8.0
@export var shoot_spread_lerp_in := 0.26
@export var shoot_spread_lerp_out := 0.14
@export var shoot_shake_px := 1.35
@export var shoot_shake_speed := 0.045
@export var shoot_feedback_hold_sec := 0.075
@export var hover_alpha := 1.0
@export var idle_alpha := 0.92
@export var move_lerp := 0.55
@export var tween_sec := 0.08

var _root: Node2D
var _sq_up: Sprite2D
var _sq_down: Sprite2D
var _sq_left: Sprite2D
var _sq_right: Sprite2D
var _tween: Tween
var _state := "idle" # idle|hover|press
var _press_until_msec := 0
var _spread_mult := 1.0
var _root_scale_mult := 1.0
var _sq_scale_mult := 1.0
var _base_sq_scale := Vector2.ONE * 4.0
var _last_mouse := Vector2.ZERO
var _move_spread := 0.0
var _motion_push := Vector2.ZERO
var _hover_wiggle_mult := 0.0
var _click_kick_mult := 0.0
var _button_click_boost_mult := 0.0
var _shoot_spread_mult := 0.0
var _shoot_feedback_until_msec := 0
var _pixel_tex: Texture2D
var _cursor_context := "game" # game|menu
var _menu_cursor_default_scaled: Texture2D
var _menu_cursor_hover_scaled: Texture2D
var _menu_cursor_text_scaled: Texture2D
var _menu_hover_blocked := false

func _ready() -> void:
	# Keep custom cursor above all regular UI/game canvas content.
	layer = 10000
	_process(true)
	_setup_crosshair()
	set_cursor_context(_cursor_context)

func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_IBEAM)
	_show_system_cursor_if_hidden()

func _make_pixel_texture() -> Texture2D:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)

func _make_square(square_name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = square_name
	s.centered = true
	s.texture = _pixel_tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s

func _setup_crosshair() -> void:
	_pixel_tex = _make_pixel_texture()

	_root = Node2D.new()
	_root.name = "CursorRoot"
	_root.modulate = Color(1, 1, 1, idle_alpha)
	_root.scale = Vector2.ONE
	_root.rotation = 0.0
	add_child(_root)

	_base_sq_scale = Vector2.ONE * clampf(pixel_size, 1.0, 32.0)
	_sq_up = _make_square("Up")
	_sq_down = _make_square("Down")
	_sq_left = _make_square("Left")
	_sq_right = _make_square("Right")
	_root.add_child(_sq_up)
	_root.add_child(_sq_down)
	_root.add_child(_sq_left)
	_root.add_child(_sq_right)
	_sq_up.scale = _vertical_square_scale()
	_sq_down.scale = _vertical_square_scale()
	_sq_left.scale = _horizontal_square_scale()
	_sq_right.scale = _horizontal_square_scale()

	_last_mouse = get_viewport().get_mouse_position()
	_root.position = _last_mouse
	_apply_crosshair_layout()

func _horizontal_square_scale() -> Vector2:
	var fallback := clampf(pixel_size, 1.0, 32.0)
	return Vector2(
		clampf(horizontal_rect_size.x, 1.0, 32.0) if horizontal_rect_size.x > 0.0 else fallback * 1.6,
		clampf(horizontal_rect_size.y, 1.0, 32.0) if horizontal_rect_size.y > 0.0 else fallback * 0.75
	)

func _vertical_square_scale() -> Vector2:
	var fallback := clampf(pixel_size, 1.0, 32.0)
	return Vector2(
		clampf(vertical_rect_size.x, 1.0, 32.0) if vertical_rect_size.x > 0.0 else fallback * 0.75,
		clampf(vertical_rect_size.y, 1.0, 32.0) if vertical_rect_size.y > 0.0 else fallback * 1.6
	)

func _hide_system_cursor_if_visible() -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _show_system_cursor_if_hidden() -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func set_cursor_context(context: String) -> void:
	var normalized := context.strip_edges().to_lower()
	if normalized != "menu" and normalized != "game":
		normalized = "game"
	_cursor_context = normalized
	if _cursor_context == "menu":
		_show_system_cursor_if_hidden()
		_apply_menu_cursor_shapes()
		if _root != null:
			_root.visible = false
		set_process(false)
		return
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_IBEAM)
	_hide_system_cursor_if_visible()
	if _root != null:
		_root.visible = true
	set_process(true)

func set_menu_hover_blocked(blocked: bool) -> void:
	_menu_hover_blocked = blocked
	if _cursor_context == "menu":
		_apply_menu_cursor_shapes()

func _apply_menu_cursor_shapes() -> void:
	var default_tex := _menu_cursor_texture_default_x4()
	Input.set_custom_mouse_cursor(default_tex, Input.CURSOR_ARROW, Vector2.ZERO)
	if _menu_hover_blocked:
		Input.set_custom_mouse_cursor(default_tex, Input.CURSOR_POINTING_HAND, Vector2.ZERO)
		Input.set_custom_mouse_cursor(default_tex, Input.CURSOR_IBEAM, Vector2.ZERO)
	else:
		Input.set_custom_mouse_cursor(_menu_cursor_texture_hover_x4(), Input.CURSOR_POINTING_HAND, Vector2.ZERO)
		Input.set_custom_mouse_cursor(_menu_cursor_texture_text_x4(), Input.CURSOR_IBEAM, Vector2.ZERO)

func _menu_cursor_texture_default_x4() -> Texture2D:
	if _menu_cursor_default_scaled != null:
		return _menu_cursor_default_scaled
	_menu_cursor_default_scaled = _menu_cursor_texture_cell_scaled_x4(0)
	return _menu_cursor_default_scaled

func _menu_cursor_texture_hover_x4() -> Texture2D:
	if _menu_cursor_hover_scaled != null:
		return _menu_cursor_hover_scaled
	_menu_cursor_hover_scaled = _menu_cursor_texture_cell_scaled_x4(1)
	return _menu_cursor_hover_scaled

func _menu_cursor_texture_text_x4() -> Texture2D:
	if _menu_cursor_text_scaled != null:
		return _menu_cursor_text_scaled
	_menu_cursor_text_scaled = _menu_cursor_texture_cell_scaled_x4(2)
	return _menu_cursor_text_scaled

func _menu_cursor_texture_cell_scaled_x4(cell_index: int) -> Texture2D:
	if MENU_CURSOR_TEXTURE == null:
		return null
	var img := MENU_CURSOR_TEXTURE.get_image()
	if img == null:
		return MENU_CURSOR_TEXTURE
	var src := Rect2i(
		maxi(0, cell_index) * MENU_CURSOR_CELL_SIZE,
		0,
		MENU_CURSOR_CELL_SIZE,
		MENU_CURSOR_CELL_SIZE
	)
	if src.position.x + src.size.x > img.get_width() or src.size.y > img.get_height():
		src = Rect2i(0, 0, mini(MENU_CURSOR_CELL_SIZE, img.get_width()), mini(MENU_CURSOR_CELL_SIZE, img.get_height()))
	var cell := Image.create(src.size.x, src.size.y, false, Image.FORMAT_RGBA8)
	cell.fill(Color(0, 0, 0, 0))
	cell.blit_rect(img, src, Vector2i.ZERO)
	cell.resize(maxi(1, cell.get_width() * MENU_CURSOR_SCALE), maxi(1, cell.get_height() * MENU_CURSOR_SCALE), Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(cell)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var hovered := get_viewport().gui_get_hovered_control()
			if hovered is BaseButton:
				_trigger_button_click_fx()
			_press_until_msec = Time.get_ticks_msec() + 120
			_set_state("press")

func _trigger_button_click_fx() -> void:
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_button_click_boost_mult", 1.0, tween_sec * 0.9)
	tw.tween_property(self, "_button_click_boost_mult", 0.0, tween_sec * 2.0)

func trigger_shot_feedback(intensity: float = 1.0) -> void:
	var hold_ms := int(maxf(0.01, shoot_feedback_hold_sec) * 1000.0 * clampf(intensity, 0.5, 2.0))
	_shoot_feedback_until_msec = max(_shoot_feedback_until_msec, Time.get_ticks_msec() + hold_ms)

func _process(_delta: float) -> void:
	if _root == null:
		return

	var mouse := get_viewport().get_mouse_position()
	_root.position = _root.position.lerp(mouse, clampf(move_lerp, 0.0, 1.0))

	var dt := maxf(0.0001, float(_delta))
	var mouse_delta := mouse - _last_mouse
	var speed := mouse_delta.length() / dt
	_last_mouse = mouse
	_move_spread = clampf((speed / 2200.0) * clampf(move_spread_add, 0.0, 24.0), 0.0, clampf(move_spread_add, 0.0, 24.0))
	var wants_shoot_spread := Time.get_ticks_msec() < _shoot_feedback_until_msec
	var shoot_target := 1.0 if wants_shoot_spread else 0.0
	var shoot_lerp := shoot_spread_lerp_in if wants_shoot_spread else shoot_spread_lerp_out
	_shoot_spread_mult = lerpf(_shoot_spread_mult, shoot_target, clampf(shoot_lerp, 0.01, 1.0))
	var push_target := Vector2.ZERO
	if mouse_delta.length_squared() > 0.0001:
		push_target = mouse_delta.normalized() * clampf((speed / 1800.0) * clampf(motion_push_px, 0.0, 12.0), 0.0, clampf(motion_push_px, 0.0, 12.0))
	_motion_push = _motion_push.lerp(push_target, 0.32)
	_apply_crosshair_layout()

	var now := Time.get_ticks_msec()
	if _state == "press" and now >= _press_until_msec:
		_set_state("idle")

	var hovered := get_viewport().gui_get_hovered_control()
	var wants_hover := hovered != null and hovered.visible and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE
	if _state != "press":
		_set_state("hover" if wants_hover else "idle")

func _apply_crosshair_layout() -> void:
	if _sq_up == null:
		return
	var base := clampf(arm_offset, 0.0, 48.0)
	var spread := base + _move_spread
	spread += clampf(shoot_spread_add, 0.0, 24.0) * clampf(_shoot_spread_mult, 0.0, 1.0)
	spread *= clampf(_spread_mult, 0.35, 2.5)
	if _state == "hover":
		spread *= clampf(hover_spread_mult, 0.5, 2.5)

	if _root != null:
		_root.scale = Vector2.ONE * clampf(_root_scale_mult, 0.25, 3.0)

	var ssm := clampf(_sq_scale_mult, 0.25, 3.0)
	if _sq_up != null:
		_sq_up.scale = _vertical_square_scale() * ssm
	if _sq_down != null:
		_sq_down.scale = _vertical_square_scale() * ssm
	if _sq_left != null:
		_sq_left.scale = _horizontal_square_scale() * ssm
	if _sq_right != null:
		_sq_right.scale = _horizontal_square_scale() * ssm

	var up_pos := Vector2(0, -spread)
	var down_pos := Vector2(0, spread)
	var left_pos := Vector2(-spread, 0)
	var right_pos := Vector2(spread, 0)

	var p := _motion_push
	if p.length_squared() > 0.0001:
		var pos_x := maxf(0.0, p.x)
		var neg_x := maxf(0.0, -p.x)
		var pos_y := maxf(0.0, p.y)
		var neg_y := maxf(0.0, -p.y)
		right_pos.x += pos_x
		left_pos.x -= neg_x
		down_pos.y += pos_y
		up_pos.y -= neg_y

	if _hover_wiggle_mult > 0.0:
		var t := Time.get_ticks_msec() * 0.001
		var w := clampf(hover_wiggle_px, 0.0, 6.0) * _hover_wiggle_mult
		up_pos.y += -cos(t * 9.0) * w
		down_pos.y += cos(t * 8.6 + 0.7) * w
		left_pos.x += -cos(t * 9.3 + 1.0) * w
		right_pos.x += cos(t * 8.9 + 0.3) * w

	if _click_kick_mult > 0.0:
		var kick := clampf(click_kick_px, 0.0, 12.0) * _click_kick_mult
		up_pos += Vector2(0, -kick)
		down_pos += Vector2(0, kick)
		left_pos += Vector2(-kick, 0)
		right_pos += Vector2(kick, 0)

	if _button_click_boost_mult > 0.0:
		var btn_kick := clampf(click_kick_px * 1.7, 0.0, 18.0) * _button_click_boost_mult
		up_pos += Vector2(0, -btn_kick)
		down_pos += Vector2(0, btn_kick)
		left_pos += Vector2(-btn_kick, 0)
		right_pos += Vector2(btn_kick, 0)

	if _shoot_spread_mult > 0.001:
		var t := float(Time.get_ticks_msec())
		var shake := clampf(shoot_shake_px, 0.0, 6.0) * _shoot_spread_mult
		var speed_mult := clampf(shoot_shake_speed, 0.005, 0.2)
		up_pos += Vector2(randf_range(-0.22, 0.22), -absf(sin(t * speed_mult)) * shake)
		down_pos += Vector2(randf_range(-0.22, 0.22), absf(cos(t * (speed_mult * 0.93))) * shake)
		left_pos += Vector2(-absf(sin(t * (speed_mult * 1.07) + 0.8)) * shake, randf_range(-0.22, 0.22))
		right_pos += Vector2(absf(cos(t * (speed_mult * 0.97) + 0.4)) * shake, randf_range(-0.22, 0.22))

	_sq_up.position = up_pos
	_sq_down.position = down_pos
	_sq_left.position = left_pos
	_sq_right.position = right_pos

func _set_state(next: String) -> void:
	if next == _state:
		return
	_state = next

	if _tween != null:
		_tween.kill()
		_tween = null

	var target_a := idle_alpha
	var target_spread := 1.0
	var target_root_scale := 1.0
	var target_sq_scale := 1.0
	var target_hover_wiggle := 0.0
	var target_click_kick := 0.0
	if _state == "hover":
		target_a = hover_alpha
		target_root_scale = clampf(hover_scale, 0.5, 2.0)
		target_hover_wiggle = 1.0
	elif _state == "press":
		target_a = 1.0
		target_spread = clampf(press_spread_mult, 0.25, 1.2)
		target_root_scale = clampf(press_scale, 0.5, 2.0)
		target_sq_scale = clampf(press_square_scale, 0.25, 2.0)
		target_click_kick = 1.0

	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_root, "modulate:a", target_a, tween_sec)
	_tween.parallel().tween_property(self, "_spread_mult", target_spread, tween_sec)
	_tween.parallel().tween_property(self, "_root_scale_mult", target_root_scale, tween_sec)
	_tween.parallel().tween_property(_root, "rotation", 0.0, tween_sec)
	_tween.parallel().tween_property(self, "_sq_scale_mult", target_sq_scale, tween_sec)
	_tween.parallel().tween_property(self, "_hover_wiggle_mult", target_hover_wiggle, tween_sec)
	_tween.parallel().tween_property(self, "_click_kick_mult", target_click_kick, tween_sec)
	if _state == "press":
		_tween.tween_property(self, "_spread_mult", 1.0, tween_sec * 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(self, "_root_scale_mult", 1.0, tween_sec * 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(self, "_sq_scale_mult", 1.0, tween_sec * 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(self, "_click_kick_mult", 0.0, tween_sec * 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
