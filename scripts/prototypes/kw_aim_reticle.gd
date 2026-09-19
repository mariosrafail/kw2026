extends Control
## The centre dot is the aim point. Arms are feedback, never random bullet spread.
var camera: Camera3D
var focused := false
var target_ready := false
var blocked := false
var blocked_point := Vector3.ZERO
var hit_time := 0.0
var kill_time := 0.0
var shot_time := 0.0
var centre_dot: ColorRect
var obstruction_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre_dot = ColorRect.new()
	centre_dot.name = "AimCentre"
	centre_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre_dot)
	centre_dot.set_anchors_preset(Control.PRESET_CENTER)
	centre_dot.offset_left = -0.5
	centre_dot.offset_top = -0.5
	centre_dot.offset_right = 0.5
	centre_dot.offset_bottom = 0.5
	obstruction_label = Label.new()
	obstruction_label.name = "CoverWarning"
	obstruction_label.text = ""
	obstruction_label.add_theme_font_size_override("font_size", 9)
	obstruction_label.add_theme_color_override("font_color", Color("ffc579"))
	obstruction_label.add_theme_color_override("font_outline_color", Color("10121b"))
	obstruction_label.add_theme_constant_override("outline_size", 2)
	obstruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	obstruction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(obstruction_label)
	obstruction_label.set_anchors_preset(Control.PRESET_CENTER)
	obstruction_label.offset_left = -38
	obstruction_label.offset_right = 38
	obstruction_label.offset_top = 17
	obstruction_label.offset_bottom = 30
	obstruction_label.hide()

func set_feedback(solution: Dictionary, cam: Camera3D, ads: bool) -> void:
	camera = cam
	focused = ads
	blocked = bool(solution.get("occluded", false))
	target_ready = bool(solution.get("target_ready", false)) and not blocked
	blocked_point = solution.get("end", Vector3.ZERO)
	if obstruction_label != null: obstruction_label.visible = false
	queue_redraw()

func notify_shot() -> void:
	shot_time = 0.09

func notify_hit(lethal: bool) -> void:
	hit_time = 0.13
	if lethal: kill_time = 0.28

func clear_feedback() -> void:
	hit_time = 0.0
	kill_time = 0.0
	blocked = false
	target_ready = false
	if obstruction_label != null: obstruction_label.hide()
	queue_redraw()

func _process(delta: float) -> void:
	hit_time = maxf(0.0, hit_time - delta)
	kill_time = maxf(0.0, kill_time - delta)
	shot_time = maxf(0.0, shot_time - delta)
	queue_redraw()

func _outlined_bar(rect: Rect2, color: Color) -> void:
	draw_rect(rect.grow(0.6), Color(0.025, 0.03, 0.045, 0.85))
	draw_rect(rect, color)

func _draw() -> void:
	var c := size * 0.5
	var color := Color("82f4cc") if target_ready and not blocked else Color("f3f5f8")
	if centre_dot != null: centre_dot.color = color
	draw_rect(Rect2(c - Vector2.ONE * 1.5, Vector2.ONE * 3.0), Color("10121b"))
	var gap := 4.0 if focused else 5.5
	var length := 2.0 if focused else 3.0
	var arm_color := color
	arm_color.a = 0.78 + shot_time * 2.0
	for sign_value in [-1.0, 1.0]:
		var a := c + Vector2(sign_value * gap, 0)
		var b := c + Vector2(sign_value * (gap + length), 0)
		_outlined_bar(Rect2(Vector2(minf(a.x,b.x), c.y - 0.5), Vector2(length,1)), arm_color)
		a = c + Vector2(0,sign_value * gap)
		b = c + Vector2(0,sign_value * (gap + length))
		_outlined_bar(Rect2(Vector2(c.x - 0.5,minf(a.y,b.y)), Vector2(1,length)), arm_color)
	# A hit confirmation never covers the exact centre dot or victim's face.
	if hit_time > 0.0 or kill_time > 0.0:
		var hc := Color("ff6c63") if kill_time > 0.0 else Color.WHITE
		hc.a = minf(1.0, maxf(hit_time / 0.065, kill_time / 0.12))
		for offset in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			var a: Vector2 = c + offset * 6.0
			var b: Vector2 = c + offset * 9.0
			draw_line(a,b,Color(0.02,0.02,0.03,hc.a),2.5,false)
			draw_line(a,b,hc,1.0,false)
	# Physical cover still blocks shots; no BLOCKED text or floating square overlay.
