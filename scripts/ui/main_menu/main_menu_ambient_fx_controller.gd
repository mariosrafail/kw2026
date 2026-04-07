extends RefCounted

class_name MainMenuAmbientFxController

const TOXIC_CHAT_BOX_SIZE := Vector2(196.0, 82.0)
const TOXIC_CHAT_MARGIN_X := 5
const TOXIC_CHAT_MARGIN_Y := 4
const TOXIC_CHAT_ROW_SEPARATION := 1

var _host: Control
var _pixel_font_bold: FontFile
var _pixel_font_chat: FontFile
var _screen_main: Control
var _toxic_chat_users: Array = []
var _toxic_bubble_lines: Array = []
var _current_screen_cb: Callable = Callable()
var _warrior_username_label_cb: Callable = Callable()
var _warrior_area_cb: Callable = Callable()
var _main_warrior_preview_cb: Callable = Callable()

var _bg_crack_layer: Control
var _toxic_bubble_layer: Control
var _toxic_bubble_timer: Timer
var _toxic_chat_box: Panel
var _toxic_chat_list: VBoxContainer
var _toxic_chat_entries: Array = []
var _toxic_chat_locked_position := Vector2.ZERO
var _toxic_chat_position_locked := false

func configure(
	host: Control,
	pixel_font_bold: FontFile,
	pixel_font_chat: FontFile,
	screen_main: Control,
	toxic_chat_users: Array,
	toxic_bubble_lines: Array,
	current_screen_cb: Callable,
	warrior_username_label_cb: Callable,
	warrior_area_cb: Callable,
	main_warrior_preview_cb: Callable
) -> void:
	_host = host
	_pixel_font_bold = pixel_font_bold
	_pixel_font_chat = pixel_font_chat
	_screen_main = screen_main
	_toxic_chat_users = toxic_chat_users.duplicate()
	_toxic_bubble_lines = toxic_bubble_lines.duplicate()
	_current_screen_cb = current_screen_cb
	_warrior_username_label_cb = warrior_username_label_cb
	_warrior_area_cb = warrior_area_cb
	_main_warrior_preview_cb = main_warrior_preview_cb

func ensure_background_crack_layer() -> void:
	if _bg_crack_layer != null and is_instance_valid(_bg_crack_layer):
		return
	_bg_crack_layer = Control.new()
	_bg_crack_layer.name = "BackgroundCrackLayer"
	_bg_crack_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_crack_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_crack_layer.z_index = 60
	_host.add_child(_bg_crack_layer)
	var screens := _host.get_node_or_null("Screens")
	if screens != null:
		_host.move_child(_bg_crack_layer, screens.get_index())

func rebuild_background_cracks(cracked_background_enabled: bool, cracked_background_impacts: int) -> void:
	if _bg_crack_layer == null or not is_instance_valid(_bg_crack_layer):
		return
	for child in _bg_crack_layer.get_children():
		if child != null:
			child.queue_free()
	if not cracked_background_enabled:
		return
	var viewport_size := _host.get_viewport_rect().size
	if viewport_size.x <= 8.0 or viewport_size.y <= 8.0:
		return
	var impacts: int = clampi(cracked_background_impacts, 1, 7)
	for i in range(impacts):
		var impact_origin := Vector2(
			randf_range(viewport_size.x * 0.12, viewport_size.x * 0.88),
			randf_range(viewport_size.y * 0.12, viewport_size.y * 0.72)
		)
		_spawn_crack_impact(impact_origin, viewport_size)

func ensure_toxic_bubble_layer() -> void:
	if _toxic_bubble_layer != null and is_instance_valid(_toxic_bubble_layer):
		ensure_toxic_chat_box()
		return
	_toxic_bubble_layer = Control.new()
	_toxic_bubble_layer.name = "ToxicBubbleLayer"
	_toxic_bubble_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toxic_bubble_layer.top_level = true
	_toxic_bubble_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toxic_bubble_layer.z_index = 120
	_host.add_child(_toxic_bubble_layer)
	var screens := _host.get_node_or_null("Screens")
	if screens != null:
		_host.move_child(_toxic_bubble_layer, screens.get_index())
	ensure_toxic_chat_box()

