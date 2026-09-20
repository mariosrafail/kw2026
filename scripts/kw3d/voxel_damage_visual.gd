extends Node
## Bounded visual voxel damage. Four MultiMeshes per actor, no per-cell physics bodies.
const CELL_TARGET := 0.14
const MAX_HIDDEN_ABS := 96
const MAX_HIDDEN_RATIO := 0.26
const MAX_REMOVE_PER_DAMAGE_EVENT := 10
const DEBRIS_PER_HIT := 2
const MAX_DEBRIS_ACTIVE := 12
const RESTORE_INTERVAL := 0.035
const DAMAGE_SHADER := preload("res://scripts/kw3d/voxel_damage_cells.gdshader")

static var color_cache: Dictionary = {}
static var debris_material_cache: Dictionary = {}
static var shared_box: BoxMesh

var visual_root: Node3D
var material: ShaderMaterial
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
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("kw_damage_visual")
	set_process(false)

func setup(root_visual: Node3D, rig_names: Array = ["HeadRig","TorsoRig","LeftLegRig","RightLegRig"], seed: int = 137) -> void:
	visual_root=root_visual
	rng.seed=seed
	material=ShaderMaterial.new()
	material.shader=DAMAGE_SHADER
	material.set_shader_parameter("pixel_enabled",false)
	material.set_shader_parameter("flash_strength",0.0)
	if shared_box==null:
		shared_box=BoxMesh.new()
		shared_box.size=Vector3.ONE
	for rig_name in rig_names:
		var rig:=root_visual.get_node_or_null(rig_name) as Node3D
		if rig!=null:_build_rig(rig)
	max_hidden=mini(MAX_HIDDEN_ABS,maxi(12,int(round(float(cells.size())*MAX_HIDDEN_RATIO))))
	current_health=maximum_health
	desired_hidden=0
	set_process(false)

func _build_rig(rig: Node3D) -> void:
	var specs: Array[Dictionary]=[]
	for child in rig.get_children():
		if not child is MeshInstance3D:continue
		var source:=child as MeshInstance3D
		if source.name in ["ShaderInkOutline","WorldInkOutline"]:continue
		if source.mesh==null:continue
		_append_source_cells(source,specs)
		source.visible=false
	if specs.is_empty():return
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.use_colors=true
	mm.instance_count=specs.size()
	mm.mesh=shared_box
	var node:=MultiMeshInstance3D.new()
	node.name="DamageCells_"+rig.name
	node.multimesh=mm
	node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin=0.4
	rig.add_child(node)
	for i in range(specs.size()):
		var spec: Dictionary=specs[i]
		mm.set_instance_transform(i,spec.transform)
		mm.set_instance_color(i,spec.color)
		cells.append({"rig":rig,"node":node,"mm":mm,"index":i,"transform":spec.transform,"color":spec.color,"hidden":false})
func _append_source_cells(source: MeshInstance3D,specs: Array[Dictionary]) -> void:
	var aabb:=source.mesh.get_aabb()
	var counts:=Vector3i(_axis_count(aabb.size.x),_axis_count(aabb.size.y),_axis_count(aabb.size.z))
	var cell_size:=Vector3(aabb.size.x/float(counts.x),aabb.size.y/float(counts.y),aabb.size.z/float(counts.z))
	var color:=_source_color(source)
	for x in range(counts.x):
		for y in range(counts.y):
			for z in range(counts.z):
				var p:=aabb.position+Vector3((x+0.5)*cell_size.x,(y+0.5)*cell_size.y,(z+0.5)*cell_size.z)
				var local_origin: Vector3=source.transform*p
				var local_basis:=source.transform.basis*Basis.from_scale(cell_size*0.965)
				specs.append({"transform":Transform3D(local_basis,local_origin),"color":color})

func _axis_count(length: float) -> int:
	return maxi(1,int(round(length/CELL_TARGET)))

func _source_color(source: MeshInstance3D) -> Color:
	var key:=source.mesh.get_instance_id()
	if color_cache.has(key):return color_cache[key]
	var mat: Material=source.material_override
	if mat==null and source.mesh.get_surface_count()>0:mat=source.mesh.surface_get_material(0)
	var result:=Color(0.55,0.11,0.15,1.0)
	if mat is ShaderMaterial:
		var sm:=mat as ShaderMaterial
		var base=sm.get_shader_parameter("base_color")
		if base is Color:result=base
		var use_texture=sm.get_shader_parameter("use_texture")
		var tex=sm.get_shader_parameter("albedo_texture")
		if bool(use_texture) and tex is Texture2D:
			result*=_sample_texture_for_mesh(tex as Texture2D,source.mesh)
	elif mat is StandardMaterial3D:
		result=(mat as StandardMaterial3D).albedo_color
	color_cache[key]=result
	return result

