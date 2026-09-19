extends "res://tools/kw3d/test_locomotion.gd"

func run() -> void:
	stage = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	stage.combat.set_training_mode(true)
	stage.set_physics_process(false)
	stage.set_process_unhandled_input(false)
	stage._add_static_box("WalkQAFloor",Vector3(0,-0.5,65),Vector3(100,1,100),Color(0.15,0.17,0.2))
	stage._add_ramp("WalkQARamp",Vector3(4,1.4,65),Vector3(14,0.25,12),Vector3(0,0,15),Color(0.2,0.2,0.3))
	for i in range(3): await physics_frame
	place()
	stage.player.global_position.x = -6.0
	stage.locomotion.reset()
	var slope_contacts := 0
	for i in range(150):
		await physics_frame
		advance(Vector3(4,-0.2,0))
		for foot in stage.locomotion.feet:
			if foot.normal.y < 0.99 and not foot.swinging:
				slope_contacts += 1
				for point in foot.corners:
					var offset: Vector3 = foot.node.global_transform * point - foot.contact
					check(offset.dot(foot.normal) > -0.02, "ramp_contact_plane")
	check(slope_contacts > 10,"ramp_raycast_support")
	print("RAMP_SUPPORT_PASS samples=",slope_contacts)
	# No animation treadmill when actual movement is stopped by a wall.
	stage._add_static_box("WalkQAWall",Vector3(22,2,65),Vector3(1,4,6),Color(0.2,0.2,0.2))
	stage.player.global_position = Vector3(20,1.716,65)
	stage.locomotion.reset()
	for i in range(120):
		await physics_frame
		advance(Vector3(7.5,-0.2,0))
	check(stage.locomotion.speed<0.12,"blocked_actual_speed_zero")
	check(not stage.locomotion.feet[0].swinging and not stage.locomotion.feet[1].swinging,"blocked_feet_idle")
	print("WALL_IDLE_PASS")
	place()
	# Every 0.35 s reverse/strafe while looking somewhere else.
	for i in range(180):
		await physics_frame
		var a := floorf(i/21.0) * PI * 0.5
		stage.camera_yaw.rotation.y = sin(i*0.045)
		advance(Vector3(sin(a)*7.5,-0.2,-cos(a)*7.5))
		if (stage.left_leg_rig.position.length() >= 3.1 or stage.right_leg_rig.position.length() >= 3.1) and not failures.has("sharp_turn_foot_reach"):
			print("REACH_DIAGNOSTIC frame=",i," actor=",stage.player.position," grounded=",stage.player.is_on_floor()," velocity=",stage.locomotion.velocity)
			for foot in stage.locomotion.feet: print("foot=",foot.node.position," contact=",foot.contact," phase=",foot.phase," swing=",foot.swinging," elapsed=",foot.elapsed," from=",foot.start," goal=",foot.goal)
		check(stage.left_leg_rig.position.length()<3.1 and stage.right_leg_rig.position.length()<3.1,"sharp_turn_foot_reach")
	print("SHARP_REVERSAL_PASS")
	stage.player.global_position += Vector3(10,0,10)
	stage._update_character_animation(dt)
	check(stage.left_leg_rig.position.length()<2.5,"teleport_reset")
	print("TELEPORT_RESET_PASS")
	stage.queue_free()
	for i in range(8): await process_frame
	print("TERRAIN_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
