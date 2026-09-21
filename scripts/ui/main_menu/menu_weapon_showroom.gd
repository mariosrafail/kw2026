extends RefCounted
## Shared 3D weapon builders for the menu showroom.

const AK47_BUILDER := preload("res://scripts/prototypes/ak47_voxel_builder.gd")
const KAR_BUILDER := preload("res://scripts/prototypes/kar_voxel_builder.gd")


static func build_weapon(parent: Node3D, weapon_id: String, skin_id: int = 0) -> void:
	match weapon_id:
		"shotgun":
			_build_shotgun(parent)
		"kar":
			KAR_BUILDER.build(parent, skin_id)
		_:
			AK47_BUILDER.build(parent, skin_id)
	_apply_showroom_finish(parent)


static func display_name(weapon_id: String) -> String:
	match weapon_id:
		"shotgun": return "SHOTGUN"
		"kar": return "KAR"
		_: return "AK-47"


static func descriptor(weapon_id: String) -> String:
	match weapon_id:
		"shotgun": return "CLOSE RANGE // HEAVY IMPACT"
		"kar": return "MARKSMAN // SCOPED PRECISION"
		_: return "ASSAULT RIFLE // FULL AUTO"


static func skin_count(weapon_id: String) -> int:
	if weapon_id == "kar":
		return KAR_BUILDER.skin_count()
	if weapon_id == "ak47":
		return AK47_BUILDER.skin_count()
	return 1


static func skin_name(weapon_id: String, skin_id: int) -> String:
	if weapon_id == "kar":
		return KAR_BUILDER.skin_name(skin_id)
	if weapon_id == "ak47":
		return AK47_BUILDER.skin_name(skin_id)
	return "DEFAULT"

static func skin_accent(weapon_id: String, skin_id: int) -> Color:
	if weapon_id == "kar":
		return KAR_BUILDER.skin_accent(skin_id)
	if weapon_id == "ak47":
		return AK47_BUILDER.skin_accent(skin_id)
	return Color("6CCFFF")


static func _build_shotgun(parent: Node3D) -> void:
	_add_part(parent,"SG_Stock",Vector3(-0.36,-0.02,0),Vector3(0.62,0.22,0.24),Color("6d4030"))
	_add_part(parent,"SG_Receiver",Vector3(0.18,0.01,0),Vector3(0.62,0.25,0.22),Color("30343b"))
	_add_part(parent,"SG_Barrel",Vector3(0.88,0.055,0),Vector3(0.92,0.12,0.14),Color("b7c0c8"))
	_add_part(parent,"SG_Pump",Vector3(0.62,-0.09,0),Vector3(0.42,0.18,0.25),Color("8a5238"))
	_add_part(parent,"SG_Grip",Vector3(0.02,-0.22,0),Vector3(0.20,0.36,0.22),Color("20232a"))
	_add_part(parent,"SG_Sight",Vector3(0.30,0.18,0),Vector3(0.10,0.08,0.10),Color("ffcf70"))


static func _add_part(parent: Node3D, title: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.12
	material.roughness = 0.60
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)


static func _apply_showroom_finish(root: Node3D) -> void:
	var normal := _surface_normal()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var source := mesh.material_override as StandardMaterial3D
		if source == null:
			continue
		var material := source.duplicate(true) as StandardMaterial3D
		material.resource_local_to_scene = true
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.normal_enabled = true
		material.normal_texture = normal
		material.normal_scale = 0.07
		material.clearcoat_enabled = true
		material.clearcoat = 0.16
		material.clearcoat_roughness = 0.38
		material.metallic = maxf(material.metallic, 0.12)
		material.roughness = clampf(material.roughness * 0.76, 0.24, 0.68)
		mesh.material_override = material


static func _surface_normal() -> NoiseTexture2D:
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	var noise := FastNoiseLite.new()
	noise.seed = 7041
	noise.frequency = 0.28
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 3
	texture.noise = noise
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.as_normal_map = true
	texture.bump_strength = 0.45
	return texture
