extends Node
## Reversible visual voxel damage on the ORIGINAL character meshes.
## Cells are logical only; no visible cube grid and no per-cell physics bodies.
const PIXEL_MATERIALS := preload("res://scripts/prototypes/kw_pixel_materials.gd")
const TOON_SHADER := preload("res://scripts/prototypes/kw_comic_toon.gdshader")
const CELL_TARGET := 0.14
const MAX_HIDDEN_ABS := 96
const MAX_HIDDEN_RATIO := 0.26
const MAX_REMOVE_PER_DAMAGE_EVENT := 10
const MAX_SHADER_CELLS := 32
const DEBRIS_PER_HIT := 2
const MAX_DEBRIS_ACTIVE := 12
const RESTORE_INTERVAL := 0.035

static var debris_material_cache: Dictionary = {}
static var shared_box: BoxMesh

var visual_root: Node3D
var records: Array[Dictionary] = []
var rig_outlines: Dictionary = {}
var cells: Array[Dictionary] = []
var hidden_order: Array[int] = []
var debris: Array[Dictionary] = []
var hidden_count := 0
var max_hidden := 0
var desired_hidden := 0
var current_health := 100.0
var maximum_health := 100.0
var restore_clock := 0.0
var flash_strength := 0.0
var flash_records: Dictionary={}
var comic_enabled := true
var pixel_enabled := false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("kw_damage_visual")
	set_process(false)
func setup(root_visual: Node3D, rig_names: Array = ["HeadRig","TorsoRig","LeftLegRig","RightLegRig"], seed: int = 137) -> void:
	visual_root=root_visual
	rng.seed=seed
	if shared_box==null:
		shared_box=BoxMesh.new()
		shared_box.size=Vector3.ONE
	for rig_name in rig_names:
		var rig:=root_visual.get_node_or_null(rig_name) as Node3D
		if rig!=null:_register_rig(rig)
	max_hidden=mini(MAX_HIDDEN_ABS,maxi(12,int(round(float(cells.size())*MAX_HIDDEN_RATIO))))
	current_health=maximum_health
	desired_hidden=0
	_apply_style()
	set_process(false)

func _register_rig(rig: Node3D) -> void:
	var rig_outline:=rig.get_node_or_null("ShaderInkOutline") as MeshInstance3D
	if rig_outline!=null:
		var mat:=_ensure_outline_material(rig_outline)
		rig_outlines[rig.get_instance_id()]={"rig":rig,"outline":rig_outline,"material":mat}
	for child in rig.get_children():
		if not child is MeshInstance3D:continue
		var mesh:=child as MeshInstance3D
		if mesh.name in ["ShaderInkOutline","WorldInkOutline"]:continue
		if mesh.mesh==null:continue
		_register_mesh(mesh)

func _register_mesh(mesh: MeshInstance3D) -> void:
	var plain:=_plain_material_for(mesh)
	var toon:=_toon_material_for(mesh,plain)
	var pixel:=_pixel_material_for(mesh,plain)
	var record_index:=records.size()
	var part_outline:=mesh.get_node_or_null("WorldInkOutline") as MeshInstance3D
	var outline_material: ShaderMaterial=_ensure_outline_material(part_outline) if part_outline!=null else null
	var record: Dictionary={
		"mesh":mesh,"plain":plain,"toon":toon,"pixel":pixel,"outline":part_outline,"outline_material":outline_material,
		"hidden_indices":[] as Array[int]
	}
	records.append(record)
	mesh.visible=true
	mesh.set_meta("plain_material",plain)
	mesh.set_meta("toon_material",toon)
	mesh.set_meta("pixel_material",pixel)
	_append_logical_cells(mesh,record_index)
	_sync_record(record_index)

