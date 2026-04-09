extends Node2D

@export var wall_size: Vector2 = Vector2(260.0, 56.0):
	set(value):
		wall_size = Vector2(max(value.x, 8.0), max(value.y, 8.0))
		_apply_shape()

@export var wall_color: Color = Color(0.17, 0.2, 0.28, 1.0):
	set(value):
		wall_color = value
		_apply_shape()

@export_range(1, 20, 1) var occluder_light_mask: int = 1:
	set(value):
		occluder_light_mask = value
		_apply_shape()

@onready var _wall_visual: Polygon2D = $WallVisual
@onready var _wall_occluder: LightOccluder2D = $LightOccluder2D


func _ready() -> void:
	_apply_shape()


func _apply_shape() -> void:
	var half_size := wall_size * 0.5
	var points := PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])

	if is_instance_valid(_wall_visual):
		_wall_visual.polygon = points
		_wall_visual.color = wall_color

	if is_instance_valid(_wall_occluder):
		if _wall_occluder.occluder == null:
			_wall_occluder.occluder = OccluderPolygon2D.new()
		_wall_occluder.occluder.polygon = points
		_wall_occluder.occluder_light_mask = occluder_light_mask
