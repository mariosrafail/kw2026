extends Node3D
## Local-only practice range. All gameplay damage is one muzzle ray per rifle shot.
const DUMMY := preload("res://scripts/prototypes/kw_training_dummy.gd")
const WAVE_DIRECTOR := preload("res://scripts/prototypes/kw_wave_director.gd")
const WEAPON_RULES := preload("res://scripts/kw3d/weapon_rules.gd")
const HIT_REGIONS := preload("res://scripts/kw3d/hit_regions.gd")
const FLAME_PARTICLES := preload("res://scripts/prototypes/kw_flame_particles.gd")
var director: RefCounted
var wave_label: Label
const DAMAGE := 5.0
const RANGE := 120.0
const SHOT_MASK := 5 # environment (1) + targets (4); cosmetic effects have no bodies.
const VICTIM_MAIN_COLORS := {
	"outrage": Color("fa0512"), "tasko": Color("bf3fff"), "gan": Color("7ab1b7"),
	"celler": Color("eaeaea"), "nova": Color("334756"), "m4": Color("c59370"),
	"crashout": Color("a11b1b"), "juice": Color("f2ff8f"), "kotro": Color("78ead8")
}
var stage: Node3D
var targets: Array[Node3D] = []
var shots_fired := 0
var kills := 0
var total_kills := 0
var credited_kills: Dictionary = {}
var roaming_enabled := true
var kill_label: Label
var alive_label: Label
var kill_notice: Label
var score_pulse := 0.0
var hit_effects: Array[Dictionary] = []
var fx_rng := RandomNumberGenerator.new()
var last_shot: Dictionary = {}
var hit_timer := 0.0
var lethal_hit := false
var counter: Label
var hit_marker: Label
var tracer_material: Material
var tracer_halo_material: Material
var tracer_hot_materials: Array[Material] = []
var fx_material_cache: Dictionary = {}
var projectile_material_cache: Dictionary = {}
var surface_material_cache: Dictionary = {}
var impact_material: Material
var impact_hot_material: Material
var hit_material: Material
var tracer_serial := 0
var reticle: Control
var camera_hit: Dictionary = {}
var aim_solution: Dictionary = {}
var active_tracers: Array[Dictionary] = []
var trail_echoes: Array[Dictionary] = []
var impacts: Array[Node3D] = []
var bullet_holes: Array[MeshInstance3D] = []
const MAX_ACTIVE_TRACERS := 40
const MAX_TRAIL_ECHOES := 72
const MAX_MUZZLE_FLASHES := 18
const MAX_REMOTE_MUZZLE_LIGHTS := 6
const MAX_IMPACT_FLASHES := 28
const MAX_BULLET_HOLES := 36
const MAX_EFFECT_MESHES := 168
const FX_FULL_DISTANCE := 26.0
const FX_MEDIUM_DISTANCE := 52.0
var tracer_pool: Array[Dictionary] = []
var inferno_tracer_pool: Array[Dictionary] = []
var trail_echo_pool: Array[MeshInstance3D] = []
var gpu_trail_records: Array[Dictionary] = []
var gpu_trail_multimesh: MultiMesh
var gpu_trail_instance: MultiMeshInstance3D
var use_multimesh_trails := false
var muzzle_flash_pool: Array[Dictionary] = []
var active_muzzle_flashes: Array[Dictionary] = []
var impact_flash_pool: Array[MeshInstance3D] = []
var active_impact_flashes: Array[Dictionary] = []
var bullet_hole_pool: Array[MeshInstance3D] = []
var active_bullet_holes: Array[Dictionary] = []
var bullet_hole_multimesh: MultiMesh
var bullet_hole_instance: MultiMeshInstance3D
var effect_mesh_pool: Array[MeshInstance3D] = []
var outlined_effect_mesh_pool: Array[MeshInstance3D] = []
var blood_fx_multimesh: MultiMesh
var blood_fx_instance: MultiMeshInstance3D
var spark_fx_multimesh: MultiMesh
var spark_fx_instance: MultiMeshInstance3D
var surface_fx_multimesh: MultiMesh
var surface_fx_instance: MultiMeshInstance3D
var confirm_audio: AudioStreamPlayer
var confirm_hit: AudioStreamWAV
var confirm_kill: AudioStreamWAV
var shot_ray_query:=PhysicsRayQueryParameters3D.new()
var surface_ray_query:=PhysicsRayQueryParameters3D.new()
var player_ray_exclude: Array[RID]=[]

static func blood_color_for_skin(skin: String) -> Color:
	return VICTIM_MAIN_COLORS.get(skin.to_lower(),Color("fa0512"))

func setup(owner_stage: Node3D) -> void:
	stage = owner_stage
	name = "PracticeRange"
	player_ray_exclude.clear()
	if stage.player!=null:player_ray_exclude.append(stage.player.get_rid())
	shot_ray_query.collision_mask=SHOT_MASK
	shot_ray_query.exclude=player_ray_exclude
	shot_ray_query.hit_from_inside=true
	surface_ray_query.collision_mask=SHOT_MASK
	surface_ray_query.exclude=player_ray_exclude
	surface_ray_query.hit_from_inside=true
	fx_rng.randomize()
	_setup_shooting_fx_materials()
	_setup_multimesh_trails()
	_setup_batched_blood_fx()
	_setup_batched_impact_fx()
	_setup_batched_bullet_holes()
	_build_hud()
	_build_confirm_audio()
	director = WAVE_DIRECTOR.new()
	director.setup(self)

func _fx_distance(point: Vector3) -> float:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		return cam.global_position.distance_to(point)
	if stage != null and stage.player != null:
		return stage.player.global_position.distance_to(point)
	return 0.0

func _fx_detail(point: Vector3) -> int:
	var distance := _fx_distance(point)
	if distance <= FX_FULL_DISTANCE:
		return 2
	if distance <= FX_MEDIUM_DISTANCE:
		return 1
	return 0

func _create_tracer_bundle(inferno: bool, color: Color) -> Dictionary:
	var root := Node3D.new()
	root.name = "PooledInfernoTracer" if inferno else "PooledTracer"
	root.visible = false
	add_child(root)
	var core := MeshInstance3D.new()
	core.name = "Core"
	var core_box := BoxMesh.new()
	core_box.size = Vector3.ONE
	core.mesh = core_box
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)
	stage._add_scene_outline(core,0.6)
	var halo := MeshInstance3D.new()
	halo.name = "Glow"
	var halo_box := BoxMesh.new()
	halo_box.size = Vector3.ONE
	halo.mesh = halo_box
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	var head := MeshInstance3D.new()
	head.name = "BulletHead"
	var head_box := BoxMesh.new()
	head_box.size = Vector3.ONE
	head.mesh = head_box
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(head)
	var flames: GPUParticles3D = null
	if inferno:
		flames = FLAME_PARTICLES.add_bullet_flames(root,color)
		flames.emitting = false
		flames.visible = false
	return {"node":root,"core":core,"halo":halo,"head":head,"flames":flames}

func _acquire_tracer_bundle(inferno: bool, color: Color) -> Dictionary:
	var pool := inferno_tracer_pool if inferno else tracer_pool
	for bundle in pool:
		var root := bundle.node as Node3D
		if is_instance_valid(root) and not root.visible:
			return bundle
	var created := _create_tracer_bundle(inferno,color)
	pool.append(created)
	return created

func _release_tracer(data: Dictionary) -> void:
	var root := data.get("node") as Node3D
	if root == null:return
	root.visible = false
	root.scale = Vector3.ONE
	var flames := data.get("flames") as GPUParticles3D
	if flames != null:
		flames.emitting = false
		flames.visible = false

func _acquire_trail_echo() -> MeshInstance3D:
	for echo in trail_echo_pool:
		if is_instance_valid(echo) and not echo.visible:
			return echo
	var echo := MeshInstance3D.new()
	echo.name = "PooledBulletTrailEcho"
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	echo.mesh = box
	echo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	echo.visible = false
	add_child(echo)
	trail_echo_pool.append(echo)
	return echo

