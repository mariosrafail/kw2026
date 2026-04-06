extends Control
class_name SkillHud

const SKILLS_TEXTURE := preload("res://assets/ui/skills.png")
const PIXEL_FONT := preload("res://assets/fonts/kwfont.ttf")
const RADIAL_SHADER := preload("res://assets/shaders/skill_cooldown_radial.gdshader")

const ICON_SIZE := 16
const SLOT_SIZE := Vector2(68.0, 68.0)
const SLOT_MARGIN_X := 18.0
const SLOT_MARGIN_Y := 18.0
const ICON_DRAW_SIZE := 64.0
const UNREADY_SCALE := 0.72
const READY_SCALE := 1.0
const READY_POP_SCALE := 1.08
const SHRINK_OUT_SEC := 0.08
const SHRINK_SETTLE_SEC := 0.16
const READY_ALPHA := 1.0
const IDLE_ALPHA := 0.38
const READY_IDLE_PULSE_SCALE := 1.03
const READY_IDLE_PULSE_SEC := 0.9
const ICON_TINT_SAT := 0.72
const ICON_TINT_VAL := 1.0
const RADIAL_TINT_SAT := 0.62
const RADIAL_TINT_VAL := 1.0
const READY_BURST_TEXT := "READY!"
const READY_BURST_COLOR := Color(1.0, 0.92, 0.18, 1.0)
const READY_BURST_OUTLINE := Color(0.46, 0.18, 0.0, 1.0)
const READY_BURST_POP_SCALE := 1.26
const READY_BURST_RISE_PX := 16.0
const READY_BURST_POP_SEC := 0.12
const READY_BURST_HOLD_SEC := 0.12
const READY_BURST_FADE_SEC := 0.26

const CHARACTER_E_ICON_COLUMNS := {
	"outrage": 1,
	"erebus": 3,
	"tasko": 5,
	"juice": 7,
	"madam": 9,
}

var _e_slot: Control
var _e_icon: TextureRect
var _e_charge_label: Label
var _e_radial: ColorRect
var _ready_burst_label: Label
var _ready_last_frame := false
var _slot_shrink_tween: Tween
var _ready_idle_tween: Tween
var _ready_burst_tween: Tween
var _ready_text_idle_tween: Tween
var _tint_rgb := Color(1.0, 1.0, 1.0, 1.0)
var _state_initialized := false
var _visual_scale := UNREADY_SCALE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	_e_slot = _build_slot()
	add_child(_e_slot)
	_layout_slots()
	set_character_id("outrage")
	set_tint(Color.WHITE)
	update_charge(0, 5)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_slots()

func set_character_id(character_id: String) -> void:
	var normalized := str(character_id).strip_edges().to_lower()
	if not CHARACTER_E_ICON_COLUMNS.has(normalized):
		normalized = "outrage"
	_e_icon.texture = _icon_texture_for_column(int(CHARACTER_E_ICON_COLUMNS[normalized]))

func update_charge(current_points: int, required_points: int) -> void:
	if _e_slot == null or _e_radial == null or _e_charge_label == null:
		return
	var safe_required := maxi(1, required_points)
	var safe_current := clampi(current_points, 0, safe_required)
	var ratio := clampf(float(safe_current) / float(safe_required), 0.0, 1.0)
	_set_radial_progress(_e_radial, ratio)
	_e_charge_label.text = "%d/%d" % [safe_current, safe_required]
	var ready := safe_current >= safe_required
	if not _state_initialized:
		_apply_ready_state(ready, false)
		_state_initialized = true
	elif ready != _ready_last_frame:
		_apply_ready_state(ready, true)
	_ready_last_frame = ready

func _apply_ready_state(ready: bool, animate: bool) -> void:
	_apply_icon_alpha(READY_ALPHA if ready else IDLE_ALPHA)
	if ready:
		_show_ready_text(animate)
		_enter_ready_state(animate)
	else:
		_hide_ready_text()
		_enter_unready_state(animate)

