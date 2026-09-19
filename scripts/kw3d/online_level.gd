extends RefCounted
const FILE := "res://assets/kw3d/arena_seed.json"
static func vec(a: Array) -> Vector3:
	return Vector3(float(a[0]),float(a[1]),float(a[2]))
static func read() -> Dictionary:
	var result: Variant=JSON.parse_string(FileAccess.get_file_as_string(FILE))
	assert(result is Dictionary and result.get("schema")==1,"Invalid built-in arena manifest")
	return result
static func fingerprint() -> String:
	return FileAccess.get_sha256(FILE)
static func build_physics(parent: Node3D, data: Dictionary) -> void:
	for entry in data.world:
		var body =StaticBody3D.new()
		body.name=entry.id
		body.collision_layer=1
		body.collision_mask=0
		parent.add_child(body)
		body.position=vec(entry.p)
		body.rotation=vec(entry.r)
		var collider =CollisionShape3D.new()
		if entry.kind=="box":
			var shape =BoxShape3D.new();shape.size=vec(entry.s);collider.shape=shape
		else:
			var shape =CylinderShape3D.new();shape.height=entry.height;shape.radius=entry.radius;collider.shape=shape
		collider.position=vec(entry.local_p)
		body.add_child(collider)