func _release_trail_echo(echo: MeshInstance3D) -> void:
	if echo == null:return
	echo.visible = false
	echo.transparency = 0.0
	echo.scale = Vector3.ONE

func _create_muzzle_flash_bundle() -> Dictionary:
	var root := Node3D.new()
	root.name = "PooledMuzzleBurst"
	root.visible = false
	add_child(root)
	var light := OmniLight3D.new()
	light.shadow_enabled = false
	root.add_child(light)
	var rays: Array[MeshInstance3D] = []
	for i in range(3):
		var ray := MeshInstance3D.new()
		ray.name = "Ray%d" % i
		var box := BoxMesh.new();box.size = Vector3.ONE;ray.mesh = box
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ray)
		rays.append(ray)
	var ember := MeshInstance3D.new()
	ember.name = "Ember"
	var cube := BoxMesh.new();cube.size = Vector3.ONE;ember.mesh = cube
	ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ember)
	return {"node":root,"light":light,"rays":rays,"ember":ember}

func _acquire_muzzle_flash() -> Dictionary:
	for bundle in muzzle_flash_pool:
		var root := bundle.node as Node3D
		if is_instance_valid(root) and not root.visible:
			return bundle
	if muzzle_flash_pool.size() < MAX_MUZZLE_FLASHES:
		var created := _create_muzzle_flash_bundle()
		muzzle_flash_pool.append(created)
		return created
	if not active_muzzle_flashes.is_empty():
		var oldest: Dictionary = active_muzzle_flashes.pop_front()
		_release_muzzle_flash(oldest)
		return _acquire_muzzle_flash()
	return _create_muzzle_flash_bundle()

func _release_muzzle_flash(data: Dictionary) -> void:
	var root := data.get("node") as Node3D
	if root != null:
		root.visible = false
		root.scale = Vector3.ONE

func _active_remote_muzzle_lights() -> int:
	var count:=0
	for data in active_muzzle_flashes:
		var light:=data.get("light") as OmniLight3D
		if light!=null and light.visible and not bool(data.get("local",false)):count+=1
	return count

func _acquire_impact_flash() -> MeshInstance3D:
	for flash in impact_flash_pool:
		if is_instance_valid(flash) and not flash.visible:
			return flash
	var flash := MeshInstance3D.new()
	flash.name = "PooledShotImpactFlash"
	var sphere := SphereMesh.new();sphere.radius = 0.065;sphere.height = 0.13
	flash.mesh = sphere
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.visible = false
	add_child(flash)
	stage._add_scene_outline(flash,0.75)
	impact_flash_pool.append(flash)
	return flash

func _release_impact_flash(flash: MeshInstance3D) -> void:
	if flash == null:return
	flash.visible = false
	flash.scale = Vector3.ONE
	impacts.erase(flash)

func _create_bullet_hole() -> MeshInstance3D:
	var hole := MeshInstance3D.new()
	hole.name = "PooledBulletHole"
	var quad := QuadMesh.new();quad.size = Vector2.ONE;hole.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.008,0.006,0.006,0.92)
	material.roughness = 1.0
	hole.material_override = material
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hole.visible = false
	hole.set_meta("kw_bullet_hole_active",false)
	add_child(hole)
	bullet_hole_pool.append(hole)
	return hole

func _acquire_bullet_hole() -> MeshInstance3D:
	for hole in bullet_hole_pool:
		if is_instance_valid(hole) and not bool(hole.get_meta("kw_bullet_hole_active",false)):
			hole.set_meta("kw_bullet_hole_active",true)
			return hole
	if bullet_hole_pool.size() < MAX_BULLET_HOLES:
		var created:=_create_bullet_hole()
		created.set_meta("kw_bullet_hole_active",true)
		return created
	if not active_bullet_holes.is_empty():
		var oldest: Dictionary = active_bullet_holes.pop_front()
		var old_hole := oldest.node as MeshInstance3D
		_release_bullet_hole(old_hole)
		return old_hole
	return _create_bullet_hole()

func _release_bullet_hole(hole: MeshInstance3D) -> void:
	if hole == null:return
	hole.visible = false
	hole.set_meta("kw_bullet_hole_active",false)
	hole.transparency = 0.0
	hole.scale = Vector3.ONE
	bullet_holes.erase(hole)

func _setup_batched_bullet_holes() -> void:
	var quad:=QuadMesh.new();quad.size=Vector2.ONE
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo=true
	material.albedo_color=Color.WHITE
	quad.material=material
	bullet_hole_multimesh=MultiMesh.new()
	bullet_hole_multimesh.transform_format=MultiMesh.TRANSFORM_3D
	bullet_hole_multimesh.use_colors=true
	bullet_hole_multimesh.mesh=quad
	bullet_hole_multimesh.instance_count=MAX_BULLET_HOLES
	bullet_hole_multimesh.visible_instance_count=0
	bullet_hole_instance=MultiMeshInstance3D.new()
	bullet_hole_instance.name="BatchedBulletHoles"
	bullet_hole_instance.multimesh=bullet_hole_multimesh
	bullet_hole_instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bullet_hole_instance.custom_aabb=AABB(Vector3(-96,-24,-96),Vector3(192,72,192))
	bullet_hole_instance.top_level=true
	add_child(bullet_hole_instance)
	bullet_hole_instance.global_transform=Transform3D.IDENTITY

func _update_batched_bullet_holes() -> void:
	if bullet_hole_multimesh==null:return
	var count:=mini(active_bullet_holes.size(),MAX_BULLET_HOLES)
	for index in range(count):
		var data: Dictionary=active_bullet_holes[index]
		var hole:=data.node as MeshInstance3D
		if hole==null:continue
		bullet_hole_multimesh.set_instance_transform(index,hole.global_transform)
		var alpha:=0.92*(1.0-clampf(hole.transparency,0.0,1.0))
		bullet_hole_multimesh.set_instance_color(index,Color(0.008,0.006,0.006,alpha))
	bullet_hole_multimesh.visible_instance_count=count

func _create_effect_mesh(outlined: bool) -> MeshInstance3D:
	var chip := MeshInstance3D.new()
	chip.name = "PooledOutlinedFX" if outlined else "PooledFX"
	var box := BoxMesh.new();box.size = Vector3.ONE;chip.mesh = box
	chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chip.visible = false
	chip.set_meta("kw_pooled_effect",true)
	chip.set_meta("kw_pooled_outlined",outlined)
	chip.set_meta("kw_effect_active",false)
	add_child(chip)
	if outlined:stage._add_scene_outline(chip,0.75)
	if outlined:outlined_effect_mesh_pool.append(chip)
	else:effect_mesh_pool.append(chip)
	return chip

func _acquire_effect_mesh(outlined: bool = false) -> MeshInstance3D:
	var pool := outlined_effect_mesh_pool if outlined else effect_mesh_pool
	for chip in pool:
		if is_instance_valid(chip) and not bool(chip.get_meta("kw_effect_active",false)):
			chip.set_meta("kw_effect_active",true)
			return chip
	var created:=_create_effect_mesh(outlined)
	created.set_meta("kw_effect_active",true)
	return created

func _release_effect_mesh(chip: MeshInstance3D) -> void:
	if chip == null:return
	chip.visible = false
	chip.set_meta("kw_effect_active",false)
	chip.scale = Vector3.ONE
	chip.rotation = Vector3.ZERO
	chip.transparency = 0.0

func _trim_effect_meshes() -> void:
	while hit_effects.size() >= MAX_EFFECT_MESHES:
		var oldest: Dictionary = hit_effects.pop_front()
		var node := oldest.get("node") as Node3D
		if node is MeshInstance3D and bool(node.get_meta("kw_pooled_effect",false)):
			_release_effect_mesh(node as MeshInstance3D)
		elif is_instance_valid(node):
			node.queue_free()

func _fx_material(color: Color, emission_energy: float = 2.5, alpha: float = 1.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(true),emission_energy,alpha]
	if fx_material_cache.has(key):return fx_material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r,color.g,color.b,alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission_energy
	if alpha < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.no_depth_test = false
	fx_material_cache[key]=material
	return material