func _enter_ready_state(animate: bool) -> void:
	if _e_slot == null:
		return
	_stop_ready_idle_animation()
	if _slot_shrink_tween != null:
		_slot_shrink_tween.kill()
	if not animate:
		_set_visual_scale(READY_SCALE)
		_start_ready_idle_animation()
		return
	_slot_shrink_tween = _e_slot.create_tween()
	_slot_shrink_tween.tween_method(Callable(self, "_set_visual_scale"), _visual_scale, READY_POP_SCALE, SHRINK_OUT_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_slot_shrink_tween.tween_method(Callable(self, "_set_visual_scale"), READY_POP_SCALE, READY_SCALE, SHRINK_SETTLE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_slot_shrink_tween.finished.connect(func() -> void:
		_start_ready_idle_animation()
	)

func _enter_unready_state(animate: bool) -> void:
	if _e_slot == null:
		return
	_stop_ready_idle_animation()
	if _slot_shrink_tween != null:
		_slot_shrink_tween.kill()
	if not animate:
		_set_visual_scale(UNREADY_SCALE)
		return
	_slot_shrink_tween = _e_slot.create_tween()
	_slot_shrink_tween.tween_method(Callable(self, "_set_visual_scale"), _visual_scale, READY_POP_SCALE * 0.84, SHRINK_OUT_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_slot_shrink_tween.tween_method(Callable(self, "_set_visual_scale"), READY_POP_SCALE * 0.84, UNREADY_SCALE, SHRINK_SETTLE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _start_ready_idle_animation() -> void:
	if _e_slot == null:
		return
	_stop_ready_idle_animation()
	_ready_idle_tween = _e_slot.create_tween()
	_ready_idle_tween.set_loops()
	_ready_idle_tween.tween_method(Callable(self, "_set_visual_scale"), READY_SCALE, READY_IDLE_PULSE_SCALE, READY_IDLE_PULSE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ready_idle_tween.tween_method(Callable(self, "_set_visual_scale"), READY_IDLE_PULSE_SCALE, READY_SCALE, READY_IDLE_PULSE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_ready_idle_animation() -> void:
	if _ready_idle_tween != null:
		_ready_idle_tween.kill()
		_ready_idle_tween = null

func _apply_icon_alpha(alpha_value: float) -> void:
	if _e_icon == null:
		return
	_e_icon.modulate = Color(_tint_rgb.r, _tint_rgb.g, _tint_rgb.b, clampf(alpha_value, 0.0, 1.0))

func _set_visual_scale(scale_value: float) -> void:
	_visual_scale = scale_value
	if _e_icon == null:
		return
	var draw_px := maxi(1, roundi(ICON_DRAW_SIZE * _visual_scale))
	var draw_size := Vector2(float(draw_px), float(draw_px))
	var offset := (SLOT_SIZE - draw_size) * 0.5
	offset = Vector2(float(roundi(offset.x)), float(roundi(offset.y)))
	_e_icon.position = offset
	_e_icon.size = draw_size
	if _e_radial != null:
		_e_radial.position = offset
		_e_radial.size = draw_size

func set_tint(base_color: Color) -> void:
	_tint_rgb = Color(
		clampf(base_color.r, 0.0, 1.0),
		clampf(base_color.g, 0.0, 1.0),
		clampf(base_color.b, 0.0, 1.0),
		1.0
	)
	_apply_icon_alpha(READY_ALPHA if _ready_last_frame else IDLE_ALPHA)
	var radial_color := Color(
		clampf(base_color.r, 0.0, 1.0),
		clampf(base_color.g, 0.0, 1.0),
		clampf(base_color.b, 0.0, 1.0),
		1.0
	)
	_set_radial_color(_e_radial, radial_color)

func _color_hue(color: Color) -> float:
	var r := clampf(color.r, 0.0, 1.0)
	var g := clampf(color.g, 0.0, 1.0)
	var b := clampf(color.b, 0.0, 1.0)
	var c_max := maxf(r, maxf(g, b))
	var c_min := minf(r, minf(g, b))
	var delta := c_max - c_min
	if delta <= 0.00001:
		return 0.0
	var hue := 0.0
	if is_equal_approx(c_max, r):
		hue = fmod((g - b) / delta, 6.0)
	elif is_equal_approx(c_max, g):
		hue = ((b - r) / delta) + 2.0
	else:
		hue = ((r - g) / delta) + 4.0
	hue /= 6.0
	if hue < 0.0:
		hue += 1.0
	return hue

func _layout_slots() -> void:
	if _e_slot == null:
		return
	_e_slot.position = Vector2(size.x - SLOT_SIZE.x - SLOT_MARGIN_X, size.y - SLOT_SIZE.y - SLOT_MARGIN_Y)

func _build_slot() -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.size = SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.pivot_offset = SLOT_SIZE * 0.5

	var icon := TextureRect.new()
	icon.position = Vector2.ZERO
	icon.size = SLOT_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)

	var radial := ColorRect.new()
	radial.set_anchors_preset(Control.PRESET_TOP_LEFT)
	radial.color = Color.WHITE
	radial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radial.material = _create_radial_material()
	slot.add_child(radial)

	var charge_label := Label.new()
	charge_label.visible = true
	charge_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	charge_label.offset_left = 8.0
	charge_label.offset_top = 38.0
	charge_label.offset_right = -8.0
	charge_label.offset_bottom = -8.0
	charge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	charge_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	charge_label.add_theme_font_override("font", PIXEL_FONT)
	charge_label.add_theme_font_size_override("font_size", 12)
	charge_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	charge_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	charge_label.add_theme_constant_override("outline_size", 4)
	slot.add_child(charge_label)

	var ready_burst_label := Label.new()
	ready_burst_label.visible = false
	ready_burst_label.text = READY_BURST_TEXT
	ready_burst_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ready_burst_label.offset_left = -8.0
	ready_burst_label.offset_top = -24.0
	ready_burst_label.offset_right = 8.0
	ready_burst_label.offset_bottom = -8.0
	ready_burst_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_burst_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ready_burst_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ready_burst_label.add_theme_font_override("font", PIXEL_FONT)
	ready_burst_label.add_theme_font_size_override("font_size", 14)
	ready_burst_label.add_theme_color_override("font_color", READY_BURST_COLOR)
	ready_burst_label.add_theme_color_override("font_outline_color", READY_BURST_OUTLINE)
	ready_burst_label.add_theme_constant_override("outline_size", 6)
	ready_burst_label.pivot_offset = Vector2(SLOT_SIZE.x * 0.5, 0.0)
	slot.add_child(ready_burst_label)

	_e_icon = icon
	_e_charge_label = charge_label
	_e_radial = radial
	_ready_burst_label = ready_burst_label
	_set_visual_scale(UNREADY_SCALE)
	return slot

func _icon_texture_for_column(column: int) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = SKILLS_TEXTURE
	atlas.region = Rect2(column * ICON_SIZE, 0.0, ICON_SIZE, ICON_SIZE)
	return atlas

func _create_radial_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = RADIAL_SHADER
	material.set_shader_parameter("progress", 0.0)
	material.set_shader_parameter("fill_color", Color(1.0, 0.86, 0.28, 0.9))
	material.set_shader_parameter("bg_color", Color(0.0, 0.0, 0.0, 0.42))
	material.set_shader_parameter("inner_radius", 0.0)
	material.set_shader_parameter("outer_radius", 1.42)
	material.set_shader_parameter("start_angle_deg", 270.0)
	return material

func _set_radial_progress(radial: ColorRect, progress: float) -> void:
	if radial == null:
		return
	var shader_material := radial.material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("progress", clampf(progress, 0.0, 1.0))

func _set_radial_color(radial: ColorRect, color: Color) -> void:
	if radial == null:
		return
	var shader_material := radial.material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("fill_color", Color(color.r, color.g, color.b, 0.9))

func _play_ready_burst() -> void:
	if _ready_burst_label == null:
		return
	_stop_ready_text_idle_animation()
	if _ready_burst_tween != null:
		_ready_burst_tween.kill()
	_ready_burst_label.visible = true
	_ready_burst_label.scale = Vector2.ONE * 0.76
	_ready_burst_label.position = Vector2.ZERO
	_ready_burst_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_ready_burst_tween = _ready_burst_label.create_tween()
	_ready_burst_tween.parallel().tween_property(_ready_burst_label, "modulate:a", 1.0, READY_BURST_POP_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_ready_burst_tween.parallel().tween_property(_ready_burst_label, "scale", Vector2.ONE * READY_BURST_POP_SCALE, READY_BURST_POP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_ready_burst_tween.tween_interval(READY_BURST_HOLD_SEC)
	_ready_burst_tween.parallel().tween_property(_ready_burst_label, "position:y", -READY_BURST_RISE_PX * 0.35, READY_BURST_FADE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ready_burst_tween.parallel().tween_property(_ready_burst_label, "modulate:a", 1.0, READY_BURST_FADE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_ready_burst_tween.parallel().tween_property(_ready_burst_label, "scale", Vector2.ONE, READY_BURST_FADE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ready_burst_tween.finished.connect(func() -> void:
		if _ready_burst_label != null:
			_ready_burst_label.visible = true
			_ready_burst_label.position = Vector2(0.0, -READY_BURST_RISE_PX * 0.35)
			_ready_burst_label.scale = Vector2.ONE
			_ready_burst_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_start_ready_text_idle_animation()
		_ready_burst_tween = null
	)

func _show_ready_text(animate: bool) -> void:
	if _ready_burst_label == null:
		return
	if animate:
		_play_ready_burst()
		return
	if _ready_burst_tween != null:
		_ready_burst_tween.kill()
		_ready_burst_tween = null
	_ready_burst_label.visible = true
	_ready_burst_label.position = Vector2(0.0, -READY_BURST_RISE_PX * 0.35)
	_ready_burst_label.scale = Vector2.ONE
	_ready_burst_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_start_ready_text_idle_animation()

func _hide_ready_text() -> void:
	if _ready_burst_tween != null:
		_ready_burst_tween.kill()
		_ready_burst_tween = null
	_stop_ready_text_idle_animation()
	if _ready_burst_label == null:
		return
	_ready_burst_label.visible = false
	_ready_burst_label.position = Vector2.ZERO
	_ready_burst_label.scale = Vector2.ONE
	_ready_burst_label.modulate = Color(1.0, 1.0, 1.0, 0.0)

func _start_ready_text_idle_animation() -> void:
	if _ready_burst_label == null:
		return
	_stop_ready_text_idle_animation()
	_ready_text_idle_tween = _ready_burst_label.create_tween()
	_ready_text_idle_tween.set_loops()
	_ready_text_idle_tween.tween_property(_ready_burst_label, "scale", Vector2.ONE * 1.06, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ready_text_idle_tween.parallel().tween_property(_ready_burst_label, "position:y", -READY_BURST_RISE_PX * 0.55, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ready_text_idle_tween.tween_property(_ready_burst_label, "scale", Vector2.ONE * 0.98, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ready_text_idle_tween.parallel().tween_property(_ready_burst_label, "position:y", -READY_BURST_RISE_PX * 0.35, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_ready_text_idle_animation() -> void:
	if _ready_text_idle_tween != null:
		_ready_text_idle_tween.kill()
		_ready_text_idle_tween = null
