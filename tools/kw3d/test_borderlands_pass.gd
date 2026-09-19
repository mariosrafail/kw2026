extends SceneTree
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
		push_error("BORDERLANDS_PASS_FAIL " + label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	ProjectSettings.set_setting("kw3d/offline_test_mode", "sandbox")
	var stage = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	for i in range(16):
		await process_frame
	check(stage.borderlands_quad != null, "quad_exists")
	check(stage.borderlands_quad.material_override is ShaderMaterial, "shader_material")
	var controls = load("res://scripts/kw3d/portable_input.gd").new()
	root.add_child(controls)
	await process_frame
	var y_bound := false
	for event in InputMap.action_get_events("kw3d_borderlands"):
		if event is InputEventKey and event.physical_keycode == KEY_Y:
			y_bound = true
	check(y_bound, "y_binding_registered")
	controls.queue_free()
	stage._set_pixel_enabled(false)
	stage._set_comic_enabled(false)
	stage._set_borderlands_enabled(false)
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	check(before != null and not before.is_empty(), "before_capture")
	before.save_png("res://tmp/kw3d/borderlands_off.png")

	stage._set_borderlands_enabled(true)
	check(stage.borderlands_quad.visible, "toggle_on")
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var after := root.get_texture().get_image()
	check(after != null and not after.is_empty(), "after_capture")
	after.save_png("res://tmp/kw3d/borderlands_on.png")
	var total_diff := 0.0
	var samples := 0
	var w: int = mini(before.get_width(), after.get_width())
	var h: int = mini(before.get_height(), after.get_height())
	for y in range(4, h, 8):
		for x in range(4, w, 8):
			var a := before.get_pixel(x, y)
			var b := after.get_pixel(x, y)
			total_diff += absf(a.r-b.r) + absf(a.g-b.g) + absf(a.b-b.b)
			samples += 1
	var mean_diff := total_diff / maxf(1.0, float(samples))
	check(mean_diff > 0.002, "visible_image_change")
	stage._set_borderlands_enabled(false)
	check(not stage.borderlands_quad.visible, "toggle_off")
	print("BORDERLANDS_PASS_", "PASS" if failures.is_empty() else "FAIL", failures, " mean_diff=", mean_diff)
	quit(0 if failures.is_empty() else 1)