func _setup_batched_blood_fx() -> void:
	var cube:=BoxMesh.new()
	cube.size=Vector3.ONE
	var shader:=Shader.new()
	shader.code="shader_type spatial; render_mode unshaded, cull_disabled; void fragment(){ ALBEDO=COLOR.rgb; EMISSION=COLOR.rgb*4.8; ALPHA=COLOR.a; }"
	var material:=ShaderMaterial.new()
	material.shader=shader
	cube.material=material
	blood_fx_multimesh=MultiMesh.new()
	blood_fx_multimesh.transform_format=MultiMesh.TRANSFORM_3D
	blood_fx_multimesh.use_colors=true
	blood_fx_multimesh.mesh=cube
	blood_fx_multimesh.instance_count=MAX_EFFECT_MESHES
	blood_fx_multimesh.visible_instance_count=0
	blood_fx_instance=MultiMeshInstance3D.new()
	blood_fx_instance.name="BatchedBloodChunks"
	blood_fx_instance.multimesh=blood_fx_multimesh
	blood_fx_instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blood_fx_instance.custom_aabb=AABB(Vector3(-96,-24,-96),Vector3(192,72,192))
	blood_fx_instance.top_level=true
	add_child(blood_fx_instance)
	blood_fx_instance.global_transform=Transform3D.IDENTITY

func _make_fx_batch(name: String, shader_code: String) -> Dictionary:
	var cube:=BoxMesh.new();cube.size=Vector3.ONE
	var shader:=Shader.new();shader.code=shader_code
	var material:=ShaderMaterial.new();material.shader=shader;cube.material=material
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=cube
	mm.instance_count=MAX_EFFECT_MESHES;mm.visible_instance_count=0
	var instance:=MultiMeshInstance3D.new();instance.name=name;instance.multimesh=mm
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb=AABB(Vector3(-96,-24,-96),Vector3(192,72,192));instance.top_level=true
	add_child(instance);instance.global_transform=Transform3D.IDENTITY
	return {"multimesh":mm,"instance":instance}

func _setup_batched_impact_fx() -> void:
	var spark:=_make_fx_batch("BatchedImpactSparks","shader_type spatial; render_mode unshaded, cull_disabled; void fragment(){ ALBEDO=COLOR.rgb; EMISSION=COLOR.rgb*5.8; ALPHA=COLOR.a; }")
	spark_fx_multimesh=spark.multimesh;spark_fx_instance=spark.instance
	var surface:=_make_fx_batch("BatchedSurfaceDebris","shader_type spatial; render_mode cull_disabled; void fragment(){ ALBEDO=COLOR.rgb; ROUGHNESS=0.84; METALLIC=0.04; ALPHA=COLOR.a; }")
	surface_fx_multimesh=surface.multimesh;surface_fx_instance=surface.instance

func _update_batched_blood_fx() -> void:
	if blood_fx_multimesh==null:return
	var count:=0
	for effect in hit_effects:
		if count>=MAX_EFFECT_MESHES:break
		if str(effect.get("kind",""))!="blood_chunk" or bool(effect.get("outlined",false)):continue
		var node:=effect.get("node") as MeshInstance3D
		if node==null or not bool(node.get_meta("kw_effect_active",false)):continue
		blood_fx_multimesh.set_instance_transform(count,node.global_transform)
		blood_fx_multimesh.set_instance_color(count,effect.get("batch_color",Color("fa0512")) as Color)
		count+=1
	blood_fx_multimesh.visible_instance_count=count

func _update_batched_impact_fx() -> void:
	if spark_fx_multimesh==null or surface_fx_multimesh==null:return
	var spark_count:=0
	var surface_count:=0
	for effect in hit_effects:
		var kind:=str(effect.get("kind",""))
		if kind!="spark" and kind!="surface_debris":continue
		var node:=effect.get("node") as MeshInstance3D
		if node==null or not bool(node.get_meta("kw_effect_active",false)):continue
		var color:=effect.get("batch_color",Color.WHITE) as Color
		if kind=="spark" and spark_count<MAX_EFFECT_MESHES:
			spark_fx_multimesh.set_instance_transform(spark_count,node.global_transform)
			spark_fx_multimesh.set_instance_color(spark_count,color);spark_count+=1
		elif kind=="surface_debris" and surface_count<MAX_EFFECT_MESHES:
			surface_fx_multimesh.set_instance_transform(surface_count,node.global_transform)
			surface_fx_multimesh.set_instance_color(surface_count,color);surface_count+=1
	spark_fx_multimesh.visible_instance_count=spark_count
	surface_fx_multimesh.visible_instance_count=surface_count

func _setup_shooting_fx_materials() -> void:
	tracer_material = _fx_material(Color("fff1a8"), 6.8)
	tracer_halo_material = _fx_material(Color("ff7b4b"), 5.6, 0.52)
	tracer_hot_materials = [
		_fx_material(Color("84edff"), 5.4),
		_fx_material(Color("ff5f9a"), 5.2),
		_fx_material(Color("fff0a2"), 5.8)
	]
	impact_material = _fx_material(Color("fff5c2"), 7.2)
	impact_hot_material = _fx_material(Color("ff8b55"), 6.1)
	hit_material = _fx_material(Color("ff4058"), 4.8)

func _setup_multimesh_trails() -> void:
	# Near bullets retain the full layered node FX. Medium-distance trail echoes are
	# batched into one MultiMesh draw instead of dozens of individual MeshInstances.
	use_multimesh_trails = not OS.get_cmdline_user_args().has("--kw-qa")
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1.35,1.35,1.35,0.72)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = material
	gpu_trail_multimesh = MultiMesh.new()
	gpu_trail_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	gpu_trail_multimesh.use_colors = true
	gpu_trail_multimesh.mesh = mesh
	gpu_trail_multimesh.instance_count = MAX_TRAIL_ECHOES
	gpu_trail_multimesh.visible_instance_count = 0
	gpu_trail_instance = MultiMeshInstance3D.new()
	gpu_trail_instance.name = "BatchedMediumBulletTrails"
	gpu_trail_instance.multimesh = gpu_trail_multimesh
	gpu_trail_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gpu_trail_instance.custom_aabb = AABB(Vector3(-96,-32,-96),Vector3(192,96,192))
	gpu_trail_instance.top_level = true
	add_child(gpu_trail_instance)
	gpu_trail_instance.global_transform = Transform3D.IDENTITY

func _spawn_multimesh_trail_echo(position: Vector3,direction: Vector3,width: float,hot: bool,color: Color,inferno: bool) -> void:
	if direction.length_squared()<0.0001:return
	while gpu_trail_records.size()>=MAX_TRAIL_ECHOES:gpu_trail_records.pop_front()
	var echo_len:=fx_rng.randf_range(0.16,0.34)*(1.25 if hot else 1.0)
	var base_scale:=Vector3(width*fx_rng.randf_range(2.0,2.8),width*fx_rng.randf_range(2.0,2.8),echo_len)
	var up:=Vector3.RIGHT if absf(direction.normalized().y)>0.98 else Vector3.UP
	var facing:=Transform3D(Basis.IDENTITY,position).looking_at(position+direction.normalized(),up)
	var trail_color:=color.lightened(0.20 if inferno else 0.10)
	gpu_trail_records.append({
		"position":position,"basis":facing.basis,"base_scale":base_scale,"age":0.0,
		"duration":fx_rng.randf_range(0.10,0.16),"drift":Vector3(fx_rng.randf_range(-0.05,0.05),fx_rng.randf_range(0.01,0.08),fx_rng.randf_range(-0.05,0.05)),
		"color":trail_color,"alpha":0.42 if inferno else 0.34
	})

