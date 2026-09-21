extends RefCounted
## Long, chunky KAR-style rifle with five reusable material identities.

const SKIN_NAMES := [
	"CLASSIC",
	"NEON",
	"BLOOD",
	"ARCTIC",
	"DIVINE",
]


static func build(parent: Node3D, skin_id: int = 0) -> void:
	var palette := _skin_palette(skin_id)
	var mats: Dictionary={}
	var wood: Color = palette["wood"]
	var wood_light: Color = palette["wood_light"]
	var wood_dark: Color = palette["wood_dark"]
	var steel: Color = palette["steel"]
	var steel_dark: Color = palette["steel_dark"]
	var sight: Color = palette["sight"]
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
	_part(parent,mats,"ScopeGlint",Vector3(0.60,0.37,0),Vector3(0.035,0.12,0.12),sight)
	_apply_skin_finish(parent, skin_id, palette)


static func skin_name(skin_id: int) -> String:
	return SKIN_NAMES[clampi(skin_id, 0, SKIN_NAMES.size() - 1)]


static func skin_count() -> int:
	return SKIN_NAMES.size()

static func skin_accent(skin_id: int) -> Color:
	match clampi(skin_id, 0, SKIN_NAMES.size() - 1):
		1: return Color("39F1FF")
		2: return Color("FF244A")
		3: return Color("9FF5FF")
		4: return Color("FFCE5A")
		_: return Color("C58B63")


static func _skin_palette(skin_id: int) -> Dictionary:
	match clampi(skin_id, 0, SKIN_NAMES.size() - 1):
		1: # Neon Viper: cyan/blue weapon with hot magenta optics.
			return {
				"wood": Color("126A86"),
				"wood_light": Color("20A8C5"),
				"wood_dark": Color("0A314A"),
				"steel": Color("437BA7"),
				"steel_dark": Color("152944"),
				"sight": Color("FF49C6"),
				"emission": Color("39F1FF"),
				"metallic": 0.24,
			}
		2: # Blood Moon: dark gunmetal with deep red furniture and hot red details.
			return {
				"wood": Color("801F2E"),
				"wood_light": Color("B62B3C"),
				"wood_dark": Color("3C101A"),
				"steel": Color("4B424A"),
				"steel_dark": Color("17151B"),
				"sight": Color("FF697C"),
				"emission": Color("FF244A"),
				"metallic": 0.30,
			}
		3: # Arctic Ghost: pale ceramic body with icy blue metal accents.
			return {
				"wood": Color("B8D9E5"),
				"wood_light": Color("E7F8FF"),
				"wood_dark": Color("6F91A4"),
				"steel": Color("8CAFC4"),
				"steel_dark": Color("355066"),
				"sight": Color("B9FFFF"),
				"emission": Color("70EFFF"),
				"metallic": 0.18,
			}
		4: # Divine: blackened steel, royal violet and warm gold trim.
			return {
				"wood": Color("51366F"),
				"wood_light": Color("7850A5"),
				"wood_dark": Color("201829"),
				"steel": Color("C49A42"),
				"steel_dark": Color("4C3920"),
				"sight": Color("FFE59A"),
				"emission": Color("FFCE5A"),
				"metallic": 0.52,
			}
		_: # Classic Timber.
			return {
				"wood": Color("71472f"),
				"wood_light": Color("936246"),
				"wood_dark": Color("4f3224"),
				"steel": Color("4a5662"),
				"steel_dark": Color("2b333c"),
				"sight": Color("c5d1d8"),
				"emission": Color("8fb7c8"),
				"metallic": 0.10,
			}


static func _apply_skin_finish(parent: Node3D, skin_id: int, palette: Dictionary) -> void:
	var glow: Color = palette["emission"]
	var metallic: float = float(palette["metallic"])
	for node in parent.get_children():
		if not node is MeshInstance3D:
			continue
		var mesh := node as MeshInstance3D
		var material := mesh.material_override as StandardMaterial3D
		if material == null:
			continue
		material.metallic = maxf(material.metallic, metallic)
		material.roughness = 0.52 if skin_id != 0 else 0.76
		if mesh.name in ["ScopeGlint", "RearSightMark", "FrontSightTip"] and skin_id != 0:
			material.emission_enabled = true
			material.emission = glow
			material.emission_energy_multiplier = 2.4 if skin_id != 4 else 1.8

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