func start_toxic_bubble_loop(toxic_bubbles_enabled: bool) -> void:
	if not toxic_bubbles_enabled:
		return
	ensure_toxic_bubble_layer()
	if _toxic_bubble_timer != null and is_instance_valid(_toxic_bubble_timer):
		return
	_toxic_bubble_timer = Timer.new()
	_toxic_bubble_timer.name = "ToxicBubbleTimer"
	_toxic_bubble_timer.one_shot = true
	_toxic_bubble_timer.autostart = false
	_host.add_child(_toxic_bubble_timer)
	_toxic_bubble_timer.timeout.connect(_on_toxic_bubble_timer_timeout)
	_schedule_next_toxic_bubble()

func layout_toxic_chat_stack() -> void:
	if _toxic_bubble_layer == null or not is_instance_valid(_toxic_bubble_layer):
		return
	if _toxic_chat_box == null or not is_instance_valid(_toxic_chat_box):
		return
	var fixed_box_size := TOXIC_CHAT_BOX_SIZE
	_toxic_chat_box.custom_minimum_size = fixed_box_size
	_toxic_chat_box.size = fixed_box_size
	_toxic_chat_box.scale = Vector2.ONE
	if not _toxic_chat_position_locked:
		var anchor := _main_warrior_message_anchor_pos()
		var viewport_size := _host.get_viewport_rect().size
		var box_size := fixed_box_size
		var x := clampf(anchor.x - box_size.x * 0.5, 8.0, maxf(10.0, viewport_size.x - box_size.x - 8.0))
		var y := clampf(anchor.y - box_size.y - 10.0, 8.0, maxf(10.0, viewport_size.y - box_size.y - 8.0))
		_toxic_chat_locked_position = Vector2(x, y)
		_toxic_chat_position_locked = true
	_toxic_chat_box.position = _toxic_chat_locked_position
	_trim_toxic_chat_entries_to_fit()

	for i in range(_toxic_chat_entries.size()):
		var entry = _toxic_chat_entries[i]
		if entry == null or not is_instance_valid(entry):
			continue
		var row := entry as RichTextLabel
		if row == null:
			continue
		var age := (_toxic_chat_entries.size() - 1) - i
		var alpha := clampf(0.82 - float(age) * 0.10, 0.20, 0.82)
		row.modulate.a = alpha

func process_tick() -> void:
	if _toxic_chat_box == null or not is_instance_valid(_toxic_chat_box):
		return
	if _toxic_chat_box.custom_minimum_size != TOXIC_CHAT_BOX_SIZE:
		_toxic_chat_box.custom_minimum_size = TOXIC_CHAT_BOX_SIZE
	if _toxic_chat_box.size != TOXIC_CHAT_BOX_SIZE:
		_toxic_chat_box.size = TOXIC_CHAT_BOX_SIZE
	if _toxic_chat_box.scale != Vector2.ONE:
		_toxic_chat_box.scale = Vector2.ONE
	if _toxic_chat_position_locked and _toxic_chat_box.position != _toxic_chat_locked_position:
		_toxic_chat_box.position = _toxic_chat_locked_position

func _spawn_crack_impact(origin: Vector2, viewport_size: Vector2) -> void:
	var branches: int = randi_range(6, 10)
	var ring_radius: float = randf_range(6.0, 11.0)
	for i in range(branches):
		var base_angle := (TAU * float(i) / float(branches)) + randf_range(-0.12, 0.12)
		var crack_len := randf_range(54.0, minf(viewport_size.x, viewport_size.y) * 0.34)
		var p := origin + Vector2(cos(base_angle), sin(base_angle)) * ring_radius
		var points := PackedVector2Array([origin, p])
		var segs: int = randi_range(5, 10)
		for s in range(segs):
			var t := float(s + 1) / float(segs)
			var spread := lerpf(1.4, 9.5, t)
			var step_angle := base_angle + randf_range(-0.13, 0.13)
			var next_p := origin + Vector2(cos(step_angle), sin(step_angle)) * (crack_len * t)
			next_p += Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
			next_p.x = clampf(next_p.x, 0.0, viewport_size.x)
			next_p.y = clampf(next_p.y, 0.0, viewport_size.y)
			points.append(next_p)
		_add_crack_line(points, randf_range(1.05, 1.8), Color(0.82, 0.90, 1.0, randf_range(0.02, 0.08)))
		if randf() < 0.72 and points.size() > 3:
			var anchor_idx: int = randi_range(2, points.size() - 1)
			var anchor := points[anchor_idx]
			var twig_angle := base_angle + randf_range(-0.95, 0.95)
			var twig_len := crack_len * randf_range(0.16, 0.34)
			var twig_end := anchor + Vector2(cos(twig_angle), sin(twig_angle)) * twig_len
			twig_end.x = clampf(twig_end.x, 0.0, viewport_size.x)
			twig_end.y = clampf(twig_end.y, 0.0, viewport_size.y)
			_add_crack_line(PackedVector2Array([anchor, twig_end]), randf_range(0.8, 1.2), Color(0.75, 0.85, 1.0, randf_range(0.05, 0.10)))

