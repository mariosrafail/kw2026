extends RefCounted

const OUTRAGE_HEAD_TEXTURE := preload("res://assets/warriors/outrage/head.png")
const HEAD_FRAME_SIZE := Vector2(64, 64)
const FACE_FILL_MAX_TILES := 760
const FACE_FILL_DENSITY := 0.00048
const FACE_GRID_CELL_PX := 34.0
const FACE_GRID_BORDER_PX := 36.0
const FACE_REVEAL_STEP_SEC := 0.018
const FACE_REVEAL_MAX_DELAY_SEC := 1.35
const FACE_PULSE_BATCH_SIZE := 14

var _host: Control
var _overlay: Control
var _dim: ColorRect
var _faces_layer: Node2D
var _head: Sprite2D
var _label: Label
var _fade_tween: Tween
var _anim_tween: Tween
var _fill_reveal_tween: Tween
var _fill_loop_tween: Tween
var _show_count := 0
var _rng := RandomNumberGenerator.new()
var _face_textures: Array[Texture2D] = []
var _face_tiles: Array[Sprite2D] = []
var _fill_pulse_cursor := 0

func configure(host: Control) -> void:
	_host = host
	_rng.randomize()
	_load_face_textures()
	_ensure_overlay()

func show(message: String = "LOADING...") -> void:
	_ensure_overlay()
	if _overlay == null:
		return
	_show_count += 1
	if _label != null:
		_label.text = message
	if _show_count > 1:
		_overlay.visible = true
		return
	if _host != null and _host.has_method("_on_menu_loading_overlay_shown"):
		_host.call("_on_menu_loading_overlay_shown")
	if _fade_tween != null:
		_fade_tween.kill()
		_fade_tween = null
	_overlay.visible = true
	_overlay.modulate.a = 0.0
	_pick_random_face()
	_prepare_face_fill()
	_start_idle_anim()
	_start_face_fill_anim()
	_fade_tween = _host.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(_overlay, "modulate:a", 1.0, 0.18)

func hide() -> void:
	if _overlay == null:
		return
	if _show_count > 0:
		_show_count -= 1
	if _show_count > 0:
		return
	if _fade_tween != null:
		_fade_tween.kill()
		_fade_tween = null
	_fade_tween = _host.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(_overlay, "modulate:a", 0.0, 0.14)
	_fade_tween.tween_callback(func() -> void:
		if _overlay != null:
			_overlay.visible = false
		_stop_idle_anim()
		_stop_face_fill_anim()
		if _host != null and _host.has_method("_on_menu_loading_overlay_hidden"):
			_host.call("_on_menu_loading_overlay_hidden")
	)

func _ensure_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_layout_overlay()
		return
	if _host == null:
		return

	var overlay := Control.new()
	overlay.name = "MenuLoadingOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	overlay.z_index = 2600
	_host.add_child(overlay)
	_overlay = overlay

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.color = Color(0.34, 0.58, 0.98, 0.78)
	overlay.add_child(dim)
	_dim = dim

	var faces_layer := Node2D.new()
	faces_layer.name = "FacesLayer"
	overlay.add_child(faces_layer)
	_faces_layer = faces_layer

	var head := Sprite2D.new()
	head.name = "OutrageHead"
	head.texture = OUTRAGE_HEAD_TEXTURE
	head.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.centered = true
	head.scale = Vector2.ONE * 4.0
	overlay.add_child(head)
	_head = head

	var label := Label.new()
	label.name = "LoadingLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12, 1.0))
	label.text = "LOADING..."
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.custom_minimum_size = Vector2(420, 28)
	overlay.add_child(label)
	_label = label

	if not _host.resized.is_connected(_layout_overlay):
		_host.resized.connect(_layout_overlay)
	_layout_overlay()

func _layout_overlay() -> void:
	if _overlay == null:
		return
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vp := _host.get_viewport_rect().size if _host != null else Vector2(1280, 720)
	if _head != null:
		_head.position = vp * 0.5 + Vector2(0, -14)
	if _label != null:
		_label.position = vp * 0.5 + Vector2(-210, 88)

