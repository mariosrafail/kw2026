@tool
extends Node3D
## Baked, editable scene preview. Removed by the runtime before gameplay starts.
func _ready() -> void:
	if Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--kw-preview-play"):
		_prepare_editor.call_deferred()

func _prepare_editor() -> void:
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree():
		return
	var editor := Engine.get_singleton("EditorInterface")
	var base: Control = editor.get_base_control()
	if base.has_meta("kw_v11_started"):
		return
	base.set_meta("kw_v11_started", true)
	editor.set_main_screen_editor("3D")
	var visual := get_node_or_null("Outrage3D/OutrageVisual")
	if visual != null:
		editor.get_selection().clear()
		editor.get_selection().add_node(visual)
		editor.edit_node(visual)
	var viewport: SubViewport = editor.get_editor_viewport_3d(0)
	if viewport != null:
		var camera := viewport.get_camera_3d()
		if camera != null:
			camera.global_position = Vector3(4.5, 4.0, 11.0)
			camera.look_at(Vector3(0, 2.1, 6), Vector3.UP)
	if viewport != null and viewport.get_parent() is Control:
		viewport.get_parent().grab_focus()
		var key := InputEventKey.new()
		key.keycode = KEY_F
		key.pressed = true
		Input.parse_input_event(key)
	await get_tree().create_timer(1.0).timeout
	print("KW_EDITOR_SCENE_READY")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kw-editor-capture="):
			await RenderingServer.frame_post_draw
			get_tree().root.get_texture().get_image().save_png(arg.trim_prefix("--kw-editor-capture="))
	editor.play_custom_scene("res://scenes/prototypes/kw_3d_prototype.tscn")
