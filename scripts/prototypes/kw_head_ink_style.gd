extends RefCounted
## Runtime-only style. The approved Blockbench source stays red, with no ink blocks.
const TOON := preload("res://scripts/prototypes/kw_comic_toon.gdshader")
const INK := preload("res://scripts/prototypes/kw_comic_ink.gdshader")
var enabled := true
var records: Array[Dictionary] = []
var outline: MeshInstance3D

func setup(model: Node3D) -> void:
	var materials: Dictionary = {}
	for child in model.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null:
			continue
		var original := mesh.material_override as StandardMaterial3D
		if original == null:
			continue
		var key := original.albedo_color.to_html()
		if not materials.has(key):
			var toon := ShaderMaterial.new()
			toon.shader = TOON
			toon.set_shader_parameter("base_color", original.albedo_color)
			materials[key] = toon
		records.append({"mesh": mesh, "plain": original, "toon": materials[key]})
	outline = MeshInstance3D.new()
	outline.name = "ShaderInkOutline"
	outline.mesh = load("res://assets/prototypes/outrage_head_v09/outline_hull.res") as Mesh
	var ink := ShaderMaterial.new()
	ink.shader = INK
	outline.material_override = ink
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outline.extra_cull_margin = 0.15
	model.add_child(outline)
	set_enabled(enabled)

func set_enabled(value: bool) -> void:
	enabled = value
	for record in records:
		var mesh := record["mesh"] as MeshInstance3D
		if is_instance_valid(mesh):
			mesh.material_override = record["toon"] if enabled else record["plain"]
	if is_instance_valid(outline):
		outline.visible = enabled
