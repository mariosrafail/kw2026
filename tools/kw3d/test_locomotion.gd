extends SceneTree
var stage: Node3D
var output := ""
var dt := 1.0 / 60.0
var failures: Array[String] = []
var observer: Camera3D
var max_slide := 0.0
var min_ground := INF
var trace: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	assert(not output.is_empty())
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	if not condition and not failures.has(label):
		failures.append(label)
		push_error("WALK_QA_FAIL: " + label)

func place() -> void:
	stage.player.global_position = Vector3(0,1.716,65)
	stage.player.velocity = Vector3(0,-0.1,0)
	stage.player.move_and_slide()
	stage.body_yaw = 0.0
	stage.player_visual.rotation = Vector3.ZERO
	stage.camera_yaw.rotation.y = 0.0
	stage.camera_pitch.rotation.x = -0.1
	stage.camera.position = Vector3(0.65,1.35,6.4)
	stage.camera.rotation = Vector3.ZERO
	stage.locomotion.reset()

func advance(v: Vector3) -> void:
	stage.player.velocity = v
	stage.animation_impact_velocity = v.y
	stage.player.move_and_slide()
	stage._update_character_animation(dt)
	stage._update_weapon_pose(dt)
	check(stage.head_rig.transform.is_finite() and stage.torso_rig.transform.is_finite(), "body_finite")
	check(absf(stage.head_rig.rotation.y) <= 1.401, "head_yaw_bound")
	check(absf(stage.head_rig.rotation.z) <= 0.621, "head_roll_bound")
	var swings := 0
	for foot in stage.locomotion.feet:
		if foot.swinging: swings += 1
		check(foot.node.transform.is_finite(), "foot_finite")
		if stage.player.is_on_floor():
			for c in foot.corners:
				var world: Vector3 = foot.node.global_transform * c
				min_ground = minf(min_ground,world.y)
				check(world.y >= -0.015, "sole_above_ground")
	check(swings <= 2, "swing_count_bounded")
	var dir: Vector3 = (stage.aim_target - stage.weapon_muzzle.global_position).normalized()
	check(dir.dot(stage.weapon_root.global_basis.x.normalized()) > 0.99998, "rifle_aim_preserved")