func _update_multimesh_trails(delta: float) -> void:
	if gpu_trail_multimesh==null:return
	for index in range(gpu_trail_records.size()-1,-1,-1):
		var data: Dictionary=gpu_trail_records[index]
		data.age=float(data.age)+delta
		if float(data.age)>=float(data.duration):
			gpu_trail_records.remove_at(index)
			continue
		data.position=(data.position as Vector3)+(data.drift as Vector3)*delta
	var count:=mini(gpu_trail_records.size(),MAX_TRAIL_ECHOES)
	for index in range(count):
		var data: Dictionary=gpu_trail_records[index]
		var p:=clampf(float(data.age)/maxf(0.001,float(data.duration)),0.0,1.0)
		var shrink:=maxf(0.05,1.0-p*0.82)
		var base_scale:=data.base_scale as Vector3
		var scale:=Vector3(base_scale.x*shrink,base_scale.y*shrink,base_scale.z*maxf(0.16,1.0-p*0.55))
		var basis: Basis=(data.basis as Basis).scaled(scale)
		gpu_trail_multimesh.set_instance_transform(index,Transform3D(basis,data.position as Vector3))
		var c:=data.color as Color
		gpu_trail_multimesh.set_instance_color(index,Color(c.r,c.g,c.b,float(data.alpha)*(1.0-p)))
	gpu_trail_multimesh.visible_instance_count=count

func _projectile_material(color: Color, emission_energy: float, alpha: float = 1.0) -> Material:
	var key := "%s|%.2f|%.2f" % [color.to_html(false), emission_energy, alpha]
	if projectile_material_cache.has(key):
		return projectile_material_cache[key] as Material
	var material := _fx_material(color, emission_energy, alpha)
	projectile_material_cache[key] = material
	return material

func _projectile_style(weapon_id: String) -> Dictionary:
	if stage != null and stage.has_method("projectile_style_for_weapon"):
		var style: Variant = stage.call("projectile_style_for_weapon", weapon_id)
		if style is Dictionary:
			return style as Dictionary
	return {"color": Color("fff1a8"), "inferno": false}

func _surface_material(color: Color, lightness: float = 0.0) -> StandardMaterial3D:
	var resolved := color.lightened(lightness) if lightness >= 0.0 else color.darkened(-lightness)
	var key := "%s|%.2f" % [resolved.to_html(false), lightness]
	if surface_material_cache.has(key):
		return surface_material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = resolved
	material.metallic = 0.04
	material.roughness = 0.84
	surface_material_cache[key] = material
	return material

func _surface_color_from_collider(collider: Object, fallback: Color = Color("8b98a8")) -> Color:
	if collider == null:
		return fallback
	if collider.has_meta("surface_color"):
		var stored: Variant = collider.get_meta("surface_color")
		if stored is Color:
			return stored as Color
	if collider is Node:
		var node := collider as Node
		for candidate in node.find_children("*", "MeshInstance3D", true, false):
			var mesh := candidate as MeshInstance3D
			var material := mesh.material_override
			if material is StandardMaterial3D:
				return (material as StandardMaterial3D).albedo_color
			if material is ShaderMaterial:
				var base: Variant = (material as ShaderMaterial).get_shader_parameter("base_color")
				if base is Color:
					return base as Color
	return fallback

func _surface_color_at(point: Vector3, normal: Vector3, collider: Object = null) -> Color:
	if collider != null:
		return _surface_color_from_collider(collider)
	var safe_normal := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	surface_ray_query.from=point+safe_normal*0.08
	surface_ray_query.to=point-safe_normal*0.12
	var sampled := get_world_3d().direct_space_state.intersect_ray(surface_ray_query)
	return _surface_color_from_collider(sampled.get("collider"))

func _build_hud() -> void:
	counter = Label.new()
	counter.name = "RangeCounter"
	counter.position = Vector2(12,92)
	counter.add_theme_font_size_override("font_size",11)
	stage.get_node("HUD/HelpPanel").add_child(counter)
	_build_score_hud()
	reticle = stage.get_node("HUD/Crosshair") as Control

func reset_targets() -> void:
	if director != null: director.retry_wave()

func sync_style() -> void:
	for target in targets:
		if is_instance_valid(target): target.set_style(stage.head_style.enabled,stage.pixel_enabled)

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	shot_ray_query.from=from;shot_ray_query.to=to
	return get_world_3d().direct_space_state.intersect_ray(shot_ray_query)

func camera_target() -> Vector3:
	# Use the same viewport centre as the HUD, also at non-default window sizes.
	var cam: Camera3D = stage.camera
	var centre := cam.get_viewport().get_visible_rect().size * 0.5
	var origin := cam.project_ray_origin(centre)
	var direction := cam.project_ray_normal(centre).normalized()
	var end := origin + direction * RANGE
	camera_hit = _ray(origin, end)
	return camera_hit["position"] if not camera_hit.is_empty() else end

func predict_shot(muzzle: Vector3, target: Vector3, chest: Vector3) -> Dictionary:
	# This exact solver serves both pre-shot feedback and damage. No aim magnet.
	var guard_hit := _ray(chest, muzzle)
	var start := chest if not guard_hit.is_empty() else muzzle
	var direction := (target - muzzle).normalized()
	var hit := guard_hit if not guard_hit.is_empty() else _ray(muzzle, target + direction * 0.035)
	var endpoint: Vector3 = hit.get("position", target)
	var object: Object = hit.get("collider")
	var expected: Object = camera_hit.get("collider")
	var receiver := object != null and object.has_method("receive_hit")
	var same_target := receiver and object == expected
	var occluded := not guard_hit.is_empty()
	if not hit.is_empty() and not same_target:
		occluded = occluded or (muzzle.distance_to(endpoint) + 0.08 < muzzle.distance_to(target) and endpoint.distance_to(target) > 0.12)
	return {"start": start, "end": endpoint, "hit": hit, "occluded": occluded,
		"guard_blocked": not guard_hit.is_empty(), "target_ready": same_target and not occluded,
		"normal": hit.get("normal", Vector3.UP), "target": target}

func update_aim_feedback(muzzle: Vector3, target: Vector3, chest: Vector3) -> void:
	aim_solution = predict_shot(muzzle, target, chest)
	if reticle != null: reticle.set_feedback(aim_solution, stage.camera, stage.aiming)

func fire(muzzle: Vector3,target: Vector3,chest: Vector3,profile: Dictionary=WEAPON_RULES.AK,weapon_id: String="ak") -> Dictionary:
	shots_fired+=1
	var guard_hit:=_ray(chest,muzzle)
	var start: Vector3=chest if not guard_hit.is_empty() else muzzle
	var base_direction: Vector3=(target-muzzle).normalized()
	var direction:=WEAPON_RULES.spread_direction(base_direction,profile,bool(stage.aiming),int(shots_fired*7919+stage.get_instance_id()%100000+stage.weapon_slot*977))
	var hit: Dictionary=guard_hit if not guard_hit.is_empty() else _ray(muzzle,muzzle+direction*float(profile.range))
	var endpoint: Vector3=hit.get("position",muzzle+direction*float(profile.range))
	var applied:=false
	var target_name:=""
	var headshot:=HIT_REGIONS.is_headshot(hit) if not hit.is_empty() else false
	var shot_damage:=WEAPON_RULES.damage(profile,headshot)*float(stage.skill_damage_multiplier() if stage.has_method("skill_damage_multiplier") else 1.0)
	if not hit.is_empty():
		var object: Object=hit.get("collider")
		var environment_hit := object == null or not object.has_method("receive_hit")
		if object!=null and object.has_method("receive_hit"):
			applied=object.receive_hit(shot_damage,direction,shots_fired,endpoint);target_name=str(object.name)
		elif object is RigidBody3D:object.apply_impulse(direction*1.6,endpoint-object.global_position)
		_spawn_impact(
			endpoint,
			hit.get("normal",Vector3.UP),
			_surface_color_at(endpoint, hit.get("normal",Vector3.UP), object),
			environment_hit
		)
		if applied:
			var victim_skin:=str(object.get("warrior_id")) if object!=null else "outrage"
			_spawn_damage_feedback(endpoint,direction,shot_damage,object.dead,blood_color_for_skin(victim_skin),true)
	if guard_hit.is_empty():_spawn_tracer(muzzle,endpoint,weapon_id)
	if reticle!=null:reticle.notify_shot()
	last_shot={"id":shots_fired,"damage_applied":applied,"target":target_name,"start":start,"end":endpoint,
		"blocked":not hit.is_empty(),"headshot":headshot,"damage":shot_damage if applied else 0.0,
		"occluded":not guard_hit.is_empty(),"guard_blocked":not guard_hit.is_empty(),"weapon":weapon_id,
		"spread_deg":WEAPON_RULES.spread_for(profile,bool(stage.aiming))}
	return last_shot

