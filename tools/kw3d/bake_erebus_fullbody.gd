extends "res://tools/kw3d/bake_fullbody.gd"
## Bake Erebus using the same four-rig contract and comic materials as Outrage.

const EREBUS_ASSET := "res://assets/prototypes/erebus_fullbody/"

func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EREBUS_ASSET + "build_data.json"))
	unit = float(data["scale"])
	plain_materials.clear()
	toon_materials.clear()
	for tex in data["textures"]:
		var image := Image.load_from_file(EREBUS_ASSET + str(tex["path"]))
		assert(image != null and not image.is_empty())
		var texture := ImageTexture.create_from_image(image)
		var plain := StandardMaterial3D.new()
		plain.albedo_texture = texture
		plain.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		plain.roughness = 0.9
		plain_materials.append(plain)
		var toon := ShaderMaterial.new()
		toon.shader = TOON
		toon.set_shader_parameter("base_color", Color.WHITE)
		toon.set_shader_parameter("use_texture", true)
		toon.set_shader_parameter("albedo_texture", texture)
		toon_materials.append(toon)

	var model := Node3D.new()
	model.name = "ErebusFullBody"
	model.set_meta("warrior_id", "erebus")
	model.set_meta("source_sha256", data["sha256"])
	model.set_meta("source_path", data["source"])
	model.set_meta("source_blocks", data["part_count"])
	model.set_meta("capsule_height", data["capsule_height"])
	var count := 0
	for rd in data["rigs"]:
		var rig := Node3D.new()
		rig.name = rd["name"]
		rig.position = v3(rd["rest"])
		model.add_child(rig)
		rig.owner = model
		for item in rd["parts"]:
			var mesh := make_part(item, v3(rd["pivot"]), data["textures"])
			rig.add_child(mesh)
			mesh.owner = model
			count += 1
	assert(count == int(data["part_count"]))

	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	assert(gltf.append_from_scene(model, state) == OK)
	assert(gltf.write_to_filesystem(state, EREBUS_ASSET + "erebus_fullbody.glb") == OK)

	for rd in data["rigs"]:
		var hull := make_hull(rd["outline"])
		var ink := MeshInstance3D.new()
		ink.name = "ShaderInkOutline"
		ink.mesh = hull
		ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ink.extra_cull_margin = 0.2
		var material := ShaderMaterial.new()
		material.shader = INK
		ink.material_override = material
		model.get_node(NodePath(rd["name"])).add_child(ink)
		ink.owner = model

	model.set_script(STYLE)
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	DirAccess.make_dir_recursive_absolute("res://scenes/prototypes/characters")
	assert(ResourceSaver.save(packed, "res://scenes/prototypes/characters/erebus_fullbody.tscn") == OK)
	print("EREBUS_FULLBODY_BAKE_PASS blocks=", count, " source=", data["sha256"])
	model.free()
	quit(0)
