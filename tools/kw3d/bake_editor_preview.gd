extends SceneTree
## Rebuild the editor-visible arena from the same runtime construction code.
const SCENE := "res://scenes/prototypes/kw_3d_prototype.tscn"
func _initialize() -> void:
	bake.call_deferred()
func bake() -> void:
	var stage := load(SCENE).instantiate() as Node3D
	root.add_child(stage)
	stage.set_physics_process(false)
	stage.set_process_unhandled_input(false)
	var preview := Node3D.new()
	preview.name = "EditorPreview"
	preview.set_script(load("res://scripts/prototypes/kw_editor_preview.gd"))
	for child in stage.get_children():
		if child is Node3D or child is WorldEnvironment:
			var flags := Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS
			if child.name != "PracticeRange": flags |= Node.DUPLICATE_SCRIPTS
			else: flags = 0
			var copy := child.duplicate(flags)
			preview.add_child(copy)
			set_owners(copy, preview)
	var packed := PackedScene.new()
	assert(packed.pack(preview) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/prototypes/kw_3d_editor_preview.tscn") == OK)
	var scene_text := "[gd_scene load_steps=3 format=3]\n\n"
	scene_text += "[ext_resource type=\"Script\" path=\"res://scripts/prototypes/kw_3d_prototype.gd\" id=\"1_kw3d\"]\n"
	scene_text += "[ext_resource type=\"PackedScene\" path=\"res://scenes/prototypes/kw_3d_editor_preview.tscn\" id=\"2_preview\"]\n\n"
	scene_text += "[node name=\"KW3DPrototype\" type=\"Node3D\"]\nscript = ExtResource(\"1_kw3d\")\n\n"
	scene_text += "[node name=\"EditorPreview\" parent=\".\" instance=ExtResource(\"2_preview\")]\n"
	var file := FileAccess.open(SCENE, FileAccess.WRITE)
	file.store_string(scene_text)
	file.close()
	print("EDITOR_PREVIEW_BAKE_PASS nodes=", preview.get_child_count())
	preview.free()
	stage.free()
	quit(0)
func set_owners(node: Node, owner_root: Node) -> void:
	node.scene_file_path = ""
	node.owner = owner_root
	for child in node.get_children(): set_owners(child, owner_root)
