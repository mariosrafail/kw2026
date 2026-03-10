extends Area2D

class_name GroundAudioZone

@export_enum("wood", "grass") var surface_id := "grass"
@export var surface_priority := 0

func _ready() -> void:
	add_to_group("ground_audio_zones")
	monitoring = true
	monitorable = true
	collision_layer = 0
	if collision_mask == 1:
		collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func get_surface_id() -> String:
	return str(surface_id).strip_edges().to_lower()

func get_surface_priority() -> int:
	return surface_priority

func contains_world_point(world_point: Vector2) -> bool:
	for child in get_children():
		var polygon := child as CollisionPolygon2D
		if polygon == null or polygon.polygon.is_empty():
			continue
		if Geometry2D.is_point_in_polygon(polygon.to_local(world_point), polygon.polygon):
			return true
	return false

func _on_body_entered(body: Node) -> void:
	if body != null and body.has_method("register_ground_audio_zone"):
		body.call("register_ground_audio_zone", self)

func _on_body_exited(body: Node) -> void:
	if body != null and body.has_method("unregister_ground_audio_zone"):
		body.call("unregister_ground_audio_zone", self)
