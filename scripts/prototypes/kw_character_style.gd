@tool
extends Node3D
const PIXEL_MATERIALS := preload("res://scripts/prototypes/kw_pixel_materials.gd")
## Comic styling is runtime/editor material state, never black model geometry.
@export var enabled := true:
	set(value):
		enabled = value
		if is_inside_tree():
			_apply_style()

@export var pixel_enabled := true:
	set(value):
		pixel_enabled = value
		if is_inside_tree():
			_apply_style()

func _ready() -> void:
	_apply_style()

func set_enabled(value: bool) -> void:
	enabled = value

func set_pixel_enabled(value: bool) -> void:
	pixel_enabled = value

func _apply_style() -> void:
	for rig in get_children():
		for child in rig.get_children():
			var mesh := child as MeshInstance3D
			if mesh == null:
				continue
			if mesh.name == "ShaderInkOutline":
				mesh.visible = enabled
			elif mesh.has_meta("plain_material"):
				var toon: ShaderMaterial = mesh.get_meta("toon_material")
				toon.set_shader_parameter("pixel_enabled", pixel_enabled)
				if enabled:
					mesh.material_override = toon
				elif pixel_enabled:
					if not mesh.has_meta("pixel_material"):
						mesh.set_meta("pixel_material", PIXEL_MATERIALS.from_standard(mesh.get_meta("plain_material")))
					mesh.material_override = mesh.get_meta("pixel_material")
				else:
					mesh.material_override = mesh.get_meta("plain_material")
