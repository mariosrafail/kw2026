extends RefCounted
## Cached silhouette shells. The visible low-poly mesh is never smoothed or changed.
const INK := preload("res://scripts/prototypes/kw_comic_ink.gdshader")
static var cache: Dictionary = {}

static func add_to(mesh: MeshInstance3D, enabled: bool, width: float = 2.5) -> MeshInstance3D:
	if mesh.mesh == null: return null
	var existing := mesh.get_node_or_null("WorldInkOutline") as MeshInstance3D
	if existing != null:
		existing.visible = enabled
		return existing
	var id := mesh.mesh.get_rid().get_id()
	if not cache.has(id):
		if cache.size() > 256: cache.clear()
		cache[id] = _smooth(mesh.mesh)
	var shell := MeshInstance3D.new()
	shell.name = "WorldInkOutline"
	shell.mesh = cache[id]
	var material := ShaderMaterial.new()
	material.shader = INK
	material.set_shader_parameter("width_pixels", width)
	shell.material_override = material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.extra_cull_margin = 0.2
	shell.visible = enabled
	mesh.add_child(shell)
	shell.add_to_group("kw_world_ink")
	return shell

static func _smooth(source: Mesh) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface in range(source.get_surface_count()):
		var arrays := source.surface_get_arrays(surface)
		if arrays.is_empty(): continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if normals.size() != vertices.size(): continue
		var sums: Dictionary = {}
		for i in range(vertices.size()):
			var key := vertices[i].snapped(Vector3.ONE*0.00001)
			if not sums.has(key): sums[key] = []
			var bucket: Array = sums[key]
			if not bucket.has(normals[i]): bucket.append(normals[i])
		for i in range(normals.size()):
			var total := Vector3.ZERO
			for normal in sums[vertices[i].snapped(Vector3.ONE*0.00001)]: total += normal
			normals[i] = total.normalized() if total.length_squared()>0.00001 else normals[i]
		arrays[Mesh.ARRAY_NORMAL] = normals
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
