extends Node

@export var enable_background_motion := false

@onready var sky := $"../Sky" as Sprite2D
@onready var bg1 := $"../MapBG1" as Sprite2D
@onready var bg2 := $"../MapBG2" as Sprite2D
@onready var bg3 := $"../MapBG3" as Sprite2D
@onready var map_front := $"../MapFront" as Sprite2D
@onready var camera := $"../MainCamera" as Camera2D
@onready var atmosphere_overlay := $"../../AtmosphereOverlay" as ColorRect
@onready var vignette_overlay := $"../../VignetteOverlay" as ColorRect

var _time_sec := 0.0
var _anchor_camera := Vector2(640.0, 360.0)
var _base_positions := {}
var _intro_weight := 0.0

func _ready() -> void:
	_capture_base("sky", sky)
	_capture_base("bg1", bg1)
	_capture_base("bg2", bg2)
	_capture_base("bg3", bg3)
	_capture_base("front", map_front)
	if bg2 != null:
		bg2.visible = true
		bg2.modulate = Color(0.86, 0.93, 1.0, 0.46)
	if bg3 != null:
		bg3.visible = true
		bg3.modulate = Color(1.0, 0.86, 0.63, 0.2)
	if sky != null:
		sky.modulate = Color(0.72, 0.95, 1.0, 1.0)
	if map_front != null:
		map_front.modulate = Color(0.94, 0.96, 1.0, 0.95)
	if atmosphere_overlay != null:
		var atmosphere_color := atmosphere_overlay.modulate
		atmosphere_color.a = 0.0
		atmosphere_overlay.modulate = atmosphere_color
	if vignette_overlay != null:
		var vignette_color := vignette_overlay.modulate
		vignette_color.a = 0.0
		vignette_overlay.modulate = vignette_color

func _process(delta: float) -> void:
	_time_sec += delta
	_intro_weight = min(_intro_weight + delta * 0.45, 1.0)
	var camera_pos := _anchor_camera
	if camera != null:
		camera_pos = camera.global_position
	var drift := camera_pos - _anchor_camera
	var intro_shift := (1.0 - _intro_weight) * 24.0
	if not enable_background_motion:
		drift = Vector2.ZERO
		intro_shift = 0.0

	_update_sprite("sky", sky, drift, 0.018 if enable_background_motion else 0.0, Vector2(sin(_time_sec * 0.11) * 14.0, cos(_time_sec * 0.09) * 7.0 - intro_shift * 0.35) if enable_background_motion else Vector2.ZERO)
	_update_sprite("bg3", bg3, drift, 0.032 if enable_background_motion else 0.0, Vector2(cos(_time_sec * 0.17) * 10.0, sin(_time_sec * 0.13) * 5.0 - intro_shift * 0.6) if enable_background_motion else Vector2.ZERO)
	_update_sprite("bg2", bg2, drift, 0.05 if enable_background_motion else 0.0, Vector2(sin(_time_sec * 0.21) * 7.0, cos(_time_sec * 0.16) * 4.0 - intro_shift * 0.85) if enable_background_motion else Vector2.ZERO)
	_update_sprite("bg1", bg1, drift, 0.08 if enable_background_motion else 0.0, Vector2(cos(_time_sec * 0.12) * 4.0, -intro_shift) if enable_background_motion else Vector2.ZERO)
	_update_sprite("front", map_front, Vector2.ZERO, 0.0, Vector2.ZERO)

	_update_layer_modulates()

	_update_material_time(sky)
	_update_overlay_material(atmosphere_overlay)
	_update_overlay_material(vignette_overlay, "pulse_sec")

	if atmosphere_overlay != null:
		var atmosphere_color := atmosphere_overlay.modulate
		atmosphere_color.a = lerpf(0.0, 1.0, _intro_weight)
		atmosphere_overlay.modulate = atmosphere_color
	if vignette_overlay != null:
		var vignette_color := vignette_overlay.modulate
		vignette_color.a = lerpf(0.0, 1.0, min(_intro_weight * 1.2, 1.0))
		vignette_overlay.modulate = vignette_color

func _capture_base(key: String, sprite: Sprite2D) -> void:
	if sprite == null:
		return
	_base_positions[key] = sprite.position

func _update_sprite(key: String, sprite: Sprite2D, drift: Vector2, parallax: float, ambient_shift: Vector2) -> void:
	if sprite == null or not _base_positions.has(key):
		return
	var base := _base_positions[key] as Vector2
	sprite.position = base + drift * parallax + ambient_shift

func _update_material_time(canvas_item: CanvasItem, parameter_name: String = "time_sec") -> void:
	if canvas_item == null:
		return
	var material := canvas_item.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter(parameter_name, _time_sec)

func _update_overlay_material(rect: ColorRect, parameter_name: String = "time_sec") -> void:
	if rect == null:
		return
	var material := rect.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter(parameter_name, _time_sec)

func _update_layer_modulates() -> void:
	if sky != null:
		var sky_pulse := 0.92 + 0.08 * sin(_time_sec * 0.18)
		sky.modulate = Color(0.72 * sky_pulse, 0.95 * sky_pulse, 1.02, 1.0)
	if bg2 != null:
		var bg2_color := bg2.modulate
		bg2_color.a = 0.4 + 0.06 * sin(_time_sec * 0.33)
		bg2.modulate = bg2_color
	if bg3 != null:
		var bg3_color := bg3.modulate
		bg3_color.a = 0.16 + 0.05 * cos(_time_sec * 0.27)
		bg3.modulate = bg3_color
	if map_front != null:
		var front_pulse := 0.94 + 0.04 * sin(_time_sec * 0.52)
		map_front.modulate = Color(front_pulse, front_pulse + 0.015, 1.0, 0.93 + 0.03 * sin(_time_sec * 0.41))
