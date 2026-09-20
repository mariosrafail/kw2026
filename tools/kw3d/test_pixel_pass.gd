extends SceneTree
var stage: Node3D
var output := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	assert(not output.is_empty())
	run.call_deferred()
func run() -> void:
	stage = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	stage.combat.set_training_mode(true)
	# Freeze target travel for deterministic aim/terrain fixtures; roaming has its own test.
	stage.combat.set_roaming_enabled(false)
	for i in range(90): await physics_frame
	stage.set_physics_process(false)
	stage.set_process_unhandled_input(false)
	assert(stage.comic_enabled)
	assert(stage.borderlands_enabled and stage.borderlands_quad.visible)
	assert(not stage.pixel_enabled and not stage.pixel_post_layer.visible)
	assert(stage.pixel_post_layer.layer < stage.get_node("HUD").layer)
	assert(stage.get_node("PixelWorldPass/PixelWorldOnly").mouse_filter == Control.MOUSE_FILTER_IGNORE)
	await capture("gameplay_default_outline")
	stage._set_pixel_enabled(true)
	await capture("gameplay_pixel")
	stage._set_pixel_enabled(false)
	await capture("gameplay_without_pixel")
	stage._set_pixel_enabled(true)
	stage.get_node("HUD").visible = false
	for child in stage.player_visual.get_children():
		if child is Label3D: child.visible = false
	stage.camera.global_position = stage.player.global_position + Vector3(3.6,1.55,-6.4)
	stage.camera.look_at(stage.player.global_position + Vector3(0,0,0),Vector3.UP)
	stage.camera.fov = 44.0
	stage.camera_yaw.rotation.y = 0.0
	# Keep this orbit-inspection view; do not aim the rifle at the inspection camera.
	await capture("character_pixel")
	await capture("character_pixel_static")
	stage._set_pixel_enabled(false)
	await capture("character_no_pixel")
	stage._set_pixel_enabled(true)
	stage.head_style.set_enabled(false)
	await capture("pixel_no_ink")
	stage.head_style.set_enabled(true)
	var checks := 0
	for turn in [0.0, 1.5, 3.0, -2.0]:
		stage.body_yaw = turn
		stage.player_visual.rotation.y = turn
		for look_yaw in [0.0, 1.5, 3.0, -2.0]:
			for look_pitch in [-0.8, 0.0, 0.52]:
				stage.camera_yaw.rotation.y = look_yaw
				stage.camera_pitch.rotation.x = look_pitch
				stage.camera.position = Vector3(0.95,1.16,4.25)
				stage.camera.rotation = Vector3.ZERO
				stage.weapon_recoil = 1.0
				stage._update_weapon_pose(0.0)
				var desired: Vector3 = (stage.aim_target - stage.weapon_muzzle.global_position).normalized()
				assert(desired.dot(stage.weapon_root.global_basis.x.normalized()) > 0.99999)
				for gun in stage.weapon_root.get_children():
					if not gun is MeshInstance3D: continue
					for torso in stage.torso_rig.get_children():
						if not torso is MeshInstance3D or torso.name == "ShaderInkOutline": continue
						assert(not overlaps(gun,torso), "Rifle clips torso in pose " + str([turn,look_yaw,look_pitch]))
				checks += 1
	print("WEAPON_CLEARANCE_AND_AIM_PASS poses=", checks)
	for rig in stage.head_style.get_children():
		for part in rig.get_children():
			if part is MeshInstance3D and part.name != "ShaderInkOutline":
				assert(part.material_override is ShaderMaterial)
				assert(part.material_override.get_shader_parameter("pixel_enabled"))
	stage.ak_fire_audio.volume_db = -80.0
	for i in range(6):
		stage.shot_cooldown = 0.0
		stage._fire_physics_ball()
		await physics_frame
	print("PIXEL_MATERIALS_UI_TOGGLE_FIRE_PASS")
	stage.queue_free()
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	print("PIXEL_QA_PASS")
	quit(0)
func capture(label: String) -> void:
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK)
	print("RENDERED ",label)
func overlaps(a: MeshInstance3D, b: MeshInstance3D) -> bool:
	var corners_a: Array[Vector3] = []
	var corners_b: Array[Vector3] = []
	for i in range(8):
		corners_a.append(a.global_transform * a.mesh.get_aabb().get_endpoint(i))
		corners_b.append(b.global_transform * b.mesh.get_aabb().get_endpoint(i))
	var axes: Array[Vector3] = [a.global_basis.x,a.global_basis.y,a.global_basis.z,b.global_basis.x,b.global_basis.y,b.global_basis.z]
	for aa in [a.global_basis.x,a.global_basis.y,a.global_basis.z]:
		for bb in [b.global_basis.x,b.global_basis.y,b.global_basis.z]: axes.append(aa.cross(bb))
	for axis in axes:
		if axis.length_squared() < 0.00001: continue
		axis = axis.normalized()
		var amin := INF
		var amax := -INF
		var bmin := INF
		var bmax := -INF
		for v in corners_a:
			amin = minf(amin,v.dot(axis)); amax = maxf(amax,v.dot(axis))
		for v in corners_b:
			bmin = minf(bmin,v.dot(axis)); bmax = maxf(bmax,v.dot(axis))
		if amax <= bmin + 0.00001 or bmax <= amin + 0.00001: return false
	return true