func _sample_texture_for_mesh(texture: Texture2D,mesh: Mesh) -> Color:
	var image:=texture.get_image()
	if image==null or image.is_empty() or mesh.get_surface_count()==0:return Color.WHITE
	var arrays:=mesh.surface_get_arrays(0)
	var raw=arrays[Mesh.ARRAY_TEX_UV]
	if not raw is PackedVector2Array or raw.is_empty():return Color.WHITE
	var uvs:=raw as PackedVector2Array
	var sum:=Vector3.ZERO
	var count:=0
	for uv in uvs:
		var x:=clampi(int(round(clampf(uv.x,0.0,1.0)*float(image.get_width()-1))),0,image.get_width()-1)
		var y:=clampi(int(round(clampf(uv.y,0.0,1.0)*float(image.get_height()-1))),0,image.get_height()-1)
		var c:=image.get_pixel(x,y)
		if c.a<0.08:continue
		sum+=Vector3(c.r,c.g,c.b);count+=1
	if count==0:return Color.WHITE
	return Color(sum.x/count,sum.y/count,sum.z/count,1.0)

func set_pixel_enabled(value: bool) -> void:
	if material!=null:material.set_shader_parameter("pixel_enabled",value)

func set_comic_enabled(_value: bool) -> void:
	pass

func flash_hit(amount: float=1.0) -> void:
	flash_strength=maxf(flash_strength,clampf(amount,0.0,1.0))
	if material!=null:material.set_shader_parameter("flash_strength",flash_strength)
	set_process(true)
func set_health(value: float,maximum: float=100.0) -> void:
	maximum_health=maxf(1.0,maximum)
	var next:=clampf(value,0.0,maximum_health)
	current_health=next
	desired_hidden=_hidden_for_health(next)
	if hidden_count>desired_hidden:set_process(true)

func damage_at(world_point: Vector3,health_after: float,maximum: float=100.0,amount: float=5.0,direction: Vector3=Vector3.ZERO) -> int:
	maximum_health=maxf(1.0,maximum)
	current_health=clampf(health_after,0.0,maximum_health)
	desired_hidden=_hidden_for_health(current_health)
	var needed:=clampi(desired_hidden-hidden_count,0,MAX_REMOVE_PER_DAMAGE_EVENT)
	if needed<=0:return 0
	var nearest: Array[int]=_nearest_visible_indices(world_point,needed)
	var removed:=0
	for index in nearest:
		var world_transform:=_cell_world_transform(index)
		_hide_cell(index)
		if removed<DEBRIS_PER_HIT:_spawn_debris(index,world_transform,direction)
		removed+=1
	flash_hit(0.85)
	return removed

func _nearest_visible_indices(world_point: Vector3,limit: int) -> Array[int]:
	var best_indices: Array[int]=[]
	var best_scores: Array[float]=[]
	for i in range(cells.size()):
		var cell: Dictionary=cells[i]
		if bool(cell.hidden):continue
		var rig:=cell.rig as Node3D
		var p: Vector3=rig.global_transform*(cell.transform as Transform3D).origin
		var score: float=p.distance_squared_to(world_point)*rng.randf_range(0.86,1.16)
		var insert_at: int=best_scores.size()
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
	var base: Transform3D=cell.transform
	var tiny:=Transform3D(Basis.from_scale(Vector3.ONE*0.001),base.origin)
	(cell.mm as MultiMesh).set_instance_transform(int(cell.index),tiny)
	cell.hidden=true
	cells[index]=cell
	hidden_order.append(index)
	hidden_count+=1

func _restore_cell(index: int) -> void:
	var cell: Dictionary=cells[index]
	if not bool(cell.hidden):return
	(cell.mm as MultiMesh).set_instance_transform(int(cell.index),cell.transform)
	cell.hidden=false
	cells[index]=cell
	hidden_count=maxi(0,hidden_count-1)

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
func _cell_world_transform(index: int) -> Transform3D:
	var cell: Dictionary=cells[index]
	return (cell.rig as Node3D).global_transform*(cell.transform as Transform3D)

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
		if material!=null:material.set_shader_parameter("flash_strength",flash_strength)
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
