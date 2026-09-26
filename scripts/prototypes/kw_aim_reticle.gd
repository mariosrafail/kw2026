extends Control
## The exact centre remains the aim point. Four chunky boxes provide focus/recoil feedback
## around an intentionally empty centre; they never alter the real shot ray.
const RETICLE_SETTINGS := preload("res://scripts/kw3d/reticle_settings.gd")

var camera: Camera3D
var focused := false
var target_ready := false
var blocked := false
var blocked_point := Vector3.ZERO
var hit_time := 0.0
var headshot_time := 0.0
var kill_time := 0.0
var shot_time := 0.0
var focus_loss := 0.0
var focus_velocity := 0.0
var centre_dot: ColorRect
var obstruction_label: Label
var reticle_preset := RETICLE_SETTINGS.PRESET_BLOCKS
var reticle_size_scale := 0.72
var custom_texture: Texture2D

const BOX_THICKNESS := 3.0
const BOX_LENGTH := 6.0
const BASE_GAP_HIP := 4.5
const BASE_GAP_ADS := 3.2
const MAX_FOCUS_OPEN := 8.0
const SHOT_FOCUS_KICK := 0.23
const SHOT_FOCUS_KICK_ADS := 0.16
const FOCUS_SPRING_HIP := 24.0
const FOCUS_SPRING_ADS := 30.0
const FOCUS_DAMPING_HIP := 8.0
const FOCUS_DAMPING_ADS := 10.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reload_reticle_settings()
	centre_dot = ColorRect.new()
	centre_dot.name = "AimCentre"
	centre_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre_dot)
	centre_dot.set_anchors_preset(Control.PRESET_CENTER)
	centre_dot.offset_left = -0.5
	centre_dot.offset_top = -0.5
	centre_dot.offset_right = 0.5
	centre_dot.offset_bottom = 0.5
	# Preserve a centred Control anchor for aim/layout contracts, but the visible
	# reticle centre is deliberately empty like the supplied reference.
	centre_dot.color = Color.TRANSPARENT
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


func _reload_reticle_settings() -> void:
	var settings := RETICLE_SETTINGS.load_settings()
	reticle_preset = str(settings.get("preset", RETICLE_SETTINGS.PRESET_BLOCKS))
	reticle_size_scale = clampf(float(settings.get("size_scale", 0.72)), 0.45, 1.60)
	custom_texture = RETICLE_SETTINGS.load_custom_texture(str(settings.get("custom_png", "")))
	if reticle_preset == RETICLE_SETTINGS.PRESET_CUSTOM and custom_texture == null:
		reticle_preset = RETICLE_SETTINGS.PRESET_BLOCKS
	queue_redraw()

func set_feedback(solution: Dictionary, cam: Camera3D, ads: bool) -> void:
	camera = cam
	focused = ads
	blocked = bool(solution.get("occluded", false))
	target_ready = bool(solution.get("target_ready", false)) and not blocked
	blocked_point = solution.get("end", Vector3.ZERO)
	if obstruction_label != null: obstruction_label.visible = false
	queue_redraw()

func notify_shot() -> void:
	shot_time = 0.12
	var kick := SHOT_FOCUS_KICK_ADS if focused else SHOT_FOCUS_KICK
	focus_loss = clampf(focus_loss + kick, 0.0, 1.0)
	focus_velocity += 0.45 if focused else 0.62

func notify_hit(lethal: bool, headshot: bool = false) -> void:
	hit_time = 0.13
	if headshot and not lethal: headshot_time = 0.19
	if lethal: kill_time = 0.28

func clear_feedback() -> void:
	hit_time = 0.0
	headshot_time = 0.0
	kill_time = 0.0
	blocked = false
	target_ready = false
	focus_loss = 0.0
	focus_velocity = 0.0
	if obstruction_label != null: obstruction_label.hide()
	queue_redraw()

func _process(delta: float) -> void:
	hit_time = maxf(0.0, hit_time - delta)
	headshot_time = maxf(0.0, headshot_time - delta)
	kill_time = maxf(0.0, kill_time - delta)
	shot_time = maxf(0.0, shot_time - delta)
	# Shots push the four blocks outward. A damped spring returns them to the
	# centre naturally after firing, with ADS settling a little faster/tighter.
	var spring := FOCUS_SPRING_ADS if focused else FOCUS_SPRING_HIP
	var damping := FOCUS_DAMPING_ADS if focused else FOCUS_DAMPING_HIP
	focus_velocity += (-focus_loss * spring - focus_velocity * damping) * delta
	focus_loss = clampf(focus_loss + focus_velocity * delta, 0.0, 1.0)
	if focus_loss <= 0.0 or (focus_loss < 0.002 and absf(focus_velocity) < 0.01):
		focus_loss = 0.0
		focus_velocity = 0.0
	queue_redraw()

