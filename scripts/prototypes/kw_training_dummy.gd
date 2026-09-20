extends StaticBody3D
## Roaming practice clone: separate movement capsule and exact animated shot shapes.
signal damaged(target: Node3D, lethal: bool)
const SCENE_INK := preload("res://scripts/prototypes/kw_scene_ink.gd")
const VOXEL_DAMAGE_VISUAL := preload("res://scripts/kw3d/voxel_damage_visual.gd")
const ROAMING := preload("res://scripts/prototypes/kw_roaming_brain.gd")
const LOCOMOTION := preload("res://scripts/prototypes/kw_goofy_locomotion.gd")
@export var roaming_enabled := true
var roam_bounds := Rect2(-21, -27, 42, 42)
var roam_seed := 137
var movement_body: CharacterBody3D
var brain: RefCounted
var locomotion: RefCounted
var hit_offset := Vector3.ZERO
var hit_offset_velocity := Vector3.ZERO
var hit_squash := 0.0
const BODY := preload("res://scenes/prototypes/characters/outrage_fullbody.tscn")
const TOON := preload("res://scripts/prototypes/kw_comic_toon.gdshader")
const INK := preload("res://scripts/prototypes/kw_comic_ink.gdshader")
const PIXELS := preload("res://scripts/prototypes/kw_pixel_materials.gd")
@export_enum("tasko", "gan", "celler", "nova", "m4", "crashout") var warrior_id := "tasko"
@export var max_health := 100.0
var health := 100.0
var dead := false
var hit_count := 0
var flash_time := 0.0
var death_time := 0.0
var time := 0.0
var pixel_enabled := true
var comic_enabled := true
var visuals: Node3D
var health_bar: Sprite3D
var name_label: Label3D
var bar_texture: ImageTexture
var records: Array[Dictionary] = []
var rigs: Array[Dictionary] = []
var hit_shapes: Array[Dictionary] = []
var damage_visual: Node
var body_bridge: CollisionShape3D
const BODY_BRIDGE_RADIUS := 0.24
const BODY_BRIDGE_HEAD_CLEARANCE := 0.46
const BODY_BRIDGE_TORSO_DROP := 0.48
var seen_shots: Dictionary = {}
var flash_material: StandardMaterial3D
var recoil := Vector3.ZERO
var recoil_velocity := Vector3.ZERO
var weapon_mount: Node3D
var weapon_muzzle: Marker3D
var attack_label: Label3D
var attack_warning := false
var trail_health := 100.0
var trail_delay := 0.0
var bar_last_trail := 100
var gun_flash := 0.0
var gun_glow: MeshInstance3D
var attack_audio: AudioStreamPlayer3D

func _ready() -> void:
	# Update visual wobble and matching hit shapes BEFORE the player traces this tick.
	process_physics_priority = -20
	collision_layer = 4
	collision_mask = 0
	health = max_health
	add_to_group("kw_training_targets")
	flash_material = StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = Color.WHITE
	flash_material.render_priority = 2
	_build_visuals()
	damage_visual=VOXEL_DAMAGE_VISUAL.new();add_child(damage_visual)
	damage_visual.setup(visuals,["HeadRig","TorsoRig","LeftLegRig","RightLegRig"],int(get_instance_id()%2147483647))
	damage_visual.set_pixel_enabled(pixel_enabled)
	_build_body_bridge()
	_build_healthbar()
	_build_enemy_weapon()
	_setup_roaming()
	_update_shapes()

