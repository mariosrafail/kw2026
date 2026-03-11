extends Control
class_name SkillHud

const SKILLS_TEXTURE := preload("res://assets/ui/skills.png")
const PIXEL_FONT := preload("res://assets/fonts/kwfont.ttf")
const RADIAL_SHADER := preload("res://assets/shaders/skill_cooldown_radial.gdshader")

const ICON_SIZE := 16
const SLOT_SIZE := Vector2(68.0, 68.0)
const SLOT_MARGIN_X := 18.0
const SLOT_MARGIN_Y := 18.0
const SHRUNK_SCALE := 0.58
const SHRINK_POP_SCALE := 0.9
const SHRINK_OUT_SEC := 0.08
const SHRINK_SETTLE_SEC := 0.16
const ACTIVE_ALPHA := 0.3
const IDLE_ALPHA := 0.6

const CHARACTER_ICON_COLUMNS := {
	"outrage": [0, 1],
	"erebus": [2, 3],
	"tasko": [4, 5],
}

var _q_slot: Control
var _e_slot: Control
var _q_icon: TextureRect
var _e_icon: TextureRect
var _q_cd_label: Label
var _e_cd_label: Label
var _q_radial: ColorRect
var _e_radial: ColorRect
var _q_cooldown_active := false
var _e_cooldown_active := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	_q_slot = _build_slot("Q", true)
	_e_slot = _build_slot("E", false)
	add_child(_q_slot)
	add_child(_e_slot)
	_layout_slots()
	set_character_id("outrage")
	set_tint(Color.WHITE)
	update_cooldowns(0.0, 0.0, 0.0, 0.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_slots()

func set_character_id(character_id: String) -> void:
	var normalized := str(character_id).strip_edges().to_lower()
	if not CHARACTER_ICON_COLUMNS.has(normalized):
		normalized = "outrage"
	var columns: Array = CHARACTER_ICON_COLUMNS[normalized]
	_q_icon.texture = _icon_texture_for_column(int(columns[0]))
	_e_icon.texture = _icon_texture_for_column(int(columns[1]))

func update_cooldowns(q_remaining: float, q_max: float, e_remaining: float, e_max: float) -> void:
	_apply_slot_state(_q_slot, _q_radial, _q_cd_label, q_remaining, q_max, true)
	_apply_slot_state(_e_slot, _e_radial, _e_cd_label, e_remaining, e_max, false)

func set_tint(base_color: Color) -> void:
	var resolved := Color(
		clampf(base_color.r * 1.08, 0.0, 1.0),
		clampf(base_color.g * 1.08, 0.0, 1.0),
		clampf(base_color.b * 1.08, 0.0, 1.0),
		IDLE_ALPHA
	)
	if _q_icon != null:
		_q_icon.modulate = resolved
	if _e_icon != null:
		_e_icon.modulate = resolved
	var radial_color := resolved.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.22)
	_set_radial_color(_q_radial, radial_color)
	_set_radial_color(_e_radial, radial_color)

func _layout_slots() -> void:
	if _q_slot == null or _e_slot == null:
		return
	_q_slot.position = Vector2(SLOT_MARGIN_X, size.y - SLOT_SIZE.y - SLOT_MARGIN_Y)
	_e_slot.position = Vector2(size.x - SLOT_SIZE.x - SLOT_MARGIN_X, size.y - SLOT_SIZE.y - SLOT_MARGIN_Y)

func _build_slot(key_text: String, _align_left: bool) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.size = SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.pivot_offset = SLOT_SIZE * 0.5

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2.ZERO
	icon.size = SLOT_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)

	var radial := ColorRect.new()
	radial.name = "Radial"
	radial.set_anchors_preset(Control.PRESET_FULL_RECT)
	radial.color = Color.WHITE
	radial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radial.material = _create_radial_material()
	slot.add_child(radial)

	var cooldown_label := Label.new()
	cooldown_label.name = "CooldownLabel"
	cooldown_label.visible = false
	cooldown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	cooldown_label.offset_left = 0.0
	cooldown_label.offset_top = 0.0
	cooldown_label.offset_right = 0.0
	cooldown_label.offset_bottom = 0.0
	cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cooldown_label.add_theme_font_override("font", PIXEL_FONT)
	cooldown_label.add_theme_font_size_override("font_size", 20)
	cooldown_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	slot.add_child(cooldown_label)

	if key_text == "Q":
		_q_icon = icon
		_q_cd_label = cooldown_label
		_q_radial = radial
	else:
		_e_icon = icon
		_e_cd_label = cooldown_label
		_e_radial = radial
	return slot

func _apply_slot_state(slot: Control, radial: ColorRect, cooldown_label: Label, remaining: float, max_value: float, is_q: bool) -> void:
	if slot == null or radial == null or cooldown_label == null:
		return
	var active := remaining > 0.0 and max_value > 0.0
	_update_slot_shrink(slot, active, is_q)
	radial.visible = active
	cooldown_label.visible = active
	var ratio := 1.0
	if max_value > 0.0:
		ratio = 1.0 - clampf(remaining / max_value, 0.0, 1.0)
	if active:
		_set_radial_progress(radial, ratio)
	if active:
		cooldown_label.text = _cooldown_text(remaining)
	else:
		cooldown_label.text = ""

func _update_slot_shrink(slot: Control, active: bool, is_q: bool) -> void:
	var was_active := _q_cooldown_active if is_q else _e_cooldown_active
	var icon := _q_icon if is_q else _e_icon
	if was_active == active:
		if icon != null:
			var current := icon.modulate
			current.a = ACTIVE_ALPHA if active else IDLE_ALPHA
			icon.modulate = current
		return
	if is_q:
		_q_cooldown_active = active
	else:
		_e_cooldown_active = active
	var tween := slot.get_meta("shrink_tween") as Tween if slot.has_meta("shrink_tween") else null
	if tween != null:
		tween.kill()
	var next := slot.create_tween()
	slot.set_meta("shrink_tween", next)
	if icon != null:
		var icon_tween := slot.create_tween()
		icon_tween.tween_property(icon, "modulate:a", ACTIVE_ALPHA if active else IDLE_ALPHA, SHRINK_SETTLE_SEC)
	if active:
		next.tween_property(slot, "scale", Vector2.ONE * SHRINK_POP_SCALE, SHRINK_OUT_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		next.tween_property(slot, "scale", Vector2.ONE * SHRUNK_SCALE, SHRINK_SETTLE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		next.tween_property(slot, "scale", Vector2.ONE, SHRINK_SETTLE_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _cooldown_text(remaining: float) -> String:
	if remaining >= 10.0:
		return str(int(ceil(remaining)))
	return "%.1f" % remaining

func _icon_texture_for_column(column: int) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = SKILLS_TEXTURE
	atlas.region = Rect2(column * ICON_SIZE, 0.0, ICON_SIZE, ICON_SIZE)
	return atlas

func _create_radial_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = RADIAL_SHADER
	material.set_shader_parameter("progress", 1.0)
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