func _append_logical_cells(mesh: MeshInstance3D,record_index: int) -> void:
	var aabb:=mesh.mesh.get_aabb()
	var counts:=Vector3i(_axis_count(aabb.size.x),_axis_count(aabb.size.y),_axis_count(aabb.size.z))
	var cell_size:=Vector3(aabb.size.x/float(counts.x),aabb.size.y/float(counts.y),aabb.size.z/float(counts.z))
	var half_extent:=maxf(cell_size.x,maxf(cell_size.y,cell_size.z))*0.52
	var color:=_source_color(mesh)
	for x in range(counts.x):
		for y in range(counts.y):
			for z in range(counts.z):
				var p:=aabb.position+Vector3((x+0.5)*cell_size.x,(y+0.5)*cell_size.y,(z+0.5)*cell_size.z)
				var rig:=mesh.get_parent() as Node3D
				var rig_local: Vector3=mesh.transform*p if rig!=null else p
				cells.append({"record":record_index,"mesh":mesh,"rig":rig,"local":p,"rig_local":rig_local,"half":half_extent,"color":color,"hidden":false})

func _axis_count(length: float) -> int:
	return maxi(1,int(round(length/CELL_TARGET)))

func _ensure_outline_material(outline: MeshInstance3D) -> ShaderMaterial:
	if outline==null or not outline.material_override is ShaderMaterial:return null
	if not outline.has_meta("damage_outline_material"):
		var copy: ShaderMaterial=(outline.material_override as ShaderMaterial).duplicate(true)
		outline.material_override=copy
		outline.set_meta("damage_outline_material",copy)
	return outline.get_meta("damage_outline_material") as ShaderMaterial
func _plain_material_for(mesh: MeshInstance3D) -> StandardMaterial3D:
	if mesh.has_meta("plain_material") and mesh.get_meta("plain_material") is StandardMaterial3D:
		return (mesh.get_meta("plain_material") as StandardMaterial3D).duplicate(true)
	if mesh.material_override is StandardMaterial3D:
		return (mesh.material_override as StandardMaterial3D).duplicate(true)
	var plain:=StandardMaterial3D.new()
	plain.albedo_color=Color.WHITE
	plain.roughness=0.95
	if mesh.material_override is ShaderMaterial:
		var sm:=mesh.material_override as ShaderMaterial
		var base=sm.get_shader_parameter("base_color")
		if base is Color:plain.albedo_color=base
		var tex=sm.get_shader_parameter("albedo_texture")
		if tex is Texture2D:plain.albedo_texture=tex
	return plain

func _toon_material_for(mesh: MeshInstance3D,plain: StandardMaterial3D) -> ShaderMaterial:
	var source: ShaderMaterial
	if mesh.has_meta("toon_material") and mesh.get_meta("toon_material") is ShaderMaterial:
		source=mesh.get_meta("toon_material") as ShaderMaterial
	elif mesh.material_override is ShaderMaterial:
		source=mesh.material_override as ShaderMaterial
	if source!=null and source.shader!=null and source.shader.resource_path.ends_with("kw_comic_toon.gdshader"):
		return source.duplicate(true)
	var mat:=ShaderMaterial.new()
	mat.shader=TOON_SHADER
	mat.set_shader_parameter("base_color",plain.albedo_color)
	mat.set_shader_parameter("use_texture",plain.albedo_texture!=null)
	if plain.albedo_texture!=null:mat.set_shader_parameter("albedo_texture",plain.albedo_texture)
	mat.set_shader_parameter("pixel_enabled",pixel_enabled)
	return mat

func _pixel_material_for(mesh: MeshInstance3D,plain: StandardMaterial3D) -> ShaderMaterial:
	if mesh.has_meta("pixel_material") and mesh.get_meta("pixel_material") is ShaderMaterial:
		return (mesh.get_meta("pixel_material") as ShaderMaterial).duplicate(true)
	return PIXEL_MATERIALS.from_standard(plain)