func run() -> void:
	stage = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	stage.combat.set_training_mode(true)
	# Freeze target travel for deterministic aim/terrain fixtures; roaming has its own test.
	stage.combat.set_roaming_enabled(false)
	stage.set_physics_process(false)
	stage.set_process_unhandled_input(false)
	stage._add_static_box("WalkQAFloor",Vector3(0,-0.5,65),Vector3(100,1,100),Color(0.15,0.17,0.2))
	stage.ak_fire_audio.volume_db = -80.0
	for i in range(3): await physics_frame
	for direction in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT,Vector3(1,0,-1).normalized()]:
		place()
		var old_contacts: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
		var old_stance := [false,false]
		var before: int = stage.locomotion.step_count
		for frame in range(85):
			await physics_frame
			advance(direction * 7.5 + Vector3.DOWN * 0.2)
			for i in range(2):
				var f = stage.locomotion.feet[i]
				if old_stance[i] and not f.swinging:
					max_slide = maxf(max_slide,old_contacts[i].distance_to(f.contact))
					check(old_contacts[i].distance_to(f.contact) < 0.001, "world_plant_lock")
				old_stance[i] = not f.swinging
				old_contacts[i] = f.contact
				if frame > 40:
					var facing: Vector3 = -f.node.global_basis.z
					facing.y = 0
					check(facing.normalized().dot(direction) > 0.80, "feet_follow_actual_motion")
		check(stage.locomotion.step_count - before >= 5, "multiple_real_steps")
		print("DIRECTION_PASS ",direction)
	var count_before: int = stage.locomotion.step_count
	for frame in range(100):
		await physics_frame
		advance(Vector3.DOWN * 0.2)
	check(not stage.locomotion.feet[0].swinging and not stage.locomotion.feet[1].swinging, "idle_settled")
	check(stage.locomotion.step_count-count_before <= 5, "stop_not_marching_forever")
	print("PLANT_STOP_PASS max_slide=",max_slide," min_sole=",min_ground)
	place()
	var vy := 8.8
	var airborne := false
	var landed := false
	for frame in range(85):
		await physics_frame
		vy -= 19.5 * dt
		advance(Vector3(0,vy,-2.8))
		if not stage.player.is_on_floor(): airborne = true
		if airborne and stage.player.is_on_floor():
			landed = true
			break
	check(airborne and landed, "jump_and_landing")
	print("JUMP_LAND_PASS")
	# Render a real cycle in motion, with an independent observer camera.
	stage.get_node("HUD").visible = false
	for tag in stage.player_visual.get_children():
		if tag is Label3D: tag.visible = false
	observer = Camera3D.new()
	stage.add_child(observer)
	observer.current = true
	observer.fov = 42.0
	place()
	for frame in range(56):
		await physics_frame
		advance(Vector3(0,-0.2,-5.0))
		observer.global_position = stage.player.global_position + Vector3(5.8,1.1,1.0)
		observer.look_at(stage.player.global_position + Vector3(0,-0.05,0),Vector3.UP)
		if frame % 4 == 0:
			await capture("walk_%02d" % frame)
			var l = stage.locomotion.feet[0]
			var r = stage.locomotion.feet[1]
			trace.append({"frame":frame,"left":l.phase,"right":r.phase,"left_pos":str(stage.left_leg_rig.position),"right_pos":str(stage.right_leg_rig.position)})
	# Full changes of direction and frame-rate variation must stay finite.
	for fps in [30.0,60.0,144.0]:
		place()
		for i in range(500):
			var tick: float = 1.0/fps
			var angle := sin(i*0.012)*3.0
			var motion := Vector3(sin(angle),0,-cos(angle))*7.0
			stage.player.global_position += motion*tick
			stage.body_yaw = sin(i*0.015)*2.8
			stage.player_visual.rotation.y = stage.body_yaw
			stage.camera_yaw.rotation.y = cos(i*0.02)*2.8
			stage.camera_pitch.rotation.x = sin(i*0.03)*0.5
			stage._update_character_animation(tick)
			check(stage.head_rig.transform.is_finite() and stage.left_leg_rig.transform.is_finite(),"variable_dt_finite")
			check(absf(stage.head_rig.rotation.y)<=1.401 and absf(stage.head_rig.rotation.z)<=0.621,"variable_dt_bounds")
	print("VARIABLE_DT_PASS 30/60/144")
	place()
	stage.aiming = true
	stage.camera_yaw.rotation.y = 0.48
	stage.camera_pitch.rotation.x = 0.2
	for i in range(100): stage._update_character_animation(dt)
	var desired: Vector3 = stage.camera.global_position-stage.camera.global_basis.z*120.0-stage.head_rig.global_position
	check(desired.normalized().dot(-stage.head_rig.global_basis.z) > 0.97,"head_tracks_target_aiming")
	print("GAZE_PASS")
	# Another preview in a three-quarter direction, using the game aesthetic.
	stage.aiming = false
	for frame in range(40):
		await physics_frame
		advance(Vector3(4,-0.2,-4))
		observer.global_position = stage.player.global_position + Vector3(4.5,1.4,-6)
		observer.look_at(stage.player.global_position,Vector3.UP)
	await capture("goofy_three_quarter")
	var f := FileAccess.open(output.path_join("walk_results.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"failures":failures,"max_plant_drift":max_slide,"min_sole_y":min_ground,"steps":stage.locomotion.step_count,"cycle":trace},"\t"))
	f.close()
	stage.queue_free()
	for i in range(8): await process_frame
	print("LOCOMOTION_QA_", "PASS" if failures.is_empty() else "FAIL", " ", failures)
	quit(0 if failures.is_empty() else 1)

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture_saved")