func fire_shotgun(muzzle: Vector3,target: Vector3,chest: Vector3) -> Dictionary:
	shots_fired += 1
	var profile: Dictionary=WEAPON_RULES.SHOTGUN
	var guard_hit:=_ray(chest,muzzle)
	var centre_dir: Vector3=(target-muzzle).normalized()
	var pellet_results: Array=[]
	var applied_damage:=0.0
	var headshots:=0
	var tracer_stride:=maxi(1,int(ceil(float(profile.pellets)/5.0)))
	for pellet in range(int(profile.pellets)):
		var direction: Vector3=WEAPON_RULES.spread_direction(centre_dir,profile,bool(stage.aiming),int(shots_fired*7919+stage.get_instance_id()%100000+pellet*131))
		var hit: Dictionary=guard_hit if not guard_hit.is_empty() else _ray(muzzle,muzzle+direction*float(profile.range))
		var endpoint: Vector3=hit.get("position",muzzle+direction*float(profile.range))
		var normal: Vector3=hit.get("normal",Vector3.UP)
		var pellet_headshot:=HIT_REGIONS.is_headshot(hit) if not hit.is_empty() else false
		var pellet_damage:=WEAPON_RULES.damage(profile,pellet_headshot)*float(stage.skill_damage_multiplier() if stage.has_method("skill_damage_multiplier") else 1.0)
		var applied:=false
		if not hit.is_empty():
			var object: Object=hit.get("collider")
			var environment_hit := object == null or not object.has_method("receive_hit")
			if object!=null and object.has_method("receive_hit"):
				applied=object.receive_hit(pellet_damage,direction,shots_fired*100+pellet,endpoint)
				if applied:
					applied_damage+=pellet_damage
					if pellet_headshot:headshots+=1
					var victim_skin:=str(object.get("warrior_id")) if object!=null else "outrage"
					_spawn_damage_feedback(endpoint,direction,pellet_damage,object.dead,blood_color_for_skin(victim_skin),true)
			elif object is RigidBody3D:
				object.apply_impulse(direction*2.6,endpoint-object.global_position)
			_spawn_impact(endpoint,normal,_surface_color_at(endpoint,normal,object),environment_hit)
		# Every pellet remains a real hitscan ray. Only a representative subset gets
		# a visual streak, keeping the shotgun dense without multiplying FX nodes.
		if pellet%tracer_stride==0:_spawn_tracer(muzzle,endpoint,"shotgun")
		pellet_results.append({"to":endpoint,"normal":normal,"hit":not hit.is_empty(),"headshot":pellet_headshot})
	if reticle!=null:
		reticle.notify_shot()
		if applied_damage>0.0:reticle.notify_hit(false)
	last_shot={"id":shots_fired,"weapon":"shotgun","pellets":pellet_results,"damage_applied":applied_damage>0.0,"damage":applied_damage,"headshots":headshots,"start":muzzle,"end":target,"guard_blocked":not guard_hit.is_empty()}
	return last_shot

func _spawn_tracer(start: Vector3, end: Vector3, weapon_id: String = "ak") -> void:
	var length := start.distance_to(end)
	if length < 0.03:
		return
	while active_tracers.size() >= MAX_ACTIVE_TRACERS:
		var oldest: Dictionary = active_tracers.pop_front()
		_release_tracer(oldest)
	tracer_serial += 1
	var direction := (end - start).normalized()
	var style := _projectile_style(weapon_id)
	var projectile_color: Color = style.get("color", Color("fff1a8"))
	var inferno := bool(style.get("inferno", false))
	var bundle := _acquire_tracer_bundle(inferno,projectile_color)
	var root := bundle.node as Node3D
	var core := bundle.core as MeshInstance3D
	var halo := bundle.halo as MeshInstance3D
	var head := bundle.head as MeshInstance3D
	var flames := bundle.get("flames") as GPUParticles3D
	root.name = "%sTracer%03d" % [weapon_id.capitalize(), tracer_serial]
	root.visible = true
	var hot_round := fx_rng.randf() < 0.12
	var chunky_round := fx_rng.randf() < 0.08
	var detail := _fx_detail(start)
	var width := fx_rng.randf_range(0.036,0.058) * (1.90 if chunky_round else 1.0)
	if detail == 0:
		width *= 1.28 # Far tracers stay readable even though their layered FX are reduced.
	var streak := minf(fx_rng.randf_range(1.00,1.55) * (1.25 if hot_round else 1.0), maxf(0.12,length * 0.58))
	core.scale = Vector3(width,width,streak)
	core.material_override = _projectile_material(projectile_color, 7.6 if hot_round else 6.5)
	halo.scale = Vector3(width * 4.2,width * 4.2,streak * 0.95)
	var halo_color := projectile_color.lightened(0.30)
	halo.material_override = _projectile_material(halo_color, 5.8 if inferno else 4.8, 0.48)
	halo.visible = detail >= 1
	head.scale = Vector3.ONE * width * (4.4 if chunky_round else 3.6)
	head.material_override = core.material_override
	head.position = Vector3(0,0,-streak * 0.52)
	head.visible = true
	if flames != null:
		flames.visible = detail >= 1
		flames.emitting = detail >= 1
		if detail >= 1:flames.restart()
	root.global_position = start + direction * minf(streak * 0.5,length * 0.5)
	root.look_at(root.global_position + direction, Vector3.RIGHT if absf(direction.y)>0.98 else Vector3.UP)
	active_tracers.append({
		"node":root,"core":core,"halo":halo,"head":head,"flames":flames,
		"start":start,"direction":direction,"length":length,"age":0.0,
		"duration":clampf(length / fx_rng.randf_range(235.0,285.0),0.028,0.12),
		"streak":streak,"width":width,"halo_base_scale":halo.scale,"head_base_scale":head.scale,"wobble":fx_rng.randf_range(0.0,0.018),
		"phase":fx_rng.randf_range(0.0,TAU),"spin":fx_rng.randf_range(-8.0,8.0),
		"trail_timer":0.0,"trail_interval":0.009 if detail==2 else (0.024 if detail==1 else 999.0),
		"hot":hot_round,"color":projectile_color,"inferno":inferno,"detail":detail
	})

func _spawn_trail_echo(position: Vector3, direction: Vector3, width: float, hot: bool, color: Color, inferno: bool, detail: int = 2) -> void:
	if direction.length_squared() < 0.0001:
		return
	if detail==1 and use_multimesh_trails:
		_spawn_multimesh_trail_echo(position,direction,width,hot,color,inferno)
		return
	while trail_echoes.size() >= MAX_TRAIL_ECHOES:
		var old: Dictionary = trail_echoes.pop_front()
		_release_trail_echo(old.get("node") as MeshInstance3D)
	var echo := _acquire_trail_echo()
	echo.visible = true
	echo.name = "BulletTrailEcho"
	var echo_len := fx_rng.randf_range(0.16,0.34) * (1.25 if hot else 1.0)
	echo.scale = Vector3(width * fx_rng.randf_range(2.0,2.8),width * fx_rng.randf_range(2.0,2.8),echo_len)
	var trail_color := color.lightened(0.20 if inferno else 0.10)
	echo.material_override = _projectile_material(trail_color, 5.6 if inferno else (4.8 if hot else 4.1), 0.42 if inferno else 0.34)
	var jitter := Vector3(fx_rng.randf_range(-0.014,0.014),fx_rng.randf_range(-0.014,0.014),fx_rng.randf_range(-0.014,0.014))
	echo.global_position = position + jitter
	echo.look_at(echo.global_position + direction.normalized(), Vector3.RIGHT if absf(direction.y)>0.98 else Vector3.UP)
	echo.transparency = fx_rng.randf_range(0.05,0.20)
	trail_echoes.append({
		"node":echo,
		"age":0.0,
		"duration":fx_rng.randf_range(0.10,0.16),
		"base_scale":echo.scale,
		"drift":Vector3(fx_rng.randf_range(-0.05,0.05),fx_rng.randf_range(0.01,0.08),fx_rng.randf_range(-0.05,0.05)),
		"spin":fx_rng.randf_range(-4.0,4.0)
	})

