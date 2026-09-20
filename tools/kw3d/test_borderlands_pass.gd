extends SceneTree
var failures: Array[String]=[]

func check(value: bool,label: String)->void:
	if not value:
		failures.append(label)
		push_error("BORDERLANDS_PASS_FAIL "+label)

func _initialize()->void:
	run.call_deferred()

func run()->void:
	ProjectSettings.set_setting("kw3d/offline_test_mode","sandbox")
	var stage=load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage);current_scene=stage
	for i in range(16):await process_frame
	stage.combat.set_training_mode(true);stage.combat.set_roaming_enabled(false)
	check(stage.comic_enabled,"comic_default_on")
	check(stage.borderlands_enabled and stage.borderlands_quad.visible,"borderlands_default_on")
	check(not stage.pixel_enabled and not stage.pixel_post_layer.visible,"pixel_default_off")
	check(stage.player_health_bar.render_priority==127,"player_health_priority")
	check(stage.player_ammo_label.render_priority==127,"player_ammo_priority")
	check(stage.borderlands_quad.material_override is ShaderMaterial,"shader_material")
	check((stage.borderlands_quad.material_override as ShaderMaterial).render_priority<127,"edge_pass_before_world_ui")

	var controls=load("res://scripts/kw3d/portable_input.gd").new();root.add_child(controls);await process_frame
	var y_bound:=false
	for event in InputMap.action_get_events("kw3d_borderlands"):
		if event is InputEventKey and event.physical_keycode==KEY_Y:y_bound=true
	check(y_bound,"y_binding_registered")
	controls.queue_free()

	var target: Node3D=stage.combat.targets[0]
	target.set_physics_process(false)
	stage.set_physics_process(false);stage.set_process_unhandled_input(false)
	stage.player.global_position=Vector3(0,1.715,65)
	target.global_position=Vector3(0,1.715,57)
	target.movement_body.global_position=target.global_position
	target.health=100.0;target.trail_health=100.0;target._refresh_bar();target._update_shapes()
	stage.camera.global_position=stage.player.global_position+Vector3(stage.CAMERA_SHOULDER_X,1.35,3.8)
	stage.camera.look_at(target.health_bar.global_position,Vector3.UP)
	stage.camera.fov=58.0
	for i in range(3):await process_frame

	stage._set_borderlands_enabled(false)
	for i in range(3):await process_frame
	await RenderingServer.frame_post_draw
	var before:=root.get_texture().get_image()
	check(before!=null and not before.is_empty(),"before_capture")

	stage._set_borderlands_enabled(true)
	for i in range(5):await process_frame
	await RenderingServer.frame_post_draw
	var after:=root.get_texture().get_image()
	check(after!=null and not after.is_empty(),"after_capture")
	check(stage.borderlands_quad.visible,"toggle_on")
	var red_pixels:=_count_bar_pixels(after,stage.camera.unproject_position(target.health_bar.global_position),root.get_visible_rect().size)
	check(red_pixels>=12,"health_bar_visible_over_borderlands")
	print("BORDERLANDS_BAR_RED_PIXELS ",red_pixels)

	var total_diff:=0.0
	var samples:=0
	var w: int=mini(before.get_width(),after.get_width())
	var h: int=mini(before.get_height(),after.get_height())
	for y in range(4,h,8):
		for x in range(4,w,8):
			var a:=before.get_pixel(x,y);var b:=after.get_pixel(x,y)
			total_diff+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b);samples+=1
	var mean_diff:=total_diff/maxf(1.0,float(samples))
	check(mean_diff>0.002,"visible_image_change")
	stage._set_borderlands_enabled(false)
	check(not stage.borderlands_quad.visible,"toggle_off")
	print("BORDERLANDS_PASS_","PASS" if failures.is_empty() else "FAIL",failures," mean_diff=",mean_diff)
	quit(0 if failures.is_empty() else 1)

func _count_bar_pixels(image: Image,screen: Vector2,viewport_size: Vector2)->int:
	var sx:=float(image.get_width())/maxf(1.0,viewport_size.x)
	var sy:=float(image.get_height())/maxf(1.0,viewport_size.y)
	var px:=int(round(screen.x*sx))
	var py:=int(round(screen.y*sy))
	var best:=0
	for flip in [false,true]:
		var cy:=image.get_height()-1-py if flip else py
		var count:=0
		for y in range(cy-12,cy+13):
			if y<0 or y>=image.get_height():continue
			for x in range(px-64,px+65):
				if x<0 or x>=image.get_width():continue
				var c:=image.get_pixel(x,y)
				if c.r>0.62 and c.r>c.g*1.22 and c.r>c.b*1.02:count+=1
		best=maxi(best,count)
	return best
