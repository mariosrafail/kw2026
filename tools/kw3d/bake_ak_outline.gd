extends SceneTree
func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/prototypes/ak47_outline/hull.json"))
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for v in data.vertices: vertices.append(Vector3(v[0],v[1],v[2]))
	for n in data.normals: normals.append(Vector3(n[0],n[1],n[2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(data.indices)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	assert(ResourceSaver.save(mesh,"res://assets/prototypes/ak47_outline/hull.res")==OK)
	print("AK_OUTLINE_BAKE_PASS")
	quit(0)
