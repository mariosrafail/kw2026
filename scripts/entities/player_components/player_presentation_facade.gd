extends RefCounted

class_name PlayerPresentationFacade

var _status_visuals_component_cb: Callable = Callable()
var _damage_feedback_component_cb: Callable = Callable()
var _name_label: Label
var _skill_bars_root: Node2D
var _skill_q_fill: ColorRect
var _skill_e_fill: ColorRect

func configure(
	status_visuals_component_cb: Callable,
	damage_feedback_component_cb: Callable,
	name_label: Label,
	skill_bars_root: Node2D,
	skill_q_fill: ColorRect,
	skill_e_fill: ColorRect
) -> void:
	_status_visuals_component_cb = status_visuals_component_cb
	_damage_feedback_component_cb = damage_feedback_component_cb
	_name_label = name_label
	_skill_bars_root = skill_bars_root
	_skill_q_fill = skill_q_fill
	_skill_e_fill = skill_e_fill

func part_base_material(sprite: Sprite2D) -> Material:
	var status_visuals_component: Variant = _status_visuals_component()
	if status_visuals_component == null:
		return null
	return status_visuals_component.get_part_base_material(sprite)

func set_outrage_boost_visual(duration_sec: float) -> void:
	var status_visuals_component: Variant = _status_visuals_component()
	if status_visuals_component != null:
		status_visuals_component.set_outrage_boost_visual(duration_sec)

func clear_outrage_boost_visual() -> void:
	var status_visuals_component: Variant = _status_visuals_component()
	if status_visuals_component != null:
		status_visuals_component.clear_outrage_boost_visual()

func set_erebus_immune_visual(duration_sec: float) -> void:
	var status_visuals_component: Variant = _status_visuals_component()
	if status_visuals_component != null:
		status_visuals_component.set_erebus_immune_visual(duration_sec)

func clear_erebus_immune_visual() -> void:
	var status_visuals_component: Variant = _status_visuals_component()
	if status_visuals_component != null:
		status_visuals_component.clear_erebus_immune_visual()

func set_juice_shrink_visual(duration_sec: float, scale_factor: float) -> void:
	var status_visuals_component: Variant = _status_visuals_component()
	if status_visuals_component != null:
		status_visuals_component.set_juice_shrink_visual(duration_sec, scale_factor)

func clear_juice_shrink_visual(animate: bool) -> void:
	var status_visuals_component: Variant = _status_visuals_component()
	if status_visuals_component != null:
		status_visuals_component.clear_juice_shrink_visual(animate)

func set_display_name(display_name: String) -> void:
	if _name_label == null:
		return
	var trimmed := display_name.strip_edges()
	_name_label.text = trimmed
	_name_label.visible = not trimmed.is_empty()

func set_skill_cooldown_bars(q_ratio: float, e_ratio: float, bars_visible: bool) -> void:
	if _skill_bars_root != null:
		_skill_bars_root.visible = bars_visible
	if _skill_q_fill != null:
		var q_material := _skill_q_fill.material as ShaderMaterial
		if q_material != null:
			q_material.set_shader_parameter("progress", clampf(q_ratio, 0.0, 1.0))
	if _skill_e_fill != null:
		var e_material := _skill_e_fill.material as ShaderMaterial
		if e_material != null:
			e_material.set_shader_parameter("progress", clampf(e_ratio, 0.0, 1.0))

func start_ulti_duration_bar(duration_sec: float, status_text: String = "") -> void:
	var status_visuals_component: Variant = _status_visuals_component()
	if status_visuals_component != null:
		status_visuals_component.start_ulti_duration_bar(duration_sec, status_text)

func clear_ulti_duration_bar() -> void:
	var status_visuals_component: Variant = _status_visuals_component()
	if status_visuals_component != null:
		status_visuals_component.clear_ulti_duration_bar()

func show_damage_number(amount: int) -> void:
	var damage_feedback_component: Variant = _damage_feedback_component()
	if damage_feedback_component != null:
		damage_feedback_component.show_damage_number(amount)

func get_hit_radius(default_radius: float) -> float:
	var status_visuals_component: Variant = _status_visuals_component()
	if status_visuals_component != null:
		return float(status_visuals_component.get_hit_radius(default_radius))
	return default_radius

func get_hit_height(default_height: float) -> float:
	var status_visuals_component: Variant = _status_visuals_component()
	if status_visuals_component != null:
		return float(status_visuals_component.get_hit_height(default_height))
	return default_height

func apply_visual_correction(offset: Vector2) -> void:
	var status_visuals_component: Variant = _status_visuals_component()
	if status_visuals_component != null:
		status_visuals_component.apply_visual_correction(offset)

func _status_visuals_component() -> Variant:
	if _status_visuals_component_cb.is_valid():
		return _status_visuals_component_cb.call()
	return null

func _damage_feedback_component() -> Variant:
	if _damage_feedback_component_cb.is_valid():
		return _damage_feedback_component_cb.call()
	return null
