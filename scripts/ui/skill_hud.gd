extends Control
class_name SkillHud

const SKILLS_TEXTURE := preload("res://assets/ui/skills.png")
const PIXEL_FONT := preload("res://assets/fonts/kwfont.ttf")
const RADIAL_SHADER := preload("res://assets/shaders/skill_cooldown_radial.gdshader")

const ICON_SIZE := 16
const SLOT_SIZE := Vector2(68.0, 68.0)
const SLOT_MARGIN_X := 18.0
const SLOT_MARGIN_Y := 18.0
const READY_ALPHA := 0.96
const IDLE_ALPHA := 0.62

const CHARACTER_E_ICON_COLUMNS := {
	"outrage": 1,
	"erebus": 3,
	"tasko": 5,
}

var _e_slot: Control
var _e_icon: TextureRect
var _e_charge_label: Label
var _e_radial: ColorRect

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
	if _e_icon != null:
		var modulate := _e_icon.modulate
		modulate.a = READY_ALPHA if ready else IDLE_ALPHA
		_e_icon.modulate = modulate
	_e_slot.scale = Vector2.ONE * (1.02 if ready else 1.0)

func set_tint(base_color: Color) -> void:
	var resolved := Color(
		clampf(base_color.r * 1.08, 0.0, 1.0),
		clampf(base_color.g * 1.08, 0.0, 1.0),
		clampf(base_color.b * 1.08, 0.0, 1.0),
		IDLE_ALPHA
	)
	if _e_icon != null:
		_e_icon.modulate = resolved
	var radial_color := resolved.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.22)
	_set_radial_color(_e_radial, radial_color)

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
	radial.set_anchors_preset(Control.PRESET_FULL_RECT)
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

	_e_icon = icon
	_e_charge_label = charge_label
	_e_radial = radial
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