func _spawn_world_muzzle_flash(point: Vector3, direction: Vector3, local_boost: bool = false) -> void:
	if direction.length_squared() < 0.0001:
		return
	var detail := 2 if local_boost else _fx_detail(point)
	var bundle := _acquire_muzzle_flash()
	var root := bundle.node as Node3D
	var light := bundle.light as OmniLight3D
	var rays: Array = bundle.rays
	var ember := bundle.ember as MeshInstance3D
	root.name = "LocalMuzzleBurst" if local_boost else "RemoteMuzzleBurst"
	root.visible = true
	root.scale = Vector3.ONE * 0.70
	root.global_position = point
	root.look_at(point + direction.normalized(), Vector3.RIGHT if absf(direction.y)>0.98 else Vector3.UP)
	light.light_color = Color(1.0,fx_rng.randf_range(0.35,0.55),0.10)
	light.light_energy = fx_rng.randf_range(5.8,7.8) if local_boost else fx_rng.randf_range(2.8,4.4)
	light.omni_range = fx_rng.randf_range(2.0,2.8) if local_boost else fx_rng.randf_range(1.4,2.0)
	light.visible = detail >= 2 and (local_boost or _active_remote_muzzle_lights()<MAX_REMOTE_MUZZLE_LIGHTS)
	var color := Color("fff0a2") if fx_rng.randf() > 0.10 else (Color("84edff") if fx_rng.randf() > 0.5 else Color("ff5f9a"))
	var ray_count := 3 if local_boost else (2 if detail>=1 else 1)
	for i in range(rays.size()):
		var ray := rays[i] as MeshInstance3D
		ray.visible = i < ray_count
		if not ray.visible:continue
		var ray_width := fx_rng.randf_range(0.045,0.075) if local_boost else fx_rng.randf_range(0.028,0.048)
		var ray_length := fx_rng.randf_range(0.32,0.62) if local_boost else fx_rng.randf_range(0.18,0.34)
		ray.scale = Vector3(ray_width,ray_width,ray_length)
		ray.material_override = _fx_material(color,5.0)
		ray.position = Vector3(0,0,-ray_length*0.45)
		ray.rotation.z = i * TAU / float(maxi(1,ray_count)) + fx_rng.randf_range(-0.25,0.25)
	var ember_size := fx_rng.randf_range(0.055,0.085)
	ember.visible = local_boost or detail>=2
	ember.scale = Vector3.ONE*ember_size
	ember.position = Vector3(fx_rng.randf_range(-0.04,0.04),fx_rng.randf_range(-0.04,0.04),-0.22)
	ember.material_override = _fx_material(Color("ff7b45"),true,5.0)
	active_muzzle_flashes.append({"node":root,"light":light,"age":0.0,"duration":0.055,"local":local_boost})

func _spawn_impact(
		point: Vector3,
		normal: Vector3 = Vector3.UP,
		surface_color: Color = Color("fff5c2"),
		surface_debris: bool = false
	) -> void:
	var detail := _fx_detail(point)
	while active_impact_flashes.size() >= MAX_IMPACT_FLASHES:
		var oldest: Dictionary = active_impact_flashes.pop_front()
		_release_impact_flash(oldest.node as MeshInstance3D)
	var flash := _acquire_impact_flash()
	flash.visible = true
	flash.name = "ShotImpactFlash"
	flash.material_override = _surface_material(surface_color, 0.20) if surface_debris else impact_material
	flash.global_position = point + normal * 0.018
	flash.scale = Vector3.ONE * 0.45
	impacts.append(flash)
	active_impact_flashes.append({"node":flash,"age":0.0,"duration":0.125})
	if surface_debris and detail >= 1 and absf(normal.normalized().y) < 0.58:
		_spawn_bullet_hole(point, normal)
	var particle_count := 0
	if detail >= 2:
		particle_count = fx_rng.randi_range(10,15) if surface_debris else fx_rng.randi_range(4,7)
	elif detail == 1:
		particle_count = fx_rng.randi_range(5,8) if surface_debris else fx_rng.randi_range(2,4)
	else:
		particle_count = 2 if surface_debris else 1
	for i in range(particle_count):
		_trim_effect_meshes()
		var chip := _acquire_effect_mesh(false)
		chip.visible = false
		chip.name = "SurfaceDebrisParticle" if surface_debris else "ImpactSpark"
		var debris_scale := fx_rng.randf_range(1.10,1.65) if surface_debris else 1.0
		var particle_scale := Vector3(
			fx_rng.randf_range(0.018,0.035) * debris_scale,
			fx_rng.randf_range(0.018,0.035) * debris_scale,
			fx_rng.randf_range(0.07,0.16) * debris_scale
		)
		chip.scale = particle_scale
		if surface_debris:
			var variation := 0.16 if i % 3 == 0 else (-0.10 if i % 3 == 1 else 0.0)
			chip.material_override = _surface_material(surface_color, variation)
			var debris_color:=surface_color.lightened(variation) if variation>=0.0 else surface_color.darkened(-variation)
			chip.set_meta("kw_batch_color",debris_color)
		else:
			chip.material_override = impact_hot_material if i % 2 == 0 else impact_material
			chip.set_meta("kw_batch_color",Color("ff8b55") if i%2==0 else Color("fff5c2"))
		chip.global_position = point + normal * 0.025
		var tangent := Vector3(fx_rng.randf_range(-1.0,1.0),fx_rng.randf_range(-0.2,1.0),fx_rng.randf_range(-1.0,1.0)).normalized()
		var speed := (
			normal * fx_rng.randf_range(0.65,1.65)
			+ tangent * fx_rng.randf_range(0.45,1.45)
		) if surface_debris else (
			normal * fx_rng.randf_range(1.2,2.8)
			+ tangent * fx_rng.randf_range(0.8,2.2)
		)
		hit_effects.append({
			"node":chip,
			"base_scale":particle_scale,
			"batch_color":chip.get_meta("kw_batch_color",Color.WHITE),
			"age":0.0,
			"duration":fx_rng.randf_range(0.28,0.48) if surface_debris else fx_rng.randf_range(0.18,0.34),
			"velocity":speed,
			"number":false,
			"kind":"surface_debris" if surface_debris else "spark",
			"spin":fx_rng.randf_range(-11.0,11.0),
			"gravity":fx_rng.randf_range(3.5,6.5) if surface_debris else 9.8,
			"angular":Vector3(
				fx_rng.randf_range(-9.0,9.0),
				fx_rng.randf_range(-9.0,9.0),
				fx_rng.randf_range(-9.0,9.0)
			),
			"shrink_from":0.38 if surface_debris else 0.72,
		})

func _spawn_bullet_hole(point: Vector3, normal: Vector3) -> MeshInstance3D:
	while active_bullet_holes.size() >= MAX_BULLET_HOLES:
		var oldest: Dictionary = active_bullet_holes.pop_front()
		_release_bullet_hole(oldest.node as MeshInstance3D)
	var safe_normal := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.FORWARD
	var hole := _acquire_bullet_hole()
	hole.visible = false
	hole.name = "BulletHole"
	var diameter := fx_rng.randf_range(0.075,0.105)
	hole.scale = Vector3(diameter,diameter,1.0)
	hole.global_position = point + safe_normal * 0.012
	var up := Vector3.UP if absf(safe_normal.dot(Vector3.UP)) < 0.96 else Vector3.RIGHT
	hole.look_at(hole.global_position + safe_normal, up)
	hole.rotate_object_local(Vector3.FORWARD, fx_rng.randf_range(-PI, PI))
	hole.transparency = 0.02
	bullet_holes.append(hole)
	active_bullet_holes.append({"node":hole,"age":0.0,"hold":0.95,"fade":0.72,"base_scale":hole.scale})
	return hole

