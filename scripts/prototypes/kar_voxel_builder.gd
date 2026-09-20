extends RefCounted
## Long, chunky KAR-style rifle using the original brown weapon identity.
static func build(parent: Node3D) -> void:
	var mats: Dictionary={}
	var wood:=Color("71472f")
	var wood_light:=Color("936246")
	var wood_dark:=Color("4f3224")
	var steel:=Color("4a5662")
	var steel_dark:=Color("2b333c")
	var sight:=Color("c5d1d8")
	_part(parent,mats,"Buttstock",Vector3(-0.78,0.00,0),Vector3(0.72,0.30,0.34),wood_dark)
	_part(parent,mats,"StockBody",Vector3(-0.34,0.00,0),Vector3(0.56,0.26,0.31),wood)
	_part(parent,mats,"Receiver",Vector3(0.10,0.08,0),Vector3(0.54,0.22,0.25),steel)
	_part(parent,mats,"ReceiverWood",Vector3(0.08,-0.06,0),Vector3(0.62,0.12,0.30),wood_light)
	_part(parent,mats,"ForeStock",Vector3(0.58,-0.01,0),Vector3(0.68,0.20,0.28),wood)
	_part(parent,mats,"ForeStockTip",Vector3(0.96,-0.01,0),Vector3(0.18,0.18,0.24),wood_dark)
	_part(parent,mats,"Barrel",Vector3(1.22,0.09,0),Vector3(0.68,0.075,0.085),steel_dark)
	_part(parent,mats,"Muzzle",Vector3(1.59,0.09,0),Vector3(0.14,0.11,0.12),steel)
	_part(parent,mats,"Bolt",Vector3(0.05,0.21,-0.17),Vector3(0.30,0.06,0.07),steel)
	_part(parent,mats,"BoltHandle",Vector3(0.14,0.14,-0.25),Vector3(0.08,0.24,0.07),steel_dark,Vector3(0,0,0.42))
	_part(parent,mats,"RearSight",Vector3(0.22,0.27,0),Vector3(0.10,0.10,0.14),steel_dark)
	_part(parent,mats,"RearSightMark",Vector3(0.22,0.34,0),Vector3(0.05,0.05,0.06),sight)
	_part(parent,mats,"FrontSightBase",Vector3(1.35,0.18,0),Vector3(0.08,0.18,0.11),steel_dark)
	_part(parent,mats,"FrontSightTip",Vector3(1.35,0.31,0),Vector3(0.045,0.08,0.05),sight)
	_part(parent,mats,"TriggerGuard",Vector3(0.05,-0.20,0),Vector3(0.26,0.08,0.18),steel_dark)
	_part(parent,mats,"Grip",Vector3(-0.14,-0.27,0),Vector3(0.20,0.35,0.25),wood_dark,Vector3(0,0,-0.13))
	_part(parent,mats,"FloorPlate",Vector3(0.16,-0.16,0),Vector3(0.28,0.07,0.20),steel)
	_part(parent,mats,"ScopeTube",Vector3(0.18,0.37,0),Vector3(0.68,0.12,0.12),steel_dark)
	_part(parent,mats,"ScopeFront",Vector3(0.52,0.37,0),Vector3(0.14,0.18,0.18),steel)
	_part(parent,mats,"ScopeRear",Vector3(-0.18,0.37,0),Vector3(0.14,0.18,0.18),steel)
	_part(parent,mats,"ScopeGlint",Vector3(0.60,0.37,0),Vector3(0.035,0.12,0.12),Color("8fb7c8"))

static func _part(parent: Node3D,mats: Dictionary,title: String,pos: Vector3,size: Vector3,color: Color,rotation: Vector3=Vector3.ZERO) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new();mesh.name=title
	var box:=BoxMesh.new();box.size=size;mesh.mesh=box
	mesh.position=pos;mesh.rotation=rotation
	mesh.material_override=_material(mats,color)
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh

static func _material(mats: Dictionary,color: Color) -> StandardMaterial3D:
	var key:=color.to_html(false)
	if mats.has(key):return mats[key]
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=color;mat.roughness=0.82;mat.metallic=0.06
	mats[key]=mat
	return mat
