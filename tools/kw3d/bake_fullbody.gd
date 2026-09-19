extends SceneTree
## Bake approved source geometry, UVs and animation pivots. No redesign.
const ASSET := "res://assets/prototypes/outrage_fullbody/"
const TOON := preload("res://scripts/prototypes/kw_comic_toon.gdshader")
const INK := preload("res://scripts/prototypes/kw_comic_ink.gdshader")
const STYLE := preload("res://scripts/prototypes/kw_character_style.gd")
var plain_materials: Array[StandardMaterial3D] = []
var toon_materials: Array[ShaderMaterial] = []
var unit := 0.07

func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ASSET + "build_data.json"))
	unit = float(data["scale"])
	for tex in data["textures"]:
		var image := Image.load_from_file(ASSET + str(tex["path"]))
		assert(image != null and not image.is_empty())
		var texture := ImageTexture.create_from_image(image)
		var plain := StandardMaterial3D.new()
		plain.albedo_texture = texture
		plain.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		plain.roughness = 0.9
		plain_materials.append(plain)
		var toon := ShaderMaterial.new()
		toon.shader = TOON
		toon.set_shader_parameter("base_color", Color.WHITE)
		toon.set_shader_parameter("use_texture", true)
		toon.set_shader_parameter("albedo_texture", texture)
		toon_materials.append(toon)
	var model := Node3D.new()
	model.name = "OutrageFullBody"
	model.set_meta("source_sha256", data["sha256"])
	model.set_meta("source_path", data["source"])
	model.set_meta("source_blocks", data["part_count"])
	model.set_meta("capsule_height", data["capsule_height"])
	var count := 0
	for rd in data["rigs"]:
		var rig := Node3D.new()
		rig.name = rd["name"]
		rig.position = v3(rd["rest"])
		model.add_child(rig)
		rig.owner = model
		for item in rd["parts"]:
			var mesh := make_part(item, v3(rd["pivot"]), data["textures"])
			rig.add_child(mesh)
			mesh.owner = model
			count += 1
	assert(count == int(data["part_count"]))
	# Export the actual colored model, without outline hulls.
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	assert(gltf.append_from_scene(model, state) == OK)
	assert(gltf.write_to_filesystem(state, ASSET + "outrage_fullbody.glb") == OK)
	for rd in data["rigs"]:
		var hull := make_hull(rd["outline"])
		var ink := MeshInstance3D.new()
		ink.name = "ShaderInkOutline"
		ink.mesh = hull
		ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ink.extra_cull_margin = 0.2
		var material := ShaderMaterial.new()
		material.shader = INK
		ink.material_override = material
		model.get_node(NodePath(rd["name"])).add_child(ink)
		ink.owner = model
	model.set_script(STYLE)
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	DirAccess.make_dir_recursive_absolute("res://scenes/prototypes/characters")
	assert(ResourceSaver.save(packed, "res://scenes/prototypes/characters/outrage_fullbody.tscn") == OK)
	print("FULLBODY_BAKE_PASS blocks=", count, " source=", data["sha256"])
	model.free()
	quit(0)

func make_part(item: Dictionary, pivot: Vector3, textures: Array) -> MeshInstance3D:
	var lo := v3(item["from"])
	var hi := v3(item["to"])
	var center := (lo + hi) * 0.5
	var half := (hi - lo) * unit * 0.5
	var part := MeshInstance3D.new()
	part.name = item["name"]
	part.position = (center - pivot) * unit
	part.set_meta("bb_from", lo)
	part.set_meta("bb_to", hi)
	part.set_meta("bb_uuid", item["uuid"])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [
		["north",Vector3.FORWARD,Vector3.LEFT,Vector3.DOWN],
		["south",Vector3.BACK,Vector3.RIGHT,Vector3.DOWN],
		["west",Vector3.LEFT,Vector3.BACK,Vector3.DOWN],
		["east",Vector3.RIGHT,Vector3.FORWARD,Vector3.DOWN],
		["up",Vector3.UP,Vector3.RIGHT,Vector3.BACK],
		["down",Vector3.DOWN,Vector3.RIGHT,Vector3.FORWARD]]
	var texture_id := -1
	for info in faces:
		var face: Dictionary = item["faces"][info[0]]
		var next_id := int(face["texture"])
		assert(texture_id == -1 or texture_id == next_id, "Multi-texture cube needs exporter extension")
		texture_id = next_id
		var tex: Dictionary = textures[texture_id]
		var tex_size := Vector2(float(tex["width"]), float(tex["height"]))
		var uv: Array = face["uv"]
		var uv_points := [Vector2(uv[0],uv[1]),Vector2(uv[2],uv[1]),Vector2(uv[2],uv[3]),Vector2(uv[0],uv[3])]
		var normal: Vector3 = info[1]
		var right: Vector3 = info[2]
		var down: Vector3 = info[3]
		var p := (normal - right - down) * half
		var vertices := [p, p+right*half*2.0, p+(right+down)*half*2.0, p+down*half*2.0]
		for idx in [0,1,2,0,2,3]:
			surface.set_normal(normal)
			surface.set_uv(uv_points[idx] / tex_size)
			surface.add_vertex(vertices[idx])
	surface.index()
	part.mesh = surface.commit()
	part.material_override = plain_materials[texture_id]
	part.set_meta("plain_material", plain_materials[texture_id])
	part.set_meta("toon_material", toon_materials[texture_id])
	return part

func make_hull(data: Dictionary) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for v in data["vertices"]: vertices.append(v3(v))
	for n in data["normals"]: normals.append(v3(n))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(data["indices"])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func v3(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))
