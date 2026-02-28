extends CanvasLayer

@export var pixel_size := 4.0 # size of each small square (in pixels)
@export var arm_offset := 6.0 # base distance from center to each square
@export var move_spread_add := 3.0 # extra distance while moving fast
@export var hover_spread_mult := 1.10
@export var press_spread_mult := 0.75
@export var hover_scale := 1.04
@export var press_scale := 0.96
@export var hover_rotation_deg := 3.0
@export var press_rotation_deg := -7.0
@export var press_square_scale := 0.82
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
var _pixel_tex: Texture2D

func _ready() -> void:
	layer = 200
	_process(true)
	_setup_crosshair()
	_hide_system_cursor_if_visible()

func _exit_tree() -> void:
	_show_system_cursor_if_hidden()

func _make_pixel_texture() -> Texture2D:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)

func _make_square(name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = name
	s.centered = true
	s.texture = _pixel_tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = _base_sq_scale
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

	_last_mouse = get_viewport().get_mouse_position()
	_root.position = _last_mouse
	_apply_crosshair_layout()

func _hide_system_cursor_if_visible() -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _show_system_cursor_if_hidden() -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_press_until_msec = Time.get_ticks_msec() + 120
			_set_state("press")

func _process(_delta: float) -> void:
	if _root == null:
		return

	var mouse := get_viewport().get_mouse_position()
	_root.position = _root.position.lerp(mouse, clampf(move_lerp, 0.0, 1.0))

	var dt := maxf(0.0001, float(_delta))
	var speed := (mouse - _last_mouse).length() / dt
	_last_mouse = mouse
	_move_spread = clampf((speed / 2200.0) * clampf(move_spread_add, 0.0, 24.0), 0.0, clampf(move_spread_add, 0.0, 24.0))
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
	spread *= clampf(_spread_mult, 0.35, 2.5)
	if _state == "hover":
		spread *= clampf(hover_spread_mult, 0.5, 2.5)

	if _root != null:
		_root.scale = Vector2.ONE * clampf(_root_scale_mult, 0.25, 3.0)

	var sqs := [_sq_up, _sq_down, _sq_left, _sq_right]
	var ssm := clampf(_sq_scale_mult, 0.25, 3.0)
	for s in sqs:
		var spr := s as Sprite2D
		if spr != null:
			spr.scale = _base_sq_scale * ssm

	_sq_up.position = Vector2(0, -spread)
	_sq_down.position = Vector2(0, spread)
	_sq_left.position = Vector2(-spread, 0)
	_sq_right.position = Vector2(spread, 0)

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
	var target_root_rot := 0.0
	var target_sq_scale := 1.0
	if _state == "hover":
		target_a = hover_alpha
		target_root_scale = clampf(hover_scale, 0.5, 2.0)
		target_root_rot = deg_to_rad(clampf(hover_rotation_deg, -45.0, 45.0))
	elif _state == "press":
		target_a = 1.0
		target_spread = clampf(press_spread_mult, 0.25, 1.2)
		target_root_scale = clampf(press_scale, 0.5, 2.0)
		target_root_rot = deg_to_rad(clampf(press_rotation_deg, -90.0, 90.0))
		target_sq_scale = clampf(press_square_scale, 0.25, 2.0)

	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_root, "modulate:a", target_a, tween_sec)
	_tween.parallel().tween_property(self, "_spread_mult", target_spread, tween_sec)
	_tween.parallel().tween_property(self, "_root_scale_mult", target_root_scale, tween_sec)
	_tween.parallel().tween_property(_root, "rotation", target_root_rot, tween_sec)
	_tween.parallel().tween_property(self, "_sq_scale_mult", target_sq_scale, tween_sec)
	if _state == "press":
		_tween.tween_property(self, "_spread_mult", 1.0, tween_sec * 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(self, "_root_scale_mult", 1.0, tween_sec * 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(_root, "rotation", 0.0, tween_sec * 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(self, "_sq_scale_mult", 1.0, tween_sec * 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