func _start_idle_anim() -> void:
	if _head == null or _host == null:
		return
	_stop_idle_anim()
	_head.rotation = -0.16
	_head.scale = Vector2.ONE * 3.95
	_anim_tween = _host.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_anim_tween.parallel().tween_property(_head, "rotation", 0.16, 0.48)
	_anim_tween.parallel().tween_property(_head, "scale", Vector2.ONE * 4.15, 0.48)
	_anim_tween.tween_interval(0.02)
	_anim_tween.parallel().tween_property(_head, "rotation", -0.16, 0.48)
	_anim_tween.parallel().tween_property(_head, "scale", Vector2.ONE * 3.95, 0.48)

func _stop_idle_anim() -> void:
	if _anim_tween != null:
		_anim_tween.kill()
		_anim_tween = null

func _prepare_face_fill() -> void:
	if _faces_layer == null:
		return
	for tile in _face_tiles:
		if tile != null and is_instance_valid(tile):
			tile.queue_free()
	_face_tiles.clear()
	if _face_textures.is_empty():
		_load_face_textures()
	if _face_textures.is_empty():
		return
	var vp := _host.get_viewport_rect().size if _host != null else Vector2(1280, 720)
	var cell := maxf(18.0, FACE_GRID_CELL_PX)
	var min_x := -FACE_GRID_BORDER_PX
	var min_y := -FACE_GRID_BORDER_PX
	var max_x := vp.x + FACE_GRID_BORDER_PX
	var max_y := vp.y + FACE_GRID_BORDER_PX
	var cols := maxi(1, int(ceil((max_x - min_x) / cell)))
	var rows := maxi(1, int(ceil((max_y - min_y) / cell)))
	var grid_positions: Array[Vector2] = []
	for row in range(rows):
		for col in range(cols):
			var x := min_x + (float(col) + 0.5) * cell
			var y := min_y + (float(row) + 0.5) * cell
			grid_positions.append(Vector2(x, y))
	var target_total := mini(FACE_FILL_MAX_TILES, maxi(90, int(vp.x * vp.y * FACE_FILL_DENSITY)))
	var stride := maxi(1, int(ceil(float(grid_positions.size()) / float(maxi(1, target_total)))))
	var reveal_index := 0
	for i in range(0, grid_positions.size(), stride):
		if _face_tiles.size() >= target_total:
			break
		var sprite := Sprite2D.new()
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture = _face_textures[_rng.randi_range(0, _face_textures.size() - 1)]
		sprite.modulate = Color(1, 1, 1, 0.0)
		sprite.position = grid_positions[i]
		var tile_scale := _rng.randf_range(1.22, 1.52)
		sprite.scale = Vector2.ONE * (tile_scale * 0.2)
		sprite.set_meta("kw_base_scale", tile_scale)
		sprite.set_meta("kw_reveal_index", reveal_index)
		reveal_index += 1
		_faces_layer.add_child(sprite)
		_face_tiles.append(sprite)

func _start_face_fill_anim() -> void:
	_stop_face_fill_anim()
	if _host == null or _face_tiles.is_empty():
		return
	_fill_pulse_cursor = 0
	_fill_reveal_tween = _host.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for tile in _face_tiles:
		if tile == null or not is_instance_valid(tile):
			continue
		var base_scale := float(tile.get_meta("kw_base_scale", 0.85))
		var reveal_index := int(tile.get_meta("kw_reveal_index", 0))
		var delay := clampf(float(reveal_index) * FACE_REVEAL_STEP_SEC, 0.0, FACE_REVEAL_MAX_DELAY_SEC)
		var target_alpha := _rng.randf_range(0.28, 0.44)
		_fill_reveal_tween.parallel().tween_property(tile, "modulate:a", target_alpha, 0.26).set_delay(delay)
		_fill_reveal_tween.parallel().tween_property(tile, "scale", Vector2.ONE * base_scale, 0.28).set_delay(delay)
		_fill_reveal_tween.parallel().tween_property(tile, "rotation", _rng.randf_range(-0.07, 0.07), 0.35).set_delay(delay)
	_fill_loop_tween = _host.create_tween().set_loops()
	_fill_loop_tween.tween_interval(0.5)
	_fill_loop_tween.tween_callback(Callable(self, "_face_fill_pulse_step"))

