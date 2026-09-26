extends RefCounted
## Shared server/client geometry for THE REACTOR.
const CORE_POSITION := Vector3(0.0,1.0,0.0)
const JUMP_PADS: Array[Vector3] = []
const SPAWNS := [Vector3(0.0,1.25,10.0),Vector3(0.0,1.25,-10.0)]
# Flat test arena: only floor + boundary walls. Rebuild the authored Reactor after gunplay QA is stable.
const BOXES := [
	{"id":"Floor","p":Vector3(0,-0.75,0),"s":Vector3(34,1.5,34),"r":Vector3.ZERO,"c":Color("171827")},
	{"id":"WallN","p":Vector3(0,3,-17),"s":Vector3(34,7,0.8),"r":Vector3.ZERO,"c":Color("22253b")},
	{"id":"WallS","p":Vector3(0,3,17),"s":Vector3(34,7,0.8),"r":Vector3.ZERO,"c":Color("22253b")},
	{"id":"WallW","p":Vector3(-17,3,0),"s":Vector3(0.8,7,34),"r":Vector3.ZERO,"c":Color("22253b")},
	{"id":"WallE","p":Vector3(17,3,0),"s":Vector3(0.8,7,34),"r":Vector3.ZERO,"c":Color("22253b")}
]

static func spawn_for_index(index: int) -> Vector3:
	return SPAWNS[clampi(index,0,1)]

static func _add_collider(parent: Node3D, entry: Dictionary, with_mesh: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = str(entry.id)
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = entry.p
	body.rotation_degrees = entry.r
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = entry.s
	shape.shape = box
	body.add_child(shape)
	if with_mesh:
		var mesh := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = entry.s
		mesh.mesh = cube
		var mat := StandardMaterial3D.new()
		mat.albedo_color = entry.c
		mat.roughness = 0.78
		mesh.material_override = mat
		body.add_child(mesh)
	return body

static func build_physics(parent: Node3D) -> void:
	for entry in BOXES:
		_add_collider(parent,entry,false)

static func build_client(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "TheReactor"
	parent.add_child(root)
	for entry in BOXES:
		_add_collider(root,entry,true)
	var core := MeshInstance3D.new()
	core.name = "OverdriveCore"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.15
	cylinder.bottom_radius = 1.15
	cylinder.height = 0.08
	core.mesh = cylinder
	# Floor marker only during flat-arena QA; it is not an obstacle.
	core.position = Vector3(0.0,0.04,0.0)
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color("6f41ca")
	core_mat.emission_enabled = true
	core_mat.emission = Color("7d58ff")
	core_mat.emission_energy_multiplier = 2.8
	core.material_override = core_mat
	root.add_child(core)
	var pads: Array[Node3D] = []
	for i in range(JUMP_PADS.size()):
		var pad := MeshInstance3D.new()
		pad.name = "JumpPad%d" % i
		var disc := CylinderMesh.new()
		disc.top_radius = 1.35
		disc.bottom_radius = 1.35
		disc.height = 0.16
		pad.mesh = disc
		pad.position = JUMP_PADS[i]
		var pad_mat := StandardMaterial3D.new()
		pad_mat.albedo_color = Color("20c9ff") if i == 0 else Color("ff366e")
		pad_mat.emission_enabled = true
		pad_mat.emission = pad_mat.albedo_color
		pad_mat.emission_energy_multiplier = 2.0
		pad.material_override = pad_mat
		root.add_child(pad)
		pads.append(pad)
	return {"root":root,"core":core,"pads":pads}

static func apply_jump_pad(body: CharacterBody3D) -> bool:
	if body.velocity.y > 2.0:
		return false
	for pad_pos in JUMP_PADS:
		var delta: Vector3 = body.global_position - (pad_pos as Vector3)
		if Vector2(delta.x,delta.z).length() <= 1.35 and absf(delta.y) <= 1.65:
			body.velocity.y = 13.2
			var inward := Vector3(-pad_pos.x,0,-pad_pos.z).normalized()
			body.velocity.x += inward.x*2.2
			body.velocity.z += inward.z*2.2
			return true
	return false