func _source_color(mesh: MeshInstance3D) -> Color:
	var plain:=_plain_material_for(mesh)
	if plain.albedo_texture==null:return plain.albedo_color
	var image:=plain.albedo_texture.get_image()
	if image==null or image.is_empty():return plain.albedo_color
	var sum:=Vector3.ZERO
	var count:=0
	for y in range(0,image.get_height(),maxi(1,image.get_height()/8)):
		for x in range(0,image.get_width(),maxi(1,image.get_width()/8)):
			var c:=image.get_pixel(x,y)
			if c.a<0.08:continue
			sum+=Vector3(c.r,c.g,c.b);count+=1
	if count==0:return plain.albedo_color
	var sampled:=Color(sum.x/count,sum.y/count,sum.z/count,1.0)
	return plain.albedo_color*sampled
func set_pixel_enabled(value: bool) -> void:
	pixel_enabled=value
	for record in records:
		(record.toon as ShaderMaterial).set_shader_parameter("pixel_enabled",value)
		(record.pixel as ShaderMaterial).set_shader_parameter("pixel_enabled",value)
	_apply_style()

func set_comic_enabled(value: bool) -> void:
	comic_enabled=value
	_apply_style()

func _apply_style() -> void:
	for record in records:
		var mesh:=record.mesh as MeshInstance3D
		if not is_instance_valid(mesh):continue
		mesh.visible=true
		if comic_enabled:
			mesh.material_override=record.toon
		else:
			var px:=record.pixel as ShaderMaterial
			px.set_shader_parameter("pixel_enabled",pixel_enabled)
			mesh.material_override=px
		_sync_material(record.toon,record)
		_sync_material(record.pixel,record)

func _sync_record(record_index: int) -> void:
	if record_index<0 or record_index>=records.size():return
	var record: Dictionary=records[record_index]
	_sync_material(record.toon,record)
	_sync_material(record.pixel,record)
	_sync_part_outline(record)
	var mesh:=record.mesh as MeshInstance3D
	_sync_rig_outline(mesh.get_parent() as Node3D)
	records[record_index]=record

func _sync_material(mat: ShaderMaterial,record: Dictionary) -> void:
	if mat==null:return
	var hidden: Array[int]=record.hidden_indices
	var data:=PackedVector4Array()
	for i in range(MAX_SHADER_CELLS):
		if i<hidden.size():
			var cell: Dictionary=cells[hidden[i]]
			var p: Vector3=cell.local
			data.append(Vector4(p.x,p.y,p.z,float(cell.half)))
		else:
			data.append(Vector4.ZERO)
	mat.set_shader_parameter("damage_cell_count",mini(hidden.size(),MAX_SHADER_CELLS))
	mat.set_shader_parameter("damage_cells",data)
	mat.set_shader_parameter("damage_flash",flash_strength)

func _sync_part_outline(record: Dictionary) -> void:
	var mat:=record.outline_material as ShaderMaterial
	if mat==null:return
	var hidden: Array[int]=record.hidden_indices
	var data:=PackedVector4Array()
	for i in range(MAX_SHADER_CELLS):
		if i<hidden.size():
			var cell: Dictionary=cells[hidden[i]]
			var p: Vector3=cell.local
			data.append(Vector4(p.x,p.y,p.z,float(cell.half)))
		else:data.append(Vector4.ZERO)
	mat.set_shader_parameter("damage_cell_count",mini(hidden.size(),MAX_SHADER_CELLS))
	mat.set_shader_parameter("damage_cells",data)

func _sync_rig_outline(rig: Node3D) -> void:
	if rig==null or not rig_outlines.has(rig.get_instance_id()):return
	var info: Dictionary=rig_outlines[rig.get_instance_id()]
	var mat:=info.material as ShaderMaterial
	if mat==null:return
	var data:=PackedVector4Array()
	var count:=0
	for cell in cells:
		if count>=MAX_SHADER_CELLS:break
		if not bool(cell.hidden) or cell.rig!=rig:continue
		var p: Vector3=cell.rig_local
		data.append(Vector4(p.x,p.y,p.z,float(cell.half)));count+=1
	while data.size()<MAX_SHADER_CELLS:data.append(Vector4.ZERO)
	mat.set_shader_parameter("damage_cell_count",count)
	mat.set_shader_parameter("damage_cells",data)