func _on_target_damaged(_target: Node3D, lethal: bool) -> void:
	hit_timer = 0.13
	lethal_hit = lethal
	if lethal:
		var id := _target.get_instance_id()
		if credited_kills.has(id): return
		credited_kills[id] = true
		kills += 1
		total_kills += 1
		score_pulse = 0.65
		if director != null: director.on_kill(_target)
	if reticle != null: reticle.notify_hit(lethal)
	if confirm_audio != null:
		confirm_audio.stream = confirm_kill if lethal else confirm_hit
		confirm_audio.play()
	_update_counter()

func _update_counter() -> void:
	_set_label_text(counter,"ENTER / B: new run after defeat")
	_set_label_text(kill_label,"KILLS  %d" % total_kills)
	var alive := 0
	for target in targets:
		if is_instance_valid(target) and not target.dead: alive += 1
	_set_label_text(alive_label,"ENEMIES  %d" % alive)
	if wave_label != null and director != null:
		_set_label_text(wave_label,"WAVE %02d   //   %d LEFT" % [director.wave,director.remaining_count()])

func _set_label_text(label: Label,value: String) -> void:
	if label!=null and label.text!=value:label.text=value

func is_game_over() -> bool:
	return director != null and director.dead

func set_training_mode(value: bool) -> void:
	# Explicit test/training switch; QA does NOT silently disable live gameplay.
	if director != null:
		director.attacks_enabled = not value
		director.advancement_enabled = not value
		if value: director.clear_projectiles()

func _physics_process(delta: float) -> void:
	if director == null: return
	if not OS.get_cmdline_user_args().has("--kw-qa") and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	director.tick(delta)

func _process(delta: float) -> void:
	hit_timer = maxf(0, hit_timer - delta)
	_update_feedback_effects(delta)
	_update_batched_blood_fx()
	_update_batched_impact_fx()
	_update_multimesh_trails(delta)
	for index in range(active_muzzle_flashes.size()-1,-1,-1):
		var flash_data: Dictionary = active_muzzle_flashes[index]
		var flash_root := flash_data.node as Node3D
		if not is_instance_valid(flash_root):
			active_muzzle_flashes.remove_at(index)
			continue
		flash_data.age = float(flash_data.age)+delta
		var fp := clampf(float(flash_data.age)/maxf(0.001,float(flash_data.duration)),0.0,1.0)
		flash_root.scale = Vector3.ONE*lerpf(0.70,1.45,fp)
		var light := flash_data.light as OmniLight3D
		if light != null and light.visible:
			light.light_energy *= maxf(0.0,1.0-delta*18.0)
		if fp >= 1.0:
			_release_muzzle_flash(flash_data)
			active_muzzle_flashes.remove_at(index)
	for index in range(active_impact_flashes.size()-1,-1,-1):
		var impact_data: Dictionary = active_impact_flashes[index]
		var impact := impact_data.node as MeshInstance3D
		if not is_instance_valid(impact):
			active_impact_flashes.remove_at(index)
			continue
		impact_data.age = float(impact_data.age)+delta
		var ip := clampf(float(impact_data.age)/maxf(0.001,float(impact_data.duration)),0.0,1.0)
		if ip < 0.44:
			impact.scale = Vector3.ONE*lerpf(0.45,1.9,ip/0.44)
		else:
			impact.scale = Vector3.ONE*lerpf(1.9,0.08,(ip-0.44)/0.56)
		if ip >= 1.0:
			_release_impact_flash(impact)
			active_impact_flashes.remove_at(index)
	for index in range(active_bullet_holes.size()-1,-1,-1):
		var hole_data: Dictionary = active_bullet_holes[index]
		var hole := hole_data.node as MeshInstance3D
		if not is_instance_valid(hole):
			active_bullet_holes.remove_at(index)
			continue
		hole_data.age = float(hole_data.age)+delta
		var hold := float(hole_data.hold)
		var fade := float(hole_data.fade)
		if float(hole_data.age) > hold:
			var hp := clampf((float(hole_data.age)-hold)/maxf(0.001,fade),0.0,1.0)
			hole.transparency = lerpf(0.02,1.0,hp)
			hole.scale = (hole_data.base_scale as Vector3)*lerpf(1.0,0.72,hp)
			if hp >= 1.0:
				_release_bullet_hole(hole)
				active_bullet_holes.remove_at(index)
	_update_batched_bullet_holes()
	for index in range(trail_echoes.size()-1,-1,-1):
		var echo_data: Dictionary = trail_echoes[index]
		var echo: MeshInstance3D = echo_data["node"]
		if not is_instance_valid(echo):
			trail_echoes.remove_at(index)
			continue
		echo_data["age"] = float(echo_data["age"]) + delta
		var ep := clampf(float(echo_data["age"]) / float(echo_data["duration"]),0.0,1.0)
		echo.global_position += (echo_data["drift"] as Vector3) * delta
		echo.rotate_object_local(Vector3.FORWARD,float(echo_data["spin"]) * delta)
		echo.transparency = lerpf(0.10,1.0,ep)
		var shrink := maxf(0.05,1.0-ep*0.82)
		var echo_base := echo_data.get("base_scale",Vector3.ONE) as Vector3
		echo.scale = Vector3(echo_base.x*shrink,echo_base.y*shrink,echo_base.z*maxf(0.16,1.0-ep*0.55))
		if ep >= 1.0:
			_release_trail_echo(echo)
			trail_echoes.remove_at(index)
	for index in range(active_tracers.size()-1,-1,-1):
		var data: Dictionary = active_tracers[index]
		var node: Node3D = data["node"]
		if not is_instance_valid(node):
			active_tracers.remove_at(index)
			continue
		data["age"] += delta
		data["trail_timer"] = float(data.get("trail_timer",0.0)) + delta
		var p := minf(1.0, float(data["age"]) / float(data["duration"]))
		var length := float(data["length"])
		var streak := float(data["streak"])
		var travel := lerpf(minf(streak * 0.25,length * 0.25), maxf(streak * 0.25,length - streak * 0.25), p)
		node.global_position = data["start"] + data["direction"] * travel
		var trail_interval := float(data.get("trail_interval",0.009))
		while float(data["trail_timer"]) >= trail_interval:
			data["trail_timer"] = float(data["trail_timer"]) - trail_interval
			var trail_pos: Vector3 = node.global_position - (data["direction"] as Vector3) * float(data["streak"]) * 0.42
			_spawn_trail_echo(
				trail_pos,
				data["direction"],
					float(data["width"]),
					bool(data.get("hot",false)),
					data.get("color", Color("fff1a8")) as Color,
					bool(data.get("inferno",false)),
					int(data.get("detail",2))
				)
		node.rotate_object_local(Vector3.FORWARD,float(data["spin"]) * delta)
		var halo: MeshInstance3D = data["halo"]
		var head: MeshInstance3D = data["head"]
		if is_instance_valid(halo):
			halo.position.x = sin(p * TAU * 1.25 + float(data["phase"])) * float(data["wobble"])
			var halo_base := data.get("halo_base_scale",Vector3.ONE) as Vector3
			var halo_xy := 1.0 + sin(p * PI) * 0.32
			halo.scale = Vector3(halo_base.x*halo_xy,halo_base.y*halo_xy,halo_base.z*maxf(0.08,1.0-p*0.58))
		if is_instance_valid(head):
			head.position.x = cos(p * TAU + float(data["phase"])) * float(data["wobble"]) * 0.55
			var head_base := data.get("head_base_scale",Vector3.ONE) as Vector3
			head.scale = head_base*(1.15 + sin(p * PI) * 0.60)
		if p >= 1.0:
			_release_tracer(data)
			active_tracers.remove_at(index)

func _build_confirm_audio() -> void:
	confirm_hit = _make_tick(false)
	confirm_kill = _make_tick(true)
	confirm_audio = AudioStreamPlayer.new()
	confirm_audio.name = "HitConfirmAudio"
	confirm_audio.volume_db = -80.0 if OS.get_cmdline_user_args().has("--kw-qa") else -14.0
	confirm_audio.bus="SFX"
	confirm_audio.max_polyphony = 3
	add_child(confirm_audio)