func _add_crack_line(points: PackedVector2Array, width: float, color: Color) -> void:
	if _bg_crack_layer == null or not is_instance_valid(_bg_crack_layer):
		return
	if points.size() < 2:
		return
	var glow := Line2D.new()
	glow.points = points
	glow.width = width + 1.2
	glow.default_color = Color(color.r, color.g, color.b, color.a * 0.28)
	glow.texture_mode = Line2D.LINE_TEXTURE_NONE
	glow.antialiased = true
	glow.z_index = 0
	_bg_crack_layer.add_child(glow)

	var line := Line2D.new()
	line.points = points
	line.width = width
	line.default_color = color
	line.texture_mode = Line2D.LINE_TEXTURE_NONE
	line.antialiased = true
	line.z_index = 1
	_bg_crack_layer.add_child(line)

func _schedule_next_toxic_bubble() -> void:
	if _toxic_bubble_timer == null or not is_instance_valid(_toxic_bubble_timer):
		return
	_toxic_bubble_timer.wait_time = randf_range(0.34, 0.9)
	_toxic_bubble_timer.start()

func _on_toxic_bubble_timer_timeout() -> void:
	var toxic_bubbles_enabled := bool(_host.get("toxic_bubbles_enabled"))
	if toxic_bubbles_enabled and _current_screen() == _screen_main:
		_spawn_toxic_bubble()
	_schedule_next_toxic_bubble()

func _spawn_toxic_bubble() -> void:
	if _toxic_bubble_layer == null or not is_instance_valid(_toxic_bubble_layer):
		return
	ensure_toxic_chat_box()
	if _toxic_chat_list == null or not is_instance_valid(_toxic_chat_list):
		return
	if _toxic_chat_users.is_empty() or _toxic_bubble_lines.is_empty():
		return
	var user := str(_toxic_chat_users[randi() % _toxic_chat_users.size()])
	var msg := str(_toxic_bubble_lines[randi() % _toxic_bubble_lines.size()])
	var row_bbcode := "[b]%s[/b]: %s" % [user, msg]

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = row_bbcode
	label.fit_content = true
	label.scroll_active = false
	label.selection_enabled = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.visible_ratio = 1.0
	label.clip_contents = false
	label.custom_minimum_size = Vector2(0.0, 13.0)
	label.add_theme_font_override("normal_font", _pixel_font_chat)
	label.add_theme_font_override("bold_font", _pixel_font_bold)
	label.add_theme_font_size_override("normal_font_size", 10)
	label.add_theme_font_size_override("bold_font_size", 10)
	label.add_theme_color_override("default_color", Color(0.95, 0.98, 1.0, 0.74))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 0)
	_toxic_chat_list.add_child(label)
	_toxic_chat_entries.append(label)
	if _toxic_chat_entries.size() > 8:
		var oldest = _toxic_chat_entries[0]
		_toxic_chat_entries.remove_at(0)
		if oldest != null and is_instance_valid(oldest):
			var out_tw := _host.create_tween()
			out_tw.tween_property(oldest, "modulate:a", 0.0, 0.18)
			out_tw.finished.connect(func() -> void:
				if oldest != null and is_instance_valid(oldest):
					oldest.queue_free()
			)

	layout_toxic_chat_stack()

	var tw := _host.create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 1.0, 0.08)

func _trim_toxic_chat_entries_to_fit() -> void:
	if _toxic_chat_box == null or not is_instance_valid(_toxic_chat_box):
		return
	if _toxic_chat_list == null or not is_instance_valid(_toxic_chat_list):
		return
	if _toxic_chat_entries.is_empty():
		return
	var max_rows_height := maxf(0.0, _toxic_chat_box.custom_minimum_size.y - float(TOXIC_CHAT_MARGIN_Y * 2))
	var used_height := 0.0
	var first_keep_index := 0
	var needs_trim := false
	for i in range(_toxic_chat_entries.size() - 1, -1, -1):
		var row := _toxic_chat_entries[i] as RichTextLabel
		if row == null or not is_instance_valid(row):
			first_keep_index = i + 1
			needs_trim = true
			break
		var row_height := maxf(row.custom_minimum_size.y, maxf(row.get_combined_minimum_size().y, row.size.y))
		var required_height := row_height
		if used_height > 0.0:
			required_height += float(TOXIC_CHAT_ROW_SEPARATION)
		if used_height + required_height > max_rows_height:
			first_keep_index = i + 1
			needs_trim = true
			break
		used_height += required_height
	if not needs_trim or first_keep_index <= 0:
		return
	for i in range(first_keep_index):
		var old_row = _toxic_chat_entries[i]
		if old_row != null and is_instance_valid(old_row):
			old_row.queue_free()
	_toxic_chat_entries = _toxic_chat_entries.slice(first_keep_index, _toxic_chat_entries.size())