func flash_hit(amount: float=1.0,record_indices: Dictionary={}) -> void:
	flash_strength=maxf(flash_strength,clampf(amount,0.0,1.0))
	for key in record_indices.keys():
		flash_records[int(key)]=true
		_sync_record(int(key))
	set_process(true)

func _sync_all_materials() -> void:
	for i in range(records.size()):_sync_record(i)
func set_health(value: float,maximum: float=100.0) -> void:
	maximum_health=maxf(1.0,maximum)
	current_health=clampf(value,0.0,maximum_health)
	desired_hidden=_hidden_for_health(current_health)
	if hidden_count>desired_hidden:set_process(true)

func damage_at(world_point: Vector3,health_after: float,maximum: float=100.0,amount: float=5.0,direction: Vector3=Vector3.ZERO) -> int:
	maximum_health=maxf(1.0,maximum)
	current_health=clampf(health_after,0.0,maximum_health)
	desired_hidden=_hidden_for_health(current_health)
	var needed:=clampi(desired_hidden-hidden_count,0,MAX_REMOVE_PER_DAMAGE_EVENT)
	if needed<=0:return 0
	var nearest: Array[int]=_nearest_visible_indices(world_point,needed)
	var removed:=0
	var dirty: Dictionary={}
	for index in nearest:
		var record_index:=int(cells[index].record)
		var world_transform:=_cell_world_transform(index)
		_hide_cell(index)
		dirty[record_index]=true
		if removed<DEBRIS_PER_HIT:_spawn_debris(index,world_transform,direction)
		removed+=1
	flash_hit(0.85,dirty)
	return removed

func _nearest_visible_indices(world_point: Vector3,limit: int) -> Array[int]:
	var best_indices: Array[int]=[]
	var best_scores: Array[float]=[]
	for i in range(cells.size()):
		var cell: Dictionary=cells[i]
		if bool(cell.hidden):continue
		var record: Dictionary=records[int(cell.record)]
		if (record.hidden_indices as Array[int]).size()>=MAX_SHADER_CELLS:continue
		var mesh:=cell.mesh as MeshInstance3D
		var p: Vector3=mesh.global_transform*Vector3(cell.local)
		var score: float=p.distance_squared_to(world_point)*rng.randf_range(0.88,1.12)
		var insert_at:=best_scores.size()
		for j in range(best_scores.size()):
			if score<best_scores[j]:insert_at=j;break
		if insert_at>=limit:continue
		best_scores.insert(insert_at,score)
		best_indices.insert(insert_at,i)
		if best_scores.size()>limit:
			best_scores.pop_back();best_indices.pop_back()
	return best_indices

func _hidden_for_health(health: float) -> int:
	var deficit:=1.0-clampf(health/maxf(1.0,maximum_health),0.0,1.0)
	return clampi(int(round(deficit*float(max_hidden))),0,max_hidden)
func _hide_cell(index: int) -> void:
	var cell: Dictionary=cells[index]
	if bool(cell.hidden):return
	cell.hidden=true
	cells[index]=cell
	var record_index:=int(cell.record)
	var record: Dictionary=records[record_index]
	(record.hidden_indices as Array[int]).append(index)
	records[record_index]=record
	hidden_order.append(index)
	hidden_count+=1

func _restore_cell(index: int) -> void:
	var cell: Dictionary=cells[index]
	if not bool(cell.hidden):return
	cell.hidden=false
	cells[index]=cell
	var record_index:=int(cell.record)
	var record: Dictionary=records[record_index]
	(record.hidden_indices as Array[int]).erase(index)
	records[record_index]=record
	hidden_count=maxi(0,hidden_count-1)
	_sync_record(record_index)