func _make_tick(lethal: bool) -> AudioStreamWAV:
	# Original quiet, dry confirmation tones; only on confirmed damage.
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var duration := 0.065 if lethal else 0.030
	var samples := int(duration * stream.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(stream.mix_rate)
		var envelope := minf(1.0, t / 0.0015) * pow(1.0 - t / duration, 3.0)
		var wave := sin(TAU * (920.0 if lethal else 670.0) * t) * 0.50
		wave += sin(TAU * (1380.0 if lethal else 1340.0) * t) * 0.18
		bytes.encode_s16(i * 2, int(wave * envelope * 20000.0))
	stream.data = bytes
	return stream

func set_roaming_enabled(value: bool) -> void:
	roaming_enabled = value
	for target in targets:
		if is_instance_valid(target): target.roaming_enabled = value

func _build_score_hud() -> void:
	# Kept separate from the help overlay: TAB cannot hide combat feedback.
	var panel := Control.new()
	panel.name = "CombatScore"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.get_node("HUD").add_child(panel)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -148
	panel.offset_right = -12
	panel.offset_top = 9
	panel.offset_bottom = 74
	var background := ColorRect.new()
	background.color = Color(0.025, 0.03, 0.055, 0.8)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	kill_label = Label.new()
	kill_label.name = "KillCounter"
	kill_label.position = Vector2(9, 2)
	kill_label.size = Vector2(118, 23)
	kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kill_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(kill_label)
	alive_label = Label.new()
	alive_label.name = "AliveCounter"
	alive_label.position = Vector2(9, 27)
	alive_label.size = Vector2(118, 15)
	alive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	alive_label.add_theme_font_size_override("font_size", 10)
	alive_label.add_theme_color_override("font_color", Color("9bb9ca"))
	panel.add_child(alive_label)
	wave_label = Label.new()
	wave_label.position = Vector2(0, 46)
	wave_label.size = Vector2(127, 19)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wave_label.add_theme_font_size_override("font_size", 10)
	wave_label.add_theme_color_override("font_color",Color("ffd68a"))
	panel.add_child(wave_label)
	kill_notice = Label.new()
	kill_notice.name = "KillNotice"
	kill_notice.text = "+1 KILL"
	kill_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kill_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kill_notice.add_theme_font_size_override("font_size", 13)
	kill_notice.add_theme_color_override("font_color", Color("ffd287"))
	kill_notice.add_theme_constant_override("outline_size", 3)
	stage.get_node("HUD").add_child(kill_notice)
	kill_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	kill_notice.offset_left = -48
	kill_notice.offset_right = 48
	kill_notice.offset_top = 33
	kill_notice.offset_bottom = 56
	kill_notice.hide()

func _spawn_damage_feedback(point: Vector3,direction: Vector3,amount: float,lethal: bool,blood_color: Color = Color("fa0512"),show_number: bool = true) -> void:
	# Cosmetic only. Randomness changes presentation, never hit direction or damage.
	_trim_effect_meshes()
	if director != null and show_number:
		director.hud.damage_number(point, amount, lethal)
	var blood_material := _fx_material(blood_color,5.4)
	var blood_hot := _fx_material(blood_color.lightened(0.30),7.2)
	var detail := _fx_detail(point)
	var count := 0
	if detail >= 2:
		count = fx_rng.randi_range(38,52) if lethal else fx_rng.randi_range(20,28)
	elif detail == 1:
		count = fx_rng.randi_range(18,26) if lethal else fx_rng.randi_range(9,14)
	else:
		count = fx_rng.randi_range(7,11) if lethal else fx_rng.randi_range(4,7)
	var bonk := fx_rng.randf() < 0.10
	for i in range(count):
		_trim_effect_meshes()
		var outlined := i < 4 and detail >= 2
		var chip := _acquire_effect_mesh(outlined)
		chip.visible = outlined
		var base_size:=fx_rng.randf_range(0.15,0.27)*(2.15 if lethal and i<7 else 1.0)
		var shape_roll:=fx_rng.randf()
		var chunk_scale := Vector3.ONE*base_size
		if shape_roll<0.42:
			chunk_scale=Vector3(base_size*fx_rng.randf_range(0.75,1.35),base_size*fx_rng.randf_range(0.65,1.25),base_size*fx_rng.randf_range(0.75,1.55))
		elif shape_roll<0.78:
			chunk_scale=Vector3(base_size*fx_rng.randf_range(0.35,0.65),base_size*fx_rng.randf_range(0.45,0.85),base_size*fx_rng.randf_range(1.7,3.0))
		else:
			chunk_scale=Vector3(base_size*fx_rng.randf_range(1.4,2.3),base_size*fx_rng.randf_range(0.25,0.55),base_size*fx_rng.randf_range(0.55,1.15))
		chip.scale = chunk_scale
		chip.material_override = blood_hot if i % 4 == 0 else blood_material
		chip.global_position=point+Vector3(fx_rng.randf_range(-0.14,0.14),fx_rng.randf_range(-0.08,0.16),fx_rng.randf_range(-0.14,0.14))
		var radial:=Vector3(fx_rng.randf_range(-1.0,1.0),fx_rng.randf_range(-0.20,1.0),fx_rng.randf_range(-1.0,1.0)).normalized()
		var spray_sign:=1.0 if fx_rng.randf()>0.18 else -0.35
		var speed:=direction.normalized()*fx_rng.randf_range(1.0,4.4)*spray_sign+radial*fx_rng.randf_range(0.8,4.0)+Vector3.UP*fx_rng.randf_range(0.2,2.6)
		if bonk and i==0:speed*=1.7
		var angular:=Vector3(fx_rng.randf_range(-13.0,13.0),fx_rng.randf_range(-13.0,13.0),fx_rng.randf_range(-13.0,13.0))
		hit_effects.append({"node":chip,"base_scale":chunk_scale,"outlined":outlined,"batch_color":blood_color.lightened(0.30) if i%4==0 else blood_color,"age":0.0,"duration":fx_rng.randf_range(0.95,1.45) if lethal else fx_rng.randf_range(0.68,1.12),"velocity":speed,"number":false,"kind":"blood_chunk","gravity":fx_rng.randf_range(8.8,14.0),"drag":fx_rng.randf_range(0.20,0.85),"angular":angular})

func _update_feedback_effects(delta: float) -> void:
	score_pulse = maxf(0.0, score_pulse - delta)
	if kill_label != null:
		kill_label.modulate = Color.WHITE.lerp(Color("ffd18a"), minf(1.0, score_pulse * 3.0))
	if kill_notice != null:
		kill_notice.visible = score_pulse > 0.0
		kill_notice.modulate.a = minf(1.0, score_pulse * 5.0)
	for i in range(hit_effects.size() - 1, -1, -1):
		var effect: Dictionary = hit_effects[i]
		var node: Node3D = effect.node
		if not is_instance_valid(node):
			hit_effects.remove_at(i)
			continue
		effect.age += delta
		node.global_position += (effect.velocity as Vector3) * delta
		if effect.number:
			(node as Label3D).modulate.a = minf(1.0, (float(effect.duration) - float(effect.age)) * 6.0)
		else:
			var velocity: Vector3=effect.velocity
			velocity*=exp(-float(effect.get("drag",0.35))*delta)
			velocity.y-=float(effect.get("gravity",9.8))*delta
			effect.velocity=velocity
			if node is MeshInstance3D:
				(node as MeshInstance3D).rotation+=(effect.get("angular",Vector3.ZERO) as Vector3)*delta
			var ratio:=clampf(float(effect.age)/maxf(0.001,float(effect.duration)),0.0,1.0)
			var shrink_from:=clampf(float(effect.get("shrink_from",0.72)),0.0,0.96)
			var scale_factor:=1.0 if ratio<shrink_from else lerpf(1.0,0.05,(ratio-shrink_from)/maxf(0.04,1.0-shrink_from))
			var base_scale:=effect.get("base_scale",Vector3.ONE) as Vector3
			node.scale=base_scale*scale_factor
		if float(effect.age) >= float(effect.duration):
			if node is MeshInstance3D and bool(node.get_meta("kw_pooled_effect",false)):_release_effect_mesh(node as MeshInstance3D)
			else:node.queue_free()
			hit_effects.remove_at(i)
