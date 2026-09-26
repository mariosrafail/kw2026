extends RefCounted
## Shared detached blocky claw hands for every 3D warrior.
## Hands are visual-only and are posed onto weapon grips by the player/replica code.


static func ensure_hands(model: Node3D) -> void:
	if model == null:
		return
	if model.get_node_or_null("LeftHandRig") != null and model.get_node_or_null("RightHandRig") != null:
		return
	var torso_mesh := model.get_node_or_null("TorsoRig/Torso_Upper") as MeshInstance3D
	if torso_mesh == null:
		return
	var left_hand := _build_hand_rig(model, "Left", torso_mesh)
	left_hand.position = Vector3(-0.68, -0.72, -0.02)
	var right_hand := _build_hand_rig(model, "Right", torso_mesh)
	right_hand.position = Vector3(0.68, -0.72, -0.02)


static func _build_hand_rig(model: Node3D, side_name: String, source_mesh: MeshInstance3D) -> Node3D:
	var rig := Node3D.new()
	rig.name = "%sHandRig" % side_name
	model.add_child(rig)
	# Same upside-down LEGO-style claw used by Outrage: bridge on top,
	# centred top pixel, and two long prongs with an open gap underneath.
	_add_hand_box(rig, "Claw_%s_Bridge" % side_name, Vector3(0.0, 0.115, 0.0), Vector3(0.30, 0.10, 0.20), source_mesh)
	_add_hand_box(rig, "Claw_%s_TopPixel" % side_name, Vector3(0.0, 0.215, 0.0), Vector3(0.10, 0.10, 0.20), source_mesh)
	_add_hand_box(rig, "Claw_%s_LeftProng" % side_name, Vector3(-0.10, -0.050, 0.0), Vector3(0.10, 0.23, 0.20), source_mesh)
	_add_hand_box(rig, "Claw_%s_RightProng" % side_name, Vector3(0.10, -0.050, 0.0), Vector3(0.10, 0.23, 0.20), source_mesh)
	return rig


static func batch_hands(model: Node3D) -> void:
	if model == null:
		return
	for side_name in ["Left", "Right"]:
		var rig := model.get_node_or_null("%sHandRig" % side_name) as Node3D
		if rig != null:
			_batch_hand_rig(rig, side_name)


static func _batch_hand_rig(rig: Node3D, side_name: String) -> void:
	var parts: Array[MeshInstance3D] = []
	for child in rig.get_children():
		if child is MeshInstance3D and str(child.name).begins_with("Claw_"):
			parts.append(child as MeshInstance3D)
	if parts.is_empty():
		return
	var first := parts[0]
	var batch := rig.get_node_or_null("Claw_%s_Batch" % side_name) as MultiMeshInstance3D
	var multimesh: MultiMesh
	if batch == null:
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE
		cube.material = first.material_override
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = cube
		multimesh.instance_count = parts.size()
		batch = MultiMeshInstance3D.new()
		batch.name = "Claw_%s_Batch" % side_name
		batch.multimesh = multimesh
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.visibility_range_end = 48.0
		batch.visibility_range_end_margin = 6.0
		batch.set_meta("kw_batch_material_source",str(first.name))
		rig.add_child(batch)
	else:
		multimesh = batch.multimesh
		batch.set_meta("kw_batch_material_source",str(first.name))
		if multimesh.mesh is BoxMesh:
			(multimesh.mesh as BoxMesh).material = first.material_override
	for index in range(parts.size()):
		var part := parts[index]
		var size := part.mesh.get_aabb().size
		multimesh.set_instance_transform(index, part.transform * Transform3D(Basis.from_scale(size), Vector3.ZERO))
		part.visible = false


static func _add_hand_box(parent: Node3D, part_name: String, pos: Vector3, size: Vector3, source_mesh: MeshInstance3D) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = part_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var source_plain: StandardMaterial3D = null
	if source_mesh.has_meta("plain_material") and source_mesh.get_meta("plain_material") is StandardMaterial3D:
		source_plain = source_mesh.get_meta("plain_material") as StandardMaterial3D
	elif source_mesh.material_override is StandardMaterial3D:
		source_plain = source_mesh.material_override as StandardMaterial3D
	if source_plain != null:
		var plain := source_plain.duplicate(true) as StandardMaterial3D
		plain.resource_local_to_scene = true
		mesh.set_meta("plain_material", plain)
		mesh.material_override = plain
	var source_toon: ShaderMaterial = null
	if source_mesh.has_meta("toon_material") and source_mesh.get_meta("toon_material") is ShaderMaterial:
		source_toon = source_mesh.get_meta("toon_material") as ShaderMaterial
	if source_toon != null:
		var toon := source_toon.duplicate(true) as ShaderMaterial
		toon.resource_local_to_scene = true
		mesh.set_meta("toon_material", toon)
		mesh.material_override = toon
	parent.add_child(mesh)
	return mesh