func _outlined_bar(rect: Rect2, color: Color) -> void:
	draw_rect(rect.grow(0.75), Color(0.025, 0.03, 0.045, 0.90))
	draw_rect(rect, color)

func _draw() -> void:
	var c := size * 0.5
	var color := Color("82f4cc") if target_ready and not blocked else Color("f3f5f8")
	if centre_dot != null: centre_dot.color = Color.TRANSPARENT
	var arm_color := color
	arm_color.a = clampf(0.88 + shot_time * 0.9, 0.0, 1.0)
	match reticle_preset:
		RETICLE_SETTINGS.PRESET_DOT:
			_draw_dot_preset(c)
		RETICLE_SETTINGS.PRESET_CLASSIC:
			_draw_classic_preset(c, arm_color)
		RETICLE_SETTINGS.PRESET_CUSTOM:
			_draw_custom_preset(c)
		_:
			_draw_block_preset(c, arm_color)
	# A hit confirmation never covers the exact centre dot or victim's face.
	if hit_time > 0.0 or headshot_time > 0.0 or kill_time > 0.0:
		var hc := Color("ff6c63") if kill_time > 0.0 else Color("fff0a8") if headshot_time > 0.0 else Color.WHITE
		hc.a = minf(1.0, maxf(maxf(hit_time / 0.065, headshot_time / 0.095), kill_time / 0.12))
		for offset in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			var a: Vector2 = c + offset * 6.0
			var b: Vector2 = c + offset * 9.0
			draw_line(a,b,Color(0.02,0.02,0.03,hc.a),2.5,false)
			draw_line(a,b,hc,1.0,false)
	# Physical cover still blocks shots; no BLOCKED text or floating square overlay.


func _draw_block_preset(c: Vector2, color: Color) -> void:
	var s := reticle_size_scale
	var thickness := BOX_THICKNESS * s
	var length := BOX_LENGTH * s
	var base_gap := (BASE_GAP_ADS if focused else BASE_GAP_HIP) * s
	var gap := base_gap + focus_loss * MAX_FOCUS_OPEN * s
	_outlined_bar(Rect2(Vector2(c.x - thickness * 0.5, c.y - gap - length), Vector2(thickness, length)), color)
	_outlined_bar(Rect2(Vector2(c.x - thickness * 0.5, c.y + gap), Vector2(thickness, length)), color)
	_outlined_bar(Rect2(Vector2(c.x - gap - length, c.y - thickness * 0.5), Vector2(length, thickness)), color)
	_outlined_bar(Rect2(Vector2(c.x + gap, c.y - thickness * 0.5), Vector2(length, thickness)), color)


func _draw_dot_preset(c: Vector2) -> void:
	# Pixel-perfect square dot: odd integer dimensions keep it centred exactly on
	# the aim point and avoid the anti-aliased blur produced by draw_circle().
	var outer_size := 5
	if reticle_size_scale > 0.90:
		outer_size = 7
	if reticle_size_scale > 1.30:
		outer_size = 9
	# Keep only a one-pixel black border on every side so the dot stays crisp
	# without reading as a heavy black square.
	var inner_size := maxi(1, outer_size - 2)
	var snapped := Vector2(round(c.x), round(c.y))
	var outer_half := floori(outer_size / 2.0)
	var inner_half := floori(inner_size / 2.0)
	var outer_rect := Rect2(
		Vector2(snapped.x - outer_half, snapped.y - outer_half),
		Vector2(outer_size, outer_size)
	)
	var inner_rect := Rect2(
		Vector2(snapped.x - inner_half, snapped.y - inner_half),
		Vector2(inner_size, inner_size)
	)
	draw_rect(outer_rect, Color(0.0, 0.0, 0.0, 1.0), true)
	draw_rect(inner_rect, Color.WHITE, true)


func _draw_classic_preset(c: Vector2, color: Color) -> void:
	var s := reticle_size_scale
	var gap := (3.0 if focused else 4.0) * s + focus_loss * 6.0 * s
	var length := 3.0 * s
	var thickness := maxf(1.0, 1.1 * s)
	_outlined_bar(Rect2(Vector2(c.x - thickness * 0.5, c.y - gap - length), Vector2(thickness, length)), color)
	_outlined_bar(Rect2(Vector2(c.x - thickness * 0.5, c.y + gap), Vector2(thickness, length)), color)
	_outlined_bar(Rect2(Vector2(c.x - gap - length, c.y - thickness * 0.5), Vector2(length, thickness)), color)
	_outlined_bar(Rect2(Vector2(c.x + gap, c.y - thickness * 0.5), Vector2(length, thickness)), color)


func _draw_custom_preset(c: Vector2) -> void:
	if custom_texture == null:
		return
	var source_size := custom_texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var max_size := 22.0 * reticle_size_scale
	var scale_factor := minf(max_size / source_size.x, max_size / source_size.y)
	var draw_size := source_size * scale_factor
	draw_texture_rect(custom_texture, Rect2(c - draw_size * 0.5, draw_size), false)