func _color_material(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON
	mat.set_shader_parameter("base_color", color)
	mat.set_shader_parameter("use_texture", false)
	mat.set_shader_parameter("pixel_enabled", pixel_enabled)
	return mat

func _record_mesh(mesh: MeshInstance3D, color: Color, hurtbox: bool = true) -> void:
	var plain := StandardMaterial3D.new()
	plain.albedo_color = color
	plain.roughness = 0.95
	var toon := _color_material(color)
	var pixel := PIXELS.from_standard(plain)
	mesh.material_override = toon
	records.append({"mesh": mesh, "plain": plain, "toon": toon, "pixel": pixel})
	if not hurtbox: return
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mesh.mesh.get_aabb().size
	shape.shape = box
	shape.set_meta("hit_region","head" if mesh.get_parent()!=null and str(mesh.get_parent().name)=="HeadRig" else "body")
	add_child(shape)
	hit_shapes.append({"shape": shape, "mesh": mesh})

func _build_body_bridge() -> void:
	body_bridge=CollisionShape3D.new()
	body_bridge.name="BodyBridgeHurtbox"
	var cylinder:=CylinderShape3D.new()
	cylinder.radius=BODY_BRIDGE_RADIUS
	cylinder.height=1.0
	body_bridge.shape=cylinder
	body_bridge.set_meta("hit_region","body")
	add_child(body_bridge)
	_update_body_bridge()

func _update_body_bridge() -> void:
	if body_bridge==null or visuals==null:return
	var torso:=visuals.get_node_or_null("TorsoRig") as Node3D
	var head:=visuals.get_node_or_null("HeadRig") as Node3D
	if torso==null or head==null:return
	var top_y:=head.global_position.y-BODY_BRIDGE_HEAD_CLEARANCE
	var bottom_y:=torso.global_position.y-BODY_BRIDGE_TORSO_DROP
	var height:=maxf(0.58,top_y-bottom_y)
	var centre:=Vector3(lerpf(torso.global_position.x,head.global_position.x,0.30),(top_y+bottom_y)*0.5,lerpf(torso.global_position.z,head.global_position.z,0.30))
	var cylinder:=body_bridge.shape as CylinderShape3D
	cylinder.radius=BODY_BRIDGE_RADIUS;cylinder.height=height
	body_bridge.transform=global_transform.affine_inverse()*Transform3D(Basis.IDENTITY,centre)

func _box(parent: Node3D, title: String, pos: Vector3, size: Vector3, color: Color, hurtbox: bool = true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	parent.add_child(mesh)
	_record_mesh(mesh, color, hurtbox)
	if title != "Head": SCENE_INK.add_to(mesh,comic_enabled,1.4)
	return mesh

func _build_visuals() -> void:
	visuals = Node3D.new()
	visuals.name = "Visuals"
	add_child(visuals)
	# Palettes and distinguishing features sampled from each existing warrior.
	var primary := Color("bf3fff")
	var accent := Color("e1a5ff")
	if warrior_id == "gan":
		primary = Color("7ab1b7")
		accent = Color("ccf2f4")
	elif warrior_id == "celler":
		primary = Color("eaeaea")
		accent = Color("630000")
	elif warrior_id == "nova":
		primary = Color("334756")
		accent = Color("ff4c29")
	elif warrior_id == "m4":
		primary = Color("c59370")
		accent = Color("3e2f24")
	elif warrior_id == "crashout":
		primary = Color("a11b1b")
		accent = Color("fff296")
	var source := BODY.instantiate() as Node3D
	for rig_name in ["TorsoRig", "LeftLegRig", "RightLegRig"]:
		var original: Node3D = source.get_node(rig_name)
		var rig := Node3D.new()
		rig.name = rig_name
		rig.transform = original.transform
		if rig_name == "TorsoRig": rig.position += Vector3(0, -0.12, 0.12)
		visuals.add_child(rig)
		for part in original.get_children():
			if not part is MeshInstance3D: continue
			var clone := MeshInstance3D.new()
			clone.name = part.name
			clone.mesh = part.mesh
			clone.transform = part.transform
			rig.add_child(clone)
			if part.name == "ShaderInkOutline":
				clone.material_override = part.material_override.duplicate()
				clone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else:
				_record_mesh(clone, primary)
		rigs.append({"node": rig, "rest": rig.position, "velocity": Vector3.ZERO})
	source.free()
	var head := Node3D.new()
	head.name = "HeadRig"
	head.position = Vector3(0,1.12,-0.16)
	visuals.add_child(head)
	_box(head, "Head", Vector3.ZERO, Vector3(0.82,0.78,0.78), accent if warrior_id == "gan" else primary)
	if warrior_id == "tasko":
		_box(head, "PurpleVisor", Vector3(0,0,-0.415), Vector3(0.88,0.42,0.08), primary)
		_box(head, "VisorHighlight", Vector3(-0.18,0.15,-0.465), Vector3(0.28,0.07,0.04), accent)
		for x in [-0.24,0.24]: _box(head, "Eye", Vector3(x,-0.08,-0.48), Vector3(0.12,0.12,0.08), Color("151020"))
	elif warrior_id == "gan":
		_box(head, "WhiteHairCap", Vector3(0,0.41,0.02), Vector3(0.90,0.24,0.78), Color.WHITE)
		_box(head, "WhiteHairTuft", Vector3(-0.16,0.57,0.06), Vector3(0.50,0.12,0.52), Color.WHITE)
		_box(head, "HairSide", Vector3(-0.43,0.26,0.04), Vector3(0.16,0.22,0.68), Color.WHITE)
		for x in [-0.22,0.22]: _box(head, "Eye", Vector3(x,-0.10,-0.43), Vector3(0.10,0.10,0.08), Color("183a3d"))
	elif warrior_id == "celler":
		_box(head, "DarkFace", Vector3(0,0,-0.41), Vector3(0.62,0.58,0.09), Color("232323"))
		for x in [-0.17,0.17]: _box(head, "Eye", Vector3(x,0.02,-0.47), Vector3(0.09,0.09,0.05), Color.WHITE)
		var torso: Node3D = visuals.get_node("TorsoRig")
		for yy in [0.20,0.39,0.58]: _box(torso, "RedIndicator", Vector3(0.12,yy,-0.365), Vector3(0.15,0.07,0.04), accent)
	elif warrior_id == "nova":
		_box(head,"HelmetCrest",Vector3(0,0.40,0.03),Vector3(0.28,0.14,0.65),primary)
		_box(head,"EmberVisor",Vector3(0,0.03,-0.42),Vector3(0.86,0.15,0.12),accent)
		_box(head,"VisorGlow",Vector3(0.19,0.03,-0.49),Vector3(0.27,0.08,0.035),Color("fff2d5"))
		for side in [-1.0,1.0]: _box(head,"HelmetWing",Vector3(side*0.44,0.0,0.02),Vector3(0.12,0.52,0.66),Color("23303a"))
	elif warrior_id == "m4":
		_box(head,"HatCrown",Vector3(0,0.44,0),Vector3(0.72,0.28,0.68),Color("171316"))
		_box(head,"WideHatBrim",Vector3(0,0.27,-0.07),Vector3(1.04,0.10,0.86),accent)
		_box(head,"Beard",Vector3(0,-0.24,-0.415),Vector3(0.65,0.22,0.10),accent)
		for x in [-0.22,0.22]: _box(head,"Eye",Vector3(x,0.01,-0.43),Vector3(0.12,0.10,0.07),Color("161216"))
	elif warrior_id == "crashout":
		_box(head,"TanFace",Vector3(0,-0.01,-0.42),Vector3(0.68,0.60,0.10),Color("c59370"))
		_box(head,"StrawHatBrim",Vector3(0,0.34,-0.09),Vector3(1.09,0.13,0.94),accent)
		_box(head,"StrawHatCrown",Vector3(-0.04,0.49,0.03),Vector3(0.68,0.22,0.61),accent)
		_box(head,"HatBand",Vector3(-0.04,0.40,-0.285),Vector3(0.69,0.10,0.04),Color("a11b1b"))
		for x in [-0.20,0.20]: _box(head,"Eye",Vector3(x,-0.02,-0.49),Vector3(0.12,0.12,0.07),Color("171217"))
	# One smooth-normal outer shell for the head, not an outline per tiny pixel.
	var outer := MeshInstance3D.new()
	outer.name = "ShaderInkOutline"
	outer.mesh = _outline_box(Vector3(0.82,0.78,0.78))
	var ink := ShaderMaterial.new()
	ink.shader = INK
	outer.material_override = ink
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.add_child(outer)
	rigs.append({"node": head, "rest": head.position, "velocity": Vector3.ZERO})

func _outline_box(size: Vector3) -> ArrayMesh:
	var cube := BoxMesh.new()
	cube.size = size
	var arrays: Array = cube.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals := PackedVector3Array()
	for p in vertices: normals.append((p / size).normalized())
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _build_healthbar() -> void:
	health_bar = Sprite3D.new()
	health_bar.name = "HealthBar"
	health_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_bar.pixel_size = 0.016
	health_bar.position = Vector3(0,2.13,0)
	health_bar.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	health_bar.render_priority=127
	add_child(health_bar)
	name_label = Label3D.new()
	name_label.name = "TargetName"
	name_label.text = warrior_id.to_upper() + " // CLONE"
	name_label.font_size = 38
	name_label.pixel_size = 0.006
	name_label.outline_size = 6
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.position = Vector3(0,2.48,0)
	name_label.render_priority=126
	add_child(name_label)
	_refresh_bar()

func _refresh_bar() -> void:
	var image := Image.create(128,18,false,Image.FORMAT_RGBA8)
	image.fill(Color("111726"))
	image.fill_rect(Rect2i(2,2,124,14),Color("351621"))
	var trailing := int(round(120.0*trail_health/max_health))
	if trailing > 0: image.fill_rect(Rect2i(4,4,trailing,10),Color("ffc187"))
	var width := int(round(120.0*health/max_health))
	if width > 0:
		image.fill_rect(Rect2i(4,4,width,10),Color("ff586e"))
		image.fill_rect(Rect2i(4,4,width,2),Color("ff9aac"))
	for i in range(1,5): image.fill_rect(Rect2i(4+i*24,4,1,10),Color("562333"))
	if bar_texture == null:
		bar_texture=ImageTexture.create_from_image(image)
		health_bar.texture=bar_texture
	else: bar_texture.update(image)

func receive_hit(amount: float, direction: Vector3, shot_id: int, impact_point: Vector3 = Vector3.INF) -> bool:
	if dead or amount <= 0.0 or seen_shots.has(shot_id): return false
	seen_shots[shot_id] = true
	trail_delay = 0.22
	health = maxf(0.0,health-amount)
	if damage_visual!=null:
		var point:=impact_point if impact_point.is_finite() else visuals.global_position+Vector3(0,0.45,0)
		damage_visual.damage_at(point,health,max_health,amount,direction)
	hit_count += 1
	flash_time = 0.075
	for record in records: record.mesh.material_overlay = flash_material
	var local_direction := global_basis.inverse() * direction
	local_direction = visuals.global_basis.inverse() * direction
	recoil_velocity = (recoil_velocity + Vector3(local_direction.z,0,-local_direction.x) * 2.8).limit_length(6.5)
	hit_offset_velocity = (hit_offset_velocity + local_direction * 1.5).limit_length(3.0)
	hit_squash = 1.0
	if brain != null and roaming_enabled: brain.impulse(direction, 3.2)
	_refresh_bar()
	if health <= 0.0: _die(direction)
	damaged.emit(self,dead)
	return true

func show_network_hit(direction: Vector3, lethal: bool = false) -> void:
	if dead:
		return
	flash_time = 0.09
	for record in records:
		record.mesh.material_overlay = flash_material
	var local_direction := visuals.global_basis.inverse() * direction
	recoil_velocity = (recoil_velocity + Vector3(local_direction.z,0,-local_direction.x) * 3.4).limit_length(7.5)
	hit_offset_velocity = (hit_offset_velocity + local_direction * 1.85).limit_length(3.6)
	hit_squash = 1.15
	if lethal:
		_die(direction)

func _die(direction: Vector3) -> void:
	dead = true
	set_attack_warning(false)
	if weapon_mount != null: weapon_mount.visible = false
	collision_layer = 0
	if movement_body != null:
		movement_body.collision_layer = 0
		movement_body.collision_mask = 0
		movement_body.velocity = Vector3.ZERO
	for data in hit_shapes: data.shape.set_deferred("disabled",true)
	health_bar.visible = false
	name_label.visible = false
	death_time = 0.0
	for i in range(rigs.size()):
		var dir := visuals.global_basis.inverse() * direction
		rigs[i].velocity = dir * (2.8+i*0.55) + Vector3(sin(i*2.1)*2.25,3.5+i*0.55,cos(i*1.8)*1.35)

func _physics_process(delta: float) -> void:
	time += delta
	_update_readability(delta)
	if flash_time > 0.0:
		flash_time = maxf(0.0,flash_time-delta)
		if flash_time <= 0.0:
			for record in records: record.mesh.material_overlay = null
	if dead:
		death_time += delta
		for i in range(rigs.size()):
			var rig: Node3D = rigs[i].node
			var v: Vector3 = rigs[i].velocity
			v.y -= delta*10.0
			rig.position += v*delta
			rig.rotation += Vector3(1.3+i*0.35,(-1.0 if i%2 else 1.0)*2.0,0.7)*delta
			rigs[i].velocity = v
			if rig.position.y < -1.35:
				rig.position.y = -1.35
				rigs[i].velocity = Vector3(v.x*0.8,0,v.z*0.8)
			if death_time > 1.90: rig.scale = Vector3.ONE * maxf(0.001,1.0-(death_time-1.90)/0.90)
		if death_time >= 2.80: queue_free()
		return
	_update_roaming_and_reaction(delta)
	_update_shapes()

func _update_shapes() -> void:
	for data in hit_shapes:
		var mesh: MeshInstance3D = data.mesh
		var shape: CollisionShape3D = data.shape
		var relative := global_transform.affine_inverse()*mesh.global_transform
		var wanted_size := mesh.mesh.get_aabb().size * relative.basis.get_scale().abs()
		var box := shape.shape as BoxShape3D
		if not box.size.is_equal_approx(wanted_size): box.size = wanted_size
		shape.transform = Transform3D(relative.basis.orthonormalized(), relative.origin)
	_update_body_bridge()

func set_style(comic: bool, pixels: bool) -> void:
	comic_enabled = comic
	pixel_enabled = pixels
	for record in records:
		record.toon.set_shader_parameter("pixel_enabled",pixels)
		record.pixel.set_shader_parameter("pixel_enabled",pixels)
		record.mesh.material_override = record.toon if comic else record.pixel if pixels else record.plain
	if visuals != null:
		for rig in visuals.get_children():
			for part in rig.get_children():
				if part.name == "ShaderInkOutline": part.visible = comic
	for shell in find_children("WorldInkOutline","MeshInstance3D",true,false): shell.visible=comic
	if damage_visual!=null:
		damage_visual.set_pixel_enabled(pixels)
		damage_visual.set_comic_enabled(comic)

func _setup_roaming() -> void:
	# The movement capsule is physical layer 8, not a shot hitbox. Animated mesh
	# boxes plus a thin body bridge cylinder stay on StaticBody layer 4.
	movement_body = CharacterBody3D.new()
	movement_body.name = "MovementBody"
	movement_body.top_level = true
	movement_body.collision_layer = 8
	movement_body.collision_mask = 11 # world + player + other movement capsules
	movement_body.floor_snap_length = 0.3
	movement_body.safe_margin = 0.004
	add_child(movement_body)
	movement_body.global_position = global_position
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 3.43
	capsule.radius = 0.44
	collider.shape = capsule
	movement_body.add_child(collider)
	brain = ROAMING.new()
	brain.setup(movement_body, visuals, roam_bounds, roam_seed)
	locomotion = LOCOMOTION.new()
	locomotion.setup(movement_body, visuals, visuals.get_node("HeadRig"), visuals.get_node("TorsoRig"), visuals.get_node("LeftLegRig"), visuals.get_node("RightLegRig"), roam_seed + 913)
	locomotion.playfulness = 1.35

func _update_roaming_and_reaction(delta: float) -> void:
	var dt := clampf(delta, 0.0001, 0.1)
	# External placement/reset and explicit frozen-target tests stay supported.
	if movement_body.global_position.distance_to(global_position) > 2.0:
		movement_body.global_position = global_position
		movement_body.velocity = Vector3.ZERO
		locomotion.reset()
	brain.enabled = roaming_enabled
	if roaming_enabled:
		brain.update(dt)
		global_position = movement_body.global_position
	else:
		movement_body.global_position = global_position
		movement_body.velocity = Vector3(0, -0.1, 0)
		movement_body.move_and_slide()
	for rig in rigs: (rig.node as Node3D).scale = Vector3.ONE
	locomotion.update(dt, brain.impact_velocity)
	var head: Node3D = visuals.get_node("HeadRig")
	var torso: Node3D = visuals.get_node("TorsoRig")
	head.rotation = locomotion.secondary_head * 0.85
	head.rotation.y = clampf(wrapf(locomotion.travel_yaw - visuals.global_rotation.y, -PI, PI) * 0.65, -0.7, 0.7)
	# Recoverable hit-punch layer on top of the same walk/torso/head animation.
	var steps := maxi(1, int(ceil(dt * 120.0)))
	var h := dt / float(steps)
	for unused in range(steps):
		recoil_velocity += (-recoil * 100.0 - recoil_velocity * 12.0) * h
		recoil += recoil_velocity * h
		hit_offset_velocity += (-hit_offset * 125.0 - hit_offset_velocity * 12.0) * h
		hit_offset += hit_offset_velocity * h
	recoil = recoil.clamp(Vector3(-0.42, -0.18, -0.42), Vector3(0.42, 0.18, 0.42))
	hit_offset = hit_offset.limit_length(0.20)
	hit_squash = move_toward(hit_squash, 0.0, dt * 7.0)
	torso.position += hit_offset * 0.75
	torso.rotation += recoil * 0.85
	head.position += hit_offset * 1.15
	head.rotation += recoil * 1.25
	torso.scale = Vector3(1.0 + hit_squash * 0.10, 1.0 - hit_squash * 0.12, 1.0 + hit_squash * 0.06)
	head.scale = Vector3(1.0 + hit_squash * 0.04, 1.0 - hit_squash * 0.04, 1.0 + hit_squash * 0.04)

func _build_enemy_weapon() -> void:
	weapon_mount=Node3D.new()
	weapon_mount.name="ClonePistol"
	visuals.add_child(weapon_mount)
	weapon_mount.position=Vector3(0.62,0.06,-0.36)
	_box(weapon_mount,"Receiver",Vector3.ZERO,Vector3(0.20,0.18,0.48),Color("28394e"),false)
	_box(weapon_mount,"Barrel",Vector3(0,0,-0.35),Vector3(0.11,0.11,0.25),Color("c2d5e0"),false)
	_box(weapon_mount,"Grip",Vector3(0,-0.14,0.09),Vector3(0.15,0.22,0.13),Color("293044"),false)
	weapon_muzzle=Marker3D.new()
	weapon_muzzle.name="EnemyMuzzle"
	weapon_muzzle.position=Vector3(0,0,-0.50)
	weapon_mount.add_child(weapon_muzzle)
	gun_glow=MeshInstance3D.new()
	var cube:=BoxMesh.new();cube.size=Vector3.ONE*0.13
	gun_glow.mesh=cube
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color("ff8059")
	gun_glow.material_override=material
	weapon_muzzle.add_child(gun_glow)
	gun_glow.visible=false
	attack_label=Label3D.new()
	attack_label.text="!"
	attack_label.font_size=60
	attack_label.pixel_size=0.011
	attack_label.outline_size=9
	attack_label.modulate=Color("ffb75e")
	attack_label.position=Vector3(0,2.87,0)
	attack_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	add_child(attack_label)
	attack_label.hide()
	attack_audio=AudioStreamPlayer3D.new()
	attack_audio.stream=load("res://assets/sounds/sfx/guns/ak47/ak_shoot.wav")
	attack_audio.volume_db=-80.0 if OS.get_cmdline_user_args().has("--kw-qa") else -18.0
	attack_audio.pitch_scale=1.22
	attack_audio.unit_size=4.0
	attack_audio.max_distance=42.0
	weapon_mount.add_child(attack_audio)

func set_attack_warning(value: bool) -> void:
	attack_warning=value and not dead
	if attack_label != null: attack_label.visible=attack_warning
	if gun_glow != null: gun_glow.visible=attack_warning

func aim_weapon(target: Vector3) -> void:
	if weapon_mount==null or weapon_mount.global_position.distance_squared_to(target)<0.01: return
	weapon_mount.look_at(target,Vector3.UP)

func notify_enemy_fire() -> void:
	gun_flash=0.07
	if attack_audio!=null: attack_audio.play()

func _update_readability(delta: float) -> void:
	if health_bar==null: return
	trail_delay=maxf(0,trail_delay-delta)
	if trail_delay<=0: trail_health=move_toward(trail_health,health,delta*90)
	if int(trail_health)!=bar_last_trail:
		bar_last_trail=int(trail_health)
		_refresh_bar()
	var camera:=get_viewport().get_camera_3d()
	if camera!=null:
		var distance:=camera.global_position.distance_to(global_position)
		var factor:=clampf(distance/17.0,0.70,3.6)
		health_bar.scale=Vector3.ONE*factor
		name_label.scale=Vector3.ONE*clampf(distance/22.0,0.8,2.4)
		name_label.position.y=health_bar.position.y+0.16*factor+0.18
		if attack_label!=null:
			attack_label.scale=Vector3.ONE*factor
			attack_label.position.y=name_label.position.y+0.32*factor
	gun_flash=maxf(0,gun_flash-delta)
	if gun_glow!=null:
		gun_glow.visible=(attack_warning or gun_flash>0) and not dead
		gun_glow.scale=Vector3.ONE*(1.0+sin(time*17.0)*0.20 if attack_warning else 1.5)
	if weapon_mount!=null and not attack_warning:
		weapon_mount.quaternion=weapon_mount.quaternion.slerp(Quaternion.IDENTITY,1.0-exp(-5.0*delta))