func ensure_toxic_chat_box() -> void:
	if _toxic_bubble_layer == null or not is_instance_valid(_toxic_bubble_layer):
		return
	if _toxic_chat_box != null and is_instance_valid(_toxic_chat_box):
		return
	_toxic_chat_box = Panel.new()
	_toxic_chat_box.name = "ToxicChatBox"
	_toxic_chat_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toxic_chat_box.top_level = true
	_toxic_chat_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_toxic_chat_box.custom_minimum_size = TOXIC_CHAT_BOX_SIZE
	_toxic_chat_box.size = _toxic_chat_box.custom_minimum_size
	_toxic_chat_box.scale = Vector2.ONE
	_toxic_chat_box.clip_contents = true
	_toxic_chat_position_locked = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.14, 0.50)
	sb.border_width_left = 0
	sb.border_width_top = 0
	sb.border_width_right = 0
	sb.border_width_bottom = 0
	sb.border_color = Color(0.0, 0.0, 0.0, 0.0)
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	_toxic_chat_box.add_theme_stylebox_override("panel", sb)
	_toxic_bubble_layer.add_child(_toxic_chat_box)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.clip_contents = true
	margin.add_theme_constant_override("margin_left", TOXIC_CHAT_MARGIN_X)
	margin.add_theme_constant_override("margin_right", TOXIC_CHAT_MARGIN_X)
	margin.add_theme_constant_override("margin_top", TOXIC_CHAT_MARGIN_Y)
	margin.add_theme_constant_override("margin_bottom", TOXIC_CHAT_MARGIN_Y)
	_toxic_chat_box.add_child(margin)

	_toxic_chat_list = VBoxContainer.new()
	_toxic_chat_list.name = "Messages"
	_toxic_chat_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toxic_chat_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_toxic_chat_list.clip_contents = true
	_toxic_chat_list.alignment = BoxContainer.ALIGNMENT_END
	_toxic_chat_list.add_theme_constant_override("separation", TOXIC_CHAT_ROW_SEPARATION)
	margin.add_child(_toxic_chat_list)
	layout_toxic_chat_stack()

func _main_warrior_message_anchor_pos() -> Vector2:
	var fallback := Vector2(_host.get_viewport_rect().size.x * 0.5, _host.get_viewport_rect().size.y * 0.5)
	var warrior_username_label := _warrior_username_label()
	if warrior_username_label != null and warrior_username_label.visible:
		var username_rect := warrior_username_label.get_global_rect()
		return username_rect.position + Vector2(username_rect.size.x * 0.5, 0.0)
	var warrior_area := _warrior_area()
	if warrior_area != null:
		var area_rect := warrior_area.get_global_rect()
		fallback = area_rect.position + Vector2(area_rect.size.x * 0.5, area_rect.size.y * 0.28)
	var main_warrior_preview := _main_warrior_preview()
	if main_warrior_preview == null:
		return fallback
	var head_node := main_warrior_preview.get_node_or_null("VisualRoot/head")
	if head_node is Node2D:
		return (head_node as Node2D).global_position
	if main_warrior_preview is Node2D:
		return (main_warrior_preview as Node2D).global_position + Vector2(0.0, -34.0)
	return fallback

func _current_screen() -> Control:
	if _current_screen_cb.is_valid():
		return _current_screen_cb.call() as Control
	return null

func _warrior_username_label() -> Label:
	if _warrior_username_label_cb.is_valid():
		return _warrior_username_label_cb.call() as Label
	return null

func _warrior_area() -> Control:
	if _warrior_area_cb.is_valid():
		return _warrior_area_cb.call() as Control
	return null

func _main_warrior_preview() -> Node:
	if _main_warrior_preview_cb.is_valid():
		return _main_warrior_preview_cb.call() as Node
	return null
