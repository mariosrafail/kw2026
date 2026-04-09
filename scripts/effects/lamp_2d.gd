@tool
extends Node2D

@export var light_color: Color = Color(1.0, 0.82, 0.55, 1.0):
	set(value):
		light_color = value
		_apply_light_settings()

@export_range(0.0, 8.0, 0.05) var light_energy: float = 1.35:
	set(value):
		light_energy = value
		_apply_light_settings()

@export_range(0.25, 8.0, 0.05) var light_range: float = 2.0:
	set(value):
		light_range = value
		_apply_light_settings()

@export_range(0.1, 4.0, 0.05) var texture_scale: float = 1.0:
	set(value):
		texture_scale = value
		_apply_light_settings()

@export var shadows_enabled: bool = true:
	set(value):
		shadows_enabled = value
		_apply_light_settings()

@export_range(-4096, 4096, 1) var light_z_min: int = -1024:
	set(value):
		light_z_min = value
		_apply_light_settings()

@export_range(-4096, 4096, 1) var light_z_max: int = 1024:
	set(value):
		light_z_max = value
		_apply_light_settings()

@onready var _lamp_sprite: Sprite2D = $LampSprite
@onready var _point_light: PointLight2D = $PointLight2D
@onready var _lamp_box: Polygon2D = get_node_or_null("LampBox")

func _ready() -> void:
	_apply_light_settings()


func _apply_light_settings() -> void:
	if not is_instance_valid(_point_light):
		return

	_point_light.color = light_color
	_point_light.energy = light_energy
	_point_light.texture_scale = light_range * texture_scale
	_point_light.shadow_enabled = shadows_enabled
	_point_light.range_z_min = light_z_min
	_point_light.range_z_max = light_z_max

	if is_instance_valid(_lamp_sprite):
		_lamp_sprite.modulate = light_color.lerp(Color.WHITE, 0.45)
	if is_instance_valid(_lamp_box):
		_lamp_box.color = light_color
