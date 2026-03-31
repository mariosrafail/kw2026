extends Node2D
class_name BattleRoyaleZoneController

const OUTLINE_COLOR := Color(1.0, 0.14, 0.14, 0.95)
const OUTLINE_WIDTH := 10.0
const OUTLINE_POINT_COUNT := 192
const OUTER_HAZE_COLOR := Color(1.0, 0.16, 0.1, 0.26)
const OUTER_HAZE_WIDTH := 122.0
const EDGE_FIRE_GLOW_COLOR := Color(1.0, 0.34, 0.1, 0.66)
const EDGE_FIRE_GLOW_WIDTH := 34.0
const EMBER_COLOR := Color(1.0, 0.5, 0.2, 0.68)
const EMBER_COUNT := 96
const EMBER_RADIUS_PADDING_MIN := 8.0
const EMBER_RADIUS_PADDING_MAX := 42.0
const EMBER_SPEED_MIN := 0.18
const EMBER_SPEED_MAX := 0.95
const EMBER_SIZE_MIN := 1.3
const EMBER_SIZE_MAX := 4.8
const OUTSIDE_OVERLAY_SHADER := preload("res://assets/shaders/battle_royale_outside_overlay.gdshader")
const OVERLAY_LAYER := 0

@export var zone_center := Vector2(1024.0, 1024.0)
@export var start_radius := 1320.0
@export var end_radius := 260.0
@export var shrink_delay_sec := 12.0
@export var shrink_duration_sec := 50.0

var _elapsed_sec := 0.0
var _current_radius := start_radius
var _outside_overlay_layer: CanvasLayer
var _outside_overlay_rect: ColorRect
var _outside_overlay_material: ShaderMaterial
var _embers: Array[Dictionary] = []
var _ember_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _visual_time_sec := 0.0

func _ready() -> void:
	position = zone_center
	_current_radius = start_radius
	var is_headless := DisplayServer.get_name().to_lower() == "headless"
	set_process(not is_headless)
	if not is_headless:
		_ensure_outside_overlay()
		_seed_embers()
		_update_overlay_uniforms()
	queue_redraw()

func reset_match() -> void:
	_elapsed_sec = 0.0
	_current_radius = start_radius
	position = zone_center
	_visual_time_sec = 0.0
	_update_overlay_uniforms()
	queue_redraw()

func server_tick(delta: float) -> void:
	_elapsed_sec = maxf(0.0, _elapsed_sec + delta)
	_set_radius(_radius_for_elapsed(_elapsed_sec))

func apply_synced_state(center: Vector2, radius: float) -> void:
	zone_center = center
	position = center
	_set_radius(radius)
	_update_overlay_uniforms()

func current_center() -> Vector2:
	return zone_center

func current_radius() -> float:
	return _current_radius

func is_outside(point: Vector2) -> bool:
	return point.distance_to(zone_center) > _current_radius

func _radius_for_elapsed(elapsed_sec: float) -> float:
	if elapsed_sec <= shrink_delay_sec:
		return start_radius
	var shrink_t := clampf(
		(elapsed_sec - shrink_delay_sec) / maxf(0.001, shrink_duration_sec),
		0.0,
		1.0
	)
	return lerpf(start_radius, end_radius, shrink_t)

func _set_radius(radius: float) -> void:
	var clamped := maxf(end_radius, radius)
	if absf(_current_radius - clamped) <= 0.05:
		return
	_current_radius = clamped
	_update_overlay_uniforms()
	queue_redraw()

func _process(delta: float) -> void:
	_visual_time_sec += maxf(0.0, delta)
	_update_overlay_uniforms()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _outside_overlay_layer != null and is_instance_valid(_outside_overlay_layer):
			_outside_overlay_layer.queue_free()
			_outside_overlay_layer = null
			_outside_overlay_rect = null
			_outside_overlay_material = null