func _restore_one() -> bool:
	while not hidden_order.is_empty():
		var index: int=int(hidden_order.pop_back())
		if index>=0 and index<cells.size() and bool(cells[index].hidden):
			_restore_cell(index)
			return true
	return false

func restore_all_immediate() -> void:
	for i in range(cells.size()):
		if bool(cells[i].hidden):_restore_cell(i)
	hidden_order.clear()
	desired_hidden=0
	current_health=maximum_health
	_sync_all_materials()

func _cell_world_transform(index: int) -> Transform3D:
	var cell: Dictionary=cells[index]
	var mesh:=cell.mesh as MeshInstance3D
	var half:=float(cell.half)
	return mesh.global_transform*Transform3D(Basis.from_scale(Vector3.ONE*half*1.7),Vector3(cell.local))
func _spawn_debris(index: int,world_transform: Transform3D,direction: Vector3) -> void:
	if get_tree()==null:return
	var parent:=get_tree().current_scene
	if parent==null:return
	while debris.size()>=MAX_DEBRIS_ACTIVE:
		var oldest: Dictionary=debris.pop_front()
		if is_instance_valid(oldest.node):oldest.node.queue_free()
	var cell: Dictionary=cells[index]
	var node:=MeshInstance3D.new()
	node.name="DamageVoxelDebris"
	node.mesh=shared_box
	node.material_override=_debris_material(cell.color)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.global_transform=world_transform
	var outward:=direction.normalized() if direction.length_squared()>0.001 else Vector3(rng.randf_range(-1,1),0.2,rng.randf_range(-1,1)).normalized()
	var velocity:=outward*rng.randf_range(1.0,2.6)+Vector3(rng.randf_range(-1.4,1.4),rng.randf_range(1.2,2.8),rng.randf_range(-1.4,1.4))
	debris.append({"node":node,"velocity":velocity,"angular":Vector3(rng.randf_range(-9,9),rng.randf_range(-9,9),rng.randf_range(-9,9)),"age":0.0,"duration":rng.randf_range(0.55,0.85),"scale":node.scale})
	set_process(true)

func _debris_material(color: Color) -> StandardMaterial3D:
	var key:=color.to_html(false)
	if debris_material_cache.has(key):return debris_material_cache[key]
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=color
	mat.roughness=1.0
	debris_material_cache[key]=mat
	return mat

func _process(delta: float) -> void:
	var active:=false
	if flash_strength>0.0:
		flash_strength=maxf(0.0,flash_strength-delta*9.5)
		for record_index in flash_records.keys():_sync_record(int(record_index))
		if flash_strength<=0.0:flash_records.clear()
		active=active or flash_strength>0.0
	if hidden_count>desired_hidden:
		restore_clock+=delta
		while restore_clock>=RESTORE_INTERVAL and hidden_count>desired_hidden:
			restore_clock-=RESTORE_INTERVAL
			if not _restore_one():break
		active=true
	else:
		restore_clock=0.0
	for i in range(debris.size()-1,-1,-1):
		var d: Dictionary=debris[i]
		var node:=d.node as Node3D
		if not is_instance_valid(node):
			debris.remove_at(i);continue
		d.age=float(d.age)+delta
		var velocity: Vector3=d.velocity
		velocity.y-=12.5*delta
		d.velocity=velocity
		node.global_position+=velocity*delta
		node.rotation+=(d.angular as Vector3)*delta
		var life:=clampf(1.0-float(d.age)/float(d.duration),0.0,1.0)
		node.scale=(d.scale as Vector3)*maxf(0.05,life)
		debris[i]=d
		if float(d.age)>=float(d.duration):
			node.queue_free();debris.remove_at(i)
		else:active=true
	if not active:set_process(false)

func cell_count() -> int:
	return cells.size()

func damaged_cell_count() -> int:
	return hidden_count

func source_mesh_count() -> int:
	return records.size()
