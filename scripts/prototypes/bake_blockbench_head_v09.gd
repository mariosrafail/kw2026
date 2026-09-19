extends SceneTree
## Explicit offline bake: preserves all 17 approved v09 boxes and source colors.
const ASSET := "res://assets/prototypes/outrage_head_v09/"

func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ASSET + "head_v09_data.json"))
	var unit := float(data["scale"])
	var pivot := Vector3(0, 6, 0)
	var model := Node3D.new()
	model.name = "OutrageHeadV09"
	model.position.y = -0.10
	model.set_meta("source_sha256", data["sha256"])
	model.set_meta("source_blocks", 17)
	var materials: Dictionary = {}
	for item in data["parts"]:
		var color_key := str(item["color"])
		if not materials.has(color_key):
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(color_key)
			material.roughness = 0.9
			materials[color_key] = material
		var lo := _v3(item["from"])
		var hi := _v3(item["to"])
		var part := MeshInstance3D.new()
		part.name = item["name"]
		var box := BoxMesh.new()
		box.size = (hi - lo) * unit
		part.mesh = box
		part.position = ((lo + hi) * 0.5 - pivot) * unit
		part.material_override = materials[color_key]
		model.add_child(part)
		part.owner = model
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/prototypes/outrage_head_v09.tscn") == OK)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for v in data["outline_vertices"]:
		vertices.append((_v3(v) - pivot) * unit)
	for n in data["outline_normals"]:
		normals.append(_v3(n))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(data["outline_indices"])
	var hull := ArrayMesh.new()
	hull.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	assert(ResourceSaver.save(hull, ASSET + "outline_hull.res") == OK)
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	assert(gltf.append_from_scene(model, state) == OK)
	assert(gltf.write_to_filesystem(state, ASSET + "outrage_head_v09.glb") == OK)
	print("V09_BAKE_PASS blocks=", model.get_child_count(), " source=", data["sha256"])
	model.free()
	quit(0)

func _v3(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