func _draw() -> void:
	draw_arc(
		Vector2.ZERO,
		_current_radius + OUTER_HAZE_WIDTH * 0.38,
		0.0,
		TAU,
		OUTLINE_POINT_COUNT,
		OUTER_HAZE_COLOR,
		OUTER_HAZE_WIDTH,
		true
	)
	draw_arc(
		Vector2.ZERO,
		_current_radius + EDGE_FIRE_GLOW_WIDTH * 0.2,
		0.0,
		TAU,
		OUTLINE_POINT_COUNT,
		EDGE_FIRE_GLOW_COLOR,
		EDGE_FIRE_GLOW_WIDTH,
		true
	)
	draw_arc(
		Vector2.ZERO,
		_current_radius,
		0.0,
		TAU,
		OUTLINE_POINT_COUNT,
		OUTLINE_COLOR,
		OUTLINE_WIDTH,
		true
	)
	_draw_embers()

func _draw_embers() -> void:
	if _embers.is_empty():
		return
	for ember_value in _embers:
		if not (ember_value is Dictionary):
			continue
		var ember := ember_value as Dictionary
		var angle_base := float(ember.get("angle", 0.0))
		var radius_pad := float(ember.get("radius_pad", EMBER_RADIUS_PADDING_MIN))
		var phase := float(ember.get("phase", 0.0))
		var speed := float(ember.get("speed", EMBER_SPEED_MIN))
		var size := float(ember.get("size", EMBER_SIZE_MIN))
		var pulse := float(ember.get("pulse", 1.0))
		var orbit := angle_base + (_visual_time_sec * speed + phase) * TAU
		var wobble := sin((_visual_time_sec * 1.8 + phase * 7.0) * TAU) * 5.0
		var radius := _current_radius + radius_pad + wobble
		var point := Vector2(cos(orbit), sin(orbit)) * radius
		var life := 0.45 + 0.55 * absf(sin((_visual_time_sec * pulse + phase) * TAU))
		var color := EMBER_COLOR
		color.a *= life
		draw_circle(point, size * (0.72 + life * 0.6), color)

func _ensure_outside_overlay() -> void:
	if _outside_overlay_layer != null and is_instance_valid(_outside_overlay_layer):
		return
	var tree := get_tree()
	if tree == null:
		return
	var root := tree.root
	if root == null:
		return
	var layer := CanvasLayer.new()
	layer.name = "BattleRoyaleOutsideOverlay"
	layer.layer = OVERLAY_LAYER
	root.add_child(layer)
	_outside_overlay_layer = layer

	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	var mat := ShaderMaterial.new()
	mat.shader = OUTSIDE_OVERLAY_SHADER
	overlay.material = mat
	layer.add_child(overlay)
	_outside_overlay_rect = overlay
	_outside_overlay_material = mat

func _update_overlay_uniforms() -> void:
	if _outside_overlay_material == null or not is_instance_valid(_outside_overlay_material):
		return
	_outside_overlay_material.set_shader_parameter("zone_center_world", zone_center)
	_outside_overlay_material.set_shader_parameter("zone_radius", _current_radius)
	_outside_overlay_material.set_shader_parameter("time_sec", _visual_time_sec)
	var viewport := get_viewport()
	if viewport == null:
		return
	_outside_overlay_material.set_shader_parameter("viewport_size", viewport.get_visible_rect().size)
	var camera := viewport.get_camera_2d()
	if camera == null:
		return
	_outside_overlay_material.set_shader_parameter("camera_center_world", camera.global_position)
	_outside_overlay_material.set_shader_parameter("camera_zoom", camera.zoom)

func _seed_embers() -> void:
	_ember_rng.seed = int(get_instance_id()) ^ int(Time.get_unix_time_from_system())
	_embers.clear()
	for _i in range(EMBER_COUNT):
		_embers.append({
			"angle": _ember_rng.randf_range(0.0, TAU),
			"radius_pad": _ember_rng.randf_range(EMBER_RADIUS_PADDING_MIN, EMBER_RADIUS_PADDING_MAX),
			"phase": _ember_rng.randf(),
			"speed": _ember_rng.randf_range(EMBER_SPEED_MIN, EMBER_SPEED_MAX),
			"size": _ember_rng.randf_range(EMBER_SIZE_MIN, EMBER_SIZE_MAX),
			"pulse": _ember_rng.randf_range(0.85, 1.45)
		})