func _face_fill_pulse_step() -> void:
	if _host == null or _face_tiles.is_empty():
		return
	var pulses := mini(FACE_PULSE_BATCH_SIZE, _face_tiles.size())
	for _i in range(pulses):
		var tile := _face_tiles[_fill_pulse_cursor % _face_tiles.size()]
		_fill_pulse_cursor += 1
		if tile == null or not is_instance_valid(tile):
			continue
		if _rng.randf() < 0.18:
			tile.texture = _face_textures[_rng.randi_range(0, _face_textures.size() - 1)]
		var base_scale := float(tile.get_meta("kw_base_scale", 0.85))
		var tw := _host.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(tile, "scale", Vector2.ONE * (base_scale * _rng.randf_range(1.08, 1.18)), 0.16)
		tw.parallel().tween_property(tile, "modulate:a", _rng.randf_range(0.42, 0.58), 0.16)
		tw.parallel().tween_property(tile, "rotation", _rng.randf_range(-0.14, 0.14), 0.16)
		tw.tween_property(tile, "scale", Vector2.ONE * base_scale, 0.22)
		tw.parallel().tween_property(tile, "modulate:a", _rng.randf_range(0.24, 0.5), 0.22)

func _stop_face_fill_anim() -> void:
	if _fill_reveal_tween != null:
		_fill_reveal_tween.kill()
		_fill_reveal_tween = null
	if _fill_loop_tween != null:
		_fill_loop_tween.kill()
		_fill_loop_tween = null

func _load_face_textures() -> void:
	_face_textures.clear()
	var dir := DirAccess.open("res://assets/warriors")
	if dir != null:
		dir.list_dir_begin()
		while true:
			var name := dir.get_next()
			if name.is_empty():
				break
			if name.begins_with("."):
				continue
			if not dir.current_is_dir():
				continue
			var head_path := "res://assets/warriors/%s/head.png" % name
			if ResourceLoader.exists(head_path):
				var tex := load(head_path) as Texture2D
				if tex != null:
					_face_textures.append_array(_all_head_frames(tex))
	dir.list_dir_end()
	if _face_textures.is_empty():
		_face_textures.append_array(_all_head_frames(OUTRAGE_HEAD_TEXTURE))

func _pick_random_face() -> void:
	if _head == null:
		return
	if _face_textures.is_empty():
		_load_face_textures()
	if _face_textures.is_empty():
		_head.texture = OUTRAGE_HEAD_TEXTURE
		return
	_head.texture = _face_textures[_rng.randi_range(0, _face_textures.size() - 1)]

func _all_head_frames(tex: Texture2D) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if tex == null:
		return out
	var size := tex.get_size()
	var frame_w := int(HEAD_FRAME_SIZE.x)
	var frame_h := int(HEAD_FRAME_SIZE.y)
	if size.x < frame_w or size.y < frame_h:
		out.append(tex)
		return out
	var cols := maxi(1, int(floor(size.x / float(frame_w))))
	var rows := maxi(1, int(floor(size.y / float(frame_h))))
	var img := tex.get_image()
	for y in range(rows):
		for x in range(cols):
			var region := Rect2(Vector2(x * frame_w, y * frame_h), HEAD_FRAME_SIZE)
			if not _region_has_visible_pixels(img, Rect2i(int(region.position.x), int(region.position.y), frame_w, frame_h)):
				continue
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = region
			out.append(atlas)
	if out.is_empty():
		out.append(tex)
	return out

func _region_has_visible_pixels(img: Image, region: Rect2i) -> bool:
	if img == null:
		return false
	var x0 := maxi(0, region.position.x)
	var y0 := maxi(0, region.position.y)
	var x1 := mini(img.get_width(), region.position.x + region.size.x)
	var y1 := mini(img.get_height(), region.position.y + region.size.y)
	if x1 <= x0 or y1 <= y0:
		return false
	var step := 4
	for y in range(y0, y1, step):
		for x in range(x0, x1, step):
			if img.get_pixel(x, y).a > 0.03:
				return true
	return false
