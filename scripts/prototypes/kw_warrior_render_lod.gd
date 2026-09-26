extends RefCounted
## Conservative render-only LOD for voxel warriors. Never changes gameplay collision,
## rig transforms or visible near-field geometry.
const HAND_STYLE:=preload("res://scripts/prototypes/warrior_hand_style.gd")

const OUTLINE_RANGE:=48.0
const OUTLINE_MARGIN:=6.0
const MICRO_RANGE:=42.0
const MICRO_MARGIN:=5.0
const MICRO_VOLUME:=0.040

static func apply(model: Node3D) -> Dictionary:
	var result:={"visible":0,"outlines":0,"micro":0,"shadow_disabled":0}
	if model==null:return result
	for raw in model.find_children("*","MeshInstance3D",true,false):
		var mesh:=raw as MeshInstance3D
		if mesh==null or not mesh.visible:continue
		result.visible+=1
		var name:=str(mesh.name)
		if "Outline" in name:
			mesh.visibility_range_end=OUTLINE_RANGE
			mesh.visibility_range_end_margin=OUTLINE_MARGIN
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			result.outlines+=1
			continue
		if mesh.mesh==null:continue
		var size:=mesh.mesh.get_aabb().size
		var volume:=absf(size.x*size.y*size.z)
		if volume>=MICRO_VOLUME:continue
		result.micro+=1
		mesh.set_meta("kw_damage_skip",true)
		# Micro details remain visible nearby, but beyond this point they are only a
		# few pixels and cost a full draw call each.
		mesh.visibility_range_end=MICRO_RANGE
		mesh.visibility_range_end_margin=MICRO_MARGIN
		if not _keep_micro_shadow(name):
			if mesh.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				result.shadow_disabled+=1
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	HAND_STYLE.batch_hands(model)
	_batch_micro_details(model)
	sync_batches(model)
	model.set_meta("kw_render_lod_applied",true)
	return result

static func _batch_micro_details(model: Node3D) -> void:
	for rig_name in ["HeadRig","TorsoRig"]:
		var rig:=model.get_node_or_null(rig_name) as Node3D
		if rig==null:continue
		var groups: Dictionary={}
		var candidates: Array[MeshInstance3D]=[]
		for child in rig.get_children():
			var mesh:=child as MeshInstance3D
			if mesh==null or not mesh.visible or not bool(mesh.get_meta("kw_damage_skip",false)):continue
			if not mesh.mesh is BoxMesh or str(mesh.name).begins_with("Claw_"):continue
			candidates.append(mesh)
			var key:=_material_key(mesh)
			if not groups.has(key):groups[key]=[]
			(groups[key] as Array).append(mesh)
		var serial:=0
		for key in groups:
			var parts:=groups[key] as Array
			if parts.size()<2:continue
			var first:=parts[0] as MeshInstance3D
			var cube:=BoxMesh.new();cube.size=Vector3.ONE;cube.material=first.material_override
			var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=cube;mm.instance_count=parts.size()
			for index in range(parts.size()):
				var part:=parts[index] as MeshInstance3D
				var box:=part.mesh as BoxMesh
				mm.set_instance_transform(index,part.transform*Transform3D(Basis.from_scale(box.size),Vector3.ZERO))
				part.visible=false
			var batch:=MultiMeshInstance3D.new();batch.name="MicroBatch_%s_%02d"%[rig_name,serial];serial+=1
			batch.multimesh=mm;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.visibility_range_end=MICRO_RANGE;batch.visibility_range_end_margin=MICRO_MARGIN
			batch.set_meta("kw_micro_batch",true);batch.set_meta("kw_batch_material_source",str(first.name))
			rig.add_child(batch)
		var outlined: Array[Dictionary]=[]
		for part in candidates:
			var outline:=part.get_node_or_null("WorldInkOutline") as MeshInstance3D
			if outline!=null and outline.mesh!=null:
				outlined.append({"part":part,"outline":outline})
		if not outlined.is_empty():
			var first_pair: Dictionary=outlined[0]
			var first_part:=first_pair.part as MeshInstance3D
			var first_outline:=first_pair.outline as MeshInstance3D
			var first_size: Vector3=(first_part.mesh as BoxMesh).size
			var outline_mm:=MultiMesh.new();outline_mm.transform_format=MultiMesh.TRANSFORM_3D;outline_mm.mesh=first_outline.mesh;outline_mm.instance_count=outlined.size()
			for index in range(outlined.size()):
				var pair: Dictionary=outlined[index]
				var part:=pair.part as MeshInstance3D
				var outline:=pair.outline as MeshInstance3D
				var size: Vector3=(part.mesh as BoxMesh).size
				var ratio:=Vector3(size.x/maxf(0.0001,first_size.x),size.y/maxf(0.0001,first_size.y),size.z/maxf(0.0001,first_size.z))
				outline_mm.set_instance_transform(index,part.transform*outline.transform*Transform3D(Basis.from_scale(ratio),Vector3.ZERO))
				outline.visible=false
				if outline.is_in_group("kw_world_ink"):outline.remove_from_group("kw_world_ink")
			var outline_batch:=MultiMeshInstance3D.new();outline_batch.name="MicroInkBatch_%s"%rig_name;outline_batch.multimesh=outline_mm
			outline_batch.material_override=first_outline.material_override;outline_batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			outline_batch.visibility_range_end=MICRO_RANGE;outline_batch.visibility_range_end_margin=MICRO_MARGIN
			outline_batch.visible=first_outline.visible;outline_batch.add_to_group("kw_world_ink");rig.add_child(outline_batch)

static func _material_key(mesh: MeshInstance3D) -> String:
	var material:=mesh.material_override
	if material is ShaderMaterial:
		var shader_material:=material as ShaderMaterial
		var color: Variant=shader_material.get_shader_parameter("base_color")
		var texture: Variant=shader_material.get_shader_parameter("albedo_texture")
		var texture_id:=str((texture as Resource).get_rid().get_id()) if texture is Resource else "none"
		return "shader:%s:%s:%s"%[shader_material.shader.get_rid().get_id() if shader_material.shader!=null else 0,str(color),texture_id]
	if material is StandardMaterial3D:
		var standard:=material as StandardMaterial3D
		var texture_id:=str(standard.albedo_texture.get_rid().get_id()) if standard.albedo_texture!=null else "none"
		return "standard:%s:%s:%.3f:%.3f"%[standard.albedo_color.to_html(true),texture_id,standard.metallic,standard.roughness]
	return str(material)

static func sync_batches(model: Node3D) -> void:
	if model==null:return
	HAND_STYLE.batch_hands(model)
	for raw in model.find_children("*","MultiMeshInstance3D",true,false):
		var batch:=raw as MultiMeshInstance3D
		if batch==null or not batch.has_meta("kw_batch_material_source"):continue
		var parent:=batch.get_parent() as Node3D
		if parent==null:continue
		var source:=parent.get_node_or_null(str(batch.get_meta("kw_batch_material_source"))) as MeshInstance3D
		if source==null or batch.multimesh==null or not batch.multimesh.mesh is BoxMesh:continue
		(batch.multimesh.mesh as BoxMesh).material=source.material_override

static func _keep_micro_shadow(name: String) -> bool:
	# Aevilok's wings are assembled from thin boxes. Keep a small representative
	# shadow silhouette while removing shadow passes from decorative stripes/tips.
	if name.begins_with("AevilokWing"):
		return "MembraneMid" in name or "MembraneOuter" in name or "LowerFrame" in name
	return false
